# Experiment 7 - Functional Dependencies and Normalization (UNF -> 1NF -> 2NF -> 3NF -> BCNF)

| Name | UID No | Course | Subject | Submitted To |
|---|---|---|---|---|
| Aditya Sharma | 25LBCS3150 | B.Tech CSE (AI/ML-2) | RDBMS (25CSH-210) | Mr. Amit Kumar Sir |

## Aim

Given a denormalized **Sales** table, identify its functional dependencies and normalize it step by step from **UNF to 1NF, 2NF, 3NF and BCNF**. Verify the **lossless-join** and **dependency-preservation** properties using SQL queries.

## Software / Tools Used

MySQL Server 8.0.31+ (`EXCEPT` is used for verification), MySQL command-line client, VS Code

## Theory

**Functional dependency (FD).** X -> Y means that any two rows with the same X value also have the same Y value. In SQL it is checked with:

```sql
SELECT X FROM R GROUP BY X HAVING COUNT(DISTINCT Y) > 1;   -- empty result  ⇒  X -> Y holds
```

| Normal form | Condition | Removes |
|---|---|---|
| **UNF** | Repeating groups / non-atomic values | - |
| **1NF** | Every value is atomic; no repeating groups | Multi-valued cells |
| **2NF** | 1NF + no **partial dependency** (a non-prime attribute depending on *part* of a candidate key) | Redundancy caused by a composite key |
| **3NF** | 2NF + no **transitive dependency**: for every X -> A, X is a superkey **or** A is a prime attribute | Non-key -> non-key dependencies |
| **BCNF** | For every non-trivial X -> A, **X is a superkey** | The remaining anomalies caused by a non-key determinant |

**Lossless-join decomposition.** R decomposed into R1 and R2 is lossless if R1 ⋈ R2 = R. This is guaranteed when (R1 ∩ R2) -> R1 or (R1 ∩ R2) -> R2, i.e. the common attributes form a key of one side. A lossy decomposition produces **spurious tuples**.

**Dependency preservation.** Every FD can be checked inside a single decomposed table without a join. A 3NF decomposition can always be made both lossless and dependency-preserving. BCNF is always lossless, but **may lose** a dependency.

## The Sales Table and Its Functional Dependencies

The UNF table `sales_unf` has one row per invoice. The product details, quantities and account managers are stored as **comma-separated lists**, which are repeating groups.

```text
Sales(invoice_no, invoice_date, customer_id, customer_name, customer_city, customer_state,
      salesperson_id, salesperson_name,
      {product_id, product_name, category, unit_price, qty, account_mgr}*)   <- repeating group
```

| FD | Meaning |
|---|---|
| F1 | invoice_no -> invoice_date, customer_id, salesperson_id |
| F2 | customer_id -> customer_name, customer_city |
| F3 | customer_city -> customer_state |
| F4 | product_id -> product_name, category, unit_price |
| F5 | salesperson_id -> salesperson_name |
| F6 | invoice_no, product_id -> qty |
| F7 | customer_id, category -> account_mgr *(each customer has one account manager per category)* |
| F8 | account_mgr -> category *(each manager handles one category)* |

**Candidate key of the 1NF table:** `{invoice_no, product_id}`

## Decomposition Steps

```text
UNF  sales_unf
 │ split repeating groups (1 row per invoice line)
1NF  sales_1nf(invoice_no, product_id, invoice_date, customer_*, salesperson_*, product_name,
               category, unit_price, qty, account_mgr)            PK (invoice_no, product_id)
 │ remove partial dependencies F1, F4
2NF  invoice_2nf(invoice_no PK, invoice_date, customer_id, customer_name, customer_city,
                 customer_state, salesperson_id, salesperson_name)
     product_2nf(product_id PK, product_name, category, unit_price)
     invoice_line_2nf(invoice_no, product_id PK, qty, account_mgr)
 │ remove transitive dependencies F2, F3, F5, F7
3NF  invoice_3nf(invoice_no PK, invoice_date, customer_id FK, salesperson_id FK)
     customer_3nf(customer_id PK, customer_name, city FK)
     city_3nf(city PK, state)
     salesperson_3nf(salesperson_id PK, salesperson_name)
     product_3nf(product_id PK, product_name, category, unit_price)
     invoice_line_3nf(invoice_no, product_id PK, qty)
     customer_account_mgr_3nf(customer_id, category PK, account_mgr)  <- 3NF but NOT BCNF
 │ account_mgr -> category, but account_mgr is not a superkey
BCNF account_mgr_bcnf(account_mgr PK, category)
     customer_mgr_bcnf(customer_id, account_mgr PK)
```

`customer_account_mgr_3nf` is in 3NF because, for the FD account_mgr -> category, **category is a prime attribute** (it is part of the key). It is **not in BCNF** because account_mgr is not a superkey.

## Procedure

1. Created the UNF table and inserted 7 invoices (12 invoice lines) of Indian sales data.
2. **UNF -> 1NF:** split the comma-separated lists into atomic rows using a numbers table and `SUBSTRING_INDEX`.
3. Verified all 8 FDs, and 3 non-FDs, with `GROUP BY ... HAVING COUNT(DISTINCT ...) > 1`.
4. **1NF -> 2NF:** projected out the invoice and product attributes (partial dependencies).
5. **2NF -> 3NF:** separated customer, city, salesperson and account-manager data (transitive dependencies).
6. **3NF -> BCNF:** decomposed `customer_account_mgr_3nf` on account_mgr -> category.
7. Verified the lossless join by rebuilding the 1NF table with joins and comparing it with `EXCEPT` in both directions. Also showed a lossy decomposition that produces spurious tuples.
8. Verified dependency preservation: 3NF enforces F7 with a primary key, while BCNF accepts a violation of F7 that can only be found with a join.

## How to Run

```bash
mysql -u root -t -vvv --force < exp07_normalization.sql
```

## Source Code

[exp07_normalization.sql](exp07_normalization.sql)

## Output

Full output: [output.txt](output.txt)

### UNF

```text
-- STEP 0 : UNF - the denormalized Sales table
--   One row per invoice. product_ids, product_names, categories,
--   unit_prices, quantities and account_mgrs are REPEATING GROUPS
--   stored as comma-separated lists (non-atomic values).
--------------
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
)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
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
 'P202','Malgudi Days','Books','280','2','Irfan')
--------------

Query OK, 7 rows affected (0.000 sec)
Records: 7  Duplicates: 0  Warnings: 0

--------------
SELECT * FROM sales_unf
--------------

+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+----------------+--------------------------------------+-------------------------+---------------+------------+-------------------+
| invoice_no | invoice_date | customer_id | customer_name | customer_city | customer_state | salesperson_id | salesperson_name | product_ids    | product_names                        | categories              | unit_prices   | quantities | account_mgrs      |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+----------------+--------------------------------------+-------------------------+---------------+------------+-------------------+
| INV1001    | 2025-09-01   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P101,P201      | Redmi Note 13,The Guide              | Electronics,Books       | 17999,299     | 1,2        | Vikas,Irfan       |
| INV1002    | 2025-09-02   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S2             | Sneha Rao        | P102,P301      | boAt Airdopes 141,Cotton Kurta       | Electronics,Clothing    | 1299,1899     | 2,1        | Komal,Leena       |
| INV1003    | 2025-09-03   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S2             | Sneha Rao        | P102           | boAt Airdopes 141                    | Electronics             | 1299          | 1          | Vikas             |
| INV1004    | 2025-09-05   | C03         | Kabir Singh   | Pune          | Maharashtra    | S1             | Rohit Kumar      | P201,P202,P101 | The Guide,Malgudi Days,Redmi Note 13 | Books,Books,Electronics | 299,280,17999 | 1,1,1      | Irfan,Irfan,Vikas |
| INV1005    | 2025-09-06   | C04         | Ananya Iyer   | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P301,P102      | Cotton Kurta,boAt Airdopes 141       | Clothing,Electronics    | 1899,1299     | 3,1        | Leena,Komal       |
| INV1006    | 2025-09-08   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S1             | Rohit Kumar      | P101           | Redmi Note 13                        | Electronics             | 17999         | 1          | Komal             |
| INV1007    | 2025-09-09   | C03         | Kabir Singh   | Pune          | Maharashtra    | S2             | Sneha Rao        | P202           | Malgudi Days                         | Books                   | 280           | 2          | Irfan             |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+----------------+--------------------------------------+-------------------------+---------------+------------+-------------------+
7 rows in set (0.000 sec)
```

```text
-- Problem with UNF: "Which invoices contain P102?" needs string matching
--------------
SELECT invoice_no, product_ids FROM sales_unf WHERE FIND_IN_SET('P102', product_ids) > 0
--------------

+------------+-------------+
| invoice_no | product_ids |
+------------+-------------+
| INV1002    | P102,P301   |
| INV1003    | P102        |
| INV1005    | P301,P102   |
+------------+-------------+
3 rows in set (0.000 sec)
```

### 1NF

```text
-- STEP 1 : 1NF - atomic values, one row per (invoice, product)
--   The parallel lists are split with a helper numbers table.
--------------
CREATE TABLE seq (n INT PRIMARY KEY)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
INSERT INTO seq VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)
--------------

Query OK, 10 rows affected (0.000 sec)
Records: 10  Duplicates: 0  Warnings: 0

--------------
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
)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
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
JOIN seq s ON s.n <= 1 + LENGTH(u.product_ids) - LENGTH(REPLACE(u.product_ids, ',', ''))
--------------

Query OK, 12 rows affected (0.000 sec)
Records: 12  Duplicates: 0  Warnings: 0

--------------
SELECT * FROM sales_1nf ORDER BY invoice_no, product_id
--------------

+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+------------+-------------------+-------------+------------+------+-------------+
| invoice_no | invoice_date | customer_id | customer_name | customer_city | customer_state | salesperson_id | salesperson_name | product_id | product_name      | category    | unit_price | qty  | account_mgr |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+------------+-------------------+-------------+------------+------+-------------+
| INV1001    | 2025-09-01   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P101       | Redmi Note 13     | Electronics |   17999.00 |    1 | Vikas       |
| INV1001    | 2025-09-01   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P201       | The Guide         | Books       |     299.00 |    2 | Irfan       |
| INV1002    | 2025-09-02   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S2             | Sneha Rao        | P102       | boAt Airdopes 141 | Electronics |    1299.00 |    2 | Komal       |
| INV1002    | 2025-09-02   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S2             | Sneha Rao        | P301       | Cotton Kurta      | Clothing    |    1899.00 |    1 | Leena       |
| INV1003    | 2025-09-03   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S2             | Sneha Rao        | P102       | boAt Airdopes 141 | Electronics |    1299.00 |    1 | Vikas       |
| INV1004    | 2025-09-05   | C03         | Kabir Singh   | Pune          | Maharashtra    | S1             | Rohit Kumar      | P101       | Redmi Note 13     | Electronics |   17999.00 |    1 | Vikas       |
| INV1004    | 2025-09-05   | C03         | Kabir Singh   | Pune          | Maharashtra    | S1             | Rohit Kumar      | P201       | The Guide         | Books       |     299.00 |    1 | Irfan       |
| INV1004    | 2025-09-05   | C03         | Kabir Singh   | Pune          | Maharashtra    | S1             | Rohit Kumar      | P202       | Malgudi Days      | Books       |     280.00 |    1 | Irfan       |
| INV1005    | 2025-09-06   | C04         | Ananya Iyer   | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P102       | boAt Airdopes 141 | Electronics |    1299.00 |    1 | Komal       |
| INV1005    | 2025-09-06   | C04         | Ananya Iyer   | Mumbai        | Maharashtra    | S1             | Rohit Kumar      | P301       | Cotton Kurta      | Clothing    |    1899.00 |    3 | Leena       |
| INV1006    | 2025-09-08   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S1             | Rohit Kumar      | P101       | Redmi Note 13     | Electronics |   17999.00 |    1 | Komal       |
| INV1007    | 2025-09-09   | C03         | Kabir Singh   | Pune          | Maharashtra    | S2             | Sneha Rao        | P202       | Malgudi Days      | Books       |     280.00 |    2 | Irfan       |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+------------+-------------------+-------------+------------+------+-------------+
12 rows in set (0.000 sec)
```

### Functional dependencies verified on the data

```text
-- STEP 1a : Identify / verify functional dependencies on sales_1nf
--   X -> Y holds if one X value never has two different Y values
--------------
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
      HAVING COUNT(DISTINCT category) > 1) t
--------------

+-------------------------------------------------------------+--------+
| fd                                                          | status |
+-------------------------------------------------------------+--------+
| F1: invoice_no -> invoice_date, customer_id, salesperson_id | HOLDS  |
| F2: customer_id -> customer_name, customer_city             | HOLDS  |
| F3: customer_city -> customer_state                         | HOLDS  |
| F4: product_id -> product_name, category, unit_price        | HOLDS  |
| F5: salesperson_id -> salesperson_name                      | HOLDS  |
| F6: invoice_no, product_id -> qty                           | HOLDS  |
| F7: customer_id, category -> account_mgr                    | HOLDS  |
| F8: account_mgr -> category                                 | HOLDS  |
+-------------------------------------------------------------+--------+
8 rows in set (0.000 sec)
```

```text
-- Counter-checks: these are NOT functional dependencies
--------------
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
      HAVING COUNT(DISTINCT qty) > 1) t
--------------

+------------------------------+----------+
| not_an_fd                    | status   |
+------------------------------+----------+
| customer_city -> customer_id | VIOLATED |
| category -> account_mgr      | VIOLATED |
| product_id -> qty            | VIOLATED |
+------------------------------+----------+
3 rows in set (0.000 sec)
```

```text
-- Candidate key check: (invoice_no, product_id) is unique in sales_1nf
--------------
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT invoice_no, product_id) AS distinct_keys
FROM sales_1nf
--------------

+------------+---------------+
| total_rows | distinct_keys |
+------------+---------------+
|         12 |            12 |
+------------+---------------+
1 row in set (0.000 sec)
```

```text
-- Redundancy / anomalies in 1NF: customer data repeated in every line
--------------
SELECT customer_id, customer_name, COUNT(*) AS times_stored
FROM sales_1nf GROUP BY customer_id, customer_name
--------------

+-------------+---------------+--------------+
| customer_id | customer_name | times_stored |
+-------------+---------------+--------------+
| C01         | Aarav Sharma  |            3 |
| C02         | Diya Patel    |            3 |
| C03         | Kabir Singh   |            4 |
| C04         | Ananya Iyer   |            2 |
+-------------+---------------+--------------+
4 rows in set (0.000 sec)
```

### 2NF

```text
-- STEP 2 : 2NF - remove PARTIAL dependencies on the key (invoice_no, product_id)
--   F1 (invoice_no -> ...) and F4 (product_id -> ...) depend on part of the key.
--------------
CREATE TABLE invoice_2nf AS
SELECT DISTINCT invoice_no, invoice_date, customer_id, customer_name, customer_city,
                customer_state, salesperson_id, salesperson_name
FROM sales_1nf
--------------

Query OK, 7 rows affected (0.002 sec)
Records: 7  Duplicates: 0  Warnings: 0

--------------
ALTER TABLE invoice_2nf ADD PRIMARY KEY (invoice_no)
--------------

Query OK, 0 rows affected (0.018 sec)
Records: 0  Duplicates: 0  Warnings: 0

--------------
CREATE TABLE product_2nf AS
SELECT DISTINCT product_id, product_name, category, unit_price FROM sales_1nf
--------------

Query OK, 5 rows affected (0.002 sec)
Records: 5  Duplicates: 0  Warnings: 0

--------------
ALTER TABLE product_2nf ADD PRIMARY KEY (product_id)
--------------

Query OK, 0 rows affected (0.025 sec)
Records: 0  Duplicates: 0  Warnings: 0

--------------
CREATE TABLE invoice_line_2nf AS
SELECT invoice_no, product_id, qty, account_mgr FROM sales_1nf
--------------

Query OK, 12 rows affected (0.002 sec)
Records: 12  Duplicates: 0  Warnings: 0

--------------
ALTER TABLE invoice_line_2nf ADD PRIMARY KEY (invoice_no, product_id)
--------------

Query OK, 0 rows affected (0.017 sec)
Records: 0  Duplicates: 0  Warnings: 0

--------------
SELECT * FROM invoice_2nf
--------------

+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+
| invoice_no | invoice_date | customer_id | customer_name | customer_city | customer_state | salesperson_id | salesperson_name |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+
| INV1001    | 2025-09-01   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S1             | Rohit Kumar      |
| INV1002    | 2025-09-02   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S2             | Sneha Rao        |
| INV1003    | 2025-09-03   | C01         | Aarav Sharma  | Mumbai        | Maharashtra    | S2             | Sneha Rao        |
| INV1004    | 2025-09-05   | C03         | Kabir Singh   | Pune          | Maharashtra    | S1             | Rohit Kumar      |
| INV1005    | 2025-09-06   | C04         | Ananya Iyer   | Mumbai        | Maharashtra    | S1             | Rohit Kumar      |
| INV1006    | 2025-09-08   | C02         | Diya Patel    | Ahmedabad     | Gujarat        | S1             | Rohit Kumar      |
| INV1007    | 2025-09-09   | C03         | Kabir Singh   | Pune          | Maharashtra    | S2             | Sneha Rao        |
+------------+--------------+-------------+---------------+---------------+----------------+----------------+------------------+
7 rows in set (0.000 sec)

--------------
SELECT * FROM product_2nf
--------------

+------------+-------------------+-------------+------------+
| product_id | product_name      | category    | unit_price |
+------------+-------------------+-------------+------------+
| P101       | Redmi Note 13     | Electronics |   17999.00 |
| P102       | boAt Airdopes 141 | Electronics |    1299.00 |
| P201       | The Guide         | Books       |     299.00 |
| P202       | Malgudi Days      | Books       |     280.00 |
| P301       | Cotton Kurta      | Clothing    |    1899.00 |
+------------+-------------------+-------------+------------+
5 rows in set (0.000 sec)

--------------
SELECT * FROM invoice_line_2nf
--------------

+------------+------------+------+-------------+
| invoice_no | product_id | qty  | account_mgr |
+------------+------------+------+-------------+
| INV1001    | P101       |    1 | Vikas       |
| INV1001    | P201       |    2 | Irfan       |
| INV1002    | P102       |    2 | Komal       |
| INV1002    | P301       |    1 | Leena       |
| INV1003    | P102       |    1 | Vikas       |
| INV1004    | P101       |    1 | Vikas       |
| INV1004    | P201       |    1 | Irfan       |
| INV1004    | P202       |    1 | Irfan       |
| INV1005    | P102       |    1 | Komal       |
| INV1005    | P301       |    3 | Leena       |
| INV1006    | P101       |    1 | Komal       |
| INV1007    | P202       |    2 | Irfan       |
+------------+------------+------+-------------+
12 rows in set (0.000 sec)
```

```text
-- Still a transitive dependency in invoice_2nf: invoice_no -> customer_id -> customer_city -> customer_state
--------------
SELECT customer_city, customer_state, COUNT(*) AS repeated
FROM invoice_2nf GROUP BY customer_city, customer_state
--------------

+---------------+----------------+----------+
| customer_city | customer_state | repeated |
+---------------+----------------+----------+
| Mumbai        | Maharashtra    |        3 |
| Ahmedabad     | Gujarat        |        2 |
| Pune          | Maharashtra    |        2 |
+---------------+----------------+----------+
3 rows in set (0.000 sec)
```

### 3NF

```text
-- F7 gets its own relation. Key = (customer_id, category).
-- It is in 3NF (account_mgr -> category, and category is a PRIME attribute)
-- but NOT in BCNF (account_mgr is not a superkey).
--------------
CREATE TABLE customer_account_mgr_3nf (
    customer_id VARCHAR(5),
    category    VARCHAR(30),
    account_mgr VARCHAR(30) NOT NULL,
    PRIMARY KEY (customer_id, category),
    FOREIGN KEY (customer_id) REFERENCES customer_3nf(customer_id)
)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
INSERT INTO customer_account_mgr_3nf
SELECT DISTINCT customer_id, category, account_mgr FROM sales_1nf
--------------

Query OK, 8 rows affected (0.000 sec)
Records: 8  Duplicates: 0  Warnings: 0

--------------
SELECT * FROM city_3nf
--------------

+-----------+-------------+
| city      | state       |
+-----------+-------------+
| Ahmedabad | Gujarat     |
| Mumbai    | Maharashtra |
| Pune      | Maharashtra |
+-----------+-------------+
3 rows in set (0.000 sec)

--------------
SELECT * FROM customer_3nf
--------------

+-------------+---------------+-----------+
| customer_id | customer_name | city      |
+-------------+---------------+-----------+
| C01         | Aarav Sharma  | Mumbai    |
| C02         | Diya Patel    | Ahmedabad |
| C03         | Kabir Singh   | Pune      |
| C04         | Ananya Iyer   | Mumbai    |
+-------------+---------------+-----------+
4 rows in set (0.000 sec)

--------------
SELECT * FROM salesperson_3nf
--------------

+----------------+------------------+
| salesperson_id | salesperson_name |
+----------------+------------------+
| S1             | Rohit Kumar      |
| S2             | Sneha Rao        |
+----------------+------------------+
2 rows in set (0.000 sec)

--------------
SELECT * FROM invoice_3nf
--------------

+------------+--------------+-------------+----------------+
| invoice_no | invoice_date | customer_id | salesperson_id |
+------------+--------------+-------------+----------------+
| INV1001    | 2025-09-01   | C01         | S1             |
| INV1002    | 2025-09-02   | C02         | S2             |
| INV1003    | 2025-09-03   | C01         | S2             |
| INV1004    | 2025-09-05   | C03         | S1             |
| INV1005    | 2025-09-06   | C04         | S1             |
| INV1006    | 2025-09-08   | C02         | S1             |
| INV1007    | 2025-09-09   | C03         | S2             |
+------------+--------------+-------------+----------------+
7 rows in set (0.000 sec)

--------------
SELECT * FROM invoice_line_3nf
--------------

+------------+------------+-----+
| invoice_no | product_id | qty |
+------------+------------+-----+
| INV1001    | P101       |   1 |
| INV1001    | P201       |   2 |
| INV1002    | P102       |   2 |
| INV1002    | P301       |   1 |
| INV1003    | P102       |   1 |
| INV1004    | P101       |   1 |
| INV1004    | P201       |   1 |
| INV1004    | P202       |   1 |
| INV1005    | P102       |   1 |
| INV1005    | P301       |   3 |
| INV1006    | P101       |   1 |
| INV1007    | P202       |   2 |
+------------+------------+-----+
12 rows in set (0.000 sec)

--------------
SELECT * FROM customer_account_mgr_3nf ORDER BY customer_id, category
--------------

+-------------+-------------+-------------+
| customer_id | category    | account_mgr |
+-------------+-------------+-------------+
| C01         | Books       | Irfan       |
| C01         | Electronics | Vikas       |
| C02         | Clothing    | Leena       |
| C02         | Electronics | Komal       |
| C03         | Books       | Irfan       |
| C03         | Electronics | Vikas       |
| C04         | Clothing    | Leena       |
| C04         | Electronics | Komal       |
+-------------+-------------+-------------+
8 rows in set (0.000 sec)
```

```text
-- BCNF violation inside customer_account_mgr_3nf: account_mgr -> category,
-- yet account_mgr is not unique (not a superkey)
--------------
SELECT account_mgr, COUNT(*) AS rows_for_mgr, COUNT(DISTINCT category) AS categories
FROM customer_account_mgr_3nf GROUP BY account_mgr
--------------

+-------------+--------------+------------+
| account_mgr | rows_for_mgr | categories |
+-------------+--------------+------------+
| Irfan       |            2 |          1 |
| Komal       |            2 |          1 |
| Leena       |            2 |          1 |
| Vikas       |            2 |          1 |
+-------------+--------------+------------+
4 rows in set (0.000 sec)
```

### BCNF

```text
-- STEP 4 : BCNF - every determinant must be a superkey
--   Decompose customer_account_mgr_3nf on account_mgr -> category
--------------
CREATE TABLE account_mgr_bcnf (
    account_mgr VARCHAR(30) PRIMARY KEY,
    category    VARCHAR(30) NOT NULL
)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
INSERT INTO account_mgr_bcnf SELECT DISTINCT account_mgr, category FROM customer_account_mgr_3nf
--------------

Query OK, 4 rows affected (0.000 sec)
Records: 4  Duplicates: 0  Warnings: 0

--------------
CREATE TABLE customer_mgr_bcnf (
    customer_id VARCHAR(5),
    account_mgr VARCHAR(30),
    PRIMARY KEY (customer_id, account_mgr),
    FOREIGN KEY (customer_id) REFERENCES customer_3nf(customer_id),
    FOREIGN KEY (account_mgr) REFERENCES account_mgr_bcnf(account_mgr)
)
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
INSERT INTO customer_mgr_bcnf SELECT customer_id, account_mgr FROM customer_account_mgr_3nf
--------------

Query OK, 8 rows affected (0.001 sec)
Records: 8  Duplicates: 0  Warnings: 0

--------------
SELECT * FROM account_mgr_bcnf
--------------

+-------------+-------------+
| account_mgr | category    |
+-------------+-------------+
| Irfan       | Books       |
| Komal       | Electronics |
| Leena       | Clothing    |
| Vikas       | Electronics |
+-------------+-------------+
4 rows in set (0.000 sec)

--------------
SELECT * FROM customer_mgr_bcnf ORDER BY customer_id
--------------

+-------------+-------------+
| customer_id | account_mgr |
+-------------+-------------+
| C01         | Irfan       |
| C01         | Vikas       |
| C02         | Komal       |
| C02         | Leena       |
| C03         | Irfan       |
| C03         | Vikas       |
| C04         | Komal       |
| C04         | Leena       |
+-------------+-------------+
8 rows in set (0.000 sec)
```

### Lossless-join verification

```text
-- L1. Rebuild the 1NF table by JOINing all 3NF relations on their keys
--------------
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
JOIN customer_account_mgr_3nf am ON am.customer_id = c.customer_id AND am.category = p.category
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT (SELECT COUNT(*) FROM sales_1nf)          AS original_rows,
       (SELECT COUNT(*) FROM v_rebuilt_from_3nf) AS rebuilt_rows
--------------

+---------------+--------------+
| original_rows | rebuilt_rows |
+---------------+--------------+
|            12 |           12 |
+---------------+--------------+
1 row in set (0.000 sec)
```

```text
-- Rows in original but not in the join, and vice versa: both must be 0
--------------
SELECT 'original EXCEPT rebuilt' AS check_name, COUNT(*) AS row_count FROM (
    SELECT * FROM sales_1nf EXCEPT SELECT * FROM v_rebuilt_from_3nf) a
UNION ALL
SELECT 'rebuilt EXCEPT original', COUNT(*) FROM (
    SELECT * FROM v_rebuilt_from_3nf EXCEPT SELECT * FROM sales_1nf) b
--------------

+-------------------------+-----------+
| check_name              | row_count |
+-------------------------+-----------+
| original EXCEPT rebuilt |         0 |
| rebuilt EXCEPT original |         0 |
+-------------------------+-----------+
2 rows in set (0.001 sec)
```

```text
-- L2. Same check for the BCNF decomposition (account_mgr table rebuilt)
--------------
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
) d
--------------

+------------------------+----------------+
| check_name             | differing_rows |
+------------------------+----------------+
| BCNF join vs 3NF table |              0 |
+------------------------+----------------+
1 row in set (0.000 sec)
```

```text
-- L3. Lossless test condition: common attribute must be a key of one side
--     (R1 ∩ R2 -> R1 or R1 ∩ R2 -> R2). Checked as uniqueness of join columns.
--------------
SELECT 'invoice_3nf.invoice_no unique'     AS test, COUNT(*) = COUNT(DISTINCT invoice_no)  AS passed FROM invoice_3nf
UNION ALL
SELECT 'product_3nf.product_id unique',          COUNT(*) = COUNT(DISTINCT product_id)      FROM product_3nf
UNION ALL
SELECT 'customer_3nf.customer_id unique',        COUNT(*) = COUNT(DISTINCT customer_id)     FROM customer_3nf
UNION ALL
SELECT 'city_3nf.city unique',                   COUNT(*) = COUNT(DISTINCT city)            FROM city_3nf
UNION ALL
SELECT 'account_mgr_bcnf.account_mgr unique',    COUNT(*) = COUNT(DISTINCT account_mgr)     FROM account_mgr_bcnf
--------------

+-------------------------------------+--------+
| test                                | passed |
+-------------------------------------+--------+
| invoice_3nf.invoice_no unique       |      1 |
| product_3nf.product_id unique       |      1 |
| customer_3nf.customer_id unique     |      1 |
| city_3nf.city unique                |      1 |
| account_mgr_bcnf.account_mgr unique |      1 |
+-------------------------------------+--------+
5 rows in set (0.000 sec)
```

```text
-- L4. Counter-example: a LOSSY decomposition
--     R1(invoice_no, customer_id) and R2(customer_id, product_id, qty)
--     customer_id is not a key of either side -> spurious tuples appear
--------------
CREATE TABLE lossy_r1 AS SELECT DISTINCT invoice_no, customer_id FROM sales_1nf
--------------

Query OK, 7 rows affected (0.002 sec)
Records: 7  Duplicates: 0  Warnings: 0

--------------
CREATE TABLE lossy_r2 AS SELECT DISTINCT customer_id, product_id, qty FROM sales_1nf
--------------

Query OK, 12 rows affected (0.002 sec)
Records: 12  Duplicates: 0  Warnings: 0

--------------
SELECT (SELECT COUNT(*) FROM sales_1nf) AS original_rows,
       (SELECT COUNT(*) FROM lossy_r1 NATURAL JOIN lossy_r2) AS joined_rows
--------------

+---------------+-------------+
| original_rows | joined_rows |
+---------------+-------------+
|            12 |          22 |
+---------------+-------------+
1 row in set (0.000 sec)

--------------
SELECT r1.invoice_no, r1.customer_id, r2.product_id, r2.qty, 'SPURIOUS' AS note
FROM lossy_r1 r1 JOIN lossy_r2 r2 ON r1.customer_id = r2.customer_id
WHERE NOT EXISTS (SELECT 1 FROM sales_1nf s
                  WHERE s.invoice_no = r1.invoice_no AND s.product_id = r2.product_id)
--------------

+------------+-------------+------------+------+----------+
| invoice_no | customer_id | product_id | qty  | note     |
+------------+-------------+------------+------+----------+
| INV1003    | C01         | P101       |    1 | SPURIOUS |
| INV1003    | C01         | P201       |    2 | SPURIOUS |
| INV1006    | C02         | P102       |    2 | SPURIOUS |
| INV1006    | C02         | P301       |    1 | SPURIOUS |
| INV1001    | C01         | P102       |    1 | SPURIOUS |
| INV1007    | C03         | P101       |    1 | SPURIOUS |
| INV1007    | C03         | P201       |    1 | SPURIOUS |
| INV1002    | C02         | P101       |    1 | SPURIOUS |
+------------+-------------+------------+------+----------+
8 rows in set (0.000 sec)
```

### Dependency preservation

```text
-- D1. In 3NF every FD can be checked inside ONE table (by its key):
--------------
SELECT 'F1 invoice_no -> ...'       AS fd, 'invoice_3nf (PK invoice_no)'                AS enforced_in UNION ALL
SELECT 'F2 customer_id -> ...',          'customer_3nf (PK customer_id)'                             UNION ALL
SELECT 'F3 city -> state',               'city_3nf (PK city)'                                        UNION ALL
SELECT 'F4 product_id -> ...',           'product_3nf (PK product_id)'                               UNION ALL
SELECT 'F5 salesperson_id -> name',      'salesperson_3nf (PK salesperson_id)'                       UNION ALL
SELECT 'F6 invoice_no,product_id -> qty','invoice_line_3nf (PK invoice_no, product_id)'               UNION ALL
SELECT 'F7 customer_id,category -> mgr', 'customer_account_mgr_3nf (PK customer_id, category)'       UNION ALL
SELECT 'F8 account_mgr -> category',     'NOT enforced by a key in 3NF (allowed: category is prime)'
--------------

+---------------------------------+-----------------------------------------------------------+
| fd                              | enforced_in                                               |
+---------------------------------+-----------------------------------------------------------+
| F1 invoice_no -> ...            | invoice_3nf (PK invoice_no)                               |
| F2 customer_id -> ...           | customer_3nf (PK customer_id)                             |
| F3 city -> state                | city_3nf (PK city)                                        |
| F4 product_id -> ...            | product_3nf (PK product_id)                               |
| F5 salesperson_id -> name       | salesperson_3nf (PK salesperson_id)                       |
| F6 invoice_no,product_id -> qty | invoice_line_3nf (PK invoice_no, product_id)              |
| F7 customer_id,category -> mgr  | customer_account_mgr_3nf (PK customer_id, category)       |
| F8 account_mgr -> category      | NOT enforced by a key in 3NF (allowed: category is prime) |
+---------------------------------+-----------------------------------------------------------+
8 rows in set (0.000 sec)
```

```text
-- D2. 3NF enforces F7: C01 already has Vikas for Electronics,
--     giving C01 a second Electronics manager is rejected -> ERROR 1062
--------------
INSERT INTO customer_account_mgr_3nf VALUES ('C01', 'Electronics', 'Komal')
--------------

ERROR 1062 (23000) at line 352: Duplicate entry 'C01-Electronics' for key 'customer_account_mgr_3nf.PRIMARY'
```

```text
-- D3. BCNF does NOT preserve F7: the same fact is ACCEPTED
--------------
INSERT INTO customer_mgr_bcnf VALUES ('C01', 'Komal')
--------------

Query OK, 1 row affected (0.000 sec)
```

```text
-- D4. F7 can now be checked only by JOINING the two BCNF tables
--------------
SELECT cm.customer_id, am.category, GROUP_CONCAT(cm.account_mgr) AS managers,
       'F7 VIOLATED' AS status
FROM customer_mgr_bcnf cm
JOIN account_mgr_bcnf am ON am.account_mgr = cm.account_mgr
GROUP BY cm.customer_id, am.category
HAVING COUNT(*) > 1
--------------

+-------------+-------------+-------------+-------------+
| customer_id | category    | managers    | status      |
+-------------+-------------+-------------+-------------+
| C01         | Electronics | Komal,Vikas | F7 VIOLATED |
+-------------+-------------+-------------+-------------+
1 row in set (0.000 sec)
```

```text
-- D5. BCNF does enforce F8 directly: a manager cannot belong to two categories
--------------
INSERT INTO account_mgr_bcnf VALUES ('Vikas', 'Books')
--------------

ERROR 1062 (23000) at line 366: Duplicate entry 'Vikas' for key 'account_mgr_bcnf.PRIMARY'
```

```text
-- D6. Update anomaly removed: change a city's state in ONE place only
--------------
UPDATE city_3nf SET state = 'Maharashtra (MH)' WHERE city = 'Mumbai'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT DISTINCT customer_city, customer_state FROM v_rebuilt_from_3nf WHERE customer_city = 'Mumbai'
--------------

+---------------+------------------+
| customer_city | customer_state   |
+---------------+------------------+
| Mumbai        | Maharashtra (MH) |
+---------------+------------------+
1 row in set (0.000 sec)
```

## Observations

* All 8 FDs **HOLD** on the data. The checks `customer_city -> customer_id`, `category -> account_mgr` and `product_id -> qty` are **VIOLATED**, so they are not FDs.
* In 1NF, the data for customer C01 is stored 3 times, which causes update anomalies. After 3NF, each fact is stored once: the update in D6 changes one row in `city_3nf`.
* **Lossless:** the 3NF join rebuilt exactly 12 rows, and both `EXCEPT` directions returned 0 rows. The BCNF join also matched the 3NF table exactly.
* **Lossy example:** joining on the non-key `customer_id` produced 22 rows instead of 12, i.e. 10 extra rows. Some of these spurious rows are listed in the output (L4).
* **Dependency preservation:**
  * 3NF rejected a second Electronics manager for C01 (`ERROR 1062`), so F7 is preserved.
  * BCNF accepted the same row (D3); the violation of F7 could only be found by joining the two BCNF tables (D4).
  * BCNF does enforce F8 directly (D5 -> `ERROR 1062`).

## Result

The Sales table was normalized from UNF to 1NF, 2NF, 3NF and BCNF. All functional dependencies were checked using SQL queries. The decomposition was shown to be lossless, and it was also shown that 3NF keeps all the dependencies while BCNF loses one (F7).

## Conclusion

Normalization removes repeated data and the insert, update and delete anomalies that come with it. 3NF is usually enough because it is lossless and keeps all dependencies. BCNF removes the remaining redundancy, but some dependencies can then only be checked with a join.
