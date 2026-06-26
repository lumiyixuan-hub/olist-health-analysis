# scripts/data_quality_check.py
# Cross-table data quality checks for olist PostgreSQL database
# Run this before applying FK constraints to identify issues

import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql+psycopg2://localhost/olist")

issues_found = 0

def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def ok(msg):
    print(f"  ✓ {msg}")

def warn(msg, count):
    global issues_found
    issues_found += count
    print(f"  ✗ {msg}")


# ── 1. Orphan Records ────────────────────────────────────────
section("1. ORPHAN RECORDS")

orphan_checks = [
    ("order_items",    "order_id", "orders",    "order_id"),
    ("order_reviews",  "order_id", "orders",    "order_id"),
    ("order_payments", "order_id", "orders",    "order_id"),
    ("orders",         "customer_id", "customers", "customer_id"),
    ("order_items",    "seller_id",  "sellers",  "seller_id"),
    ("order_items",    "product_id", "products", "product_id"),
]

for child_table, child_col, parent_table, parent_col in orphan_checks:
    query = f"""
        SELECT COUNT(*) AS cnt
        FROM {child_table} c
        LEFT JOIN {parent_table} p ON c.{child_col} = p.{parent_col}
        WHERE p.{parent_col} IS NULL
    """
    count = pd.read_sql(query, engine)["cnt"].iloc[0]
    if count == 0:
        ok(f"{child_table}.{child_col} → {parent_table}: no orphans")
    else:
        warn(f"{child_table}.{child_col} → {parent_table}: {count} orphan rows", count)


# ── 2. Missing Category Translations ────────────────────────
section("2. MISSING CATEGORY TRANSLATIONS")

query = """
    SELECT DISTINCT p.product_category_name
    FROM products p
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE ct.product_category_name IS NULL
      AND p.product_category_name IS NOT NULL
"""
missing = pd.read_sql(query, engine)

if missing.empty:
    ok("All product categories have translations")
else:
    warn(f"{len(missing)} categories missing translation:", len(missing))
    for cat in missing["product_category_name"]:
        print(f"     - {cat}")


# ── 3. Duplicate Primary Keys ────────────────────────────────
section("3. DUPLICATE PRIMARY KEYS")

pk_checks = [
    ("orders",               ["order_id"]),
    ("customers",            ["customer_id"]),
    ("sellers",              ["seller_id"]),
    ("products",             ["product_id"]),
    ("category_translation", ["product_category_name"]),
    ("order_reviews",        ["review_id"]),
    ("order_items",          ["order_id", "order_item_id"]),
    ("order_payments",       ["order_id", "payment_sequential"]),
]

for table, pk_cols in pk_checks:
    cols = ", ".join(pk_cols)
    query = f"""
        SELECT COUNT(*) AS cnt
        FROM (
            SELECT {cols}, COUNT(*) AS n
            FROM {table}
            GROUP BY {cols}
            HAVING COUNT(*) > 1
        ) dupes
    """
    count = pd.read_sql(query, engine)["cnt"].iloc[0]
    if count == 0:
        ok(f"{table} ({cols}): no duplicates")
    else:
        warn(f"{table} ({cols}): {count} duplicate key combinations", count)


# ── 4. Payment vs Order Items Total ─────────────────────────
section("4. PAYMENT TOTALS VS ORDER ITEMS TOTALS")

query = """
    WITH payment_totals AS (
        SELECT order_id, SUM(payment_value) AS total_payment
        FROM order_payments
        GROUP BY order_id
    ),
    item_totals AS (
        SELECT order_id, SUM(price + freight_value) AS total_items
        FROM order_items
        GROUP BY order_id
    )
    SELECT COUNT(*) AS cnt
    FROM payment_totals pt
    JOIN item_totals it ON pt.order_id = it.order_id
    WHERE ABS(pt.total_payment - it.total_items) > 1.0
"""
count = pd.read_sql(query, engine)["cnt"].iloc[0]
if count == 0:
    ok("Payment totals match order item totals for all orders")
else:
    warn(f"{count} orders have payment vs item total mismatch (> $1.00 difference)", count)
    print(f"     Note: deferred to Phase 2 for deeper investigation")


# ── Summary ──────────────────────────────────────────────────
section("SUMMARY")
if issues_found == 0:
    print("  ✓ All checks passed. Safe to apply FK constraints.")
else:
    print(f"  ✗ {issues_found} issues found. Review above before applying constraints.")