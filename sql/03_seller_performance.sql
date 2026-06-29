/* ============================================================
   03_seller_performance.sql
   Brazilian E-Commerce Analysis | SQLite

   Question: which sellers drive the business, and who is
   strong vs weak on revenue, ratings, and delivery?

   Note: a seller's revenue is the PRICE of their items in
   order_items — never payment_value, which is the whole
   order's total and can't be split across sellers.
   ============================================================ */


-- 1. Most active sellers by order volume
SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*)                 AS items_sold
FROM order_items
GROUP BY seller_id
ORDER BY orders DESC;          -- add LIMIT 20 for the top view


-- 2. Top sellers by revenue
-- price = item revenue, freight_value = shipping charged.
SELECT
    seller_id,
    COUNT(DISTINCT order_id)     AS orders,
    ROUND(SUM(price), 2)         AS item_revenue,
    ROUND(SUM(freight_value), 2) AS freight_revenue
FROM order_items
GROUP BY seller_id
ORDER BY item_revenue DESC;


-- 3. Rating leaders (min 20 reviewed orders so averages are stable)
-- Reviews are taken to order level first, then matched to the
-- distinct orders each seller appears in.
WITH seller_order AS (
    SELECT DISTINCT seller_id, order_id
    FROM order_items
),
order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT
    so.seller_id,
    COUNT(*)                        AS reviewed_orders,
    ROUND(AVG(orv.review_score), 2) AS avg_review
FROM seller_order so
JOIN order_review orv ON orv.order_id = so.order_id
GROUP BY so.seller_id
HAVING COUNT(*) >= 20
ORDER BY avg_review DESC;


-- 4. Seller scorecard: volume, revenue, rating, speed, reliability
-- Grain is (seller, order): each seller's revenue within an order
-- is summed first, so nothing fans out and revenue stays correct.
WITH seller_order AS (
    SELECT
        seller_id,
        order_id,
        SUM(price) AS order_revenue
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
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date
                                <= o.order_estimated_delivery_date
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct
FROM seller_order so
JOIN orders o          ON o.order_id = so.order_id
LEFT JOIN order_review orv ON orv.order_id = so.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY so.seller_id
HAVING COUNT(*) >= 20
ORDER BY revenue DESC;