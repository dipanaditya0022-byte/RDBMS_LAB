-- Experiment 10: query optimization (20000 customers + 100000 orders)

DROP DATABASE IF EXISTS shop_db;
CREATE DATABASE shop_db;
USE shop_db;

-- PART A : Schema (primary keys only - no secondary indexes yet)
CREATE TABLE customers (
    customer_id  INT PRIMARY KEY,
    full_name    VARCHAR(50) NOT NULL,
    email        VARCHAR(80) NOT NULL,
    phone        VARCHAR(10) NOT NULL,         -- stored as text
    city         VARCHAR(30) NOT NULL,
    signup_date  DATE NOT NULL
);

CREATE TABLE orders (
    order_id      INT PRIMARY KEY,
    customer_id   INT NOT NULL,
    order_date    DATETIME NOT NULL,
    status        VARCHAR(12) NOT NULL,
    payment_mode  VARCHAR(12) NOT NULL,
    amount        DECIMAL(10,2) NOT NULL
);

-- PART B : Generate the dataset (values made using CRC32 of n)
SET SESSION cte_max_recursion_depth = 200000;

INSERT INTO customers
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 20000)
SELECT n,
       CONCAT(ELT(1 + CRC32(CONCAT(n,'f')) % 20, 'Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai',
              'Reyansh','Krishna','Ishaan','Rohan','Ananya','Diya','Saanvi','Aadhya','Pari','Myra',
              'Kavya','Priya','Sneha','Meera'), ' ',
              ELT(1 + CRC32(CONCAT(n,'l')) % 15, 'Sharma','Verma','Patel','Reddy','Iyer','Nair',
              'Singh','Gupta','Joshi','Kulkarni','Mehta','Rao','Das','Banerjee','Khan')),
       CONCAT('user', n, '@example.in'),
       CONCAT('9', LPAD((n * 7919) % 1000000000, 9, '0')),
       ELT(1 + CRC32(CONCAT(n,'c')) % 20, 'Mumbai','Delhi','Bengaluru','Hyderabad','Chennai',
           'Kolkata','Pune','Ahmedabad','Jaipur','Lucknow','Surat','Indore','Bhopal','Nagpur',
           'Kochi','Chandigarh','Patna','Vadodara','Coimbatore','Visakhapatnam'),
       DATE_ADD('2020-01-01', INTERVAL CRC32(CONCAT(n,'s')) % 2000 DAY)
FROM seq;

INSERT INTO orders
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 100000)
SELECT n,
       1 + CRC32(CONCAT(n,'cust')) % 20000,
       TIMESTAMP('2023-01-01') + INTERVAL CRC32(CONCAT(n,'d')) % 1000 DAY
                               + INTERVAL CRC32(CONCAT(n,'t')) % 86400 SECOND,
       ELT(1 + CRC32(CONCAT(n,'st')) % 10, 'DELIVERED','DELIVERED','DELIVERED','DELIVERED',
           'DELIVERED','DELIVERED','DELIVERED','SHIPPED','CANCELLED','RETURNED'),
       ELT(1 + CRC32(CONCAT(n,'pm')) % 5, 'UPI','CARD','COD','NETBANKING','WALLET'),
       100 + CRC32(CONCAT(n,'a')) % 20000
FROM seq;

ANALYZE TABLE customers, orders;

SELECT (SELECT COUNT(*) FROM customers) AS customers,
       (SELECT COUNT(*) FROM orders)    AS orders,
       (SELECT COUNT(*) FROM customers) + (SELECT COUNT(*) FROM orders) AS total_rows;

SELECT * FROM customers LIMIT 3;
SELECT * FROM orders LIMIT 3;

-- PART C : Benchmark helper
--   Runs a statement N times, stores the average time and the result
--   (@c, @s) to check that optimized query gives same answer
CREATE TABLE timing (
    query_no   VARCHAR(4),
    version    VARCHAR(30),
    runs       INT,
    avg_ms     DECIMAL(12,3),
    result_c   BIGINT,
    result_s   DECIMAL(16,2),
    PRIMARY KEY (query_no, version)
);

DELIMITER $$
CREATE PROCEDURE bench(IN p_no VARCHAR(4), IN p_version VARCHAR(30), IN p_sql TEXT, IN p_runs INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE t0 DATETIME(6);
    SET @bench_sql = p_sql;
    PREPARE s FROM @bench_sql;
    SET t0 = NOW(6);
    WHILE i < p_runs DO
        EXECUTE s;
        SET i = i + 1;
    END WHILE;
    REPLACE INTO timing VALUES (p_no, p_version, p_runs,
        TIMESTAMPDIFF(MICROSECOND, t0, NOW(6)) / 1000 / p_runs, @c, @s);
    DEALLOCATE PREPARE s;
END$$
DELIMITER ;

-- SLOW QUERY 1 : function applied to an indexed/filter column
--   "Revenue for March 2024"
SET @sq1_slow = "SELECT COUNT(*), SUM(amount) INTO @c, @s FROM orders
                 WHERE YEAR(order_date) = 2024 AND MONTH(order_date) = 3";
SET @sq1_fast = "SELECT COUNT(*), SUM(amount) INTO @c, @s FROM orders
                 WHERE order_date >= '2024-03-01' AND order_date < '2024-04-01'";

EXPLAIN FORMAT=TRADITIONAL
SELECT COUNT(*), SUM(amount) FROM orders WHERE YEAR(order_date) = 2024 AND MONTH(order_date) = 3;
CALL bench('SQ1', '1 original (no index)', @sq1_slow, 10);

CREATE INDEX idx_orders_date_amount ON orders (order_date, amount);

-- index exists, but YEAR()/MONTH() hide the column -> still not usable for a range
EXPLAIN FORMAT=TRADITIONAL
SELECT COUNT(*), SUM(amount) FROM orders WHERE YEAR(order_date) = 2024 AND MONTH(order_date) = 3;
CALL bench('SQ1', '2 original + index', @sq1_slow, 10);

-- rewrite as a sargable range -> index range scan, covering (order_date, amount)
EXPLAIN FORMAT=TRADITIONAL
SELECT COUNT(*), SUM(amount) FROM orders WHERE order_date >= '2024-03-01' AND order_date < '2024-04-01';
CALL bench('SQ1', '3 rewritten + index', @sq1_fast, 10);

-- SLOW QUERY 2 : implicit type conversion (VARCHAR column vs number)
--   "Find customer by mobile number"
SET @sq2_slow = "SELECT COUNT(*), MAX(customer_id) INTO @c, @s FROM customers WHERE phone = 9039595000";
SET @sq2_fast = "SELECT COUNT(*), MAX(customer_id) INTO @c, @s FROM customers WHERE phone = '9039595000'";

SELECT customer_id, full_name, phone, city FROM customers WHERE phone = '9039595000';

EXPLAIN FORMAT=TRADITIONAL SELECT * FROM customers WHERE phone = 9039595000;
CALL bench('SQ2', '1 original (no index)', @sq2_slow, 20);

CREATE INDEX idx_customers_phone ON customers (phone);

-- number literal -> every phone string must be converted -> index ignored
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM customers WHERE phone = 9039595000;
CALL bench('SQ2', '2 original + index', @sq2_slow, 20);

-- string literal -> index lookup (type = ref)
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM customers WHERE phone = '9039595000';
CALL bench('SQ2', '3 rewritten + index', @sq2_fast, 20);

-- SLOW QUERY 3 : correlated subquery executed once per outer row
--   "Pune customers who joined in 2025 and spent more than Rs 40,000"
SET @sq3_slow = "SELECT COUNT(*), SUM(c.customer_id) INTO @c, @s
                 FROM customers c
                 WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
                   AND (SELECT SUM(o.amount) FROM orders o
                        WHERE o.customer_id = c.customer_id) > 40000";
SET @sq3_fast = "SELECT COUNT(*), SUM(t.customer_id) INTO @c, @s FROM (
                     SELECT c.customer_id
                     FROM customers c
                     JOIN orders o ON o.customer_id = c.customer_id
                     WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
                     GROUP BY c.customer_id
                     HAVING SUM(o.amount) > 40000) t";

EXPLAIN FORMAT=TRADITIONAL
SELECT c.customer_id FROM customers c
WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
  AND (SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id) > 40000;
CALL bench('SQ3', '1 original (no index)', @sq3_slow, 1);

CREATE INDEX idx_orders_cust_amount  ON orders (customer_id, amount);
CREATE INDEX idx_customers_city_sign ON customers (city, signup_date);

EXPLAIN FORMAT=TRADITIONAL
SELECT c.customer_id FROM customers c
WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
  AND (SELECT SUM(o.amount) FROM orders o WHERE o.customer_id = c.customer_id) > 40000;
CALL bench('SQ3', '2 original + index', @sq3_slow, 10);

EXPLAIN FORMAT=TRADITIONAL
SELECT c.customer_id
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
GROUP BY c.customer_id HAVING SUM(o.amount) > 40000;
CALL bench('SQ3', '3 rewritten + index', @sq3_fast, 10);

EXPLAIN ANALYZE
SELECT c.customer_id
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city = 'Pune' AND c.signup_date >= '2025-01-01'
GROUP BY c.customer_id HAVING SUM(o.amount) > 40000;

-- SLOW QUERY 4 : deep pagination with a large OFFSET
--   "Page 4001 of order history (20 rows per page)"
SET @sq4_slow = "SELECT COUNT(*), SUM(amount) INTO @c, @s FROM (
                     SELECT order_id, amount FROM orders
                     ORDER BY order_date DESC, order_id DESC
                     LIMIT 20 OFFSET 80000) t";

-- keyset ("seek") pagination: remember the last row of the previous page
SELECT order_date, order_id INTO @last_date, @last_id
FROM orders ORDER BY order_date DESC, order_id DESC LIMIT 1 OFFSET 79999;
SELECT @last_date AS last_seen_date, @last_id AS last_seen_id;

SET @sq4_fast = CONCAT("SELECT COUNT(*), SUM(amount) INTO @c, @s FROM (
                     SELECT order_id, amount FROM orders
                     WHERE order_date < '", @last_date, "'
                        OR (order_date = '", @last_date, "' AND order_id < ", @last_id, ")
                     ORDER BY order_date DESC, order_id DESC
                     LIMIT 20) t");

DROP INDEX idx_orders_date_amount ON orders;      -- start this test without any date index

EXPLAIN FORMAT=TRADITIONAL
SELECT order_id, amount FROM orders ORDER BY order_date DESC, order_id DESC LIMIT 20 OFFSET 80000;
CALL bench('SQ4', '1 original (no index)', @sq4_slow, 10);

-- InnoDB appends the primary key to every secondary index, so (order_date)
-- is really (order_date, order_id) = exactly the ORDER BY of the page query
CREATE INDEX idx_orders_date ON orders (order_date);

EXPLAIN FORMAT=TRADITIONAL
SELECT order_id, amount FROM orders ORDER BY order_date DESC, order_id DESC LIMIT 20 OFFSET 80000;
CALL bench('SQ4', '2 original + index', @sq4_slow, 10);

EXPLAIN FORMAT=TRADITIONAL
SELECT order_id, amount FROM orders
WHERE order_date < @last_date OR (order_date = @last_date AND order_id < @last_id)
ORDER BY order_date DESC, order_id DESC LIMIT 20;
CALL bench('SQ4', '3 rewritten + index', @sq4_fast, 10);

-- SLOW QUERY 5 : filter + ORDER BY + LIMIT with SELECT * (filesort)
--   "Top 10 highest-value COD orders that were RETURNED"
SET @sq5_slow = "SELECT COUNT(*), SUM(amount) INTO @c, @s FROM (
                     SELECT * FROM orders
                     WHERE status = 'RETURNED' AND payment_mode = 'COD'
                     ORDER BY amount DESC LIMIT 10) t";
SET @sq5_fast = "SELECT COUNT(*), SUM(amount) INTO @c, @s FROM (
                     SELECT order_id, customer_id, order_date, amount FROM orders
                     WHERE status = 'RETURNED' AND payment_mode = 'COD'
                     ORDER BY amount DESC LIMIT 10) t";

EXPLAIN FORMAT=TRADITIONAL
SELECT * FROM orders WHERE status = 'RETURNED' AND payment_mode = 'COD' ORDER BY amount DESC LIMIT 10;
CALL bench('SQ5', '1 original (no index)', @sq5_slow, 10);

-- composite index: equality columns first, then the ORDER BY column
CREATE INDEX idx_orders_status_mode_amt ON orders (status, payment_mode, amount);

EXPLAIN FORMAT=TRADITIONAL
SELECT * FROM orders WHERE status = 'RETURNED' AND payment_mode = 'COD' ORDER BY amount DESC LIMIT 10;
CALL bench('SQ5', '2 original + index', @sq5_slow, 10);

EXPLAIN FORMAT=TRADITIONAL
SELECT order_id, customer_id, order_date, amount FROM orders
WHERE status = 'RETURNED' AND payment_mode = 'COD' ORDER BY amount DESC LIMIT 10;
CALL bench('SQ5', '3 rewritten + index', @sq5_fast, 10);

SELECT order_id, customer_id, order_date, payment_mode, amount
FROM orders WHERE status = 'RETURNED' AND payment_mode = 'COD'
ORDER BY amount DESC LIMIT 10;

-- PART D : Results

-- D1. All measurements (result_c / result_s prove every version returns the same answer)
SELECT * FROM timing ORDER BY query_no, version;

-- D2. Before vs after summary
SELECT b.query_no,
       b.avg_ms                              AS before_ms,
       i.avg_ms                              AS index_only_ms,
       a.avg_ms                              AS after_ms,
       ROUND(b.avg_ms / NULLIF(a.avg_ms,0), 1) AS speedup_x,
       IF(b.result_c <=> a.result_c AND b.result_s <=> a.result_s, 'YES', 'NO') AS same_result
FROM timing b
JOIN timing i ON i.query_no = b.query_no AND i.version = '2 original + index'
JOIN timing a ON a.query_no = b.query_no AND a.version = '3 rewritten + index'
WHERE b.version = '1 original (no index)'
ORDER BY b.query_no;

-- D3. Indexes created during the optimization
SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns_in_order
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'shop_db' AND INDEX_NAME <> 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME;
