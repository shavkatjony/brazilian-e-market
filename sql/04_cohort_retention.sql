/* ============================================================
   04_cohort_retention.sql
   Brazilian E-Commerce Analysis | SQLite

   Question: do customers come back, do certain acquisition
   cohorts retain better, and how long until a second order?

   Reality check: Olist is a near one-time-purchase marketplace,
   so retention is low — that low number IS the finding.
   ============================================================ */


-- 1. Overall retention headline: how many ever bought twice
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                              AS customers,
    SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)          AS returned,
    ROUND(100.0 * SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                  AS retention_pct
FROM customer_orders;


-- 2. Acquisition trend: new customers per first-purchase month
WITH first_purchase AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_order
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    strftime('%Y-%m', first_order) AS cohort_month,
    COUNT(*)                       AS new_customers
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month;


-- 3. Retention by cohort: did some months' customers come back more?
-- Each customer is bucketed by their first-purchase month, then we
-- check how many of that cohort ever placed a second order.
WITH customer_first AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_order,
           COUNT(DISTINCT o.order_id)      AS lifetime_orders
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    strftime('%Y-%m', first_order)                          AS cohort_month,
    COUNT(*)                                                AS cohort_size,
    SUM(CASE WHEN lifetime_orders >= 2 THEN 1 ELSE 0 END)   AS returned,
    ROUND(100.0 * SUM(CASE WHEN lifetime_orders >= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                    AS retention_pct
FROM customer_first
GROUP BY cohort_month
ORDER BY cohort_month;


-- 4. Time to second purchase (for those who returned)
-- ROW_NUMBER orders each customer's purchases; we pull order 1 and 2
-- and measure the gap. Uses the window functions you just learned.
WITH ranked AS (
    SELECT c.customer_unique_id,
           o.order_purchase_timestamp AS order_ts,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                              ORDER BY o.order_purchase_timestamp) AS seq
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
),
first_two AS (
    SELECT customer_unique_id,
           MAX(CASE WHEN seq = 1 THEN order_ts END) AS first_order,
           MAX(CASE WHEN seq = 2 THEN order_ts END) AS second_order
    FROM ranked
    WHERE seq <= 2
    GROUP BY customer_unique_id
)
SELECT
    COUNT(second_order)                                           AS repeat_customers,
    ROUND(AVG(julianday(second_order) - julianday(first_order)), 1)
                                                                 AS avg_days_to_repeat
FROM first_two
WHERE second_order IS NOT NULL;