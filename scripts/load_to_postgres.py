# scripts/load_to_postgres.py
# Load cleaned CSVs into PostgreSQL olist database

import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.types import Text, Float, BigInteger, TIMESTAMP
import os

# ── Connection ──────────────────────────────────────────────
engine = create_engine("postgresql+psycopg2://localhost/olist")

CLEANED_DIR = "data/cleaned"

# ── dtype mappings ──────────────────────────────────────────
orders_dtypes = {
    "order_id":                      Text(),
    "customer_id":                   Text(),
    "order_status":                  Text(),
    "order_purchase_timestamp":      TIMESTAMP(),
    "order_approved_at":             TIMESTAMP(),
    "order_delivered_carrier_date":  TIMESTAMP(),
    "order_delivered_customer_date": TIMESTAMP(),
    "order_estimated_delivery_date": TIMESTAMP(),
    "delivery_delay_days":           Float(),
    "estimated_delivery_days":       BigInteger(),
}

order_items_dtypes = {
    "order_id":           Text(),
    "order_item_id":      BigInteger(),
    "product_id":         Text(),
    "seller_id":          Text(),
    "shipping_limit_date": TIMESTAMP(),
    "price":              Float(),
    "freight_value":      Float(),
}

order_reviews_dtypes = {
    "review_id":               Text(),
    "order_id":                Text(),
    "review_score":            BigInteger(),
    "review_comment_title":    Text(),
    "review_comment_message":  Text(),
    "review_creation_date":    TIMESTAMP(),
    "review_answer_timestamp": TIMESTAMP(),
}

# ── File mapping ────────────────────────────────────────────
tables = {
    "orders":               ("orders_cleaned.csv",                orders_dtypes),
    "order_items":          ("order_items_cleaned.csv",           order_items_dtypes),
    "order_payments":       ("order_payments_cleaned.csv",        None),
    "order_reviews":        ("order_reviews_cleaned.csv",         order_reviews_dtypes),
    "customers":            ("customers_cleaned.csv",             None),
    "sellers":              ("sellers_cleaned.csv",               None),
    "products":             ("products_cleaned.csv",              None),
    "category_translation": ("category_translation_cleaned.csv",  None),
    "geolocation":          ("geolocation_cleaned.csv",           None),
}

# ── Load ─────────────────────────────────────────────────────
for table_name, (filename, dtype) in tables.items():
    filepath = os.path.join(CLEANED_DIR, filename)
    df = pd.read_csv(filepath, parse_dates=True)
    df.to_sql(table_name, engine, if_exists="replace", index=False, dtype=dtype)
    print(f"✓ {table_name}: {len(df)} rows loaded")

print("\nAll tables loaded successfully.")