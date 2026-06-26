-- ============================================================
-- add_constraints.sql
-- Schema constraints setup for olist PostgreSQL database
-- Includes pre-constraint data quality fixes
-- ============================================================


-- ── STEP 1: Check and fix orphan records ─────────────────────

-- 1a. Check orphan rows in order_items
SELECT COUNT(*)
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Result: 24 rows

-- 1b. Remove orphan rows from order_items
DELETE FROM order_items
WHERE order_id NOT IN (SELECT order_id FROM orders);


-- 2a. Check orphan rows in order_reviews
SELECT COUNT(*)
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Result: 23 rows

-- 2b. Remove orphan rows from order_reviews
DELETE FROM order_reviews
WHERE order_id NOT IN (SELECT order_id FROM orders);


-- 3a. Check orphan rows in order_payments
SELECT COUNT(*)
FROM order_payments p
LEFT JOIN orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 3b. Remove orphan rows from order_payments
DELETE FROM order_payments
WHERE order_id NOT IN (SELECT order_id FROM orders);


-- 4a. Check products with missing category translations
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE ct.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;
-- Result: pc_gamer, portateis_cozinha_e_preparadores_de_alimentos

-- 4b. Insert missing category translations
INSERT INTO category_translation (product_category_name, product_category_name_english)
VALUES
    ('pc_gamer', 'PC Gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'Portable Kitchen & Food Processors');


-- ── STEP 2: Primary Keys ─────────────────────────────────────

-- Dimension tables
ALTER TABLE customers
    ADD PRIMARY KEY (customer_id);

ALTER TABLE sellers
    ADD PRIMARY KEY (seller_id);

ALTER TABLE products
    ADD PRIMARY KEY (product_id);

ALTER TABLE category_translation
    ADD PRIMARY KEY (product_category_name);

-- Fact tables
ALTER TABLE orders
    ADD PRIMARY KEY (order_id);

ALTER TABLE order_items
    ADD PRIMARY KEY (order_id, order_item_id);

ALTER TABLE order_reviews
    ADD PRIMARY KEY (review_id);

ALTER TABLE order_payments
    ADD PRIMARY KEY (order_id, payment_sequential);


-- ── STEP 3: Foreign Keys ──────────────────────────────────────

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_seller
    FOREIGN KEY (seller_id) REFERENCES sellers (seller_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id);

ALTER TABLE order_reviews
    ADD CONSTRAINT fk_order_reviews_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_payments
    ADD CONSTRAINT fk_order_payments_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE products
    ADD CONSTRAINT fk_products_category
    FOREIGN KEY (product_category_name) REFERENCES category_translation (product_category_name);


-- ── STEP 4: Verify all constraints ───────────────────────────

SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;