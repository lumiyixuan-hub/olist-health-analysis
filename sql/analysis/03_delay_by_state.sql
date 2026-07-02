SELECT
    c.customer_state,

    -- Total orders per state
    COUNT(*) AS total_orders,

    -- Delayed orders per state
    COUNT(*) FILTER (WHERE o.delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate per state
    ROUND(
        COUNT(*) FILTER (WHERE o.delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct,

    -- Average delay days for delayed orders only
    ROUND(
        AVG(o.delivery_delay_days) FILTER (WHERE o.delivery_delay_days > 0)::numeric, 2
    ) AS avg_delay_days_delayed,

    -- Average delay days across all orders (negative = early on average)
    ROUND(AVG(o.delivery_delay_days)::numeric, 2) AS avg_delay_days_all

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL

GROUP BY c.customer_state
ORDER BY delay_rate_pct DESC;