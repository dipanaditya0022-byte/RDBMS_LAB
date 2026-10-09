# Experiment 6 - Stored Procedure with Error Handling, and Triggers for Validation and Audit

## Aim

Create a stored procedure **`transfer_employee(emp_id, new_dept_id)`** with validation and error handling. Implement **triggers** for salary validation and audit logging, and test the edge cases.

## Software / Tools Used

MySQL Server 8.0+ (uses `company_db` from Experiment 3), MySQL command-line client, VS Code

## Theory

### Stored procedures

A stored procedure is a named block of SQL statements stored in the database and run with `CALL`. Its advantages are reusability, less network traffic, and centrally enforced business rules.

| Feature | Syntax used |
|---|---|
| Parameters | `IN p_emp_id INT, IN p_new_dept_id INT` |
| Local variables | `DECLARE v_old_dept INT;` |
| Raising a user-defined error | `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'` |
| Error handler | `DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;` |
| Transactions | `START TRANSACTION ... COMMIT` - the transfer is all-or-nothing |
| Rows affected | `ROW_COUNT()` |

`EXIT` handlers leave the block after handling the error; `CONTINUE` handlers carry on with the next statement. `RESIGNAL` passes the original error back to the caller after cleaning up.

### Triggers

A trigger runs automatically `BEFORE` or `AFTER` an `INSERT`, `UPDATE` or `DELETE` on a table, once **for each row**. `NEW.col` is the new value and `OLD.col` the old value.

* **BEFORE triggers** validate (or correct) data. A `SIGNAL` cancels the statement.
* **AFTER triggers** record what happened (audit trail, history tables).
* If a trigger fails, the whole statement is rolled back. This is **statement atomicity**.

## Procedure

1. Created the `transfer_log` and `employee_audit` tables.
2. Wrote `transfer_employee`. It performs 6 validations:
   1. no NULL arguments;
   2. the employee exists;
   3. the target department exists;
   4. the target is not the current department;
   5. the employee is not a department head;
   6. the employee has no direct reports.

   It then, in one transaction, releases the employee from the old department's projects, moves them, sets their new manager to the new department's head, and logs the transfer.
3. Wrote 5 triggers:

   | Trigger | Purpose |
   |---|---|
   | `trg_emp_before_insert` | Salary must be between 15,000 and 5,00,000 |
   | `trg_emp_before_update` | Same range, no pay cut, at most a 30% hike |
   | `trg_emp_after_insert` | Writes an audit row for a new employee |
   | `trg_emp_after_update` | Audits changes to salary, dept_id and manager_id |
   | `trg_emp_after_delete` | Audits a removed employee |

4. Tested 2 valid transfers and 7 invalid ones, followed by 11 trigger tests.

## How to Run

```bash
mysql -u root -t -vvv < ../Experiment-03-Employee-Queries/exp03_employee_queries.sql   # reset data
mysql -u root -t -vvv --force < exp06_procedures_triggers.sql
```

## Source Code

[exp06_procedures_triggers.sql](exp06_procedures_triggers.sql)

```sql
CREATE PROCEDURE transfer_employee(IN p_emp_id INT, IN p_new_dept_id INT)
BEGIN
    ...
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_emp_id IS NULL OR p_new_dept_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: emp_id and new_dept_id must not be NULL';
    END IF;
    ...                                   -- 5 more validations
    START TRANSACTION;
        DELETE w FROM works_on w JOIN project p ON p.project_id = w.project_id
        WHERE w.emp_id = p_emp_id AND p.dept_id = v_old_dept;
        UPDATE employee SET dept_id = p_new_dept_id, manager_id = v_new_manager
        WHERE emp_id = p_emp_id;
        INSERT INTO transfer_log (...) VALUES (...);
    COMMIT;
END

CREATE TRIGGER trg_emp_before_update BEFORE UPDATE ON employee FOR EACH ROW
BEGIN
    IF NEW.salary <> OLD.salary THEN
        IF NEW.salary < 15000 OR NEW.salary > 500000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary validation: salary must be between 15000 and 500000';
        ELSEIF NEW.salary < OLD.salary THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary validation: salary reduction is not allowed';
        ELSEIF NEW.salary > OLD.salary * 1.30 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary validation: hike above 30% needs board approval';
        END IF;
    END IF;
END
```

## Output

Full output: [output.txt](output.txt)

### Objects created

```text
-- Triggers and procedures stored in the data dictionary
--------------
SELECT TRIGGER_NAME, ACTION_TIMING, EVENT_MANIPULATION, EVENT_OBJECT_TABLE
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'company_db'
ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING DESC, EVENT_MANIPULATION
--------------

+-----------------------+---------------+--------------------+--------------------+
| TRIGGER_NAME          | ACTION_TIMING | EVENT_MANIPULATION | EVENT_OBJECT_TABLE |
+-----------------------+---------------+--------------------+--------------------+
| trg_emp_after_insert  | AFTER         | INSERT             | employee           |
| trg_emp_after_update  | AFTER         | UPDATE             | employee           |
| trg_emp_after_delete  | AFTER         | DELETE             | employee           |
| trg_emp_before_insert | BEFORE        | INSERT             | employee           |
| trg_emp_before_update | BEFORE        | UPDATE             | employee           |
+-----------------------+---------------+--------------------+--------------------+
5 rows in set (0.000 sec)

--------------
SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'company_db'
--------------

+-------------------+--------------+---------------------+
| ROUTINE_NAME      | ROUTINE_TYPE | CREATED             |
+-------------------+--------------+---------------------+
| transfer_employee | PROCEDURE    | 2026-10-10 02:11:59 |
+-------------------+--------------+---------------------+
1 row in set (0.000 sec)
```

### Procedure tests

```text
-- P1. Valid transfer: Nikhil (22, Marketing SEO Analyst) -> Sales (20)
--------------
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 22
--------------

+--------+------------+---------+------------+
| emp_id | first_name | dept_id | manager_id |
+--------+------------+---------+------------+
|     22 | Nikhil     |      30 |         20 |
+--------+------------+---------+------------+
1 row in set (0.000 sec)

--------------
SELECT * FROM works_on WHERE emp_id = 22
--------------

+--------+------------+------+----------------+
| emp_id | project_id | role | hours_per_week |
+--------+------------+------+----------------+
|     22 |        104 | SEO  |           30.0 |
+--------+------------+------+----------------+
1 row in set (0.000 sec)

--------------
CALL transfer_employee(22, 20)
--------------

+------------------------------------------------------------------------------------+
| result                                                                             |
+------------------------------------------------------------------------------------+
| Employee 22 transferred from dept 30 to dept 20 (1 project assignment(s) released) |
+------------------------------------------------------------------------------------+
1 row in set (0.001 sec)

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 22
--------------

+--------+------------+---------+------------+
| emp_id | first_name | dept_id | manager_id |
+--------+------------+---------+------------+
|     22 | Nikhil     |      20 |         12 |
+--------+------------+---------+------------+
1 row in set (0.000 sec)

--------------
SELECT * FROM works_on WHERE emp_id = 22
--------------

Empty set (0.000 sec)
```

```text
-- P2. Edge case: employee does not exist
--------------
CALL transfer_employee(999, 20)
--------------

ERROR 1644 (45000) at line 227: transfer_employee: employee does not exist
```

```text
-- P3. Edge case: department does not exist
--------------
CALL transfer_employee(10, 60)
--------------

ERROR 1644 (45000) at line 230: transfer_employee: target department does not exist
```

```text
-- P4. Edge case: already in the target department
--------------
CALL transfer_employee(10, 10)
--------------

ERROR 1644 (45000) at line 233: transfer_employee: employee is already in that department
```

```text
-- P5. Edge case: NULL arguments
--------------
CALL transfer_employee(NULL, 20)
--------------

ERROR 1644 (45000) at line 236: transfer_employee: emp_id and new_dept_id must not be NULL
--------------
CALL transfer_employee(10, NULL)
--------------

ERROR 1644 (45000) at line 237: transfer_employee: emp_id and new_dept_id must not be NULL
```

```text
-- P6. Edge case: employee is a department head (Suresh, Head of Sales)
--------------
CALL transfer_employee(12, 30)
--------------

ERROR 1644 (45000) at line 240: transfer_employee: employee heads a department; appoint a new head first
```

```text
-- P7. Edge case: employee has direct reports (Vikram, Tech Lead)
--------------
CALL transfer_employee(3, 40)
--------------

ERROR 1644 (45000) at line 243: transfer_employee: employee has direct reports; reassign them first
```

```text
-- P8. Failed calls changed nothing: only ONE row in transfer_log
--------------
SELECT * FROM transfer_log
--------------

+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+---------------------+
| log_id | emp_id | old_dept_id | new_dept_id | old_manager | new_manager | projects_released | transferred_by | transferred_at      |
+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+---------------------+
|      1 |     22 |          30 |          20 |          20 |          12 |                 1 | root@localhost | 2026-10-10 02:11:59 |
+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+---------------------+
1 row in set (0.000 sec)
```

```text
-- P9. Another valid transfer: Meera (10, QA, Engineering) -> Finance (40)
--------------
CALL transfer_employee(10, 40)
--------------

+------------------------------------------------------------------------------------+
| result                                                                             |
+------------------------------------------------------------------------------------+
| Employee 10 transferred from dept 10 to dept 40 (2 project assignment(s) released) |
+------------------------------------------------------------------------------------+
1 row in set (0.000 sec)

Query OK, 0 rows affected (0.000 sec)
```

### Trigger tests

```text
-- T1. Valid hike of 10% for Sneha (emp 6)
--------------
UPDATE employee SET salary = salary * 1.10 WHERE emp_id = 6
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 6
--------------

+--------+------------+----------+
| emp_id | first_name | salary   |
+--------+------------+----------+
|      6 | Sneha      | 93500.00 |
+--------+------------+----------+
1 row in set (0.000 sec)
```

```text
-- T2. Hike above 30% -> rejected by BEFORE UPDATE trigger
--------------
UPDATE employee SET salary = salary * 1.50 WHERE emp_id = 7
--------------

ERROR 1644 (45000) at line 258: Salary validation: hike above 30% needs board approval
```

```text
-- T3. Salary cut -> rejected
--------------
UPDATE employee SET salary = 70000 WHERE emp_id = 7
--------------

ERROR 1644 (45000) at line 261: Salary validation: salary reduction is not allowed
```

```text
-- T4. Salary above the ceiling -> rejected
--------------
UPDATE employee SET salary = 600000 WHERE emp_id = 1
--------------

ERROR 1644 (45000) at line 264: Salary validation: salary must be between 15000 and 500000
```

```text
-- T5. INSERT with salary below minimum -> rejected by BEFORE INSERT trigger
--------------
INSERT INTO employee VALUES
(40,'Low','Pay','M','2002-02-02','2025-10-01','Intern',5000,'Pune',40,25)
--------------

ERROR 1644 (45000) at line 267: Salary validation: salary must be at least 15000 (minimum wage)
```

```text
-- T6. INSERT with negative salary -> rejected
--------------
INSERT INTO employee VALUES
(41,'Neg','Pay','F','2002-02-02','2025-10-01','Intern',-100,'Pune',40,25)
--------------

ERROR 1644 (45000) at line 271: Salary validation: salary must be at least 15000 (minimum wage)
```

```text
-- T7. Valid INSERT -> audit row with action INSERT
--------------
INSERT INTO employee VALUES
(33,'Yash','Thakur','M','2001-03-14','2025-10-01','Graduate Engineer Trainee',30000,'Pune',10,3)
--------------

Query OK, 1 row affected (0.000 sec)
```

```text
-- T8. Bulk raise (5%) for HR -> one audit row per employee
--------------
UPDATE employee SET salary = salary * 1.05 WHERE dept_id = 50
--------------

Query OK, 4 rows affected (0.000 sec)
Rows matched: 4  Changed: 4  Warnings: 0
```

```text
-- T9. Statement atomicity: 40% raise for Finance fails on the first row,
--     so no salary of Finance is changed
--------------
SELECT emp_id, salary FROM employee WHERE dept_id = 40
--------------

+--------+-----------+
| emp_id | salary    |
+--------+-----------+
|     10 |  70000.00 |
|     25 | 210000.00 |
|     26 |  75000.00 |
|     27 |  88000.00 |
|     28 |  50000.00 |
+--------+-----------+
5 rows in set (0.000 sec)

--------------
UPDATE employee SET salary = salary * 1.40 WHERE dept_id = 40
--------------

ERROR 1644 (45000) at line 284: Salary validation: hike above 30% needs board approval
--------------
SELECT emp_id, salary FROM employee WHERE dept_id = 40
--------------

+--------+-----------+
| emp_id | salary    |
+--------+-----------+
|     10 |  70000.00 |
|     25 | 210000.00 |
|     26 |  75000.00 |
|     27 |  88000.00 |
|     28 |  50000.00 |
+--------+-----------+
5 rows in set (0.000 sec)
```

```text
-- T10. Updating a non-salary column does not fire salary validation and
--      is not written to the audit log (only salary/dept/manager are audited)
--------------
UPDATE employee SET city = 'Gurugram' WHERE emp_id = 14
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

```text
-- T11. DELETE -> audit row with action DELETE
--------------
DELETE FROM employee WHERE emp_id = 33
--------------

Query OK, 1 row affected (0.000 sec)
```

### Audit trail

```text
-- Final audit trail
--------------
SELECT audit_id, emp_id, action, column_name, old_value, new_value, changed_by
FROM employee_audit ORDER BY audit_id
--------------

+----------+--------+--------+-------------+-----------------------------------------+-----------+----------------+
| audit_id | emp_id | action | column_name | old_value                               | new_value | changed_by     |
+----------+--------+--------+-------------+-----------------------------------------+-----------+----------------+
|        1 |     22 | UPDATE | dept_id     | 30                                      | 20        | root@localhost |
|        2 |     22 | UPDATE | manager_id  | 20                                      | 12        | root@localhost |
|        3 |     10 | UPDATE | dept_id     | 10                                      | 40        | root@localhost |
|        4 |     10 | UPDATE | manager_id  | 9                                       | 25        | root@localhost |
|        5 |      6 | UPDATE | salary      | 85000.00                                | 93500.00  | root@localhost |
|        6 |     33 | INSERT | salary      | NULL                                    | 30000.00  | root@localhost |
|        7 |     29 | UPDATE | salary      | 170000.00                               | 178500.00 | root@localhost |
|        8 |     30 | UPDATE | salary      | 95000.00                                | 99750.00  | root@localhost |
|        9 |     31 | UPDATE | salary      | 55000.00                                | 57750.00  | root@localhost |
|       10 |     32 | UPDATE | salary      | 48000.00                                | 50400.00  | root@localhost |
|       11 |     33 | DELETE | NULL        | Yash Thakur / Graduate Engineer Trainee | NULL      | root@localhost |
+----------+--------+--------+-------------+-----------------------------------------+-----------+----------------+
11 rows in set (0.000 sec)

--------------
SELECT log_id, emp_id, old_dept_id, new_dept_id, old_manager, new_manager,
       projects_released, transferred_by
FROM transfer_log
--------------

+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+
| log_id | emp_id | old_dept_id | new_dept_id | old_manager | new_manager | projects_released | transferred_by |
+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+
|      1 |     22 |          30 |          20 |          20 |          12 |                 1 | root@localhost |
|      2 |     10 |          10 |          40 |           9 |          25 |                 2 | root@localhost |
+--------+--------+-------------+-------------+-------------+-------------+-------------------+----------------+
2 rows in set (0.000 sec)
```

## Observations

| # | Test case | Expected | Actual |
|---|---|---|---|
| P1 | Valid transfer 22 -> Sales | Moved, new manager = 12, project released | Yes |
| P2 | Employee 999 | Error | Yes, `ERROR 1644 ... employee does not exist` |
| P3 | Department 60 | Error | Yes, `... target department does not exist` |
| P4 | Same department | Error | Yes, `... already in that department` |
| P5 | NULL arguments | Error | Yes, `... must not be NULL` (both calls) |
| P6 | Department head | Error | Yes, `... heads a department` |
| P7 | Has direct reports | Error | Yes, `... has direct reports` |
| P8 | Failed calls change nothing | 1 log row | Yes |
| T1 | +10% hike | Allowed and audited | Yes |
| T2 | +50% hike | Rejected | Yes, `hike above 30% needs board approval` |
| T3 | Pay cut | Rejected | Yes |
| T4 / T5 / T6 | Above max / below min / negative | Rejected | Yes |
| T7 | Valid new employee | INSERT audited | Yes |
| T8 | 5% bulk raise for HR | 4 audit rows | Yes |
| T9 | 40% bulk raise for Finance | Whole statement rejected, no salary changed | Yes |
| T10 | City change | Not audited | Yes |
| T11 | Delete employee | DELETE audited | Yes |

## Result

The procedure `transfer_employee` was created with validation, error handling and rollback. Five triggers were created for salary validation and audit logging. All the test cases, including the edge cases, gave the expected result.

## Conclusion

Procedures and triggers keep the business rules inside the database, so every user has to follow them. The error handler with ROLLBACK makes sure a transfer is never left half done. BEFORE triggers stop wrong salary values, and AFTER triggers keep a record of every change.
