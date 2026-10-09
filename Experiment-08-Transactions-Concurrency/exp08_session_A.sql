-- Experiment 8 part 2: SESSION A
-- run together with session B. wait_until(x) waits till x seconds from start
USE bank_db;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION innodb_lock_wait_timeout = 3;

-- SCENARIO 1 : DIRTY READ  (t = 0 .. 4)
CALL wait_until(0.5);
-- A1 (t=0.5): debit Rs 20,000 from ACC101 but do NOT commit yet
START TRANSACTION;
UPDATE accounts SET balance = balance - 20000 WHERE acc_no = 'ACC101';
SELECT t_now() AS t, acc_no, balance AS balance_inside_A FROM accounts WHERE acc_no = 'ACC101';

CALL wait_until(3);
-- A2 (t=3): the debit is cancelled
ROLLBACK;
SELECT t_now() AS t, 'A rolled back' AS event;

-- SCENARIO 2 : NON-REPEATABLE READ  (t = 5 .. 11)
CALL wait_until(6);
-- A3 (t=6): deposit Rs 5,000 into ACC102 and COMMIT (autocommit)
UPDATE accounts SET balance = balance + 5000 WHERE acc_no = 'ACC102';
SELECT t_now() AS t, 'A committed +5000 to ACC102' AS event;

CALL wait_until(9);
-- A4 (t=9): another committed deposit of Rs 5,000
UPDATE accounts SET balance = balance + 5000 WHERE acc_no = 'ACC102';
SELECT t_now() AS t, 'A committed +5000 to ACC102' AS event;

-- SCENARIO 3 : PHANTOM READ  (t = 12 .. 18)
CALL wait_until(13);
-- A5 (t=13): a new rich customer opens an account (committed)
INSERT INTO accounts VALUES ('ACC106', 'Ananya Iyer', 'Bengaluru - Koramangala', 90000, 'ACTIVE');
SELECT t_now() AS t, 'A inserted ACC106 (90000)' AS event;

CALL wait_until(16);
-- A6 (t=16): another new account (committed)
INSERT INTO accounts VALUES ('ACC107', 'Rohan Gupta', 'Delhi - CP', 60000, 'ACTIVE');
SELECT t_now() AS t, 'A inserted ACC107 (60000)' AS event;

-- SCENARIO 4 : LOST UPDATE  (t = 19 .. 23)  read-modify-write without locks
CALL wait_until(19.5);
-- A7 (t=19.5): ATM withdrawal of Rs 10,000 from ACC103 - read the balance
START TRANSACTION;
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103';
SELECT t_now() AS t, @bal AS balance_read_by_A;

CALL wait_until(21);
-- A8 (t=21): write back (read value - 10000) and commit
UPDATE accounts SET balance = @bal - 10000 WHERE acc_no = 'ACC103';
COMMIT;
SELECT t_now() AS t, 'A wrote balance = 75000 - 10000 = 65000' AS event;

CALL wait_until(23);
-- A9 (t=23): final balance - expected 75000 - 10000 + 5000 = 70000
SELECT t_now() AS t, acc_no, balance AS final_balance,
       IF(balance = 70000, 'CORRECT', 'LOST UPDATE!') AS verdict
FROM accounts WHERE acc_no = 'ACC103';

-- SCENARIO 4b : LOST UPDATE PREVENTED with SELECT ... FOR UPDATE (t = 24 .. 29)
CALL wait_until(24);
UPDATE accounts SET balance = 75000 WHERE acc_no = 'ACC103';      -- reset
CALL wait_until(24.5);
-- A10 (t=24.5): read WITH an exclusive row lock
START TRANSACTION;
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103' FOR UPDATE;
SELECT t_now() AS t, @bal AS balance_read_by_A_for_update;

CALL wait_until(26.5);
-- A11 (t=26.5): write and commit -> releases the lock, B can continue
UPDATE accounts SET balance = @bal - 10000 WHERE acc_no = 'ACC103';
COMMIT;
SELECT t_now() AS t, 'A committed 65000, lock released' AS event;

CALL wait_until(28.5);
SELECT t_now() AS t, acc_no, balance AS final_balance,
       IF(balance = 70000, 'CORRECT', 'LOST UPDATE!') AS verdict
FROM accounts WHERE acc_no = 'ACC103';

-- SCENARIO 5 : SERIALIZABLE - readers block writers  (t = 30 .. 40)
CALL wait_until(31);
-- A12 (t=31): try to update ACC104 that B has read under SERIALIZABLE
--             -> A WAITS until B commits at t=33
SELECT t_now() AS t, 'A starts UPDATE on ACC104' AS event;
UPDATE accounts SET balance = balance + 1000 WHERE acc_no = 'ACC104';
SELECT t_now() AS t, 'A UPDATE finished (was blocked until B committed)' AS event;

CALL wait_until(36);
-- A13 (t=36): same again, but B holds the lock longer than the
--             lock-wait timeout (3 s) -> ERROR 1205
SELECT t_now() AS t, 'A starts UPDATE on ACC104 again' AS event;
UPDATE accounts SET balance = balance + 1000 WHERE acc_no = 'ACC104';
SELECT t_now() AS t, 'A gave up waiting' AS event;

-- SCENARIO 6 : DEADLOCK  (t = 42 .. 47)
CALL wait_until(42);
-- A14 (t=42): lock ACC101 first
START TRANSACTION;
UPDATE accounts SET balance = balance - 100 WHERE acc_no = 'ACC101';
SELECT t_now() AS t, 'A locked ACC101' AS event;

CALL wait_until(43);
-- A15 (t=43): now needs ACC102 (held by B) -> waits
UPDATE accounts SET balance = balance + 100 WHERE acc_no = 'ACC102';
SELECT t_now() AS t, 'A got ACC102 after B was chosen as deadlock victim' AS event;
COMMIT;

CALL wait_until(46);
SELECT t_now() AS t, acc_no, balance FROM accounts ORDER BY acc_no;
