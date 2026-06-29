-- Retention % by acquisition cohort (first-purchase month).
-- Feeds: line chart of retention over time.
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