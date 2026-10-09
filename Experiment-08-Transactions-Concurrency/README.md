# Experiment 8 - Transactions, Savepoints, Isolation Levels and Concurrency Anomalies

## Aim

Implement banking-style transactions using **BEGIN, COMMIT, ROLLBACK and SAVEPOINT**, and simulate partial failures. Demonstrate **isolation levels and concurrency anomalies using two sessions**.

## Software / Tools Used

MySQL Server 8.0+ (InnoDB), two MySQL client sessions (two VS Code terminals), VS Code

## Theory

### ACID properties

| Property | Meaning | Shown in |
|---|---|---|
| **Atomicity** | All operations of a transaction happen, or none do | ROLLBACK, partial-failure procedure (Part C) |
| **Consistency** | Constraints hold before and after the transaction | `CHECK (balance >= 0)`, frozen-account trigger, total money conserved |
| **Isolation** | Concurrent transactions do not interfere (according to the isolation level) | Two-session demo (Part 2) |
| **Durability** | Committed data survives failures | InnoDB redo log (COMMIT) |

### Transaction control statements

* `START TRANSACTION` / `BEGIN` - start a transaction.
* `COMMIT` - make the changes permanent.
* `ROLLBACK` - undo all the changes.
* `SAVEPOINT name` - mark a point inside a transaction.
* `ROLLBACK TO SAVEPOINT name` - undo only the work done after that mark.
* `RELEASE SAVEPOINT name` - remove the mark.
* DDL statements such as `CREATE TABLE` cause an **implicit commit**.

### Concurrency anomalies and isolation levels (InnoDB)

| Isolation level | Dirty read | Non-repeatable read | Phantom read |
|---|---|---|---|
| READ UNCOMMITTED | Possible | Possible | Possible |
| READ COMMITTED | Not possible | Possible | Possible |
| REPEATABLE READ *(MySQL default)* | Not possible | Not possible | Not possible for plain SELECT (consistent snapshot, MVCC) |
| SERIALIZABLE | Not possible | Not possible | Not possible (plain SELECTs take shared locks) |

| Anomaly | Description |
|---|---|
| **Dirty read** | Reading data that another transaction has not yet committed (and may roll back) |
| **Non-repeatable read** | Reading the same row twice and getting different values |
| **Phantom read** | Running the same range query twice and getting new rows |
| **Lost update** | Two transactions read the same value; the second write overwrites the first |
| **Deadlock** | Each of two transactions waits for a lock the other holds; InnoDB rolls one back (`ERROR 1213`) |

**Locking reads:** `SELECT ... FOR UPDATE` (exclusive) and `SELECT ... FOR SHARE` (shared) lock the rows they read, which prevents lost updates.

## Files

| File | Purpose |
|---|---|
| [exp08_transactions.sql](exp08_transactions.sql) | Part 1 - COMMIT, ROLLBACK, SAVEPOINT, partial failures, batch with savepoints, implicit commit |
| [exp08_concurrency_setup.sql](exp08_concurrency_setup.sql) | Part 2 setup - resets balances and makes `wait_until()` and `t_now()` so both sessions follow the same timing |
| [exp08_session_A.sql](exp08_session_A.sql) | Part 2 - **Session A** (writer) |
| [exp08_session_B.sql](exp08_session_B.sql) | Part 2 - **Session B** (reader / second customer) |
| [output.txt](output.txt), [output_session_A.txt](output_session_A.txt), [output_session_B.txt](output_session_B.txt) | Recorded outputs |

## Procedure

**Part 1 - single session**

1. Created `bank_db` with `accounts` (`CHECK balance >= 0`, plus a trigger that blocks money movement on FROZEN accounts), `transactions` and `failed_txn_log`.
2. **Part A:** a transfer with `COMMIT`, and a transfer cancelled with `ROLLBACK`.
3. **Part B:** a 3-step transaction with `SAVEPOINT`s. The wrong 3rd step is undone with `ROLLBACK TO SAVEPOINT`; `RELEASE SAVEPOINT` is also shown.
4. **Part C:** procedure `transfer_funds` that *credits first, then debits*, so a failure leaves a half-done transfer. Its `EXIT HANDLER` rolls back and logs the failure. Tested with 6 cases.
5. **Part D:** interest-posting batch with one `SAVEPOINT` per account. The FROZEN account fails and only its own work is rolled back.
6. **Part E:** DDL inside a transaction causes an implicit commit.

**Part 2 - two concurrent sessions**

7. Ran the setup, then started Session A and Session B **at the same time**. Each step waits for an agreed second (`CALL wait_until(t)`), so the statements interleave on a fixed timeline.
8. Recorded six scenarios: dirty read, non-repeatable read, phantom read, lost update (and its fix with `FOR UPDATE`), SERIALIZABLE blocking with a lock-wait timeout, and a deadlock.

## How to Run

```bash
# Part 1
mysql -u root -t -vvv --force < exp08_transactions.sql

# Part 2 - open two terminals
mysql -u root -t -vvv < exp08_concurrency_setup.sql                                  # first, then within 3 seconds:
mysql -u root -t -vvv --force < exp08_session_A.sql > output_session_A.txt   # terminal 1
mysql -u root -t -vvv --force < exp08_session_B.sql > output_session_B.txt   # terminal 2
```

## Output - Part 1 (single session)

Full output: [output.txt](output.txt)

### COMMIT and ROLLBACK

```text
-- A1. Successful transfer of Rs 5,000 from ACC101 to ACC102 -> COMMIT
--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance - 5000 WHERE acc_no = 'ACC101'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    UPDATE accounts SET balance = balance + 5000 WHERE acc_no = 'ACC102'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    INSERT INTO transactions (from_acc, to_acc, amount, txn_type) VALUES ('ACC101','ACC102',5000,'TRANSFER')
--------------

Query OK, 1 row affected (0.000 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC101','ACC102')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC101 | 45000.00 |
| ACC102 | 35000.00 |
+--------+----------+
2 rows in set (0.000 sec)
```

```text
-- A2. Transfer started but cancelled by the user -> ROLLBACK
--------------
BEGIN                       -- BEGIN is a synonym of START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance - 20000 WHERE acc_no = 'ACC103'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    UPDATE accounts SET balance = balance + 20000 WHERE acc_no = 'ACC104'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC103','ACC104')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC103 | 55000.00 |
| ACC104 | 40000.00 |
+--------+----------+
2 rows in set (0.000 sec)

--------------
ROLLBACK
--------------

Query OK, 0 rows affected (0.000 sec)
```

```text
-- after ROLLBACK the balances are back to the original values
--------------
SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC103','ACC104')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC103 | 75000.00 |
| ACC104 | 20000.00 |
+--------+----------+
2 rows in set (0.000 sec)
```

### SAVEPOINT

```text
-- PART B : SAVEPOINT, ROLLBACK TO SAVEPOINT, RELEASE SAVEPOINT
--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance + 40000 WHERE acc_no = 'ACC104'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    INSERT INTO transactions (to_acc, amount, txn_type) VALUES ('ACC104', 40000, 'DEPOSIT')
--------------

Query OK, 1 row affected (0.000 sec)

--------------
    SAVEPOINT after_salary
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance - 15000 WHERE acc_no = 'ACC104'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    UPDATE accounts SET balance = balance + 15000 WHERE acc_no = 'ACC102'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    INSERT INTO transactions (from_acc, to_acc, amount, txn_type) VALUES ('ACC104','ACC102',15000,'TRANSFER')
--------------

Query OK, 1 row affected (0.000 sec)

--------------
    SAVEPOINT after_rent
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance - 15000 WHERE acc_no = 'ACC104'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    UPDATE accounts SET balance = balance + 15000 WHERE acc_no = 'ACC102'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC102 | 65000.00 |
| ACC104 | 30000.00 |
+--------+----------+
2 rows in set (0.000 sec)

--------------
    ROLLBACK TO SAVEPOINT after_rent
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC102 | 50000.00 |
| ACC104 | 45000.00 |
+--------+----------+
2 rows in set (0.000 sec)

--------------
    RELEASE SAVEPOINT after_salary
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    ROLLBACK TO SAVEPOINT after_salary      -- ERROR 1305: SAVEPOINT does not exist
--------------

ERROR 1305 (42000) at line 103: SAVEPOINT after_salary does not exist
--------------
COMMIT                                      -- steps 1 and 2 are made permanent
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT acc_no, balance FROM accounts WHERE acc_no IN ('ACC102','ACC104')
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC102 | 50000.00 |
| ACC104 | 45000.00 |
+--------+----------+
2 rows in set (0.000 sec)

--------------
SELECT * FROM transactions
--------------

+--------+----------+--------+----------+----------+---------------------+
| txn_id | from_acc | to_acc | amount   | txn_type | txn_time            |
+--------+----------+--------+----------+----------+---------------------+
|      1 | ACC101   | ACC102 |  5000.00 | TRANSFER | 2026-10-10 02:11:59 |
|      2 | NULL     | ACC104 | 40000.00 | DEPOSIT  | 2026-10-10 02:11:59 |
|      3 | ACC104   | ACC102 | 15000.00 | TRANSFER | 2026-10-10 02:11:59 |
+--------+----------+--------+----------+----------+---------------------+
3 rows in set (0.000 sec)
```

### Partial failures rolled back by the error handler

```text
-- C1. Valid transfer -> COMMITTED
--------------
CALL transfer_funds('ACC103', 'ACC101', 10000)
--------------

+-----------+------------------------------+
| outcome   | details                      |
+-----------+------------------------------+
| COMMITTED | Rs 10000.00 ACC103 -> ACC101 |
+-----------+------------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- C2. Insufficient balance: credit to ACC102 succeeds, debit of ACC104 violates
--     CHECK (balance >= 0) -> whole transaction rolled back
--------------
CALL transfer_funds('ACC104', 'ACC102', 999999)
--------------

+-------------+---------------------------------------------+
| outcome     | reason                                      |
+-------------+---------------------------------------------+
| ROLLED BACK | Check constraint 'chk_balance' is violated. |
+-------------+---------------------------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- C3. Receiver does not exist
--------------
CALL transfer_funds('ACC101', 'ACC999', 1000)
--------------

+-------------+----------------------------+
| outcome     | reason                     |
+-------------+----------------------------+
| ROLLED BACK | Receiver account not found |
+-------------+----------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- C4. Sender does not exist (credit already done -> must be undone)
--------------
CALL transfer_funds('ACC999', 'ACC101', 1000)
--------------

+-------------+--------------------------+
| outcome     | reason                   |
+-------------+--------------------------+
| ROLLED BACK | Sender account not found |
+-------------+--------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- C5. Frozen receiver -> trigger raises error -> rolled back
--------------
CALL transfer_funds('ACC101', 'ACC105', 500)
--------------

+-------------+---------------------------------------------+
| outcome     | reason                                      |
+-------------+---------------------------------------------+
| ROLLED BACK | Account is FROZEN - no debit/credit allowed |
+-------------+---------------------------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- C6. Negative amount
--------------
CALL transfer_funds('ACC101', 'ACC102', -50)
--------------

+-------------+-------------------------+
| outcome     | reason                  |
+-------------+-------------------------+
| ROLLED BACK | Amount must be positive |
+-------------+-------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

```text
-- Balances: only C1 changed anything; money is conserved
--------------
SELECT acc_no, balance, status FROM accounts
--------------

+--------+----------+--------+
| acc_no | balance  | status |
+--------+----------+--------+
| ACC101 | 55000.00 | ACTIVE |
| ACC102 | 50000.00 | ACTIVE |
| ACC103 | 65000.00 | ACTIVE |
| ACC104 | 45000.00 | ACTIVE |
| ACC105 | 15000.00 | FROZEN |
+--------+----------+--------+
5 rows in set (0.000 sec)

--------------
SELECT SUM(balance) AS total_money_in_bank FROM accounts
--------------

+---------------------+
| total_money_in_bank |
+---------------------+
|           230000.00 |
+---------------------+
1 row in set (0.000 sec)

--------------
SELECT id, from_acc, to_acc, amount, reason FROM failed_txn_log
--------------

+----+----------+--------+-----------+---------------------------------------------+
| id | from_acc | to_acc | amount    | reason                                      |
+----+----------+--------+-----------+---------------------------------------------+
|  1 | ACC104   | ACC102 | 999999.00 | Check constraint 'chk_balance' is violated. |
|  2 | ACC101   | ACC999 |   1000.00 | Receiver account not found                  |
|  3 | ACC999   | ACC101 |   1000.00 | Sender account not found                    |
|  4 | ACC101   | ACC105 |    500.00 | Account is FROZEN - no debit/credit allowed |
|  5 | ACC101   | ACC102 |    -50.00 | Amount must be positive                     |
+----+----------+--------+-----------+---------------------------------------------+
5 rows in set (0.000 sec)
```

### Batch with one savepoint per account

```text
-- PART D : Batch job with one SAVEPOINT per row
--   Post 1% interest to every account. A failure on one account rolls back
--   only that account's work; the rest of the batch is committed.
--------------
DROP PROCEDURE IF EXISTS post_monthly_interest
--------------

Query OK, 0 rows affected, 1 warning (0.000 sec)

--------------
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
END
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
CALL post_monthly_interest()
--------------

+-------------------+-----------------+
| accounts_credited | accounts_failed |
+-------------------+-----------------+
|                 4 |               1 |
+-------------------+-----------------+
1 row in set (0.001 sec)

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT acc_no, balance, status FROM accounts
--------------

+--------+----------+--------+
| acc_no | balance  | status |
+--------+----------+--------+
| ACC101 | 55550.00 | ACTIVE |
| ACC102 | 50500.00 | ACTIVE |
| ACC103 | 65650.00 | ACTIVE |
| ACC104 | 45450.00 | ACTIVE |
| ACC105 | 15000.00 | FROZEN |
+--------+----------+--------+
5 rows in set (0.000 sec)

--------------
SELECT txn_id, to_acc, amount, txn_type FROM transactions WHERE txn_type = 'INTEREST'
--------------

+--------+--------+--------+----------+
| txn_id | to_acc | amount | txn_type |
+--------+--------+--------+----------+
|      5 | ACC101 | 550.00 | INTEREST |
|      6 | ACC102 | 500.00 | INTEREST |
|      7 | ACC103 | 650.00 | INTEREST |
|      8 | ACC104 | 450.00 | INTEREST |
+--------+--------+--------+----------+
4 rows in set (0.000 sec)

--------------
SELECT id, to_acc, reason FROM failed_txn_log WHERE reason LIKE 'Interest%'
--------------

+----+--------+-------------------------+
| id | to_acc | reason                  |
+----+--------+-------------------------+
|  6 | ACC105 | Interest posting failed |
+----+--------+-------------------------+
1 row in set (0.000 sec)
```

### Implicit commit

```text
-- PART E : Implicit commit - DDL inside a transaction cannot be rolled back
--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
    UPDATE accounts SET balance = balance + 1 WHERE acc_no = 'ACC101'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
    CREATE TABLE temp_audit (id INT)   -- DDL causes an IMPLICIT COMMIT
--------------

Query OK, 0 rows affected (0.002 sec)

--------------
ROLLBACK                               -- nothing left to roll back
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT acc_no, balance FROM accounts WHERE acc_no = 'ACC101'   -- the +1 survived
--------------

+--------+----------+
| acc_no | balance  |
+--------+----------+
| ACC101 | 55551.00 |
+--------+----------+
1 row in set (0.000 sec)

--------------
DROP TABLE temp_audit
--------------

Query OK, 0 rows affected (0.001 sec)
```

## Output - Part 2 (two sessions running concurrently)

Full outputs: [output_session_A.txt](output_session_A.txt) and [output_session_B.txt](output_session_B.txt). The `t` column is the number of seconds since the common start.

### Merged timeline (from the recorded outputs)

| t (s) | Session A | Session B | What it shows |
|---|---|---|---|
| **Scenario 1** | | | **Dirty read** |
| 0.5 | `START`; ACC101 −20000 (balance 30000, **not committed**) | | |
| 1.5 | | READ UNCOMMITTED -> reads **30000** | dirty read |
| 2.0 | | READ COMMITTED -> reads 50000 | prevented |
| 3.0 | `ROLLBACK` | | |
| 3.5 | | READ UNCOMMITTED -> 50000 (the 30000 never existed) | |
| **Scenario 2** | | | **Non-repeatable read** |
| 5.0 | | READ COMMITTED `START`; ACC102 = **30000** | |
| 6.0 | +5000 to ACC102, committed | | |
| 7.0 | | Same transaction reads **35000** | non-repeatable read |
| 8.0 | | REPEATABLE READ `START`; ACC102 = 35000 | |
| 9.0 | +5000 to ACC102, committed (40000) | | |
| 10.0 | | Same transaction still reads **35000**; after COMMIT reads 40000 | repeatable |
| **Scenario 3** | | | **Phantom read** |
| 12.0 | | READ COMMITTED: 3 accounts with balance ≥ 40000 | |
| 13.0 | INSERT ACC106 (90000), committed | | |
| 14.0 | | Same query, same transaction -> **4** accounts | phantom |
| 15.0 | | REPEATABLE READ: 4 accounts | |
| 16.0 | INSERT ACC107 (60000), committed | | |
| 17.0 | | Same query -> still **4**; after COMMIT -> 5 | no phantom |
| **Scenario 4** | | | **Lost update** |
| 19.5 | Reads ACC103 = 75000 | | |
| 20.0 | | Reads ACC103 = 75000 | |
| 21.0 | Writes 75000 − 10000 = 65000, COMMIT | | |
| 22.0 | | Writes 75000 + 5000 = 80000, COMMIT | |
| 23.0 | Final balance **80000** (should be 70000) | | **LOST UPDATE** |
| **Scenario 4b** | | | **Fixed with `SELECT ... FOR UPDATE`** |
| 24.5 | `FOR UPDATE` reads 75000 (row locked) | | |
| 25.0 | | `FOR UPDATE` -> **waits** | |
| 26.5 | Writes 65000, COMMIT (lock released) | Gets the lock, reads **65000**, writes 70000 | |
| 28.5 | Final balance **70000** | | correct |
| **Scenario 5** | | | **SERIALIZABLE** |
| 30.0 | | SERIALIZABLE `SELECT` ACC104 (takes a shared lock) | |
| 31.0 | `UPDATE` ACC104 -> **blocked** | | |
| 33.0 | UPDATE completes (waited ~2 s) | COMMIT | readers block writers |
| 35.0 | | SERIALIZABLE `SELECT`, holds the lock until t = 40 | |
| 36.0 | `UPDATE` -> waits 3 s -> **ERROR 1205 lock wait timeout** | | |
| **Scenario 6** | | | **Deadlock** |
| 42.0 | Locks ACC101 | | |
| 42.5 | | Locks ACC102 | |
| 43.0 | Wants ACC102 -> waits for B | | |
| 44.0 | Gets ACC102, COMMIT | Wants ACC101 -> **ERROR 1213 deadlock**; B rolled back | InnoDB breaks the cycle |

### Session A - lost update (scenario 4)

```text
-- A7 (t=19.5): ATM withdrawal of Rs 10,000 from ACC103 - read the balance
--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103'
--------------

Query OK, 1 row affected (0.000 sec)

--------------
SELECT t_now() AS t, @bal AS balance_read_by_A
--------------

+------+-------------------+
| t    | balance_read_by_A |
+------+-------------------+
| 19.6 |          75000.00 |
+------+-------------------+
1 row in set (0.000 sec)

--------------
CALL wait_until(21)
--------------

Query OK, 0 rows affected (1.503 sec)
```

```text
-- A8 (t=21): write back (read value - 10000) and commit
--------------
UPDATE accounts SET balance = @bal - 10000 WHERE acc_no = 'ACC103'
--------------

Query OK, 1 row affected (0.001 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT t_now() AS t, 'A wrote balance = 75000 - 10000 = 65000' AS event
--------------

+------+-----------------------------------------+
| t    | event                                   |
+------+-----------------------------------------+
| 21.1 | A wrote balance = 75000 - 10000 = 65000 |
+------+-----------------------------------------+
1 row in set (0.000 sec)

--------------
CALL wait_until(23)
--------------

Query OK, 0 rows affected (1.988 sec)
```

```text
-- A9 (t=23): final balance - expected 75000 - 10000 + 5000 = 70000
--------------
SELECT t_now() AS t, acc_no, balance AS final_balance,
       IF(balance = 70000, 'CORRECT', 'LOST UPDATE!') AS verdict
FROM accounts WHERE acc_no = 'ACC103'
--------------

+------+--------+---------------+--------------+
| t    | acc_no | final_balance | verdict      |
+------+--------+---------------+--------------+
| 23.1 | ACC103 |      80000.00 | LOST UPDATE! |
+------+--------+---------------+--------------+
1 row in set (0.001 sec)
```

### Session B - dirty read (scenario 1)

```text
-- B1 (t=1.5): READ UNCOMMITTED sees A's uncommitted debit -> DIRTY READ
--------------
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101'
--------------

+------+------------------+--------+----------+
| t    | level            | acc_no | balance  |
+------+------------------+--------+----------+
|  1.6 | READ-UNCOMMITTED | ACC101 | 30000.00 |
+------+------------------+--------+----------+
1 row in set (0.001 sec)

--------------
CALL wait_until(2)
--------------

Query OK, 0 rows affected (0.492 sec)
```

```text
-- B2 (t=2): READ COMMITTED does not see uncommitted data -> no dirty read
--------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101'
--------------

+------+----------------+--------+----------+
| t    | level          | acc_no | balance  |
+------+----------------+--------+----------+
|  2.1 | READ-COMMITTED | ACC101 | 50000.00 |
+------+----------------+--------+----------+
1 row in set (0.001 sec)

--------------
CALL wait_until(3.5)
--------------

Query OK, 0 rows affected (1.499 sec)
```

```text
-- B3 (t=3.5): after A's ROLLBACK, the 30000 that B read at t=1.5 never existed
--------------
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance
FROM accounts WHERE acc_no = 'ACC101'
--------------

+------+------------------+--------+----------+
| t    | level            | acc_no | balance  |
+------+------------------+--------+----------+
|  3.6 | READ-UNCOMMITTED | ACC101 | 50000.00 |
+------+------------------+--------+----------+
1 row in set (0.001 sec)
```

### Session B - non-repeatable read vs repeatable read (scenario 2)

```text
-- B4 (t=5): READ COMMITTED transaction, first read
--------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS first_read
FROM accounts WHERE acc_no = 'ACC102'
--------------

+------+----------------+--------+------------+
| t    | level          | acc_no | first_read |
+------+----------------+--------+------------+
|  5.1 | READ-COMMITTED | ACC102 |   30000.00 |
+------+----------------+--------+------------+
1 row in set (0.001 sec)

--------------
CALL wait_until(7)
--------------

Query OK, 0 rows affected (2.000 sec)
```

```text
-- B5 (t=7): same query, same transaction -> different value (NON-REPEATABLE READ)
--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS second_read
FROM accounts WHERE acc_no = 'ACC102'
--------------

+------+----------------+--------+-------------+
| t    | level          | acc_no | second_read |
+------+----------------+--------+-------------+
|  7.1 | READ-COMMITTED | ACC102 |    35000.00 |
+------+----------------+--------+-------------+
1 row in set (0.001 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
CALL wait_until(8)
--------------

Query OK, 0 rows affected (1.000 sec)
```

```text
-- B6 (t=8): REPEATABLE READ transaction, first read
--------------
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS first_read
FROM accounts WHERE acc_no = 'ACC102'
--------------

+------+-----------------+--------+------------+
| t    | level           | acc_no | first_read |
+------+-----------------+--------+------------+
|  8.1 | REPEATABLE-READ | ACC102 |   35000.00 |
+------+-----------------+--------+------------+
1 row in set (0.001 sec)

--------------
CALL wait_until(10)
--------------

Query OK, 0 rows affected (1.996 sec)
```

```text
-- B7 (t=10): A committed +5000 at t=9 but B still sees its snapshot -> repeatable
--------------
SELECT t_now() AS t, @@transaction_isolation AS level, acc_no, balance AS second_read
FROM accounts WHERE acc_no = 'ACC102'
--------------

+------+-----------------+--------+-------------+
| t    | level           | acc_no | second_read |
+------+-----------------+--------+-------------+
| 10.1 | REPEATABLE-READ | ACC102 |    35000.00 |
+------+-----------------+--------+-------------+
1 row in set (0.001 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)
```

### Session B - phantom read (scenario 3)

```text
-- B8 (t=12): READ COMMITTED - count accounts with balance >= 40000
--------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000
--------------

+------+----------------+---------------+-----------+
| t    | level          | rich_accounts | total     |
+------+----------------+---------------+-----------+
| 12.1 | READ-COMMITTED |             3 | 165000.00 |
+------+----------------+---------------+-----------+
1 row in set (0.001 sec)

--------------
CALL wait_until(14)
--------------

Query OK, 0 rows affected (2.000 sec)
```

```text
-- B9 (t=14): same query -> a new row (ACC106) appears = PHANTOM
--------------
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000
--------------

+------+----------------+---------------+-----------+
| t    | level          | rich_accounts | total     |
+------+----------------+---------------+-----------+
| 14.1 | READ-COMMITTED |             4 | 255000.00 |
+------+----------------+---------------+-----------+
1 row in set (0.001 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
CALL wait_until(15)
--------------

Query OK, 0 rows affected (0.999 sec)
```

```text
-- B10 (t=15): REPEATABLE READ - first count
--------------
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000
--------------

+------+-----------------+---------------+-----------+
| t    | level           | rich_accounts | total     |
+------+-----------------+---------------+-----------+
| 15.1 | REPEATABLE-READ |             4 | 255000.00 |
+------+-----------------+---------------+-----------+
1 row in set (0.001 sec)

--------------
CALL wait_until(17)
--------------

Query OK, 0 rows affected (1.973 sec)
```

```text
-- B11 (t=17): A inserted ACC107 at t=16, but the snapshot shows no phantom
--------------
SELECT t_now() AS t, @@transaction_isolation AS level,
       COUNT(*) AS rich_accounts, SUM(balance) AS total
FROM accounts WHERE balance >= 40000
--------------

+------+-----------------+---------------+-----------+
| t    | level           | rich_accounts | total     |
+------+-----------------+---------------+-----------+
| 17.0 | REPEATABLE-READ |             4 | 255000.00 |
+------+-----------------+---------------+-----------+
1 row in set (0.001 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, COUNT(*) AS rich_accounts_after_commit FROM accounts WHERE balance >= 40000
--------------

+------+----------------------------+
| t    | rich_accounts_after_commit |
+------+----------------------------+
| 17.0 |                          5 |
+------+----------------------------+
1 row in set (0.000 sec)
```

### Session B - waiting on FOR UPDATE (scenario 4b)

```text
-- B14 (t=25): FOR UPDATE must wait for A's lock (released at t=26.5)
--------------
SELECT t_now() AS t, 'B requests lock on ACC103' AS event
--------------

+------+---------------------------+
| t    | event                     |
+------+---------------------------+
| 25.1 | B requests lock on ACC103 |
+------+---------------------------+
1 row in set (0.000 sec)

--------------
START TRANSACTION
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT balance INTO @bal FROM accounts WHERE acc_no = 'ACC103' FOR UPDATE
--------------

Query OK, 1 row affected (1.510 sec)

--------------
SELECT t_now() AS t, @bal AS balance_read_by_B_after_wait
--------------

+------+------------------------------+
| t    | balance_read_by_B_after_wait |
+------+------------------------------+
| 26.6 |                     65000.00 |
+------+------------------------------+
1 row in set (0.000 sec)

--------------
UPDATE accounts SET balance = @bal + 5000 WHERE acc_no = 'ACC103'
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.000 sec)

--------------
SELECT t_now() AS t, 'B committed 65000 + 5000 = 70000' AS event
--------------

+------+----------------------------------+
| t    | event                            |
+------+----------------------------------+
| 26.6 | B committed 65000 + 5000 = 70000 |
+------+----------------------------------+
1 row in set (0.000 sec)
```

### Session A - blocked by a SERIALIZABLE reader, then lock-wait timeout (scenario 5)

```text
-- A12 (t=31): try to update ACC104 that B has read under SERIALIZABLE
--             -> A WAITS until B commits at t=33
--------------
SELECT t_now() AS t, 'A starts UPDATE on ACC104' AS event
--------------

+------+---------------------------+
| t    | event                     |
+------+---------------------------+
| 31.1 | A starts UPDATE on ACC104 |
+------+---------------------------+
1 row in set (0.000 sec)

--------------
UPDATE accounts SET balance = balance + 1000 WHERE acc_no = 'ACC104'
--------------

Query OK, 1 row affected (2.004 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT t_now() AS t, 'A UPDATE finished (was blocked until B committed)' AS event
--------------

+------+---------------------------------------------------+
| t    | event                                             |
+------+---------------------------------------------------+
| 33.1 | A UPDATE finished (was blocked until B committed) |
+------+---------------------------------------------------+
1 row in set (0.000 sec)

--------------
CALL wait_until(36)
--------------

Query OK, 0 rows affected (2.973 sec)
```

```text
-- A13 (t=36): same again, but B holds the lock longer than the
--             lock-wait timeout (3 s) -> ERROR 1205
--------------
SELECT t_now() AS t, 'A starts UPDATE on ACC104 again' AS event
--------------

+------+---------------------------------+
| t    | event                           |
+------+---------------------------------+
| 36.0 | A starts UPDATE on ACC104 again |
+------+---------------------------------+
1 row in set (0.000 sec)

--------------
UPDATE accounts SET balance = balance + 1000 WHERE acc_no = 'ACC104'
--------------

ERROR 1205 (HY000) at line 92: Lock wait timeout exceeded; try restarting transaction
--------------
SELECT t_now() AS t, 'A gave up waiting' AS event
--------------

+------+-------------------+
| t    | event             |
+------+-------------------+
| 39.2 | A gave up waiting |
+------+-------------------+
1 row in set (0.000 sec)
```

### Deadlock (scenario 6)

```text
-- A15 (t=43): now needs ACC102 (held by B) -> waits
--------------
UPDATE accounts SET balance = balance + 100 WHERE acc_no = 'ACC102'
--------------

Query OK, 1 row affected (1.002 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT t_now() AS t, 'A got ACC102 after B was chosen as deadlock victim' AS event
--------------

+------+----------------------------------------------------+
| t    | event                                              |
+------+----------------------------------------------------+
| 44.1 | A got ACC102 after B was chosen as deadlock victim |
+------+----------------------------------------------------+
1 row in set (0.000 sec)

--------------
COMMIT
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
CALL wait_until(46)
--------------

Query OK, 0 rows affected (1.995 sec)

--------------
SELECT t_now() AS t, acc_no, balance FROM accounts ORDER BY acc_no
--------------

+------+--------+----------+
| t    | acc_no | balance  |
+------+--------+----------+
| 46.1 | ACC101 | 49900.00 |
| 46.1 | ACC102 | 40100.00 |
| 46.1 | ACC103 | 70000.00 |
| 46.1 | ACC104 | 21000.00 |
| 46.1 | ACC105 | 15000.00 |
| 46.1 | ACC106 | 90000.00 |
| 46.1 | ACC107 | 60000.00 |
+------+--------+----------+
7 rows in set (0.001 sec)
```

```text
-- B19 (t=44): now needs ACC101 (held by A, and A waits for B) -> DEADLOCK
--             mysql finds the deadlock and rolls back one transaction -> ERROR 1213
--------------
UPDATE accounts SET balance = balance + 100 WHERE acc_no = 'ACC101'
--------------

ERROR 1213 (40001) at line 144: Deadlock found when trying to get lock; try restarting transaction
--------------
SELECT t_now() AS t, 'B continues after deadlock' AS event
--------------

+------+----------------------------+
| t    | event                      |
+------+----------------------------+
| 44.1 | B continues after deadlock |
+------+----------------------------+
1 row in set (0.000 sec)

--------------
ROLLBACK
--------------

Query OK, 0 rows affected (0.000 sec)
```

## Observations

* **Atomicity:** in every failed `transfer_funds` call, the credit that had already been applied was undone. The total money in the bank stayed exactly the same, apart from the one valid transfer, which only moves money between accounts.
* **Savepoints** undid only the wrong 3rd step. Rolling back to a *released* savepoint gives `ERROR 1305`.
* In the batch job, 4 accounts were credited and 1 (FROZEN) failed. Its partial `INSERT` was rolled back to the savepoint.
* A `CREATE TABLE` inside a transaction committed the pending update, so the later `ROLLBACK` had nothing to undo.
* Every anomaly appeared at the weaker isolation level and did not appear at the stronger one. The lost update happens even under REPEATABLE READ when the application reads and then writes back; locking reads (`FOR UPDATE`) or an atomic `UPDATE ... SET balance = balance - x` are required.

## Result

Banking transactions were done using START TRANSACTION / BEGIN, COMMIT, ROLLBACK and SAVEPOINT, and partial failures were rolled back correctly. Using two sessions at the same time, the following were shown:
- dirty read;
- non-repeatable read;
- phantom read;
- lost update and how to prevent it;
- blocking under SERIALIZABLE, with a lock wait timeout;
- deadlock.

## Conclusion

A transaction makes a group of statements work as one unit, so either all changes happen or none do. A lower isolation level allows more anomalies, and a higher one prevents them but makes sessions wait. The default level in MySQL (REPEATABLE READ) prevents dirty, non-repeatable and phantom reads for normal SELECTs. A lost update still needs SELECT ... FOR UPDATE.
