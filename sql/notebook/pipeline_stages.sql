-- Slowest states by actual delivery speed.
-- Feeds: horizontal bar chart of avg delivery days by state.
SELECT
    c.customer_state,
    COUNT(*)                                                AS orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_purchase_timestamp)), 1)  AS avg_delivery_days
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;