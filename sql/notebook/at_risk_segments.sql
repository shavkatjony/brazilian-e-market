-- Customers grouped by recency segment. Feeds: bar chart of
-- segment vs customer count (the at-risk story).
WITH order_totals AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
customer_recency AS (
    SELECT
        c.customer_unique_id,
        ROUND(SUM(ot.order_value), 2) AS total_spent,
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
        WHEN days_since_last_order <=  90 THEN '1: Active'
        WHEN days_since_last_order <= 180 THEN '2: Cooling'
        WHEN days_since_last_order <= 365 THEN '3: At Risk'
        ELSE                                   '4: Churned'
    END                        AS segment,
    COUNT(*)                   AS customers,
    ROUND(AVG(total_spent), 2) AS avg_spend
FROM customer_recency
GROUP BY segment
ORDER BY segment;