-- ============================================================
-- 01_delivery_overview.sql
-- Purpose: Establish the baseline picture of delivery delay across the whole platform - how common delays are, and how severe they are on average.
-- ============================================================

-- Query 1: Overall delay rate and severity
-- Business question: Out of all delivered orders, what percentage arrived late, and by how many days on average?

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
    -- (negative value = orders arrive early on average)
    ROUND(AVG(delivery_delay_days)::numeric, 2) AS avg_delay_days_all,

    -- Average delay days for delayed orders only
    -- (how bad is the delay, once it happens)
    ROUND(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0)::numeric, 2) AS avg_delay_days_delayed

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL;


-- Query 2: Distribution of delay days among delayed orders
-- Business question: Among orders that are delayed, are most of them delayed by just a few days, or is there a long tail of severely delayed orders? This tells us whether fixing delay is a "shave off a few days" problem or a structural long-haul logistics problem.

SELECT
    delivery_delay_days,

    -- Number of orders delayed by this exact number of days
    COUNT(*) AS delayed_orders,

    -- What percentage of ALL delayed orders this group represents
    -- (SUM(COUNT(*)) OVER () sums across all groups, so each row
    -- can be divided by the grand total of delayed orders)
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2) AS pct_of_all_delayed

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days > 0

GROUP BY delivery_delay_days
ORDER BY delivery_delay_days ASC;