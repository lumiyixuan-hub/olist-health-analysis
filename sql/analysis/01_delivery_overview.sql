SELECT
    -- Total number of delivered orders
    COUNT(*) AS total_orders,

    -- Number of delayed orders (delay > 0 days)
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate as a percentage
    ROUND(
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct,

    -- Average delay days across all delivered orders
    ROUND(AVG(delivery_delay_days)::numeric, 2) AS avg_delay_days_all,

    -- Average delay days for delayed orders only
    ROUND(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0)::numeric, 2) AS avg_delay_days_delayed

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL;