-- Experiment 9: railway booking table (50000 rows) and indexing

DROP DATABASE IF EXISTS railway_db;
CREATE DATABASE railway_db;
USE railway_db;

-- PART A : Table WITHOUT any secondary index (only the primary key)
CREATE TABLE train (
    train_no    INT PRIMARY KEY,
    train_name  VARCHAR(50) NOT NULL,
    source_stn  CHAR(4) NOT NULL,
    dest_stn    CHAR(4) NOT NULL
);

INSERT INTO train VALUES
(12951,'Mumbai Rajdhani Express','MMCT','NDLS'),(12952,'New Delhi Rajdhani','NDLS','MMCT'),
(12301,'Howrah Rajdhani Express','HWH','NDLS'), (12302,'New Delhi Howrah Rajdhani','NDLS','HWH'),
(12627,'Karnataka Express','SBC','NDLS'),       (12628,'Karnataka Express','NDLS','SBC'),
(12621,'Tamil Nadu Express','MAS','NDLS'),      (12622,'Tamil Nadu Express','NDLS','MAS'),
(12009,'Shatabdi Express','MMCT','ADI'),        (12010,'Shatabdi Express','ADI','MMCT'),
(12002,'Bhopal Shatabdi','NDLS','RKMP'),        (12001,'Bhopal Shatabdi','RKMP','NDLS'),
(22691,'Rajdhani Express','SBC','NZM'),         (22692,'Rajdhani Express','NZM','SBC'),
(12259,'Duronto Express','SDAH','NDLS'),        (12260,'Duronto Express','NDLS','SDAH'),
(12723,'Telangana Express','HYB','NDLS'),       (12724,'Telangana Express','NDLS','HYB'),
(16345,'Netravati Express','LTT','TVC'),        (16346,'Netravati Express','TVC','LTT'),
(12137,'Punjab Mail','CSMT','FZR'),             (12138,'Punjab Mail','FZR','CSMT'),
(12859,'Gitanjali Express','CSMT','HWH'),       (12860,'Gitanjali Express','HWH','CSMT'),
(12433,'Chennai Rajdhani','MAS','NZM'),         (12434,'Chennai Rajdhani','NZM','MAS'),
(22439,'Vande Bharat Express','NDLS','SVDK'),   (22440,'Vande Bharat Express','SVDK','NDLS'),
(20901,'Vande Bharat Express','MMCT','GNC'),    (20902,'Vande Bharat Express','GNC','MMCT'),
(12213,'Duronto Express','DEE','YPR'),          (12214,'Duronto Express','YPR','DEE'),
(12801,'Purushottam Express','PURI','NDLS'),    (12802,'Purushottam Express','NDLS','PURI'),
(12423,'Dibrugarh Rajdhani','DBRT','NDLS'),     (12424,'Dibrugarh Rajdhani','NDLS','DBRT'),
(11077,'Jhelum Express','PUNE','JAT'),          (11078,'Jhelum Express','JAT','PUNE'),
(12925,'Paschim Express','BDTS','ASR'),         (12926,'Paschim Express','ASR','BDTS');

CREATE TABLE railway_booking (
    booking_id      INT AUTO_INCREMENT PRIMARY KEY,
    pnr             CHAR(10)     NOT NULL,
    passenger_name  VARCHAR(40)  NOT NULL,
    age             TINYINT      NOT NULL,
    gender          CHAR(1)      NOT NULL,
    train_no        INT          NOT NULL,
    source_stn      CHAR(4)      NOT NULL,
    dest_stn        CHAR(4)      NOT NULL,
    journey_date    DATE         NOT NULL,
    travel_class    CHAR(2)      NOT NULL,
    coach           VARCHAR(4)   NOT NULL,
    seat_no         SMALLINT     NOT NULL,
    fare            DECIMAL(8,2) NOT NULL,
    booking_status  ENUM('CNF','RAC','WL','CAN') NOT NULL,
    booking_time    DATETIME     NOT NULL
);

-- PART B : Generate 50,000 bookings with a recursive CTE
--          (used CRC32 instead of RAND so data comes same every time)
SET SESSION cte_max_recursion_depth = 100000;

INSERT INTO railway_booking (pnr, passenger_name, age, gender, train_no, source_stn, dest_stn,
                             journey_date, travel_class, coach, seat_no, fare,
                             booking_status, booking_time)
WITH RECURSIVE seq(n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 50000
),
tr AS (
    SELECT train_no, source_stn, dest_stn,
           ROW_NUMBER() OVER (ORDER BY train_no) - 1 AS idx
    FROM train
),
r AS (
    SELECT n,
           CRC32(CONCAT(n, '-train'))  % 40  AS t_idx,
           CRC32(CONCAT(n, '-date'))   % 365 AS d_off,
           CRC32(CONCAT(n, '-class'))  % 6   AS c_idx,
           CRC32(CONCAT(n, '-status')) % 100 AS s_pct,
           CRC32(CONCAT(n, '-fname'))  % 20  AS fn_idx,
           CRC32(CONCAT(n, '-lname'))  % 15  AS ln_idx,
           CRC32(CONCAT(n, '-age'))    % 75 + 5 AS age
    FROM seq
)
SELECT CONCAT(LPAD(4000000000 + n * 97, 10, '0')),
       CONCAT(ELT(fn_idx + 1, 'Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Reyansh','Krishna',
                  'Ishaan','Rohan','Ananya','Diya','Saanvi','Aadhya','Pari','Myra','Kavya',
                  'Priya','Sneha','Meera'), ' ',
              ELT(ln_idx + 1, 'Sharma','Verma','Patel','Reddy','Iyer','Nair','Singh','Gupta',
                  'Joshi','Kulkarni','Mehta','Rao','Das','Banerjee','Khan')),
       age,
       IF(fn_idx < 10, 'M', 'F'),
       tr.train_no, tr.source_stn, tr.dest_stn,
       DATE_ADD('2025-01-01', INTERVAL d_off DAY),
       ELT(c_idx + 1, 'SL','3A','2A','1A','CC','2S'),
       CONCAT(ELT(c_idx + 1, 'S','B','A','H','C','D'), 1 + n % 12),
       1 + n % 72,
       ELT(c_idx + 1, 650, 1750, 2500, 4200, 1300, 280) + (n % 50) * 5,
       CASE WHEN s_pct < 78 THEN 'CNF' WHEN s_pct < 86 THEN 'RAC'
            WHEN s_pct < 95 THEN 'WL'  ELSE 'CAN' END,
       DATE_SUB(DATE_ADD('2025-01-01', INTERVAL d_off DAY), INTERVAL (n % 120) DAY)
         + INTERVAL (n % 86400) SECOND
FROM r JOIN tr ON tr.idx = r.t_idx;

ANALYZE TABLE railway_booking;

-- Verify the generated data
SELECT COUNT(*) AS total_bookings, COUNT(DISTINCT train_no) AS trains,
       MIN(journey_date) AS first_journey, MAX(journey_date) AS last_journey
FROM railway_booking;

SELECT * FROM railway_booking LIMIT 5;

SELECT booking_status, COUNT(*) AS bookings FROM railway_booking GROUP BY booking_status;

SHOW INDEX FROM railway_booking;

-- PART C : Benchmark helper - runs a query N times and stores avg time
CREATE TABLE benchmark (
    query_no   VARCHAR(4),
    query_desc VARCHAR(80),
    phase      ENUM('BEFORE','AFTER'),
    runs       INT,
    avg_ms     DECIMAL(10,3),
    PRIMARY KEY (query_no, phase)
);

DELIMITER $$
CREATE PROCEDURE bench(IN p_no VARCHAR(4), IN p_desc VARCHAR(80), IN p_phase VARCHAR(6),
                       IN p_sql TEXT, IN p_runs INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE t0 DATETIME(6);
    SET @bench_sql = p_sql;
    PREPARE s FROM @bench_sql;
    EXECUTE s;                                  -- warm-up run (loads pages into buffer pool)
    SET t0 = NOW(6);
    WHILE i < p_runs DO
        EXECUTE s;
        SET i = i + 1;
    END WHILE;
    REPLACE INTO benchmark VALUES (p_no, p_desc, p_phase, p_runs,
        TIMESTAMPDIFF(MICROSECOND, t0, NOW(6)) / 1000 / p_runs);
    DEALLOCATE PREPARE s;
END$$
DELIMITER ;

-- The 6 benchmark queries (each returns COUNT and SUM INTO variables so that
-- the benchmark measures query time, not the time to print rows)
SET @q1 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM railway_booking WHERE pnr = '4000485097'";
SET @q2 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM railway_booking WHERE train_no = 12951";
SET @q3 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15'";
SET @q4 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM railway_booking WHERE source_stn = 'NDLS' AND dest_stn = 'MMCT' AND journey_date BETWEEN '2025-10-01' AND '2025-10-31'";
SET @q5 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM railway_booking WHERE journey_date = '2025-06-15' AND booking_status = 'WL'";
SET @q6 = "SELECT COUNT(*), SUM(fare) INTO @c, @s FROM (SELECT fare FROM railway_booking WHERE train_no = 12627 ORDER BY booking_time DESC LIMIT 10) t";

-- PART D : BEFORE indexing - execution plans and timings

-- Q1. Lookup by PNR
SELECT booking_id, pnr, passenger_name, train_no, journey_date, booking_status
FROM railway_booking WHERE pnr = '4000485097';
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE pnr = '4000485097';

-- Q2. All bookings of one train
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12951;

-- Q3. Train + journey date (chart preparation)
SELECT travel_class, COUNT(*) AS passengers
FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15'
GROUP BY travel_class;
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15';

-- Q4. Route search: source, destination and date range
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking
WHERE source_stn = 'NDLS' AND dest_stn = 'MMCT' AND journey_date BETWEEN '2025-10-01' AND '2025-10-31';

-- Q5. Waiting-list passengers on a date
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE journey_date = '2025-06-15' AND booking_status = 'WL';

-- Q6. Latest 10 bookings of a train (ORDER BY + LIMIT)
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12627 ORDER BY booking_time DESC LIMIT 10;

-- EXPLAIN ANALYZE shows the real work done for Q3 (full table scan)
EXPLAIN ANALYZE SELECT * FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15';

-- Handler counters: how many rows did InnoDB read for Q2?
FLUSH STATUS;
SELECT COUNT(*) FROM railway_booking WHERE train_no = 12951;
SHOW SESSION STATUS WHERE Variable_name IN ('Handler_read_rnd_next','Handler_read_key','Handler_read_next');

CALL bench('Q1', 'PNR lookup',                      'BEFORE', @q1, 20);
CALL bench('Q2', 'train_no = ?',                    'BEFORE', @q2, 20);
CALL bench('Q3', 'train_no = ? AND journey_date = ?','BEFORE', @q3, 20);
CALL bench('Q4', 'source, dest, date range',        'BEFORE', @q4, 20);
CALL bench('Q5', 'journey_date = ? AND status = WL','BEFORE', @q5, 20);
CALL bench('Q6', 'train_no = ? ORDER BY time LIMIT','BEFORE', @q6, 20);

SELECT * FROM benchmark WHERE phase = 'BEFORE';

-- PART E : Create single-column and composite indexes
-- single-column indexes
CREATE UNIQUE INDEX idx_pnr      ON railway_booking (pnr);
CREATE INDEX        idx_train_no ON railway_booking (train_no);
-- composite indexes
CREATE INDEX idx_train_date      ON railway_booking (train_no, journey_date);
CREATE INDEX idx_route_date      ON railway_booking (source_stn, dest_stn, journey_date);
CREATE INDEX idx_date_status     ON railway_booking (journey_date, booking_status);
CREATE INDEX idx_train_btime     ON railway_booking (train_no, booking_time);

ANALYZE TABLE railway_booking;

SELECT INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns_in_order,
       IF(NON_UNIQUE = 0, 'UNIQUE', 'NON-UNIQUE') AS uniqueness
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'railway_db' AND TABLE_NAME = 'railway_booking'
GROUP BY INDEX_NAME, NON_UNIQUE;

-- Space used by the indexes
SELECT index_name, ROUND(stat_value * @@innodb_page_size / 1024, 0) AS size_kb
FROM mysql.innodb_index_stats
WHERE database_name = 'railway_db' AND table_name = 'railway_booking' AND stat_name = 'size';

-- PART F : AFTER indexing - execution plans and timings
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE pnr = '4000485097';
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12951;
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15';
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking
WHERE source_stn = 'NDLS' AND dest_stn = 'MMCT' AND journey_date BETWEEN '2025-10-01' AND '2025-10-31';
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE journey_date = '2025-06-15' AND booking_status = 'WL';
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE train_no = 12627 ORDER BY booking_time DESC LIMIT 10;

EXPLAIN ANALYZE SELECT * FROM railway_booking WHERE train_no = 12951 AND journey_date = '2025-06-15';

FLUSH STATUS;
SELECT COUNT(*) FROM railway_booking WHERE train_no = 12951;
SHOW SESSION STATUS WHERE Variable_name IN ('Handler_read_rnd_next','Handler_read_key','Handler_read_next');

CALL bench('Q1', 'PNR lookup',                      'AFTER', @q1, 20);
CALL bench('Q2', 'train_no = ?',                    'AFTER', @q2, 20);
CALL bench('Q3', 'train_no = ? AND journey_date = ?','AFTER', @q3, 20);
CALL bench('Q4', 'source, dest, date range',        'AFTER', @q4, 20);
CALL bench('Q5', 'journey_date = ? AND status = WL','AFTER', @q5, 20);
CALL bench('Q6', 'train_no = ? ORDER BY time LIMIT','AFTER', @q6, 20);

-- PART G : Comparison
SELECT b.query_no, b.query_desc,
       b.avg_ms AS before_ms, a.avg_ms AS after_ms,
       ROUND(b.avg_ms / NULLIF(a.avg_ms, 0), 1) AS speedup_x
FROM benchmark b
JOIN benchmark a ON a.query_no = b.query_no AND a.phase = 'AFTER'
WHERE b.phase = 'BEFORE'
ORDER BY b.query_no;

-- PART H : Composite index rules (leftmost prefix)
-- H1. Uses idx_route_date: leftmost column source_stn is present
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE source_stn = 'NDLS';
-- H2. Cannot use idx_route_date: leftmost column missing -> full scan
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE dest_stn = 'MMCT';
-- H3. Covering index: all needed columns are inside idx_train_date -> "Using index"
EXPLAIN FORMAT=TRADITIONAL SELECT train_no, journey_date FROM railway_booking WHERE train_no = 12951;
-- H4. Index forced off for comparison
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking IGNORE INDEX (idx_train_date, idx_train_no, idx_train_btime, idx_date_status)
WHERE train_no = 12951 AND journey_date = '2025-06-15';
-- H5. A function on the indexed column prevents index use
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM railway_booking WHERE MONTH(journey_date) = 6 AND YEAR(journey_date) = 2025 AND booking_status = 'WL';
