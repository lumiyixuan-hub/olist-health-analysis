-- ============================================================
-- 04_delay_vs_review_score.sql
-- Purpose: Examine whether delivery delay has a measurable impact on customer satisfaction, as reflected in review scores.
-- ============================================================

-- Query 1: Average review score and score distribution by delivery status
-- Business question: Do delayed orders receive meaningfully lower review scores than on-time orders, and how does the full distribution of scores differ between the two groups?
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


-- Query 2: Average review score by delay severity bucket
-- Business question: Does review score decline steadily as delay severity increases, or does satisfaction bottom out quickly once any meaningful delay occurs?
SELECT
    CASE
        WHEN o.delivery_delay_days <= 0 THEN 'On Time'
        WHEN o.delivery_delay_days BETWEEN 1 AND 3 THEN '1-3 Days Late'
        WHEN o.delivery_delay_days BETWEEN 4 AND 7 THEN '4-7 Days Late'
        WHEN o.delivery_delay_days BETWEEN 8 AND 14 THEN '8-14 Days Late'
        ELSE '15+ Days Late'
    END AS delay_bucket,

    -- Number of orders in each bucket
    COUNT(*) AS total_orders,

    -- Average review score per bucket
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


-- Query 3: Review score distribution as percentages, by delivery status
-- Business question: What percentage of delayed versus on-time orders fall into each star rating, expressed as a proportion rather than a raw count, to allow fair visual comparison between the two groups?

SELECT
    CASE 
        WHEN o.delivery_delay_days > 0 THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,

    COUNT(*) AS total_orders,

    -- Percentage of orders in this group that gave each star rating
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


-- Conclusion: Review score does not decline linearly with delay severity - it drops sharply as soon as any delay occurs (4.29 to 3.29 within the first 1-3 days late) and then plateaus once delay exceeds a week (1.67 for 8-14 days vs 1.72 for 15+ days), suggesting satisfaction bottoms out quickly rather than worsening proportionally with delay length. This is reinforced by the percentage breakdown: on-time orders are dominated by 5-star reviews (62.31%), while delayed orders are dominated by 1-star reviews (53.81%), confirming that delay does not just lower scores modestly but inverts the entire rating distribution.