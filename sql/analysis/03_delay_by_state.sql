-- ============================================================
-- 03_delay_by_state.sql
-- Purpose: Examine how delivery delay varies across Brazilian states, in order to identify which geographic regions carry the highest delay risk and why.
-- ============================================================

-- Query 1: Delay rate and severity by customer state
-- Business question: Which customer states experience the highest delay rates and the most severe delays, and does this align with Brazil's geographic distribution of sellers versus customers?

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




-- Query 2: Seller distribution by state
-- Business question: Are sellers concentrated in specific states (e.g. the southeast), which would help explain why customers in distant states experience higher delay rates?

SELECT
    seller_state,
    COUNT(*) AS seller_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::numeric, 2) AS pct_of_all_sellers

FROM sellers

GROUP BY seller_state
ORDER BY seller_count DESC;



-- Query 3: Delay rate for same-state vs cross-state delivery
-- Business question: Do orders shipped across state lines experience meaningfully higher delay rates than orders shipped within the same state, confirming that distance between seller and customer is a key driver of delay?

WITH order_shipping_type AS (
    SELECT
        o.order_id,
        o.delivery_delay_days,
        -- If ANY item in this order comes from a seller in a different state 
        -- than the customer, the whole order is classified as Cross State.
        -- This is a conservative approximation: the dataset records only a single 
        -- delivery timestamp per order (not per seller-shipment), so orders with 
        -- items from multiple sellers across different states cannot be split 
        -- into separate shipments here. 247 orders (0.26%) were affected by this 
        -- reclassification.
        CASE 
            WHEN BOOL_OR(s.seller_state != c.customer_state) THEN 'Cross State'
            ELSE 'Same State'
        END AS shipping_type
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.delivery_delay_days IS NOT NULL
    GROUP BY o.order_id, o.delivery_delay_days
)

SELECT
    shipping_type,

    -- Total orders in this group
    COUNT(*) AS total_orders,

    -- Delayed orders in this group
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate for this group
    ROUND(
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct,

    -- Average delay days for delayed orders only
    ROUND(
        AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0)::numeric, 2
    ) AS avg_delay_days_delayed

FROM order_shipping_type
GROUP BY shipping_type
ORDER BY delay_rate_pct DESC;

-- Conclusion: Sellers are heavily concentrated in São Paulo (59.74% of all sellers), while delay rates are highest in northeastern states such as Alagoas and Maranhão. Cross-state shipments show a delay rate nearly twice that of same-state shipments (8.03% vs 4.52%), with longer average delays when they do occur (11.49 vs 7.86 days). This confirms that seller concentration in the southeast, combined with the distance to customers in other regions, is a key structural driver of delivery delay.

