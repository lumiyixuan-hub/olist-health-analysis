-- ============================================================
-- 02_delay_trend_over_time.sql
-- Purpose: Track how delivery delay rate and severity change month over month, in order to identify seasonal spikes or external shocks such as Black Friday or logistics strikes.
-- ============================================================

-- Query 1: Monthly delay rate and severity trend
-- Business question: Are certain months or periods experiencing significantly higher delay rates than others, and what might explain those spikes?

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

    -- Average delay days for delayed orders only, defaulting to 0 when a month has no delayed orders at all
    ROUND(
        COALESCE(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0), 0)::numeric, 2
    ) AS avg_delay_days_delayed

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;

-- Conclusion: Excluding 2016-09 and 2016-12 (each with only 1 order, statistically insignificant), delay rate shows three clear spikes above 10%: Nov 2017 (12.40%), Feb 2018 (14.13%), and Mar 2018 (18.96%), corresponding to Black Friday demand surge and the early-2018 logistics strike, with average delay days also slightly elevated (10-12 days) during these months, compared to the total average delievery delay days. Notably, Jan-Mar 2017 shows an inverse pattern: delay rate is low (2.94%-4.56%), but average delay days for delayed orders is much higher (20-25 days) than any other period, likely reflecting the platform's early-stage logistics network being less mature and order volume still relatively low (748-2546 orders per month) at this time.



-- Query 2: Delay rate by day of week
-- Business question: Do orders placed on weekends experience higher delay rates than orders placed on weekdays, potentially due to warehouses not processing orders until the following business day?

SELECT
    -- Extract day of week (0 = Sunday, 6 = Saturday)
    EXTRACT(DOW FROM order_purchase_timestamp) AS day_of_week,

    -- Total orders placed on this day of week
    COUNT(*) AS total_orders,

    -- Delayed orders placed on this day of week
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate for this day of week
    ROUND(
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL

GROUP BY EXTRACT(DOW FROM order_purchase_timestamp)
ORDER BY day_of_week;

-- Conclusion: Delay rate stays within a narrow 6-7% range across all days of the week, with no clear weekday/weekend divide. This rules out purchase day as a meaningful driver of delivery delay.



-- Query 3: Correlation between monthly order volume and delay rate
-- Business question: Is there a measurable relationship between how many orders are placed in a month and how likely those orders are to be delayed - in other words, does surge demand strain the logistics system?

SELECT
    ROUND(
        CORR(monthly_orders, monthly_delay_rate)::numeric, 3
    ) AS correlation_coefficient

FROM (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
        COUNT(*) AS monthly_orders,
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*) AS monthly_delay_rate
    FROM orders
    WHERE order_status = 'delivered'
      AND delivery_delay_days IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
) AS monthly_stats;


-- Query 4: Correlation between weekly order volume and delay rate
-- Business question: Does using a finer time granularity (weekly instead of monthly) reveal a stronger relationship between order volume surges and delay rate, given that monthly aggregation may dilute short-term spikes like Black Friday?

SELECT
    ROUND(
        CORR(weekly_orders, weekly_delay_rate)::numeric, 3
    ) AS correlation_coefficient

FROM (
    SELECT
        DATE_TRUNC('week', order_purchase_timestamp) AS order_week,
        COUNT(*) AS weekly_orders,
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*) AS weekly_delay_rate
    FROM orders
    WHERE order_status = 'delivered'
      AND delivery_delay_days IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('week', order_purchase_timestamp)
) AS weekly_stats;


-- Query 5: Correlation between daily order volume and delay rate
-- Business question: Does using an even finer time granularity (daily instead of weekly or monthly) reveal a relationship between order volume surges and delay rate that coarser time units failed to capture?

SELECT
    ROUND(
        CORR(daily_orders, daily_delay_rate)::numeric, 3
    ) AS correlation_coefficient

FROM (
    SELECT
        DATE_TRUNC('day', order_purchase_timestamp) AS order_day,
        COUNT(*) AS daily_orders,
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*) AS daily_delay_rate
    FROM orders
    WHERE order_status = 'delivered'
      AND delivery_delay_days IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('day', order_purchase_timestamp)
) AS daily_stats;

-- Conclusion: Correlation between order volume and delay rate varies by time granularity - monthly (-0.238), weekly (0.06), and daily (0.302). The correlation strengthens as granularity narrows, suggesting that short-term demand surges (e.g. single-day spikes around Black Friday) have a mild but real association with delay, while this effect gets diluted when aggregated over longer periods. However, even at the daily level the correlation (0.302) remains weak-to-moderate, indicating that order volume alone is not a strong driver of delay. The more likely explanation is specific disruptive events (demand surges, logistics strikes) rather than sustained high-volume pressure.



-- Query 6: Estimated delivery window over time
-- Business question: Has Olist been setting increasingly conservative (longer) estimated delivery windows over time, which would inflate the "days ahead of schedule" metric without reflecting genuine logistics improvement?

SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,

    -- Average number of days between purchase and estimated delivery date
    ROUND(AVG(estimated_delivery_days)::numeric, 2) AS avg_estimated_delivery_days

FROM orders
WHERE order_status = 'delivered'
  AND estimated_delivery_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;

-- Conclusion: No, Olist did not set longer estimated delivery window over time.



-- Query 7: Estimated delivery window vs actual delay, side by side
-- Business question: As Olist tightened its estimated delivery windows over time, did the buffer between promised and actual delivery shrink proportionally, leaving less room to absorb external shocks?

SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,

    -- Total orders per month
    COUNT(*) AS total_orders,

    -- Delayed orders per month
    COUNT(*) FILTER (WHERE delivery_delay_days > 0) AS delayed_orders,

    -- Delay rate per month
    ROUND(
        COUNT(*) FILTER (WHERE delivery_delay_days > 0) * 100.0 / COUNT(*), 2
    ) AS delay_rate_pct,

    -- Average delay days for delayed orders only, defaulting to 0 when a month has no delayed orders at all
    ROUND(
        COALESCE(AVG(delivery_delay_days) FILTER (WHERE delivery_delay_days > 0), 0)::numeric, 2
    ) AS avg_delay_days_delayed,

    -- Average actual delay/lead days across all orders (negative = early)
    ROUND(AVG(delivery_delay_days)::numeric, 2) AS avg_delay_days_all,

    -- Average estimated delivery window (days from purchase to promised delivery)
    ROUND(AVG(estimated_delivery_days)::numeric, 2) AS avg_estimated_delivery_days,

    -- What percentage of the promised delivery window was actually used on average
    -- (higher percentage = less buffer left to absorb disruptions)
    ROUND(
    ((AVG(estimated_delivery_days) + AVG(delivery_delay_days)) / NULLIF(AVG(estimated_delivery_days), 0) * 100)::numeric, 2
    ) AS pct_of_window_used

FROM orders
WHERE order_status = 'delivered'
  AND delivery_delay_days IS NOT NULL
  AND estimated_delivery_days IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;


-- Conclusion: The percentage of the promised delivery window actually used stayed in a stable 30-50% range through most of 2017, but spiked to 60-70% during periods of known disruption (November 2017 Black Friday surge, early 2018 logistics strikes). This confirms that Olist's delivery system normally operates with a healthy buffer, but that buffer gets consumed rapidly under demand or supply shocks, directly explaining why delay rates spiked during those same periods.