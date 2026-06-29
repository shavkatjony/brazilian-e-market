-- Average review score across degrees of lateness.
-- Feeds: bar chart showing reviews fall as orders run late.
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
    END                           AS delivery_status,
    COUNT(*)                      AS orders,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM delivered d
JOIN order_review r ON r.order_id = d.order_id
GROUP BY delivery_status
ORDER BY delivery_status;