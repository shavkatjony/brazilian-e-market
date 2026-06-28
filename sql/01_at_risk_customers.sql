/* 01_at_risk_customers.sql
   Brazilian E-Commerce Analysis | SQLite

   Question:
  -  who are our valuable customers, 
  - how loyal is the base, and 
  - which customers have gone quiet (at-risk)?

   Note: the real person is customer_unique_id. customer_id is
   issued per order, so it must never be the grouping key.
   ============================================================ */


-- 1. Loyalty snapshot: base size, one-time vs repeat, repeat rate
WITH orders_per_customer AS (SELECT c.customer_unique_id,
     COUNT(o.order_id) AS orders
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                                    AS total_customers,
    SUM(CASE WHEN orders = 1 THEN 1 ELSE 0 END)                 AS one_time_customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)                 AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                        AS repeat_rate_pct
FROM orders_per_customer;


-- 2. Customer lifetime value
-- payments has one row per payment method, so total per order is
-- summed first; avg_order_value is then spend / orders (per order,
-- not per payment row).
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
)
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id)                                  AS orders,
    ROUND(SUM(ot.order_value), 2)                               AS total_spent,
    ROUND(SUM(ot.order_value) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM customers c
JOIN orders o        ON o.customer_id = c.customer_id
JOIN order_totals ot ON ot.order_id = o.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC;          -- add LIMIT 20 for the top-customers view


-- 3. Spending distribution: how the base splits by total spend
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
customer_spend AS (
    SELECT c.customer_unique_id,
           SUM(ot.order_value) AS total_spent
    FROM customers c
    JOIN orders o        ON o.customer_id = c.customer_id
    JOIN order_totals ot ON ot.order_id = o.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN total_spent <  100 THEN '1: under 100'
        WHEN total_spent <  300 THEN '2: 100-299'
        WHEN total_spent <  500 THEN '3: 300-499'
        WHEN total_spent < 1000 THEN '4: 500-999'
        ELSE                         '5: 1000+'
    END                AS spend_band,
    COUNT(*)           AS customers
FROM customer_spend
GROUP BY spend_band
ORDER BY spend_band;


--  4. At-risk segmentation
-- Recency measured against the last date in the data, not today,
-- since the dataset is historical. Cancelled/unavailable orders
-- aren't real engagement, so they're excluded.
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
customer_recency AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)      AS orders,
        ROUND(SUM(ot.order_value), 2)   AS total_spent,
        MAX(o.order_purchase_timestamp) AS last_order,
        CAST(julianday((SELECT MAX(order_purchase_timestamp) FROM orders))
             - julianday(MAX(o.order_purchase_timestamp)) AS INT) AS days_since_last_order
    FROM customers c
    JOIN orders o        ON o.customer_id = c.customer_id
    JOIN order_totals ot ON ot.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN days_since_last_order <=  90 THEN '1: Active (<=90d)'
        WHEN days_since_last_order <= 180 THEN '2: Cooling (<=180d)'
        WHEN days_since_last_order <= 365 THEN '3: At Risk (<=365d)'
        ELSE                                   '4: Churned (>365d)'
    END                           AS segment,
    COUNT(*)                      AS customers,
    ROUND(AVG(total_spent), 2)    AS avg_spend
FROM customer_recency
GROUP BY segment
ORDER BY segment;


-- 5. Win-back priority list
-- Repeat buyers who have since gone quiet (>180 days). Highest
-- value first — these proved they'll buy again, then stopped.
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
customer_recency AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)      AS orders,
        ROUND(SUM(ot.order_value), 2)   AS total_spent,
        MAX(o.order_purchase_timestamp) AS last_order,
        CAST(julianday((SELECT MAX(order_purchase_timestamp) FROM orders))
             - julianday(MAX(o.order_purchase_timestamp)) AS INT) AS days_since_last_order
    FROM customers c
    JOIN orders o        ON o.customer_id = c.customer_id
    JOIN order_totals ot ON ot.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)


SELECT customer_unique_id,
    orders,
    total_spent,
    DATE(last_order)        AS last_order_date,
    days_since_last_order
FROM customer_recency
WHERE orders >= 2
  AND days_since_last_order > 180
ORDER BY total_spent DESC;