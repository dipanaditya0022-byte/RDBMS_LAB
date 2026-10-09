# Experiment 2 - ER Diagram to Relational Schema (MySQL)

| Name | UID No | Course | Subject | Submitted To |
|---|---|---|---|---|
| Aditya Sharma | 25LBCS3150 | B.Tech CSE (AI/ML-2) | RDBMS (25CSH-210) | Mr. Amit Kumar Sir |

## Aim

Convert the ER diagram of Experiment 1 into a relational schema. Write complete MySQL `CREATE TABLE` statements with **PRIMARY KEY, FOREIGN KEY, NOT NULL, UNIQUE, ON DELETE CASCADE and ON DELETE SET NULL** constraints, insert sample data, and demonstrate referential-integrity violations.

## Software / Tools Used

MySQL Server 8.0+ (InnoDB engine), MySQL command-line client, VS Code

## Theory

### ER-to-relational mapping rules

| ER construct | Relational mapping used here |
|---|---|
| Strong entity | Its own table; the key attribute becomes the `PRIMARY KEY` (`customer`, `seller`, `product`, ...) |
| Composite attribute | Only the simple components are stored (`first_name`, `middle_name`, `last_name`) |
| Multi-valued attribute | A separate table keyed by (owner key, value) (`customer_phone`, `seller_contact`, `book_author`) |
| Derived attribute | Not stored; computed in queries (`age`, `order_total`) |
| Weak entity | A table whose PK = owner's PK + partial key, with an FK `ON DELETE CASCADE` (`address`, `order_item`) |
| 1:N relationship | FK on the N side (`product.seller_id`, `orders.customer_id`) |
| 1:1 relationship | FK with a `UNIQUE` constraint (`delivery.order_id`) |
| Recursive relationship | Self-referencing FK (`category.parent_id`) |
| Specialization (ISA) | One table per sub-class whose PK is also an FK to the super-class (`electronics`, `clothing`, `book`) |
| Total participation | `NOT NULL` foreign key (`product.seller_id NOT NULL`) |

### Integrity constraints

* **Entity integrity:** a primary key is unique and never NULL.
* **Referential integrity:** every foreign-key value must exist in the parent table (or be NULL).
* **Referential actions** decide what happens when a parent row is deleted:
  * `CASCADE` deletes the child rows too.
  * `SET NULL` sets the child's FK to NULL (the child row is kept).
  * `RESTRICT` / `NO ACTION` rejects the delete while child rows exist.
* **Domain constraints:** `NOT NULL`, `UNIQUE`, `CHECK`, `ENUM`, data types.

## Relational Schema (result of the mapping)

```text
customer       (customer_id PK, first_name, middle_name, last_name, email UQ, dob, created_at)
customer_phone (customer_id PK/FK->customer CASCADE, phone_no PK)
address        (customer_id PK/FK->customer CASCADE, address_no PK, house_no, street, city, state, pincode, address_type)
seller         (seller_id PK, business_name, gstin UQ, pan UQ, rating)
seller_contact (seller_id PK/FK->seller CASCADE, contact_no PK)
category       (category_id PK, category_name UQ, parent_id FK->category SET NULL)
product        (product_id PK, product_name, brand, mrp, selling_price, stock_qty, gst_rate, product_type,
                seller_id FK->seller CASCADE NOT NULL, category_id FK->category SET NULL)
electronics    (product_id PK/FK->product CASCADE, warranty_months, power_rating)
clothing       (product_id PK/FK->product CASCADE, size, fabric, gender)
book           (product_id PK/FK->product CASCADE, isbn UQ, language)
book_author    (product_id PK/FK->book CASCADE, author_name PK)
orders         (order_id PK, customer_id FK->customer RESTRICT, ship_address_no, order_date, status,
                (customer_id, ship_address_no) FK->address RESTRICT)
order_item     (order_id PK/FK->orders CASCADE, line_no PK, product_id FK->product SET NULL, quantity, unit_price, discount)
payment        (payment_id PK, order_id FK->orders CASCADE, method, amount, paid_at, transaction_ref UQ, status)
delivery       (delivery_id PK, order_id UQ FK->orders CASCADE, courier_partner, awb_no UQ, shipped_on, delivered_on, status)
```

## Procedure

1. Created the database `ecommerce_db`.
2. Mapped every entity, weak entity, multi-valued attribute and sub-class to a table (Part A).
3. Added PK, FK, NOT NULL, UNIQUE, CHECK and the referential actions CASCADE, SET NULL and RESTRICT.
4. Inserted sample Indian data: 5 customers, 3 sellers, 7 categories, 6 products, 5 orders, payments and deliveries (Part B).
5. Ran statements that **violate** each constraint and recorded the errors (Part C).
6. Deleted parent rows to observe CASCADE, SET NULL and RESTRICT (Part D).

## How to Run

```bash
mysql -u root -t -vvv --force < exp02_ecommerce_schema.sql
```

`--force` keeps the script running after the intentional errors in Part C.

## Source Code

[exp02_ecommerce_schema.sql](exp02_ecommerce_schema.sql)

Key part (weak entity with a composite FK and different referential actions):

```sql
CREATE TABLE address (
    customer_id  INT          NOT NULL,
    address_no   TINYINT      NOT NULL,
    ...
    PRIMARY KEY (customer_id, address_no),
    CONSTRAINT chk_pincode CHECK (pincode REGEXP '^[1-9][0-9]{5}$'),
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE order_item (
    order_id   INT NOT NULL,
    line_no    TINYINT NOT NULL,
    product_id INT NULL,                   -- SET NULL keeps order history
    ...
    PRIMARY KEY (order_id, line_no),
    CONSTRAINT fk_item_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_product FOREIGN KEY (product_id)
        REFERENCES product(product_id) ON DELETE SET NULL
);
```

## Output

Full output: [output.txt](output.txt)

### Sample data (derived attributes computed in SQL)

```text
-- Verify the data
--------------
SELECT customer_id, CONCAT_WS(' ', first_name, middle_name, last_name) AS full_name,
       email, TIMESTAMPDIFF(YEAR, dob, '2025-10-10') AS age_derived
FROM customer
--------------

+-------------+--------------------+-------------------------+-------------+
| customer_id | full_name          | email                   | age_derived |
+-------------+--------------------+-------------------------+-------------+
|           1 | Aarav Sharma       | aarav.sharma@gmail.com  |          27 |
|           2 | Diya Rani Patel    | diya.patel@yahoo.in     |          24 |
|           3 | Kabir Singh        | kabir.singh@outlook.com |          30 |
|           4 | Ishaan Kumar Reddy | ishaan.reddy@gmail.com  |          24 |
|           5 | Ananya Iyer        | ananya.iyer@gmail.com   |          26 |
+-------------+--------------------+-------------------------+-------------+
5 rows in set (0.000 sec)

--------------
SELECT c.category_name, p.category_name AS parent_category
FROM category c LEFT JOIN category p ON c.parent_id = p.category_id
--------------

+-----------------+-----------------+
| category_name   | parent_category |
+-----------------+-----------------+
| Electronics     | NULL            |
| Fashion         | NULL            |
| Books           | NULL            |
| Mobiles         | Electronics     |
| Laptops         | Electronics     |
| Men Ethnic Wear | Fashion         |
| Fiction         | Books           |
+-----------------+-----------------+
7 rows in set (0.000 sec)

--------------
SELECT o.order_id, CONCAT(c.first_name,' ',c.last_name) AS customer, a.city,
       o.status, SUM(oi.quantity*oi.unit_price - oi.discount) AS order_total
FROM orders o
JOIN customer c   ON c.customer_id = o.customer_id
JOIN address  a   ON a.customer_id = o.customer_id AND a.address_no = o.ship_address_no
JOIN order_item oi ON oi.order_id = o.order_id
GROUP BY o.order_id, customer, a.city, o.status
--------------

+----------+--------------+-----------+-----------+-------------+
| order_id | customer     | city      | status    | order_total |
+----------+--------------+-----------+-----------+-------------+
|        1 | Aarav Sharma | Mumbai    | Delivered |    18097.00 |
|        2 | Aarav Sharma | Mumbai    | Shipped   |    50990.00 |
|        3 | Diya Patel   | Ahmedabad | Placed    |     6497.00 |
|        4 | Kabir Singh  | Noida     | Delivered |      840.00 |
|        5 | Ananya Iyer  | Bengaluru | Cancelled |    17999.00 |
+----------+--------------+-----------+-----------+-------------+
5 rows in set (0.000 sec)
```

### Referential-integrity and constraint violations

```text
-- C1. FOREIGN KEY violation: customer 99 does not exist  -> ERROR 1452
--------------
INSERT INTO orders (customer_id, ship_address_no) VALUES (99, 1)
--------------

ERROR 1452 (23000) at line 274: Cannot add or update a child row: a foreign key constraint fails (`ecommerce_db`.`orders`, CONSTRAINT `fk_orders_address` FOREIGN KEY (`customer_id`, `ship_address_no`) REFERENCES `address` (`customer_id`, `address_no`) ON DELETE RESTRICT)
```

```text
-- C2. FOREIGN KEY violation on composite FK: customer 2 has no address_no 5 -> ERROR 1452
--------------
INSERT INTO orders (customer_id, ship_address_no) VALUES (2, 5)
--------------

ERROR 1452 (23000) at line 277: Cannot add or update a child row: a foreign key constraint fails (`ecommerce_db`.`orders`, CONSTRAINT `fk_orders_address` FOREIGN KEY (`customer_id`, `ship_address_no`) REFERENCES `address` (`customer_id`, `address_no`) ON DELETE RESTRICT)
```

```text
-- C3. UNIQUE violation: duplicate email -> ERROR 1062
--------------
INSERT INTO customer (first_name, last_name, email) VALUES ('Fake','User','aarav.sharma@gmail.com')
--------------

ERROR 1062 (23000) at line 280: Duplicate entry 'aarav.sharma@gmail.com' for key 'customer.email'
```

```text
-- C4. NOT NULL violation -> ERROR 1048
--------------
INSERT INTO customer (first_name, last_name, email) VALUES ('NoEmail','User', NULL)
--------------

ERROR 1048 (23000) at line 283: Column 'email' cannot be null
```

```text
-- C5. PRIMARY KEY violation on weak entity (same owner + partial key) -> ERROR 1062
--------------
INSERT INTO address VALUES (1,1,'X','Y','Pune','Maharashtra','411001','Other')
--------------

ERROR 1062 (23000) at line 286: Duplicate entry '1-1' for key 'address.PRIMARY'
```

```text
-- C6. CHECK violation: selling_price > mrp -> ERROR 3819
--------------
INSERT INTO product (product_name, mrp, selling_price, product_type, seller_id)
VALUES ('Overpriced Cable', 100, 150, 'Electronics', 1)
--------------

ERROR 3819 (HY000) at line 289: Check constraint 'chk_price' is violated.
```

```text
-- C7. CHECK violation: invalid Indian pincode -> ERROR 3819
--------------
INSERT INTO address VALUES (3,2,'1','MG Road','Pune','Maharashtra','012345','Work')
--------------

ERROR 3819 (HY000) at line 293: Check constraint 'chk_pincode' is violated.
```

```text
-- C8. ON DELETE RESTRICT: address 1/1 is used by an order -> ERROR 1451
--------------
DELETE FROM address WHERE customer_id = 1 AND address_no = 1
--------------

ERROR 1451 (23000) at line 296: Cannot delete or update a parent row: a foreign key constraint fails (`ecommerce_db`.`orders`, CONSTRAINT `fk_orders_address` FOREIGN KEY (`customer_id`, `ship_address_no`) REFERENCES `address` (`customer_id`, `address_no`) ON DELETE RESTRICT)
```

### ON DELETE SET NULL

```text
-- D1. ON DELETE SET NULL : delete category 'Fiction' -> books lose their category
--------------
SELECT product_id, product_name, category_id FROM product WHERE product_type = 'Book'
--------------

+------------+--------------+-------------+
| product_id | product_name | category_id |
+------------+--------------+-------------+
|          5 | The Guide    |           7 |
|          6 | Malgudi Days |           7 |
+------------+--------------+-------------+
2 rows in set (0.000 sec)

--------------
DELETE FROM category WHERE category_name = 'Fiction'
--------------

Query OK, 1 row affected (0.000 sec)

--------------
SELECT product_id, product_name, category_id FROM product WHERE product_type = 'Book'
--------------

+------------+--------------+-------------+
| product_id | product_name | category_id |
+------------+--------------+-------------+
|          5 | The Guide    |        NULL |
|          6 | Malgudi Days |        NULL |
+------------+--------------+-------------+
2 rows in set (0.000 sec)
```

### ON DELETE CASCADE + SET NULL chain

```text
-- D3. ON DELETE CASCADE + SET NULL chain : delete seller 2 (Desi Threads)
--     product rows cascade away, clothing rows cascade away,
--     order_item.product_id for those products becomes NULL (history kept)
--------------
SELECT 'before' AS stage, COUNT(*) AS products FROM product WHERE seller_id = 2
--------------

+--------+----------+
| stage  | products |
+--------+----------+
| before |        2 |
+--------+----------+
1 row in set (0.000 sec)

--------------
DELETE FROM seller WHERE seller_id = 2
--------------

Query OK, 1 row affected (0.000 sec)

--------------
SELECT 'after' AS stage, COUNT(*) AS products FROM product WHERE seller_id = 2
--------------

+-------+----------+
| stage | products |
+-------+----------+
| after |        0 |
+-------+----------+
1 row in set (0.000 sec)

--------------
SELECT * FROM clothing
--------------

Empty set (0.000 sec)

--------------
SELECT * FROM order_item WHERE order_id = 3
--------------

+----------+---------+------------+----------+------------+----------+
| order_id | line_no | product_id | quantity | unit_price | discount |
+----------+---------+------------+----------+------------+----------+
|        3 |       1 |       NULL |        2 |    1899.00 |   100.00 |
|        3 |       2 |       NULL |        1 |    2799.00 |     0.00 |
+----------+---------+------------+----------+------------+----------+
2 rows in set (0.000 sec)
```

### RESTRICT and multi-level CASCADE

```text
-- D4. RESTRICT on orders.customer_id : customer 1 has orders -> ERROR 1451
--------------
DELETE FROM customer WHERE customer_id = 1
--------------

ERROR 1451 (23000) at line 322: Cannot delete or update a parent row: a foreign key constraint fails (`ecommerce_db`.`orders`, CONSTRAINT `fk_orders_address` FOREIGN KEY (`customer_id`, `ship_address_no`) REFERENCES `address` (`customer_id`, `address_no`) ON DELETE RESTRICT)
```

```text
-- D5. Multi-level ON DELETE CASCADE : delete order 1
--     -> its order_items, payments and delivery are removed automatically
--------------
SELECT
  (SELECT COUNT(*) FROM order_item WHERE order_id = 1) AS items,
  (SELECT COUNT(*) FROM payment    WHERE order_id = 1) AS payments,
  (SELECT COUNT(*) FROM delivery   WHERE order_id = 1) AS deliveries
--------------

+-------+----------+------------+
| items | payments | deliveries |
+-------+----------+------------+
|     2 |        1 |          1 |
+-------+----------+------------+
1 row in set (0.000 sec)

--------------
DELETE FROM orders WHERE order_id = 1
--------------

Query OK, 1 row affected (0.000 sec)

--------------
SELECT
  (SELECT COUNT(*) FROM order_item WHERE order_id = 1) AS items,
  (SELECT COUNT(*) FROM payment    WHERE order_id = 1) AS payments,
  (SELECT COUNT(*) FROM delivery   WHERE order_id = 1) AS deliveries
--------------

+-------+----------+------------+
| items | payments | deliveries |
+-------+----------+------------+
|     0 |        0 |          0 |
+-------+----------+------------+
1 row in set (0.000 sec)
```

### Foreign keys in the data dictionary

```text
-- Foreign keys defined in the schema (from the data dictionary)
--------------
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'ecommerce_db'
ORDER BY TABLE_NAME
--------------

+----------------+-----------------------+-----------------------+-------------+
| TABLE_NAME     | CONSTRAINT_NAME       | REFERENCED_TABLE_NAME | DELETE_RULE |
+----------------+-----------------------+-----------------------+-------------+
| address        | fk_address_customer   | customer              | CASCADE     |
| book           | book_ibfk_1           | product               | CASCADE     |
| book_author    | book_author_ibfk_1    | book                  | CASCADE     |
| category       | fk_category_parent    | category              | SET NULL    |
| clothing       | clothing_ibfk_1       | product               | CASCADE     |
| customer_phone | fk_cphone_customer    | customer              | CASCADE     |
| delivery       | fk_delivery_order     | orders                | CASCADE     |
| electronics    | electronics_ibfk_1    | product               | CASCADE     |
| order_item     | fk_item_order         | orders                | CASCADE     |
| order_item     | fk_item_product       | product               | SET NULL    |
| orders         | fk_orders_address     | address               | RESTRICT    |
| orders         | fk_orders_customer    | customer              | RESTRICT    |
| payment        | fk_payment_order      | orders                | CASCADE     |
| product        | fk_product_category   | category              | SET NULL    |
| product        | fk_product_seller     | seller                | CASCADE     |
| seller_contact | seller_contact_ibfk_1 | seller                | CASCADE     |
+----------------+-----------------------+-----------------------+-------------+
16 rows in set (0.000 sec)
```

## Observations

| Test | Constraint | MySQL error |
|---|---|---|
| Order for non-existent customer | FOREIGN KEY | `ERROR 1452` - cannot add or update a child row |
| Duplicate e-mail | UNIQUE | `ERROR 1062` - duplicate entry |
| NULL e-mail | NOT NULL | `ERROR 1048` - column cannot be null |
| Same (customer_id, address_no) twice | PRIMARY KEY of weak entity | `ERROR 1062` |
| selling_price > mrp, invalid pincode | CHECK | `ERROR 3819` - check constraint is violated |
| Delete an address or customer that is still referenced | RESTRICT | `ERROR 1451` - cannot delete or update a parent row |
| Delete category 'Fiction' | SET NULL | books keep existing with `category_id = NULL` |
| Delete seller 2 | CASCADE -> SET NULL | products and clothing rows deleted; `order_item.product_id` becomes NULL |
| Delete order 1 | CASCADE | items, payment and delivery rows deleted automatically |

## Result

The ER diagram was converted into 15 MySQL tables with all the required constraints. Every invalid insert, update or delete was rejected by MySQL with the correct error, and CASCADE, SET NULL and RESTRICT worked as defined.

## Conclusion

When constraints are written in the table definition, MySQL itself stops wrong data from being stored. The delete rule has to be chosen for each foreign key:
- CASCADE for child data that belongs to the parent;
- SET NULL when old records should be kept;
- RESTRICT when deleting the parent should not be allowed.
