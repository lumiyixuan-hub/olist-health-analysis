SELECT
    -- Classify orders as delayed or on time
    CASE 
        WHEN o.delivery_delay_days > 0 THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,

    -- Number of orders in each group
    COUNT(*) AS total_orders,

    -- Average review score per group
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score,

    -- Distribution of review scores
    COUNT(*) FILTER (WHERE r.review_score = 1) AS score_1,
    COUNT(*) FILTER (WHERE r.review_score = 2) AS score_2,
    COUNT(*) FILTER (WHERE r.review_score = 3) AS score_3,
    COUNT(*) FILTER (WHERE r.review_score = 4) AS score_4,
    COUNT(*) FILTER (WHERE r.review_score = 5) AS score_5

FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.delivery_delay_days IS NOT NULL

GROUP BY delivery_status
ORDER BY delivery_status DESC;