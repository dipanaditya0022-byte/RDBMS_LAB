-- Experiment 7: normalization of sales table (UNF to BCNF)

DROP DATABASE IF EXISTS sales_norm_db;
CREATE DATABASE sales_norm_db;
USE sales_norm_db;

-- STEP 0 : UNF - the denormalized Sales table
--   One row per invoice. product_ids, product_names, categories,
--   unit_prices, quantities and account_mgrs are REPEATING GROUPS
--   stored as comma-separated lists (non-atomic values).
CREATE TABLE sales_unf (
    invoice_no       VARCHAR(10),
    invoice_date     DATE,
    customer_id      VARCHAR(5),
    customer_name    VARCHAR(40),
    customer_city    VARCHAR(30),
    customer_state   VARCHAR(30),
    salesperson_id   VARCHAR(5),
    salesperson_name VARCHAR(40),
    product_ids      VARCHAR(100),
    product_names    VARCHAR(300),
    categories       VARCHAR(200),
    unit_prices      VARCHAR(100),
    quantities       VARCHAR(50),
    account_mgrs     VARCHAR(100)
);

INSERT INTO sales_unf VALUES
('INV1001','2025-09-01','C01','Aarav Sharma','Mumbai','Maharashtra','S1','Rohit Kumar',
 'P101,P201','Redmi Note 13,The Guide','Electronics,Books','17999,299','1,2','Vikas,Irfan'),
('INV1002','2025-09-02','C02','Diya Patel','Ahmedabad','Gujarat','S2','Sneha Rao',
 'P102,P301','boAt Airdopes 141,Cotton Kurta','Electronics,Clothing','1299,1899','2,1','Komal,Leena'),
('INV1003','2025-09-03','C01','Aarav Sharma','Mumbai','Maharashtra','S2','Sneha Rao',
 'P102','boAt Airdopes 141','Electronics','1299','1','Vikas'),
('INV1004','2025-09-05','C03','Kabir Singh','Pune','Maharashtra','S1','Rohit Kumar',
 'P201,P202,P101','The Guide,Malgudi Days,Redmi Note 13','Books,Books,Electronics','299,280,17999','1,1,1','Irfan,Irfan,Vikas'),
('INV1005','2025-09-06','C04','Ananya Iyer','Mumbai','Maharashtra','S1','Rohit Kumar',
 'P301,P102','Cotton Kurta,boAt Airdopes 141','Clothing,Electronics','1899,1299','3,1','Leena,Komal'),
('INV1006','2025-09-08','C02','Diya Patel','Ahmedabad','Gujarat','S1','Rohit Kumar',
 'P101','Redmi Note 13','Electronics','17999','1','Komal'),
('INV1007','2025-09-09','C03','Kabir Singh','Pune','Maharashtra','S2','Sneha Rao',
 'P202','Malgudi Days','Books','280','2','Irfan');

SELECT * FROM sales_unf;

-- Problem with UNF: "Which invoices contain P102?" needs string matching
SELECT invoice_no, product_ids FROM sales_unf WHERE FIND_IN_SET('P102', product_ids) > 0;

-- STEP 1 : 1NF - atomic values, one row per (invoice, product)
--   The parallel lists are split with a helper numbers table.
CREATE TABLE seq (n INT PRIMARY KEY);
INSERT INTO seq VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10);

CREATE TABLE sales_1nf (
    invoice_no       VARCHAR(10),
    invoice_date     DATE,
    customer_id      VARCHAR(5),
    customer_name    VARCHAR(40),
    customer_city    VARCHAR(30),
    customer_state   VARCHAR(30),
    salesperson_id   VARCHAR(5),
    salesperson_name VARCHAR(40),
    product_id       VARCHAR(5),
    product_name     VARCHAR(60),
    category         VARCHAR(30),
    unit_price       DECIMAL(10,2),
    qty              INT,
    account_mgr      VARCHAR(30),
    PRIMARY KEY (invoice_no, product_id)
);

INSERT INTO sales_1nf
SELECT u.invoice_no, u.invoice_date, u.customer_id, u.customer_name, u.customer_city,
       u.customer_state, u.salesperson_id, u.salesperson_name,
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.product_ids,   ',', s.n), ',', -1),
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.product_names, ',', s.n), ',', -1),
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.categories,    ',', s.n), ',', -1),
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.unit_prices,   ',', s.n), ',', -1),
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.quantities,    ',', s.n), ',', -1),
       SUBSTRING_INDEX(SUBSTRING_INDEX(u.account_mgrs,  ',', s.n), ',', -1)
FROM sales_unf u
JOIN seq s ON s.n <= 1 + LENGTH(u.product_ids) - LENGTH(REPLACE(u.product_ids, ',', ''));

SELECT * FROM sales_1nf ORDER BY invoice_no, product_id;

-- STEP 1a : Identify / verify functional dependencies on sales_1nf
--   X -> Y holds if one X value never has two different Y values
SELECT 'F1: invoice_no -> invoice_date, customer_id, salesperson_id' AS fd,
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED') AS status
FROM (SELECT invoice_no FROM sales_1nf GROUP BY invoice_no
      HAVING COUNT(DISTINCT invoice_date, customer_id, salesperson_id) > 1) t
UNION ALL
SELECT 'F2: customer_id -> customer_name, customer_city',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT customer_id FROM sales_1nf GROUP BY customer_id
      HAVING COUNT(DISTINCT customer_name, customer_city) > 1) t
UNION ALL
SELECT 'F3: customer_city -> customer_state',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT customer_city FROM sales_1nf GROUP BY customer_city
      HAVING COUNT(DISTINCT customer_state) > 1) t
UNION ALL
SELECT 'F4: product_id -> product_name, category, unit_price',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT product_id FROM sales_1nf GROUP BY product_id
      HAVING COUNT(DISTINCT product_name, category, unit_price) > 1) t
UNION ALL
SELECT 'F5: salesperson_id -> salesperson_name',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT salesperson_id FROM sales_1nf GROUP BY salesperson_id
      HAVING COUNT(DISTINCT salesperson_name) > 1) t
UNION ALL
SELECT 'F6: invoice_no, product_id -> qty',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT invoice_no, product_id FROM sales_1nf GROUP BY invoice_no, product_id
      HAVING COUNT(DISTINCT qty) > 1) t
UNION ALL
SELECT 'F7: customer_id, category -> account_mgr',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT customer_id, category FROM sales_1nf GROUP BY customer_id, category
      HAVING COUNT(DISTINCT account_mgr) > 1) t
UNION ALL
SELECT 'F8: account_mgr -> category',
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT account_mgr FROM sales_1nf GROUP BY account_mgr
      HAVING COUNT(DISTINCT category) > 1) t;

-- Counter-checks: these are NOT functional dependencies
SELECT 'customer_city -> customer_id' AS not_an_fd,
       IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED') AS status
FROM (SELECT customer_city FROM sales_1nf GROUP BY customer_city
      HAVING COUNT(DISTINCT customer_id) > 1) t
UNION ALL
SELECT 'category -> account_mgr', IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT category FROM sales_1nf GROUP BY category
      HAVING COUNT(DISTINCT account_mgr) > 1) t
UNION ALL
SELECT 'product_id -> qty', IF(COUNT(*) = 0, 'HOLDS', 'VIOLATED')
FROM (SELECT product_id FROM sales_1nf GROUP BY product_id
      HAVING COUNT(DISTINCT qty) > 1) t;

-- Candidate key check: (invoice_no, product_id) is unique in sales_1nf
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT invoice_no, product_id) AS distinct_keys
FROM sales_1nf;

-- Redundancy / anomalies in 1NF: customer data repeated in every line
SELECT customer_id, customer_name, COUNT(*) AS times_stored
FROM sales_1nf GROUP BY customer_id, customer_name;

-- STEP 2 : 2NF - remove PARTIAL dependencies on the key (invoice_no, product_id)
--   F1 (invoice_no -> ...) and F4 (product_id -> ...) depend on part of the key.
CREATE TABLE invoice_2nf AS
SELECT DISTINCT invoice_no, invoice_date, customer_id, customer_name, customer_city,
                customer_state, salesperson_id, salesperson_name
FROM sales_1nf;
ALTER TABLE invoice_2nf ADD PRIMARY KEY (invoice_no);

CREATE TABLE product_2nf AS
SELECT DISTINCT product_id, product_name, category, unit_price FROM sales_1nf;
ALTER TABLE product_2nf ADD PRIMARY KEY (product_id);

CREATE TABLE invoice_line_2nf AS
SELECT invoice_no, product_id, qty, account_mgr FROM sales_1nf;
ALTER TABLE invoice_line_2nf ADD PRIMARY KEY (invoice_no, product_id);

SELECT * FROM invoice_2nf;
SELECT * FROM product_2nf;
SELECT * FROM invoice_line_2nf;

-- Still a transitive dependency in invoice_2nf: invoice_no -> customer_id -> customer_city -> customer_state
SELECT customer_city, customer_state, COUNT(*) AS repeated
FROM invoice_2nf GROUP BY customer_city, customer_state;

-- STEP 3 : 3NF - remove TRANSITIVE dependencies
--   invoice_no -> customer_id -> (customer_name, customer_city)   [F2]
--   customer_city -> customer_state                               [F3]
--   invoice_no -> salesperson_id -> salesperson_name              [F5]
--   (invoice_no, product_id) -> (customer_id, category) -> account_mgr [F7]
CREATE TABLE city_3nf (
    city  VARCHAR(30) PRIMARY KEY,
    state VARCHAR(30) NOT NULL
);
INSERT INTO city_3nf SELECT DISTINCT customer_city, customer_state FROM invoice_2nf;

CREATE TABLE customer_3nf (
    customer_id   VARCHAR(5) PRIMARY KEY,
    customer_name VARCHAR(40) NOT NULL,
    city          VARCHAR(30) NOT NULL,
    FOREIGN KEY (city) REFERENCES city_3nf(city)
);
INSERT INTO customer_3nf SELECT DISTINCT customer_id, customer_name, customer_city FROM invoice_2nf;

CREATE TABLE salesperson_3nf (
    salesperson_id   VARCHAR(5) PRIMARY KEY,
    salesperson_name VARCHAR(40) NOT NULL
);
INSERT INTO salesperson_3nf SELECT DISTINCT salesperson_id, salesperson_name FROM invoice_2nf;

CREATE TABLE invoice_3nf (
    invoice_no     VARCHAR(10) PRIMARY KEY,
    invoice_date   DATE NOT NULL,
    customer_id    VARCHAR(5) NOT NULL,
    salesperson_id VARCHAR(5) NOT NULL,
    FOREIGN KEY (customer_id)    REFERENCES customer_3nf(customer_id),
    FOREIGN KEY (salesperson_id) REFERENCES salesperson_3nf(salesperson_id)
);
INSERT INTO invoice_3nf SELECT invoice_no, invoice_date, customer_id, salesperson_id FROM invoice_2nf;

CREATE TABLE product_3nf (
    product_id   VARCHAR(5) PRIMARY KEY,
    product_name VARCHAR(60) NOT NULL,
    category     VARCHAR(30) NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL
);
INSERT INTO product_3nf SELECT * FROM product_2nf;

CREATE TABLE invoice_line_3nf (
    invoice_no VARCHAR(10),
    product_id VARCHAR(5),
    qty        INT NOT NULL,
    PRIMARY KEY (invoice_no, product_id),
    FOREIGN KEY (invoice_no) REFERENCES invoice_3nf(invoice_no),
    FOREIGN KEY (product_id) REFERENCES product_3nf(product_id)
);
INSERT INTO invoice_line_3nf SELECT invoice_no, product_id, qty FROM invoice_line_2nf;

-- F7 gets its own relation. Key = (customer_id, category).
-- It is in 3NF (account_mgr -> category, and category is a PRIME attribute)
-- but NOT in BCNF (account_mgr is not a superkey).
CREATE TABLE customer_account_mgr_3nf (
    customer_id VARCHAR(5),
    category    VARCHAR(30),
    account_mgr VARCHAR(30) NOT NULL,
    PRIMARY KEY (customer_id, category),
    FOREIGN KEY (customer_id) REFERENCES customer_3nf(customer_id)
);
INSERT INTO customer_account_mgr_3nf
SELECT DISTINCT customer_id, category, account_mgr FROM sales_1nf;

SELECT * FROM city_3nf;
SELECT * FROM customer_3nf;
SELECT * FROM salesperson_3nf;
SELECT * FROM invoice_3nf;
SELECT * FROM invoice_line_3nf;
SELECT * FROM customer_account_mgr_3nf ORDER BY customer_id, category;

-- BCNF violation inside customer_account_mgr_3nf: account_mgr -> category,
-- yet account_mgr is not unique (not a superkey)
SELECT account_mgr, COUNT(*) AS rows_for_mgr, COUNT(DISTINCT category) AS categories
FROM customer_account_mgr_3nf GROUP BY account_mgr;

-- STEP 4 : BCNF - every determinant must be a superkey
--   Decompose customer_account_mgr_3nf on account_mgr -> category
CREATE TABLE account_mgr_bcnf (
    account_mgr VARCHAR(30) PRIMARY KEY,
    category    VARCHAR(30) NOT NULL
);
INSERT INTO account_mgr_bcnf SELECT DISTINCT account_mgr, category FROM customer_account_mgr_3nf;

CREATE TABLE customer_mgr_bcnf (
    customer_id VARCHAR(5),
    account_mgr VARCHAR(30),
    PRIMARY KEY (customer_id, account_mgr),
    FOREIGN KEY (customer_id) REFERENCES customer_3nf(customer_id),
    FOREIGN KEY (account_mgr) REFERENCES account_mgr_bcnf(account_mgr)
);
INSERT INTO customer_mgr_bcnf SELECT customer_id, account_mgr FROM customer_account_mgr_3nf;

SELECT * FROM account_mgr_bcnf;
SELECT * FROM customer_mgr_bcnf ORDER BY customer_id;

-- STEP 5 : Lossless-join verification

-- L1. Rebuild the 1NF table by JOINing all 3NF relations on their keys
CREATE VIEW v_rebuilt_from_3nf AS
SELECT i.invoice_no, i.invoice_date, c.customer_id, c.customer_name,
       c.city AS customer_city, ct.state AS customer_state,
       s.salesperson_id, s.salesperson_name,
       p.product_id, p.product_name, p.category, p.unit_price, l.qty, am.account_mgr
FROM invoice_line_3nf l
JOIN invoice_3nf     i  ON i.invoice_no     = l.invoice_no
JOIN customer_3nf    c  ON c.customer_id    = i.customer_id
JOIN city_3nf        ct ON ct.city          = c.city
JOIN salesperson_3nf s  ON s.salesperson_id = i.salesperson_id
JOIN product_3nf     p  ON p.product_id     = l.product_id
JOIN customer_account_mgr_3nf am ON am.customer_id = c.customer_id AND am.category = p.category;

SELECT (SELECT COUNT(*) FROM sales_1nf)          AS original_rows,
       (SELECT COUNT(*) FROM v_rebuilt_from_3nf) AS rebuilt_rows;

-- Rows in original but not in the join, and vice versa: both must be 0
SELECT 'original EXCEPT rebuilt' AS check_name, COUNT(*) AS row_count FROM (
    SELECT * FROM sales_1nf EXCEPT SELECT * FROM v_rebuilt_from_3nf) a
UNION ALL
SELECT 'rebuilt EXCEPT original', COUNT(*) FROM (
    SELECT * FROM v_rebuilt_from_3nf EXCEPT SELECT * FROM sales_1nf) b;

-- L2. Same check for the BCNF decomposition (account_mgr table rebuilt)
SELECT 'BCNF join vs 3NF table' AS check_name, COUNT(*) AS differing_rows FROM (
    (SELECT cm.customer_id, am.category, cm.account_mgr
     FROM customer_mgr_bcnf cm JOIN account_mgr_bcnf am ON am.account_mgr = cm.account_mgr
     EXCEPT
     SELECT customer_id, category, account_mgr FROM customer_account_mgr_3nf)
    UNION ALL
    (SELECT customer_id, category, account_mgr FROM customer_account_mgr_3nf
     EXCEPT
     SELECT cm.customer_id, am.category, cm.account_mgr
     FROM customer_mgr_bcnf cm JOIN account_mgr_bcnf am ON am.account_mgr = cm.account_mgr)
) d;

-- L3. Lossless test condition: common attribute must be a key of one side
--     (R1 ∩ R2 -> R1 or R1 ∩ R2 -> R2). Checked as uniqueness of join columns.
SELECT 'invoice_3nf.invoice_no unique'     AS test, COUNT(*) = COUNT(DISTINCT invoice_no)  AS passed FROM invoice_3nf
UNION ALL
SELECT 'product_3nf.product_id unique',          COUNT(*) = COUNT(DISTINCT product_id)      FROM product_3nf
UNION ALL
SELECT 'customer_3nf.customer_id unique',        COUNT(*) = COUNT(DISTINCT customer_id)     FROM customer_3nf
UNION ALL
SELECT 'city_3nf.city unique',                   COUNT(*) = COUNT(DISTINCT city)            FROM city_3nf
UNION ALL
SELECT 'account_mgr_bcnf.account_mgr unique',    COUNT(*) = COUNT(DISTINCT account_mgr)     FROM account_mgr_bcnf;

-- L4. Counter-example: a LOSSY decomposition
--     R1(invoice_no, customer_id) and R2(customer_id, product_id, qty)
--     customer_id is not a key of either side -> spurious tuples appear
CREATE TABLE lossy_r1 AS SELECT DISTINCT invoice_no, customer_id FROM sales_1nf;
CREATE TABLE lossy_r2 AS SELECT DISTINCT customer_id, product_id, qty FROM sales_1nf;

SELECT (SELECT COUNT(*) FROM sales_1nf) AS original_rows,
       (SELECT COUNT(*) FROM lossy_r1 NATURAL JOIN lossy_r2) AS joined_rows;

SELECT r1.invoice_no, r1.customer_id, r2.product_id, r2.qty, 'SPURIOUS' AS note
FROM lossy_r1 r1 JOIN lossy_r2 r2 ON r1.customer_id = r2.customer_id
WHERE NOT EXISTS (SELECT 1 FROM sales_1nf s
                  WHERE s.invoice_no = r1.invoice_no AND s.product_id = r2.product_id);

-- STEP 6 : Dependency preservation

-- D1. In 3NF every FD can be checked inside ONE table (by its key):
SELECT 'F1 invoice_no -> ...'       AS fd, 'invoice_3nf (PK invoice_no)'                AS enforced_in UNION ALL
SELECT 'F2 customer_id -> ...',          'customer_3nf (PK customer_id)'                             UNION ALL
SELECT 'F3 city -> state',               'city_3nf (PK city)'                                        UNION ALL
SELECT 'F4 product_id -> ...',           'product_3nf (PK product_id)'                               UNION ALL
SELECT 'F5 salesperson_id -> name',      'salesperson_3nf (PK salesperson_id)'                       UNION ALL
SELECT 'F6 invoice_no,product_id -> qty','invoice_line_3nf (PK invoice_no, product_id)'               UNION ALL
SELECT 'F7 customer_id,category -> mgr', 'customer_account_mgr_3nf (PK customer_id, category)'       UNION ALL
SELECT 'F8 account_mgr -> category',     'NOT enforced by a key in 3NF (allowed: category is prime)';

-- D2. 3NF enforces F7: C01 already has Vikas for Electronics,
--     giving C01 a second Electronics manager is rejected -> ERROR 1062
INSERT INTO customer_account_mgr_3nf VALUES ('C01', 'Electronics', 'Komal');

-- D3. BCNF does NOT preserve F7: the same fact is ACCEPTED
INSERT INTO customer_mgr_bcnf VALUES ('C01', 'Komal');

-- D4. F7 can now be checked only by JOINING the two BCNF tables
SELECT cm.customer_id, am.category, GROUP_CONCAT(cm.account_mgr) AS managers,
       'F7 VIOLATED' AS status
FROM customer_mgr_bcnf cm
JOIN account_mgr_bcnf am ON am.account_mgr = cm.account_mgr
GROUP BY cm.customer_id, am.category
HAVING COUNT(*) > 1;

-- D5. BCNF does enforce F8 directly: a manager cannot belong to two categories
INSERT INTO account_mgr_bcnf VALUES ('Vikas', 'Books');

-- D6. Update anomaly removed: change a city's state in ONE place only
UPDATE city_3nf SET state = 'Maharashtra (MH)' WHERE city = 'Mumbai';
SELECT DISTINCT customer_city, customer_state FROM v_rebuilt_from_3nf WHERE customer_city = 'Mumbai';
