-- Experiment 2: ER diagram to relational schema (e-commerce)

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- PART A : CREATE TABLE statements

-- Strong entity : CUSTOMER  (composite attribute name -> 3 columns)
CREATE TABLE customer (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(40)  NOT NULL,
    middle_name   VARCHAR(40),
    last_name     VARCHAR(40)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    dob           DATE,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- age is a DERIVED attribute -> computed in queries, not stored
);

-- Multi-valued attribute phone_no -> separate table
CREATE TABLE customer_phone (
    customer_id INT         NOT NULL,
    phone_no    VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone_no),
    CONSTRAINT fk_cphone_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE CASCADE
);

-- Weak entity : ADDRESS (owner = CUSTOMER, partial key = address_no)
CREATE TABLE address (
    customer_id  INT          NOT NULL,
    address_no   TINYINT      NOT NULL,
    house_no     VARCHAR(20)  NOT NULL,
    street       VARCHAR(100) NOT NULL,
    city         VARCHAR(50)  NOT NULL,
    state        VARCHAR(50)  NOT NULL,
    pincode      CHAR(6)      NOT NULL,
    address_type ENUM('Home','Work','Other') NOT NULL DEFAULT 'Home',
    PRIMARY KEY (customer_id, address_no),
    CONSTRAINT chk_pincode CHECK (pincode REGEXP '^[1-9][0-9]{5}$'),
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE seller (
    seller_id     INT AUTO_INCREMENT PRIMARY KEY,
    business_name VARCHAR(100) NOT NULL,
    gstin         CHAR(15)     NOT NULL UNIQUE,
    pan           CHAR(10)     NOT NULL UNIQUE,
    rating        DECIMAL(2,1) CHECK (rating BETWEEN 0 AND 5)
);

-- Multi-valued attribute contact_no of SELLER
CREATE TABLE seller_contact (
    seller_id  INT         NOT NULL,
    contact_no VARCHAR(15) NOT NULL,
    PRIMARY KEY (seller_id, contact_no),
    FOREIGN KEY (seller_id) REFERENCES seller(seller_id) ON DELETE CASCADE
);

-- Recursive relationship SUBCATEGORY_OF -> self-referencing FK
CREATE TABLE category (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(60) NOT NULL UNIQUE,
    parent_id     INT NULL,
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_id)
        REFERENCES category(category_id) ON DELETE SET NULL
);

-- Superclass PRODUCT
CREATE TABLE product (
    product_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_name  VARCHAR(120)  NOT NULL,
    brand         VARCHAR(60),
    mrp           DECIMAL(10,2) NOT NULL CHECK (mrp > 0),
    selling_price DECIMAL(10,2) NOT NULL,
    stock_qty     INT           NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    gst_rate      DECIMAL(4,2)  NOT NULL DEFAULT 18.00,
    product_type  ENUM('Electronics','Clothing','Book','Other') NOT NULL,
    seller_id     INT NOT NULL,          -- total participation in SELLS
    category_id   INT NULL,              -- becomes NULL if category deleted
    CONSTRAINT chk_price CHECK (selling_price <= mrp),
    CONSTRAINT fk_product_seller FOREIGN KEY (seller_id)
        REFERENCES seller(seller_id) ON DELETE CASCADE,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id)
        REFERENCES category(category_id) ON DELETE SET NULL
);

-- Specialization (disjoint): one table per subclass, PK = FK to superclass
CREATE TABLE electronics (
    product_id      INT PRIMARY KEY,
    warranty_months INT NOT NULL,
    power_rating    VARCHAR(20),
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
);

CREATE TABLE clothing (
    product_id INT PRIMARY KEY,
    size       ENUM('XS','S','M','L','XL','XXL') NOT NULL,
    fabric     VARCHAR(30),
    gender     ENUM('Men','Women','Unisex','Kids') NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
);

CREATE TABLE book (
    product_id INT PRIMARY KEY,
    isbn       CHAR(13) NOT NULL UNIQUE,
    language   VARCHAR(30) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
);

-- Multi-valued attribute author of BOOK
CREATE TABLE book_author (
    product_id  INT NOT NULL,
    author_name VARCHAR(80) NOT NULL,
    PRIMARY KEY (product_id, author_name),
    FOREIGN KEY (product_id) REFERENCES book(product_id) ON DELETE CASCADE
);

-- ORDER (named orders because ORDER is a reserved word)
CREATE TABLE orders (
    order_id         INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT NOT NULL,
    ship_address_no  TINYINT NOT NULL,
    order_date       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status           ENUM('Placed','Shipped','Delivered','Cancelled','Returned')
                     NOT NULL DEFAULT 'Placed',
    -- a customer who has orders must not be deleted (financial records)
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE RESTRICT,
    -- SHIPS_TO : composite FK to the weak entity ADDRESS
    CONSTRAINT fk_orders_address FOREIGN KEY (customer_id, ship_address_no)
        REFERENCES address(customer_id, address_no) ON DELETE RESTRICT
);

-- Weak entity ORDER_ITEM (owner = ORDERS, partial key = line_no)
CREATE TABLE order_item (
    order_id   INT NOT NULL,
    line_no    TINYINT NOT NULL,
    product_id INT NULL,                   -- SET NULL keeps order history
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    discount   DECIMAL(10,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (order_id, line_no),
    CONSTRAINT fk_item_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_product FOREIGN KEY (product_id)
        REFERENCES product(product_id) ON DELETE SET NULL
);

CREATE TABLE payment (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT NOT NULL,
    method          ENUM('UPI','Card','NetBanking','COD','Wallet') NOT NULL,
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    paid_at         DATETIME,
    transaction_ref VARCHAR(40) UNIQUE,
    status          ENUM('Pending','Success','Failed','Refunded') NOT NULL,
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 1:1 relationship SHIPPED_VIA -> UNIQUE foreign key
CREATE TABLE delivery (
    delivery_id     INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT NOT NULL UNIQUE,
    courier_partner VARCHAR(40) NOT NULL,
    awb_no          VARCHAR(20) NOT NULL UNIQUE,
    shipped_on      DATE,
    delivered_on    DATE,
    status          ENUM('Pending','In Transit','Delivered','RTO') NOT NULL,
    CONSTRAINT fk_delivery_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT chk_dates CHECK (delivered_on IS NULL OR delivered_on >= shipped_on)
);

SHOW TABLES;

-- PART B : Sample data

INSERT INTO customer (first_name, middle_name, last_name, email, dob) VALUES
('Aarav',  NULL,     'Sharma', 'aarav.sharma@gmail.com', '1998-04-12'),
('Diya',   'Rani',   'Patel',  'diya.patel@yahoo.in',    '2000-11-03'),
('Kabir',  NULL,     'Singh',  'kabir.singh@outlook.com','1995-07-21'),
('Ishaan', 'Kumar',  'Reddy',  'ishaan.reddy@gmail.com', '2001-01-30'),
('Ananya', NULL,     'Iyer',   'ananya.iyer@gmail.com',  '1999-09-09');

INSERT INTO customer_phone VALUES
(1,'9876543210'),(1,'9123456780'),(2,'9988776655'),(3,'9001122334'),
(4,'9812345678'),(4,'8800112233'),(5,'9090909090');

INSERT INTO address VALUES
(1,1,'B-204','Andheri East, MG Road','Mumbai','Maharashtra','400069','Home'),
(1,2,'5th Floor','BKC Tower','Mumbai','Maharashtra','400051','Work'),
(2,1,'12','Satellite Road','Ahmedabad','Gujarat','380015','Home'),
(3,1,'H-45','Sector 18','Noida','Uttar Pradesh','201301','Home'),
(4,1,'Plot 7','Jubilee Hills','Hyderabad','Telangana','500033','Home'),
(5,1,'22/3','Koramangala 4th Block','Bengaluru','Karnataka','560034','Home');

INSERT INTO seller (business_name, gstin, pan, rating) VALUES
('TechBazaar Pvt Ltd',   '27AABCT1234F1Z5', 'AABCT1234F', 4.5),
('Desi Threads',         '24AAFCD5678K1Z2', 'AAFCD5678K', 4.2),
('Pustak Mahal Online',  '07AAGCP9012L1Z8', 'AAGCP9012L', 4.8);

INSERT INTO seller_contact VALUES
(1,'02240001111'),(1,'9820098200'),(2,'07926001234'),(3,'01123456789');

INSERT INTO category (category_name, parent_id) VALUES
('Electronics', NULL), ('Fashion', NULL), ('Books', NULL),
('Mobiles', 1), ('Laptops', 1), ('Men Ethnic Wear', 2), ('Fiction', 3);

INSERT INTO product (product_name, brand, mrp, selling_price, stock_qty, gst_rate, product_type, seller_id, category_id) VALUES
('Redmi Note 13 5G (8GB/256GB)', 'Xiaomi', 20999, 17999, 50, 18, 'Electronics', 1, 4),
('Lenovo IdeaPad Slim 3',        'Lenovo', 65990, 52990, 15, 18, 'Electronics', 1, 5),
('Cotton Kurta Pyjama Set',      'Manyavar', 2999, 1899, 120, 5, 'Clothing',    2, 6),
('Silk Nehru Jacket',            'Fabindia', 3499, 2799, 40,  12, 'Clothing',   2, 6),
('The Guide',                    'Penguin',   399,  299, 200, 0,  'Book',       3, 7),
('Malgudi Days',                 'Penguin',   350,  280, 150, 0,  'Book',       3, 7);

INSERT INTO electronics VALUES (1, 12, '5000 mAh'), (2, 12, '65 W');
INSERT INTO clothing    VALUES (3, 'L', 'Cotton', 'Men'), (4, 'M', 'Silk', 'Men');
INSERT INTO book        VALUES (5, '9780143039648', 'English'), (6, '9780143031581', 'English');
INSERT INTO book_author VALUES (5, 'R. K. Narayan'), (6, 'R. K. Narayan');

INSERT INTO orders (customer_id, ship_address_no, order_date, status) VALUES
(1, 1, '2025-10-01 10:15:00', 'Delivered'),
(1, 2, '2025-10-05 18:40:00', 'Shipped'),
(2, 1, '2025-10-06 09:05:00', 'Placed'),
(3, 1, '2025-10-07 21:30:00', 'Delivered'),
(5, 1, '2025-10-08 13:00:00', 'Cancelled');

INSERT INTO order_item VALUES
(1, 1, 1, 1, 17999, 500),
(1, 2, 5, 2,   299,   0),
(2, 1, 2, 1, 52990, 2000),
(3, 1, 3, 2,  1899, 100),
(3, 2, 4, 1,  2799,   0),
(4, 1, 6, 3,   280,   0),
(5, 1, 1, 1, 17999,   0);

INSERT INTO payment (order_id, method, amount, paid_at, transaction_ref, status) VALUES
(1, 'UPI',        18097, '2025-10-01 10:16:00', 'UPI2510011016AB', 'Success'),
(2, 'Card',       50990, '2025-10-05 18:41:00', 'CRD2510051841XY', 'Success'),
(3, 'COD',         6497, NULL,                  NULL,              'Pending'),
(4, 'NetBanking',   840, '2025-10-07 21:31:00', 'NB25100721319Q',  'Success'),
(5, 'UPI',        17999, '2025-10-08 13:01:00', 'UPI2510081301ZZ', 'Refunded');

INSERT INTO delivery (order_id, courier_partner, awb_no, shipped_on, delivered_on, status) VALUES
(1, 'Delhivery',     'DLV100200300', '2025-10-02', '2025-10-04', 'Delivered'),
(2, 'Blue Dart',     'BD5566778899', '2025-10-06', NULL,         'In Transit'),
(4, 'Ekart',         'EK9988776655', '2025-10-08', '2025-10-10', 'Delivered');

-- Verify the data
SELECT customer_id, CONCAT_WS(' ', first_name, middle_name, last_name) AS full_name,
       email, TIMESTAMPDIFF(YEAR, dob, '2025-10-10') AS age_derived
FROM customer;

SELECT c.category_name, p.category_name AS parent_category
FROM category c LEFT JOIN category p ON c.parent_id = p.category_id;

SELECT o.order_id, CONCAT(c.first_name,' ',c.last_name) AS customer, a.city,
       o.status, SUM(oi.quantity*oi.unit_price - oi.discount) AS order_total
FROM orders o
JOIN customer c   ON c.customer_id = o.customer_id
JOIN address  a   ON a.customer_id = o.customer_id AND a.address_no = o.ship_address_no
JOIN order_item oi ON oi.order_id = o.order_id
GROUP BY o.order_id, customer, a.city, o.status;

-- PART C : Demonstrating integrity-constraint violations
-- (all of these should give error)

-- C1. FOREIGN KEY violation: customer 99 does not exist  -> ERROR 1452
INSERT INTO orders (customer_id, ship_address_no) VALUES (99, 1);

-- C2. FOREIGN KEY violation on composite FK: customer 2 has no address_no 5 -> ERROR 1452
INSERT INTO orders (customer_id, ship_address_no) VALUES (2, 5);

-- C3. UNIQUE violation: duplicate email -> ERROR 1062
INSERT INTO customer (first_name, last_name, email) VALUES ('Fake','User','aarav.sharma@gmail.com');

-- C4. NOT NULL violation -> ERROR 1048
INSERT INTO customer (first_name, last_name, email) VALUES ('NoEmail','User', NULL);

-- C5. PRIMARY KEY violation on weak entity (same owner + partial key) -> ERROR 1062
INSERT INTO address VALUES (1,1,'X','Y','Pune','Maharashtra','411001','Other');

-- C6. CHECK violation: selling_price > mrp -> ERROR 3819
INSERT INTO product (product_name, mrp, selling_price, product_type, seller_id)
VALUES ('Overpriced Cable', 100, 150, 'Electronics', 1);

-- C7. CHECK violation: invalid Indian pincode -> ERROR 3819
INSERT INTO address VALUES (3,2,'1','MG Road','Pune','Maharashtra','012345','Work');

-- C8. ON DELETE RESTRICT: address 1/1 is used by an order -> ERROR 1451
DELETE FROM address WHERE customer_id = 1 AND address_no = 1;

-- C9. Updating a parent key that is referenced -> ERROR 1451
UPDATE orders SET order_id = 500 WHERE order_id = 1;

-- PART D : ON DELETE CASCADE and ON DELETE SET NULL in action

-- D1. ON DELETE SET NULL : delete category 'Fiction' -> books lose their category
SELECT product_id, product_name, category_id FROM product WHERE product_type = 'Book';
DELETE FROM category WHERE category_name = 'Fiction';
SELECT product_id, product_name, category_id FROM product WHERE product_type = 'Book';

-- D2. Self-referencing SET NULL : delete 'Fashion' -> 'Men Ethnic Wear' becomes top-level
DELETE FROM category WHERE category_name = 'Fashion';
SELECT * FROM category;

-- D3. ON DELETE CASCADE + SET NULL chain : delete seller 2 (Desi Threads)
--     product rows cascade away, clothing rows cascade away,
--     order_item.product_id for those products becomes NULL (history kept)
SELECT 'before' AS stage, COUNT(*) AS products FROM product WHERE seller_id = 2;
DELETE FROM seller WHERE seller_id = 2;
SELECT 'after' AS stage, COUNT(*) AS products FROM product WHERE seller_id = 2;
SELECT * FROM clothing;
SELECT * FROM order_item WHERE order_id = 3;

-- D4. RESTRICT on orders.customer_id : customer 1 has orders -> ERROR 1451 
DELETE FROM customer WHERE customer_id = 1;

-- D5. Multi-level ON DELETE CASCADE : delete order 1
--     -> its order_items, payments and delivery are removed automatically
SELECT
  (SELECT COUNT(*) FROM order_item WHERE order_id = 1) AS items,
  (SELECT COUNT(*) FROM payment    WHERE order_id = 1) AS payments,
  (SELECT COUNT(*) FROM delivery   WHERE order_id = 1) AS deliveries;
DELETE FROM orders WHERE order_id = 1;
SELECT
  (SELECT COUNT(*) FROM order_item WHERE order_id = 1) AS items,
  (SELECT COUNT(*) FROM payment    WHERE order_id = 1) AS payments,
  (SELECT COUNT(*) FROM delivery   WHERE order_id = 1) AS deliveries;

-- D6. Customer 4 has no orders -> delete cascades to phones and addresses (weak entity)
SELECT (SELECT COUNT(*) FROM customer_phone WHERE customer_id = 4) AS phones,
       (SELECT COUNT(*) FROM address        WHERE customer_id = 4) AS addresses;
DELETE FROM customer WHERE customer_id = 4;
SELECT (SELECT COUNT(*) FROM customer_phone WHERE customer_id = 4) AS phones,
       (SELECT COUNT(*) FROM address        WHERE customer_id = 4) AS addresses;

-- Foreign keys defined in the schema (from the data dictionary)
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'ecommerce_db'
ORDER BY TABLE_NAME;
