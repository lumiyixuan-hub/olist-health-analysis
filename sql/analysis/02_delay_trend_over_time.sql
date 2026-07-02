SELECT
    -- Extract year and month from purchase timestamp
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,

    -- Total orders per month
    COUNT(*) AS total_orders,

    -- Delayed orders per month
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate per month
    ROUND(
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct,

    -- Average delay days for delayed orders only
    ROUND(
        COALESCE(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0)::numeric, 2
    ), 0) AS avg_delay_days_delayed

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;