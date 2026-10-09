-- Experiment 8 part 2: SESSION B
-- run together with session A. wait_until(x) waits till x seconds from start
USE bank_db;
SET SESSION innodb_lock_wait_timeout = 10;

-- SCENARIO 1 : DIRTY READ  (t = 0 .. 4)
CALL wait_until(1.5);
-- B1 (t=1.5): READ UNCOMMITTED sees A's uncommitted debit -> DIRTY READ
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101';

CALL wait_until(2);
-- B2 (t=2): READ COMMITTED does not see uncommitted data -> no dirty read
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101';

CALL wait_until(3.5);
-- B3 (t=3.5): after A's ROLLBACK, the 30000 that B read at t=1.5 never existed
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101';

-- SCENARIO 2 : NON-REPEATABLE READ  (t = 5 .. 11)
CALL wait_until(5);
-- B4 (t=5): READ COMMITTED transaction, first read
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS first_read
FROM accounts WHERE acc_no = 'ACC102';

CALL wait_until(7);
-- B5 (t=7): same query, same transaction -> different value (NON-REPEATABLE READ)
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS second_read
FROM accounts WHERE acc_no = 'ACC102';
COMMIT;

CALL wait_until(8);
-- B6 (t=8): REPEATABLE READ transaction, first read
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS first_read
FROM accounts WHERE acc_no = 'ACC102';

CALL wait_until(10);
-- B7 (t=10): A committed +5000 at t=9 but B still sees its snapshot -> repeatable
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS second_read
FROM accounts WHERE acc_no = 'ACC102';
COMMIT;
-- after COMMIT a new snapshot shows the latest value
SELECT t_now() AS t, acc_no, balance AS after_commit FROM accounts WHERE acc_no = 'ACC102';

-- SCENARIO 3 : PHANTOM READ  (t = 12 .. 18)
CALL wait_until(12);
-- B8 (t=12): READ COMMITTED - count accounts with balance >= 40000
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000;

CALL wait_until(14);
-- B9 (t=14): same query -> a new row (ACC106) appears = PHANTOM
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000;
COMMIT;

CALL wait_until(15);
-- B10 (t=15): REPEATABLE READ - first count
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000;

CALL wait_until(17);
-- B11 (t=17): A inserted ACC107 at t=16, but the snapshot shows no phantom
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000;
COMMIT;
SELECT t_now() AS t, COUNT(*) AS rich_accounts_after_commit FROM accounts WHERE balance >= 40000;

-- SCENARIO 4 : LOST UPDATE  (t = 19 .. 23)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
CALL wait_until(20);
-- B12 (t=20): UPI credit of Rs 5,000 to ACC103 - read the balance
START TRANSACTION;
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103';
SELECT t_now() AS t, @bal AS balance_read_by_B;

CALL wait_until(22);
-- B13 (t=22): write back (read value + 5000) -> overwrites A's withdrawal
UPDATE accounts SET balance = @bal + 5000 WHERE acc_no = 'ACC103';
COMMIT;
SELECT t_now() AS t, 'B wrote balance = 75000 + 5000 = 80000' AS event;

-- SCENARIO 4b : LOST UPDATE PREVENTED with SELECT ... FOR UPDATE (t = 24 .. 29)
CALL wait_until(25);
-- B14 (t=25): FOR UPDATE must wait for A's lock (released at t=26.5)
SELECT t_now() AS t, 'B requests lock on ACC103' AS event;
START TRANSACTION;
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103' FOR UPDATE;
SELECT t_now() AS t, @bal AS balance_read_by_B_after_wait;
UPDATE accounts SET balance = @bal + 5000 WHERE acc_no = 'ACC103';
COMMIT;
SELECT t_now() AS t, 'B committed 65000 + 5000 = 70000' AS event;

-- SCENARIO 5 : SERIALIZABLE - readers block writers  (t = 30 .. 40)
CALL wait_until(30);
-- B15 (t=30): under SERIALIZABLE a plain SELECT takes a SHARED lock
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC104';

CALL wait_until(33);
-- B16 (t=33): commit -> A's waiting UPDATE can proceed
COMMIT;
SELECT t_now() AS t, 'B committed (shared lock released)' AS event;

CALL wait_until(35);
-- B17 (t=35): hold the shared lock for 5 seconds this time
START TRANSACTION;
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC104';
CALL wait_until(40);
COMMIT;
SELECT t_now() AS t, 'B committed' AS event;

-- SCENARIO 6 : DEADLOCK  (t = 42 .. 47)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
CALL wait_until(42.5);
-- B18 (t=42.5): lock ACC102 first
START TRANSACTION;
UPDATE accounts SET balance = balance - 100 WHERE acc_no = 'ACC102';
SELECT t_now() AS t, 'B locked ACC102' AS event;

CALL wait_until(44);
-- B19 (t=44): now needs ACC101 (held by A, and A waits for B) -> DEADLOCK
--             mysql finds the deadlock and rolls back one transaction -> ERROR 1213
UPDATE accounts SET balance = balance + 100 WHERE acc_no = 'ACC101';
SELECT t_now() AS t, 'B continues after deadlock' AS event;
ROLLBACK;
