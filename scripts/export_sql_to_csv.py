"""
export_sql_to_csv.py

Purpose: Run the core analysis queries from sql/analysis/ against the
PostgreSQL database and export each result set as a standalone CSV file
for import into Tableau Public (free tier does not support a direct
database connection, so CSV is the required intermediate step).

Usage:
    python scripts/export_sql_to_csv.py

Requirements:
    pip install pandas sqlalchemy psycopg2-binary python-dotenv
"""

import os
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv

# ============================================================
# Load database credentials from .env (never hardcode credentials)
# ============================================================

load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

# Fail fast with a clear message if any required variable is missing.
# DB_PASSWORD is intentionally excluded here: Postgres.app on Mac often
# uses trust authentication for local connections, meaning no password
# is required, so an empty DB_PASSWORD is valid and not an error.
required_vars = {
    "DB_USER": DB_USER,
    "DB_NAME": DB_NAME,
}
missing = [name for name, value in required_vars.items() if not value]
if missing:
    raise EnvironmentError(
        f"Missing required environment variable(s) in .env: {', '.join(missing)}"
    )

# Build the connection string, handling the case where no password is set
if DB_PASSWORD:
    connection_string = (
        f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
else:
    connection_string = (
        f"postgresql://{DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )

engine = create_engine(connection_string)

# Ensure the output folder exists
OUTPUT_DIR = "tableau"
os.makedirs(OUTPUT_DIR, exist_ok=True)


# ============================================================
# Queries from 01_delivery_overview.sql
# ============================================================

# Query 1: Platform-wide delay rate and severity (KPI summary cards)
overview_kpi = """
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,
    ROUND(COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2) AS delay_rate_pct,
    ROUND(AVG(delivery_delay_days)::numeric, 2) AS avg_delay_days_all,
    ROUND(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0)::numeric, 2) AS avg_delay_days_delayed
FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL;
"""

# Query 2: Distribution of delay severity among delayed orders (histogram)
delay_days_distribution = """
SELECT
    delivery_delay_days,
    COUNT(*) AS delayed_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2) AS pct_of_all_delayed
FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days > 0
GROUP BY delivery_delay_days
ORDER BY delivery_delay_days ASC;
"""


# ============================================================
# Queries from 02_delay_trend_over_time.sql
# ============================================================

# Query 7 (superset of Query 1 and Query 6): monthly delay trend plus
# estimated delivery window and buffer utilization, in one time series
monthly_trend = """
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,
    ROUND(COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2) AS delay_rate_pct,
    ROUND(COALESCE(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0), 0)::numeric, 2) AS avg_delay_days_delayed,
    ROUND(AVG(delivery_delay_days)::numeric, 2) AS avg_delay_days_all,
    ROUND(AVG(estimated_delivery_days)::numeric, 2) AS avg_estimated_delivery_days,
    ROUND(((AVG(estimated_delivery_days) + AVG(delivery_delay_days)) / NULLIF(AVG(estimated_delivery_days), 0) * 100)::numeric, 2) AS pct_of_window_used
FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND estimated_delivery_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;
"""

# Query 2 (optional): delay rate by day of week
# Conclusion in the source SQL file: no meaningful weekday/weekend divide,
# kept here in case a small supporting chart is wanted on the dashboard
delay_by_dow = """
SELECT
    EXTRACT(DOW FROM order_purchase_timestamp) AS day_of_week,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,
    ROUND(COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2) AS delay_rate_pct
FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
GROUP BY EXTRACT(DOW FROM order_purchase_timestamp)
ORDER BY day_of_week;
"""

# Note: Queries 3/4/5 (monthly/weekly/daily volume-vs-delay correlation)
# each return a single coefficient, not a chartable series.
# These are recorded as text conclusions in the README instead of exported here.


# ============================================================
# Queries from 03_delay_by_state.sql
# ============================================================

# Query 1: Delay rate and severity by customer state
delay_by_state = """
SELECT
    c.customer_state,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE o.delivery_delay_days > 0) AS delayed_orders,
    ROUND(COUNT(*) FILTER (WHERE o.delivery_delay_days > 0) * 100.0 / COUNT(*), 2) AS delay_rate_pct,
    ROUND(AVG(o.delivery_delay_days) FILTER (WHERE o.delivery_delay_days > 0)::numeric, 2) AS avg_delay_days_delayed,
    ROUND(AVG(o.delivery_delay_days)::numeric, 2) AS avg_delay_days_all
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL
GROUP BY c.customer_state
ORDER BY delay_rate_pct DESC;
"""

# Query 2: Seller count and share by state
seller_distribution_by_state = """
SELECT
    seller_state,
    COUNT(*) AS seller_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2) AS pct_of_all_sellers
FROM sellers
GROUP BY seller_state
ORDER BY seller_count DESC;
"""

# Query 3: Same-state vs cross-state delay rate comparison
same_vs_cross_state = """
SELECT
    CASE 
        WHEN s.seller_state = c.customer_state THEN 'Same State'
        ELSE 'Cross State'
    END AS shipping_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.order_id) FILTER (WHERE o.delivery_delay_days > 0) AS delayed_orders,
    ROUND(COUNT(DISTINCT o.order_id) FILTER (WHERE o.delivery_delay_days > 0) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS delay_rate_pct,
    ROUND(AVG(o.delivery_delay_days) FILTER (WHERE o.delivery_delay_days > 0)::numeric, 2) AS avg_delay_days_delayed
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL
GROUP BY shipping_type
ORDER BY delay_rate_pct DESC;
"""


# ============================================================
# Queries from 04_delay_vs_review_score.sql
# ============================================================

# Query 2: Average review score by delay severity bucket
# Highlights that satisfaction drops sharply early and then plateaus
review_score_by_delay_bucket = """
SELECT
    CASE
        WHEN o.delivery_delay_days <= 0 THEN 'On Time'
        WHEN o.delivery_delay_days BETWEEN 1 AND 3 THEN '1-3 Days Late'
        WHEN o.delivery_delay_days BETWEEN 4 AND 7 THEN '4-7 Days Late'
        WHEN o.delivery_delay_days BETWEEN 8 AND 14 THEN '8-14 Days Late'
        ELSE '15+ Days Late'
    END AS delay_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL
GROUP BY 
    CASE
        WHEN o.delivery_delay_days <= 0 THEN 'On Time'
        WHEN o.delivery_delay_days BETWEEN 1 AND 3 THEN '1-3 Days Late'
        WHEN o.delivery_delay_days BETWEEN 4 AND 7 THEN '4-7 Days Late'
        WHEN o.delivery_delay_days BETWEEN 8 AND 14 THEN '8-14 Days Late'
        ELSE '15+ Days Late'
    END
ORDER BY MIN(o.delivery_delay_days);
"""

# Query 3: Review score distribution as percentages, on-time vs delayed
# Used instead of Query 1 (raw counts) since percentages allow a fair
# side-by-side bar chart comparison between the two groups
review_score_pct_by_status = """
SELECT
    CASE 
        WHEN o.delivery_delay_days > 0 THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) FILTER (WHERE r.review_score = 1) * 100.0 / COUNT(*), 2) AS pct_score_1,
    ROUND(COUNT(*) FILTER (WHERE r.review_score = 2) * 100.0 / COUNT(*), 2) AS pct_score_2,
    ROUND(COUNT(*) FILTER (WHERE r.review_score = 3) * 100.0 / COUNT(*), 2) AS pct_score_3,
    ROUND(COUNT(*) FILTER (WHERE r.review_score = 4) * 100.0 / COUNT(*), 2) AS pct_score_4,
    ROUND(COUNT(*) FILTER (WHERE r.review_score = 5) * 100.0 / COUNT(*), 2) AS pct_score_5
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL
GROUP BY delivery_status
ORDER BY delivery_status DESC;
"""


# ============================================================
# Run all queries and export each result to its own CSV file
# ============================================================

queries_to_export = {
    f"{OUTPUT_DIR}/overview_kpi.csv": overview_kpi,
    f"{OUTPUT_DIR}/delay_days_distribution.csv": delay_days_distribution,
    f"{OUTPUT_DIR}/monthly_trend.csv": monthly_trend,
    f"{OUTPUT_DIR}/delay_by_dow.csv": delay_by_dow,
    f"{OUTPUT_DIR}/delay_by_state.csv": delay_by_state,
    f"{OUTPUT_DIR}/seller_distribution_by_state.csv": seller_distribution_by_state,
    f"{OUTPUT_DIR}/same_vs_cross_state.csv": same_vs_cross_state,
    f"{OUTPUT_DIR}/review_score_by_delay_bucket.csv": review_score_by_delay_bucket,
    f"{OUTPUT_DIR}/review_score_pct_by_status.csv": review_score_pct_by_status,
}

if __name__ == "__main__":
    for csv_path, query in queries_to_export.items():
        df = pd.read_sql(query, engine)
        df.to_csv(csv_path, index=False)
        print(f"Exported: {csv_path} ({len(df)} rows)")

    print("\nAll exports complete. Files are saved under the 'tableau/' folder.")
