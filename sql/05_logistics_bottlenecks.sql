/* ============================================================
   05_logistics_bottlenecks.sql
   Brazilian E-Commerce Analysis | SQLite

   Question: where do delivery delays come from — which stage
   of the pipeline, and which regions?

   The orders table timestamps each stage:
   purchase -> approved -> handed to carrier -> delivered.
   Differencing them shows which leg is the bottleneck.
   Confirm these column names with PRAGMA table_info(orders).
   ============================================================ */


-- 1. The bottleneck: average days spent in each pipeline stage
-- approval = payment clearing, handling = seller dispatch,
-- transit = carrier to customer. The biggest number is the
-- stage to fix.
SELECT
    ROUND(AVG(julianday(order_approved_at)
              - julianday(order_purchase_timestamp)), 1)          AS approval_days,
    ROUND(AVG(julianday(order_delivered_carrier_date)
              - julianday(order_approved_at)), 1)                 AS handling_days,
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_delivered_carrier_date)), 1)      AS transit_days,
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)          AS total_days
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at            IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;


-- 2. Slowest states by actual delivery speed
SELECT
    c.customer_state,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_purchase_timestamp)), 1)       AS avg_delivery_days
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;


-- 3. Cities that most overshoot the promised date
-- (min 30 orders so a single bad order doesn't top the list)
SELECT
    c.customer_city,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_estimated_delivery_date)), 1)  AS avg_days_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_city
HAVING COUNT(*) >= 30
ORDER BY avg_days_late DESC;


-- 4. Late-delivery rate overall
SELECT
    COUNT(*)                                                     AS delivered_orders,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date
                                > order_estimated_delivery_date
                           THEN 1 ELSE 0 END) / COUNT(*), 1)     AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;