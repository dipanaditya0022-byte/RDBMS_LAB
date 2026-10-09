-- Experiment 8 part 1: transactions, savepoints, rollback
-- part 2 (two sessions) is in exp08_session_A.sql and exp08_session_B.sql

DROP DATABASE IF EXISTS bank_db;
CREATE DATABASE bank_db;
USE bank_db;

CREATE TABLE accounts (
    acc_no   CHAR(6) PRIMARY KEY,
    holder   VARCHAR(40) NOT NULL,
    branch   VARCHAR(30) NOT NULL,
    balance  DECIMAL(12,2) NOT NULL,
    status   ENUM('ACTIVE','FROZEN') NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_balance CHECK (balance >= 0)        -- no overdraft
) ENGINE = InnoDB;

CREATE TABLE transactions (
    txn_id    INT AUTO_INCREMENT PRIMARY KEY,
    from_acc  CHAR(6),
    to_acc    CHAR(6),
    amount    DECIMAL(12,2) NOT NULL,
    txn_type  ENUM('TRANSFER','DEPOSIT','WITHDRAW','INTEREST','FEE') NOT NULL,
    txn_time  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- failed transfers are saved here (after rollback)
CREATE TABLE failed_txn_log (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    from_acc  CHAR(6),
    to_acc    CHAR(6),
    amount    DECIMAL(12,2),
    reason    VARCHAR(200),
    logged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO accounts (acc_no, holder, branch, balance, status) VALUES
('ACC101', 'Aarav Sharma',  'Mumbai - Andheri',   50000.00, 'ACTIVE'),
('ACC102', 'Diya Patel',    'Ahmedabad - CG Rd',  30000.00, 'ACTIVE'),
('ACC103', 'Kabir Singh',   'Pune - FC Road',     75000.00, 'ACTIVE'),
('ACC104', 'Ishaan Reddy',  'Hyderabad - HITEC',  20000.00, 'ACTIVE'),
('ACC105', 'Meera Pillai',  'Kochi - MG Road',    15000.00, 'FROZEN');

-- no debit/credit allowed on frozen account
DELIMITER $$
CREATE TRIGGER trg_frozen_account
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF OLD.status = 'FROZEN' AND NEW.balance <> OLD.balance THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is FROZEN - no debit/credit allowed';
    END IF;
END$$
DELIMITER ;

SELECT * FROM accounts;
SELECT SUM(balance) AS total_money_in_bank FROM accounts;

-- PART A : COMMIT and ROLLBACK
SELECT @@autocommit AS autocommit, @@transaction_isolation AS isolation_level;

-- A1. Successful transfer of Rs 5,000 from ACC101 to ACC102 -> COMMIT
START TRANSACTION;
    UPDATE accounts SET balance = balance - 5000 WHERE acc_no = 'ACC101';
    UPDATE accounts SET balance = balance + 5000 WHERE acc_no = 'ACC102';
    INSERT INTO transactions (from_acc, to_acc, amount, txn_type) VALUES ('ACC101','ACC102',5000,'TRANSFER');
COMMIT;
SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC101','ACC102');

-- A2. Transfer started but cancelled by the user -> ROLLBACK
BEGIN;                       -- BEGIN is a synonym of START TRANSACTION
    UPDATE accounts SET balance = balance - 20000 WHERE acc_no = 'ACC103';
    UPDATE accounts SET balance = balance + 20000 WHERE acc_no = 'ACC104';
    -- inside the transaction the change is visible
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC103','ACC104');
ROLLBACK;
-- after ROLLBACK the balances are back to the original values
SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC103','ACC104');

-- PART B : SAVEPOINT, ROLLBACK TO SAVEPOINT, RELEASE SAVEPOINT
START TRANSACTION;
    -- step 1: salary credit
    UPDATE accounts SET balance = balance + 40000 WHERE acc_no = 'ACC104';
    INSERT INTO transactions (to_acc, amount, txn_type) VALUES ('ACC104', 40000, 'DEPOSIT');
    SAVEPOINT after_salary;

    -- step 2: rent payment to ACC102
    UPDATE accounts SET balance = balance - 15000 WHERE acc_no = 'ACC104';
    UPDATE accounts SET balance = balance + 15000 WHERE acc_no = 'ACC102';
    INSERT INTO transactions (from_acc, to_acc, amount, txn_type) VALUES ('ACC104','ACC102',15000,'TRANSFER');
    SAVEPOINT after_rent;

    -- step 3: a wrong duplicate rent payment
    UPDATE accounts SET balance = balance - 15000 WHERE acc_no = 'ACC104';
    UPDATE accounts SET balance = balance + 15000 WHERE acc_no = 'ACC102';
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104');

    -- undo only step 3
    ROLLBACK TO SAVEPOINT after_rent;
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104');

    -- release a savepoint (it can no longer be used)
    RELEASE SAVEPOINT after_salary;
    ROLLBACK TO SAVEPOINT after_salary;      -- ERROR 1305: SAVEPOINT does not exist
COMMIT;                                      -- steps 1 and 2 are made permanent

SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104');
SELECT * FROM transactions;

-- PART C : Simulating partial failures inside a stored procedure
DROP PROCEDURE IF EXISTS transfer_funds;
DELIMITER $$
CREATE PROCEDURE transfer_funds(IN p_from CHAR(6), IN p_to CHAR(6), IN p_amount DECIMAL(12,2))
BEGIN
    DECLARE v_msg VARCHAR(200);
    DECLARE v_cnt INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
        ROLLBACK;                                  -- undo the partial work
        INSERT INTO failed_txn_log (from_acc, to_acc, amount, reason)
        VALUES (p_from, p_to, p_amount, v_msg);    -- runs in autocommit mode
        SELECT 'ROLLED BACK' AS outcome, v_msg AS reason;
    END;

    START TRANSACTION;
        IF p_amount <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
        END IF;

        -- credit is done first on purpose, so if debit fails
        -- we get half done transfer which has to be rolled back
        UPDATE accounts SET balance = balance + p_amount WHERE acc_no = p_to;
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Receiver account not found';
        END IF;

        UPDATE accounts SET balance = balance - p_amount WHERE acc_no = p_from;  -- CHECK may fail here
        SELECT COUNT(*) INTO v_cnt FROM accounts WHERE acc_no = p_from;
        IF v_cnt = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sender account not found';
        END IF;

        INSERT INTO transactions (from_acc, to_acc, amount, txn_type)
        VALUES (p_from, p_to, p_amount, 'TRANSFER');
    COMMIT;
    SELECT 'COMMITTED' AS outcome, CONCAT('Rs ', p_amount, ' ', p_from, ' -> ', p_to) AS details;
END$$
DELIMITER ;

SELECT acc_no, balance, status FROM accounts;

-- C1. Valid transfer -> COMMITTED
CALL transfer_funds('ACC103', 'ACC101', 10000);

-- C2. Insufficient balance: credit to ACC102 succeeds, debit of ACC104 violates
--     CHECK (balance >= 0) -> whole transaction rolled back
CALL transfer_funds('ACC104', 'ACC102', 999999);

-- C3. Receiver does not exist
CALL transfer_funds('ACC101', 'ACC999', 1000);

-- C4. Sender does not exist (credit already done -> must be undone)
CALL transfer_funds('ACC999', 'ACC101', 1000);

-- C5. Frozen receiver -> trigger raises error -> rolled back
CALL transfer_funds('ACC101', 'ACC105', 500);

-- C6. Negative amount
CALL transfer_funds('ACC101', 'ACC102', -50);

-- Balances: only C1 changed anything; money is conserved
SELECT acc_no, balance, status FROM accounts;
SELECT SUM(balance) AS total_money_in_bank FROM accounts;
SELECT id, from_acc, to_acc, amount, reason FROM failed_txn_log;

-- PART D : Batch job with one SAVEPOINT per row
--   Post 1% interest to every account. A failure on one account rolls back
--   only that account's work; the rest of the batch is committed.
DROP PROCEDURE IF EXISTS post_monthly_interest;
DELIMITER $$
CREATE PROCEDURE post_monthly_interest()
BEGIN
    DECLARE v_acc   CHAR(6);
    DECLARE v_done  INT DEFAULT 0;
    DECLARE v_ok    INT DEFAULT 0;
    DECLARE v_fail  INT DEFAULT 0;
    DECLARE v_error INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT acc_no FROM accounts ORDER BY acc_no;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

    START TRANSACTION;
    OPEN cur;
    acc_loop: LOOP
        FETCH cur INTO v_acc;
        IF v_done = 1 THEN LEAVE acc_loop; END IF;

        SAVEPOINT sp_account;
        SET v_error = 0;

        INSERT INTO transactions (to_acc, amount, txn_type)
        SELECT acc_no, ROUND(balance * 0.01, 2), 'INTEREST' FROM accounts WHERE acc_no = v_acc;
        UPDATE accounts SET balance = ROUND(balance * 1.01, 2) WHERE acc_no = v_acc;

        IF v_error = 1 THEN
            ROLLBACK TO SAVEPOINT sp_account;    -- undo the INSERT for this account only
            INSERT INTO failed_txn_log (to_acc, reason) VALUES (v_acc, 'Interest posting failed');
            SET v_fail = v_fail + 1;
        ELSE
            SET v_ok = v_ok + 1;
        END IF;
    END LOOP;
    CLOSE cur;
    COMMIT;

    SELECT v_ok AS accounts_credited, v_fail AS accounts_failed;
END$$
DELIMITER ;

CALL post_monthly_interest();

SELECT acc_no, balance, status FROM accounts;
SELECT txn_id, to_acc, amount, txn_type FROM transactions WHERE txn_type = 'INTEREST';
SELECT id, to_acc, reason FROM failed_txn_log WHERE reason LIKE 'Interest%';

-- PART E : Implicit commit - DDL inside a transaction cannot be rolled back
START TRANSACTION;
    UPDATE accounts SET balance = balance + 1 WHERE acc_no = 'ACC101';
    CREATE TABLE temp_audit (id INT);   -- DDL causes an IMPLICIT COMMIT
ROLLBACK;                               -- nothing left to roll back
SELECT acc_no, balance FROM accounts WHERE acc_no = 'ACC101';   -- the +1 survived
DROP TABLE temp_audit;

-- Reset balances for the two-session concurrency demo (Part 2)
UPDATE accounts SET balance = CASE acc_no
    WHEN 'ACC101' THEN 50000 WHEN 'ACC102' THEN 30000 WHEN 'ACC103' THEN 75000
    WHEN 'ACC104' THEN 20000 ELSE balance END
WHERE status = 'ACTIVE';
