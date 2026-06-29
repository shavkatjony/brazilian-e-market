-- Top 15 sellers by item revenue, with rating and on-time rate.
-- Feeds: bar chart of revenue; the extra columns annotate it.
-- Revenue = order_items.price (never payment_value).
WITH seller_order AS (
    SELECT seller_id, order_id, SUM(price) AS order_revenue
    FROM order_items
    GROUP BY seller_id, order_id
),
order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT
    so.seller_id,
    COUNT(*)                                   AS orders,
    ROUND(SUM(so.order_revenue), 2)            AS revenue,
    ROUND(AVG(orv.review_score), 2)            AS avg_review,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date
                                <= o.order_estimated_delivery_date
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct
FROM seller_order so
JOIN orders o              ON o.order_id = so.order_id
LEFT JOIN order_review orv ON orv.order_id = so.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY so.seller_id
HAVING COUNT(*) >= 20
ORDER BY revenue DESC
LIMIT 15;