/* 02_delivery_vs_reviews.sql
   Brazilian E-Commerce Analysis | SQLite

   Question: does delivery performance affect review scores?

   knowthat brp : only delivered orders have a delivery date. Filtering
   on order_status = 'delivered' AND order_delivered_customer_date
   IS NOT NULL is required, or NULLs corrupt every average.
   (Confirmed in 00_exploration, step 5c.)
 */

-- 000000000000000000000000000000000000000000000


-- 1. Delivery overview: speed, accuracy vs estimate, on-time rate
-- avg_vs_estimate < 0 means deliveries beat the promised date on
-- average. Timestamps are ISO text, so '<=' compares them correctly.
SELECT
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)          AS avg_delivery_days,
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_estimated_delivery_date)), 1)     AS avg_vs_estimate_days,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date
                                <= order_estimated_delivery_date
                           THEN 1 ELSE 0 END) / COUNT(*), 1)       AS on_time_rate_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- 2. The headline: late vs on-time, and the hit to reviews
-- Reviews are averaged per order first (a few orders have >1).
-- 100.0 forces float division so the percentage isn't truncated to 0.
WITH delivered AS (
    SELECT order_id,
           CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                THEN 'Late'
                ELSE 'On time / early'
           END AS delivery_status
    FROM orders  WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT
    d.delivery_status,
    COUNT(*)                                                      AS orders,
    ROUND(AVG(r.review_score), 2)                                 AS avg_review,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                          AS pct_1_2_star
FROM delivered d
JOIN order_review r ON r.order_id = d.order_id
GROUP BY d.delivery_status;


-- 3. The gradient: review score across degrees of lateness
WITH delivered AS (
    SELECT order_id,
           julianday(order_delivered_customer_date)
           - julianday(order_estimated_delivery_date) AS days_vs_estimate
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT
    CASE
        WHEN days_vs_estimate <= 0 THEN '1: on time / early'
        WHEN days_vs_estimate <= 3 THEN '2: 1-3 days late'
        WHEN days_vs_estimate <= 7 THEN '3: 4-7 days late'
        ELSE                            '4: 8+ days late'
    END                            AS delivery_status,
    COUNT(*)                       AS orders,
    ROUND(AVG(r.review_score), 2)  AS avg_review
FROM delivered d
JOIN order_review r ON r.order_id = d.order_id
GROUP BY delivery_status
ORDER BY delivery_status;


-- 4. Delivery speed over time (watch for seasonal degradation)
SELECT
    strftime('%Y-%m', order_purchase_timestamp)                  AS month,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)         AS avg_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY month
ORDER BY month;


-- 5. Worst states by average lateness vs estimate
-- HAVING filters out tiny states whose averages aren't meaningful.
SELECT
    c.customer_state,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_estimated_delivery_date)), 1)  AS avg_days_vs_estimate
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY avg_days_vs_estimate DESC;