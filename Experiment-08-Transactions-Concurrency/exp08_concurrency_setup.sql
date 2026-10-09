-- Experiment 8 part 2: setup for two session demo
-- run this first and then run session A and session B together in two terminals
USE bank_db;

-- start time is stored in a table so both sessions use the same clock
DROP TABLE IF EXISTS sync_clock;
CREATE TABLE sync_clock (start_ts DECIMAL(16,3) NOT NULL);
INSERT INTO sync_clock VALUES (UNIX_TIMESTAMP(NOW(3)) + 3);   -- start in 3 seconds

DROP PROCEDURE IF EXISTS wait_until;
DELIMITER $$
CREATE PROCEDURE wait_until(IN t DECIMAL(8,3))
BEGIN
    DECLARE s DECIMAL(16,3);
    SELECT start_ts INTO s FROM sync_clock;
    DO SLEEP(GREATEST(0, s + t - UNIX_TIMESTAMP(NOW(3))));
END$$
DELIMITER ;

-- seconds passed since start
DROP FUNCTION IF EXISTS t_now;
CREATE FUNCTION t_now() RETURNS DECIMAL(8,1) NOT DETERMINISTIC READS SQL DATA
RETURN ROUND(UNIX_TIMESTAMP(NOW(3)) - (SELECT start_ts FROM sync_clock), 1);

DELETE FROM accounts WHERE acc_no IN ('ACC106', 'ACC107');
UPDATE accounts SET balance = CASE acc_no
    WHEN 'ACC101' THEN 50000 WHEN 'ACC102' THEN 30000 WHEN 'ACC103' THEN 75000
    WHEN 'ACC104' THEN 20000 ELSE balance END
WHERE status = 'ACTIVE';

SELECT acc_no, holder, balance FROM accounts;
