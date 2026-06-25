-- 00_exploration.sql
-- Project: brazilian-e-market
-- Purpose: data explorations, confirm setup, list tables, inspect each table's
--          structure, size, and a sample of rows.
-- Engine:  SQLite (DB Browser)
-- Author:  Shavkatjon Yuldashev| Date: 2026-06-25
-- email: shavkatjon.yuldashev.0411@gmail.com
--  -------------------------------------------------------------------------


-- all tables available 
SELECT name FROM sqlite_master WHERE type='table';
--  -------------------------------------------------------------------------


-- columns of the tables 
PRAGMA table_info(category_translation);
PRAGMA table_info(customers);
PRAGMA table_info(geolocation);
PRAGMA table_info(order_items);
PRAGMA table_info(orders);
PRAGMA table_info(payments);
PRAGMA table_info(products);
PRAGMA table_info(reviews);
PRAGMA table_info(sellers);
--  -------------------------------------------------------------------------

-- amount of all rows 

SELECT 'category_translation' AS table_name, 
COUNT(*) AS n_rows FROM category_translation
UNION ALL SELECT 'customers',          COUNT(*) FROM customers
UNION ALL SELECT 'geolocation',        COUNT(*) FROM geolocation
UNION ALL SELECT 'order_items',        COUNT(*) FROM order_items
UNION ALL SELECT 'orders',             COUNT(*) FROM orders
UNION ALL SELECT 'payments',           COUNT(*) FROM payments
UNION ALL SELECT 'products',           COUNT(*) FROM products
UNION ALL SELECT 'reviews',            COUNT(*) FROM reviews
UNION ALL SELECT 'sellers',            COUNT(*) FROM sellers
ORDER BY n_rows DESC;
--  -------------------------------------------------------------------------


-- head of the tables , 5 rows per table 
SELECT * FROM category_translation LIMIT 5;
SELECT * FROM geolocation LIMIT 5;
SELECT * FROM order_items LIMIT 5;
SELECT * FROM orders LIMIT 5;
SELECT * FROM payments LIMIT 5;
SELECT * FROM products LIMIT 5;
SELECT * FROM reviews LIMIT 5;
SELECT * FROM sellers LIMIT 5;
--  -------------------------------------------------------------------------


-- revenue TREND  monthly 

SELECT 
strftime('%Y-%m', o.order_purchase_timestamp) month,
ROUND(SUM(p.payment_value),2) revenue
FROM orders o
JOIN payments p
ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;
--  -------------------------------------------------------------------------

-- monthly ORDER TREND 

 SELECT
strftime('%Y-%m', order_purchase_timestamp) month,
COUNT(*) total_orders
FROM orders
GROUP BY month
ORDER BY month;
 --  -------------------------------------------------------------------------
 
 
 -- order status now 
 
 SELECT
order_status,
COUNT(*) orders,
ROUND(100.0 * COUNT(*) /
      (SELECT COUNT(*) FROM orders),2) pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;
--  -------------------------------------------------------------------------


-- missing values any in there 

SELECT
SUM(customer_id IS NULL) customer_id_nulls,
SUM(customer_unique_id IS NULL) unique_id_nulls,
SUM(customer_city IS NULL) city_nulls
FROM customers;
-- there are no missing values looks like developers works clean 
--  -------------------------------------------------------------------------
