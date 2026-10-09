# Experiment 5 - Views, View Updatability and Recursive CTE

## Aim

Create SQL views for a **department salary summary** and the **employee hierarchy**, test whether the views are updatable, and implement a **recursive CTE** to display reporting chains.

## Software / Tools Used

MySQL Server 8.0+ (uses `company_db` from Experiment 3), MySQL command-line client, VS Code

## Theory

### Views

A **view** is a stored `SELECT` statement that behaves like a virtual table. Views are used to:

* hide complexity (joins and aggregates written once);
* provide security (expose only some rows or columns, e.g. hide `salary`);
* keep queries working when the underlying tables change (logical data independence).

### When is a view updatable in MySQL?

A view can be the target of `INSERT / UPDATE / DELETE` only if each of its rows maps to exactly one row of a base table. A view is **not updatable** if it contains:

* aggregate functions, `GROUP BY`, `HAVING`, `DISTINCT`, `UNION`, or a subquery in the select list;
* an outer join (in MySQL);
* for a particular column, an expression (e.g. `CONCAT(...)`) instead of a plain column.

Additional rules for views:

* An **inner-join view** may be updated, but one statement may change columns of only **one** base table. `DELETE` is not allowed.
* An `INSERT` through a view must supply every NOT NULL column (that has no default) of the base table.
* **`WITH CHECK OPTION`** rejects an insert or update that would produce a row the view cannot see (i.e. one that fails the view's `WHERE`).

### Recursive CTE

```sql
WITH RECURSIVE cte AS (
    anchor_member                 -- starting rows (e.g. the CEO)
    UNION ALL
    recursive_member              -- joins the table with cte itself
)
SELECT ... FROM cte;
```

The recursive member runs repeatedly, each time on the rows produced by the previous step, until it returns no new rows. This is how hierarchies (organisation charts, category trees, bill of materials) are traversed in SQL. `cte_max_recursion_depth` guards against infinite loops.

## Procedure

1. Created 6 views:

   | View | Contents |
   |---|---|
   | `v_dept_salary_summary` | Aggregate, LEFT JOIN |
   | `v_employee_hierarchy` | Self LEFT JOIN |
   | `v_engineering_staff` | Single table, `WITH CHECK OPTION` |
   | `v_high_earners` | Single table, no check option |
   | `v_emp_basic` | Projection only |
   | `v_emp_dept` | INNER JOIN |

2. Checked `information_schema.VIEWS.IS_UPDATABLE`.
3. Ran 13 update / insert / delete tests through the views inside one transaction, then rolled back so the base data stayed unchanged.
4. Wrote recursive CTEs:
   * R1 - top-down organisation tree
   * R2 - bottom-up chain of one employee
   * R3 - chain string for every engineer
   * R4 - total team size and payroll
   * R5 - depth of the hierarchy
   * R6 - recursive CTE saved inside a view

## How to Run

```bash
mysql -u root -t -vvv < ../Experiment-03-Employee-Queries/exp03_employee_queries.sql   # once
mysql -u root -t -vvv --force < exp05_views_cte.sql
```

## Source Code

[exp05_views_cte.sql](exp05_views_cte.sql)

```sql
CREATE VIEW v_dept_salary_summary AS
SELECT d.dept_id, d.dept_name, d.location,
       COUNT(e.emp_id) AS headcount, SUM(e.salary) AS monthly_payroll,
       ROUND(AVG(e.salary), 2) AS avg_salary, MIN(e.salary) AS min_salary, MAX(e.salary) AS max_salary
FROM department d LEFT JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.location;

WITH RECURSIVE org_chart AS (
    SELECT emp_id, manager_id, CONCAT(first_name,' ',last_name) AS name, job_title,
           0 AS level, CAST(first_name AS CHAR(500)) AS reporting_path
    FROM employee WHERE manager_id IS NULL                        -- anchor: CEO
    UNION ALL
    SELECT e.emp_id, e.manager_id, CONCAT(e.first_name,' ',e.last_name), e.job_title,
           oc.level + 1, CONCAT(oc.reporting_path, ' > ', e.first_name)
    FROM employee e JOIN org_chart oc ON e.manager_id = oc.emp_id -- recursive member
)
SELECT emp_id, CONCAT(REPEAT('    ', level), name) AS org_tree, job_title, level, reporting_path
FROM org_chart ORDER BY reporting_path;
```

## Output

Full output: [output.txt](output.txt)

### Views

```text
-- V1. Department salary summary (aggregate view)
--------------
CREATE VIEW v_dept_salary_summary AS
SELECT d.dept_id,
       d.dept_name,
       d.location,
       COUNT(e.emp_id)          AS headcount,
       SUM(e.salary)            AS monthly_payroll,
       ROUND(AVG(e.salary), 2)  AS avg_salary,
       MIN(e.salary)            AS min_salary,
       MAX(e.salary)            AS max_salary
FROM department d
LEFT JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.location
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT * FROM v_dept_salary_summary ORDER BY monthly_payroll DESC
--------------

+---------+-----------------+-----------+-----------+-----------------+------------+------------+------------+
| dept_id | dept_name       | location  | headcount | monthly_payroll | avg_salary | min_salary | max_salary |
+---------+-----------------+-----------+-----------+-----------------+------------+------------+------------+
|      10 | Engineering     | Bengaluru |        11 |      1528000.00 |  138909.09 |   70000.00 |  350000.00 |
|      20 | Sales           | Mumbai    |         7 |       625000.00 |   89285.71 |   48000.00 |  200000.00 |
|      30 | Marketing       | Delhi     |         6 |       527000.00 |   87833.33 |   45000.00 |  190000.00 |
|      40 | Finance         | Pune      |         4 |       423000.00 |  105750.00 |   50000.00 |  210000.00 |
|      50 | Human Resources | Hyderabad |         4 |       368000.00 |   92000.00 |   48000.00 |  170000.00 |
+---------+-----------------+-----------+-----------+-----------------+------------+------------+------------+
5 rows in set (0.000 sec)
```

```text
-- V2. Employee hierarchy view (self join: employee -> manager)
--------------
CREATE VIEW v_employee_hierarchy AS
SELECT e.emp_id,
       CONCAT(e.first_name, ' ', e.last_name)  AS employee_name,
       e.job_title,
       e.dept_id,
       e.manager_id,
       CONCAT(m.first_name, ' ', m.last_name)  AS manager_name,
       m.job_title                             AS manager_title
FROM employee e
LEFT JOIN employee m ON m.emp_id = e.manager_id
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT * FROM v_employee_hierarchy WHERE dept_id = 10 ORDER BY emp_id
--------------

+--------+----------------+--------------------------+---------+------------+---------------+-------------------------+
| emp_id | employee_name  | job_title                | dept_id | manager_id | manager_name  | manager_title           |
+--------+----------------+--------------------------+---------+------------+---------------+-------------------------+
|      1 | Rajesh Sharma  | Chief Executive Officer  |      10 |       NULL | NULL          | NULL                    |
|      2 | Ananya Iyer    | Engineering Manager      |      10 |          1 | Rajesh Sharma | Chief Executive Officer |
|      3 | Vikram Reddy   | Tech Lead                |      10 |          2 | Ananya Iyer   | Engineering Manager     |
|      4 | Priya Nair     | Senior Software Engineer |      10 |          3 | Vikram Reddy  | Tech Lead               |
|      5 | Arjun Mehta    | Senior Software Engineer |      10 |          3 | Vikram Reddy  | Tech Lead               |
|      6 | Sneha Kulkarni | Software Engineer        |      10 |          3 | Vikram Reddy  | Tech Lead               |
|      7 | Rohan Gupta    | Software Engineer        |      10 |          3 | Vikram Reddy  | Tech Lead               |
|      8 | Kavya Menon    | Software Engineer        |      10 |          9 | Aditya Joshi  | Tech Lead               |
|      9 | Aditya Joshi   | Tech Lead                |      10 |          2 | Ananya Iyer   | Engineering Manager     |
|     10 | Meera Pillai   | QA Engineer              |      10 |          9 | Aditya Joshi  | Tech Lead               |
|     11 | Karthik Rao    | DevOps Engineer          |      10 |          9 | Aditya Joshi  | Tech Lead               |
+--------+----------------+--------------------------+---------+------------+---------------+-------------------------+
11 rows in set (0.000 sec)
```

```text
-- Views can be queried like tables: managers with more than 2 direct reports
--------------
SELECT manager_name, COUNT(*) AS reports
FROM v_employee_hierarchy
WHERE manager_id IS NOT NULL
GROUP BY manager_name
HAVING COUNT(*) > 2
--------------

+---------------+---------+
| manager_name  | reports |
+---------------+---------+
| Rajesh Sharma |       5 |
| Vikram Reddy  |       4 |
| Aditya Joshi  |       3 |
| Neha Agarwal  |       3 |
| Sanjay Chopra |       3 |
+---------------+---------+
5 rows in set (0.000 sec)
```

```text
-- Data dictionary: which views does MySQL consider updatable?
--------------
SELECT TABLE_NAME AS view_name, IS_UPDATABLE, CHECK_OPTION
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'company_db'
ORDER BY TABLE_NAME
--------------

+-----------------------+--------------+--------------+
| view_name             | IS_UPDATABLE | CHECK_OPTION |
+-----------------------+--------------+--------------+
| v_dept_salary_summary | NO           | NONE         |
| v_emp_basic           | YES          | NONE         |
| v_emp_dept            | YES          | NONE         |
| v_employee_hierarchy  | NO           | NONE         |
| v_engineering_staff   | YES          | CASCADED     |
| v_high_earners        | YES          | NONE         |
+-----------------------+--------------+--------------+
6 rows in set (0.000 sec)
```

### Updatability tests

```text
-- T1. UPDATE through a simple view -> works, base table changes
--------------
UPDATE v_engineering_staff SET salary = salary + 5000 WHERE emp_id = 7
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 7
--------------

+--------+------------+----------+
| emp_id | first_name | salary   |
+--------+------------+----------+
|      7 | Rohan      | 85000.00 |
+--------+------------+----------+
1 row in set (0.000 sec)
```

```text
-- T2. INSERT through a view that exposes every NOT NULL column -> works
--------------
INSERT INTO v_engineering_staff
VALUES (99, 'Test', 'Intern', 'M', '2003-01-01', '2025-10-01', 'Intern', 25000, 'Bengaluru', 10)
--------------

Query OK, 1 row affected (0.000 sec)

--------------
SELECT emp_id, first_name, job_title, dept_id FROM employee WHERE emp_id = 99
--------------

+--------+------------+-----------+---------+
| emp_id | first_name | job_title | dept_id |
+--------+------------+-----------+---------+
|     99 | Test       | Intern    |      10 |
+--------+------------+-----------+---------+
1 row in set (0.000 sec)
```

```text
-- T2b. INSERT through a projection view that HIDES NOT NULL columns
--      (gender, dob, hire_date, salary, city have no default) -> ERROR 1423
--------------
INSERT INTO v_emp_basic (emp_id, first_name, last_name, job_title, dept_id)
VALUES (98, 'Hidden', 'Cols', 'Intern', 10)
--------------

ERROR 1423 (HY000) at line 92: Field of view 'company_db.v_emp_basic' underlying table doesn't have a default value
```

```text
-- T3. WITH CHECK OPTION : moving an employee out of the view's WHERE -> ERROR 1369
--------------
UPDATE v_engineering_staff SET dept_id = 20 WHERE emp_id = 7
--------------

ERROR 1369 (HY000) at line 96: CHECK OPTION failed 'company_db.v_engineering_staff'
```

```text
-- T4. WITH CHECK OPTION : inserting a row that does not satisfy dept_id = 10 -> ERROR 1369
--------------
INSERT INTO v_engineering_staff
VALUES (97, 'Out', 'Side', 'F', '2000-01-01', '2025-10-01', 'Analyst', 50000, 'Delhi', 30)
--------------

ERROR 1369 (HY000) at line 99: CHECK OPTION failed 'company_db.v_engineering_staff'
```

```text
-- T5. Same update through a view WITHOUT check option -> works,
--     the row simply "disappears" from the view
--------------
SELECT * FROM v_high_earners WHERE emp_id = 3
--------------

+--------+------------+-----------+---------+
| emp_id | first_name | salary    | dept_id |
+--------+------------+-----------+---------+
|      3 | Vikram     | 160000.00 |      10 |
+--------+------------+-----------+---------+
1 row in set (0.000 sec)

--------------
UPDATE v_high_earners SET salary = 140000 WHERE emp_id = 3
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT * FROM v_high_earners WHERE emp_id = 3
--------------

Empty set (0.000 sec)

--------------
SELECT emp_id, salary FROM employee WHERE emp_id = 3
--------------

+--------+-----------+
| emp_id | salary    |
+--------+-----------+
|      3 | 140000.00 |
+--------+-----------+
1 row in set (0.000 sec)
```

```text
-- T6. UPDATE on an aggregate view (GROUP BY) -> ERROR 1288 (not updatable)
--------------
UPDATE v_dept_salary_summary SET avg_salary = 100000 WHERE dept_id = 10
--------------

ERROR 1288 (HY000) at line 110: The target table v_dept_salary_summary of the UPDATE is not updatable
```

```text
-- T7. DELETE from an aggregate view -> ERROR 1288
--------------
DELETE FROM v_dept_salary_summary WHERE dept_id = 50
--------------

ERROR 1288 (HY000) at line 113: The target table v_dept_salary_summary of the DELETE is not updatable
```

```text
-- T8. Join view with LEFT JOIN (v_employee_hierarchy) -> ERROR 1288 (not updatable)
--------------
UPDATE v_employee_hierarchy SET job_title = 'Senior Tech Lead' WHERE emp_id = 9
--------------

ERROR 1288 (HY000) at line 116: The target table v_employee_hierarchy of the UPDATE is not updatable
```

```text
-- T9. INNER JOIN view: updating columns of ONE base table -> works
--------------
UPDATE v_emp_dept SET job_title = 'Senior Tech Lead' WHERE emp_id = 9
--------------

Query OK, 1 row affected (0.000 sec)
Rows matched: 1  Changed: 1  Warnings: 0

--------------
SELECT emp_id, first_name, job_title, dept_name FROM v_emp_dept WHERE emp_id = 9
--------------

+--------+------------+------------------+-------------+
| emp_id | first_name | job_title        | dept_name   |
+--------+------------+------------------+-------------+
|      9 | Aditya     | Senior Tech Lead | Engineering |
+--------+------------+------------------+-------------+
1 row in set (0.000 sec)
```

```text
-- T10. INNER JOIN view: one UPDATE touching columns of TWO base tables -> ERROR 1393
--------------
UPDATE v_emp_dept SET salary = 160000, location = 'Mysuru' WHERE emp_id = 9
--------------

ERROR 1393 (HY000) at line 123: Can not modify more than one base table through a join view 'company_db.v_emp_dept'
```

```text
-- T11. INNER JOIN view: DELETE is not allowed on a multi-table view -> ERROR 1395
--------------
DELETE FROM v_emp_dept WHERE emp_id = 32
--------------

ERROR 1395 (HY000) at line 126: Can not delete from join view 'company_db.v_emp_dept'
```

```text
-- T12. INNER JOIN view: INSERT into columns of a single base table is allowed only
--      if that table's NOT NULL columns are covered; here they are not -> ERROR 1423
--------------
INSERT INTO v_emp_dept (emp_id, first_name, job_title, salary) VALUES (96, 'A', 'B', 1000)
--------------

ERROR 1423 (HY000) at line 130: Field of view 'company_db.v_emp_dept' underlying table doesn't have a default value
--------------
ROLLBACK
--------------

Query OK, 0 rows affected (0.000 sec)
```

```text
-- After ROLLBACK the base table is unchanged
--------------
SELECT emp_id, first_name, job_title, salary FROM employee WHERE emp_id IN (3, 7, 9, 99)
--------------

+--------+------------+-------------------+-----------+
| emp_id | first_name | job_title         | salary    |
+--------+------------+-------------------+-----------+
|      3 | Vikram     | Tech Lead         | 160000.00 |
|      7 | Rohan      | Software Engineer |  80000.00 |
|      9 | Aditya     | Tech Lead         | 155000.00 |
+--------+------------+-------------------+-----------+
3 rows in set (0.000 sec)
```

### Recursive CTE - reporting chains

```text
-- R1. Top-down: whole organisation tree starting from the CEO
--------------
WITH RECURSIVE org_chart AS (
    SELECT emp_id, manager_id, CONCAT(first_name,' ',last_name) AS name, job_title,
           0 AS level,
           CAST(first_name AS CHAR(500)) AS reporting_path
    FROM employee
    WHERE manager_id IS NULL                        -- anchor member: CEO
    UNION ALL
    SELECT e.emp_id, e.manager_id, CONCAT(e.first_name,' ',e.last_name), e.job_title,
           oc.level + 1,
           CONCAT(oc.reporting_path, ' > ', e.first_name)
    FROM employee e
    JOIN org_chart oc ON e.manager_id = oc.emp_id   -- recursive member
)
SELECT emp_id,
       CONCAT(REPEAT('    ', level), name) AS org_tree,
       job_title, level, reporting_path
FROM org_chart
ORDER BY reporting_path
--------------

+--------+-----------------------------+-------------------------------+-------+------------------------------------+
| emp_id | org_tree                    | job_title                     | level | reporting_path                     |
+--------+-----------------------------+-------------------------------+-------+------------------------------------+
|      1 | Rajesh Sharma               | Chief Executive Officer       |     0 | Rajesh                             |
|      2 |     Ananya Iyer             | Engineering Manager           |     1 | Rajesh > Ananya                    |
|      9 |         Aditya Joshi        | Tech Lead                     |     2 | Rajesh > Ananya > Aditya           |
|     11 |             Karthik Rao     | DevOps Engineer               |     3 | Rajesh > Ananya > Aditya > Karthik |
|      8 |             Kavya Menon     | Software Engineer             |     3 | Rajesh > Ananya > Aditya > Kavya   |
|     10 |             Meera Pillai    | QA Engineer                   |     3 | Rajesh > Ananya > Aditya > Meera   |
|      3 |         Vikram Reddy        | Tech Lead                     |     2 | Rajesh > Ananya > Vikram           |
|      5 |             Arjun Mehta     | Senior Software Engineer      |     3 | Rajesh > Ananya > Vikram > Arjun   |
|      4 |             Priya Nair      | Senior Software Engineer      |     3 | Rajesh > Ananya > Vikram > Priya   |
|      7 |             Rohan Gupta     | Software Engineer             |     3 | Rajesh > Ananya > Vikram > Rohan   |
|      6 |             Sneha Kulkarni  | Software Engineer             |     3 | Rajesh > Ananya > Vikram > Sneha   |
|     29 |     Farah Khan              | Head of HR                    |     1 | Rajesh > Farah                     |
|     30 |         Varun Kapoor        | HR Manager                    |     2 | Rajesh > Farah > Varun             |
|     31 |             Anjali Dubey    | Talent Acquisition Specialist |     3 | Rajesh > Farah > Varun > Anjali    |
|     32 |             Siddharth Bose  | HR Executive                  |     3 | Rajesh > Farah > Varun > Siddharth |
|     25 |     Gopal Krishnan          | Chief Financial Officer       |     1 | Rajesh > Gopal                     |
|     27 |         Deepak Jain         | Financial Analyst             |     2 | Rajesh > Gopal > Deepak            |
|     26 |         Lakshmi Subramanian | Senior Accountant             |     2 | Rajesh > Gopal > Lakshmi           |
|     28 |             Swati Mishra    | Accounts Executive            |     3 | Rajesh > Gopal > Lakshmi > Swati   |
|     19 |     Ritu Malhotra           | Head of Marketing             |     1 | Rajesh > Ritu                      |
|     24 |         Harsh Vardhan       | Digital Marketing Executive   |     2 | Rajesh > Ritu > Harsh              |
|     20 |         Sanjay Chopra       | Brand Manager                 |     2 | Rajesh > Ritu > Sanjay             |
|     21 |             Ishita Banerjee | Content Strategist            |     3 | Rajesh > Ritu > Sanjay > Ishita    |
|     22 |             Nikhil Saxena   | SEO Analyst                   |     3 | Rajesh > Ritu > Sanjay > Nikhil    |
|     23 |             Tanvi Shah      | Social Media Executive        |     3 | Rajesh > Ritu > Sanjay > Tanvi     |
|     12 |     Suresh Patel            | Head of Sales                 |     1 | Rajesh > Suresh                    |
|     17 |         Divya Bhat          | Key Account Manager           |     2 | Rajesh > Suresh > Divya            |
|     18 |             Manish Tiwari   | Sales Executive               |     3 | Rajesh > Suresh > Divya > Manish   |
|     13 |         Neha Agarwal        | Regional Sales Manager        |     2 | Rajesh > Suresh > Neha             |
|     14 |             Amit Singh      | Sales Executive               |     3 | Rajesh > Suresh > Neha > Amit      |
|     15 |             Pooja Desai     | Sales Executive               |     3 | Rajesh > Suresh > Neha > Pooja     |
|     16 |             Rahul Verma     | Sales Executive               |     3 | Rajesh > Suresh > Neha > Rahul     |
+--------+-----------------------------+-------------------------------+-------+------------------------------------+
32 rows in set (0.000 sec)
```

```text
-- R2. Bottom-up: complete reporting chain of one employee (Kavya, emp 8) up to the CEO
--------------
WITH RECURSIVE chain AS (
    SELECT emp_id, manager_id, CONCAT(first_name,' ',last_name) AS name, job_title, 1 AS step
    FROM employee WHERE emp_id = 8
    UNION ALL
    SELECT m.emp_id, m.manager_id, CONCAT(m.first_name,' ',m.last_name), m.job_title, c.step + 1
    FROM employee m
    JOIN chain c ON m.emp_id = c.manager_id
)
SELECT step, emp_id, name, job_title FROM chain ORDER BY step
--------------

+------+--------+---------------+-------------------------+
| step | emp_id | name          | job_title               |
+------+--------+---------------+-------------------------+
|    1 |      8 | Kavya Menon   | Software Engineer       |
|    2 |      9 | Aditya Joshi  | Tech Lead               |
|    3 |      2 | Ananya Iyer   | Engineering Manager     |
|    4 |      1 | Rajesh Sharma | Chief Executive Officer |
+------+--------+---------------+-------------------------+
4 rows in set (0.000 sec)
```

```text
-- R3. Chain as a single string for every Engineering employee
--------------
WITH RECURSIVE up AS (
    SELECT emp_id AS start_emp, emp_id, manager_id, CAST(first_name AS CHAR(300)) AS chain
    FROM employee WHERE dept_id = 10
    UNION ALL
    SELECT up.start_emp, m.emp_id, m.manager_id, CONCAT(up.chain, ' -> ', m.first_name)
    FROM up JOIN employee m ON m.emp_id = up.manager_id
)
SELECT start_emp AS emp_id, chain AS reporting_chain
FROM up
WHERE manager_id IS NULL
ORDER BY start_emp
--------------

+--------+---------------------------------------+
| emp_id | reporting_chain                       |
+--------+---------------------------------------+
|      1 | Rajesh                                |
|      2 | Ananya -> Rajesh                      |
|      3 | Vikram -> Ananya -> Rajesh            |
|      4 | Priya -> Vikram -> Ananya -> Rajesh   |
|      5 | Arjun -> Vikram -> Ananya -> Rajesh   |
|      6 | Sneha -> Vikram -> Ananya -> Rajesh   |
|      7 | Rohan -> Vikram -> Ananya -> Rajesh   |
|      8 | Kavya -> Aditya -> Ananya -> Rajesh   |
|      9 | Aditya -> Ananya -> Rajesh            |
|     10 | Meera -> Aditya -> Ananya -> Rajesh   |
|     11 | Karthik -> Aditya -> Ananya -> Rajesh |
+--------+---------------------------------------+
11 rows in set (0.000 sec)
```

```text
-- R4. Total team size (direct + indirect reports) and team payroll for every manager
--------------
WITH RECURSIVE subordinates AS (
    SELECT manager_id AS boss_id, emp_id, salary
    FROM employee WHERE manager_id IS NOT NULL
    UNION ALL
    SELECT s.boss_id, e.emp_id, e.salary
    FROM subordinates s
    JOIN employee e ON e.manager_id = s.emp_id
)
SELECT s.boss_id, CONCAT(b.first_name,' ',b.last_name) AS manager,
       COUNT(*) AS total_team_size, SUM(s.salary) AS team_payroll
FROM subordinates s
JOIN employee b ON b.emp_id = s.boss_id
GROUP BY s.boss_id, manager
ORDER BY total_team_size DESC
--------------

+---------+---------------------+-----------------+--------------+
| boss_id | manager             | total_team_size | team_payroll |
+---------+---------------------+-----------------+--------------+
|       1 | Rajesh Sharma       |              31 |   3121000.00 |
|       2 | Ananya Iyer         |               9 |    958000.00 |
|      12 | Suresh Patel        |               6 |    425000.00 |
|      19 | Ritu Malhotra       |               5 |    337000.00 |
|       3 | Vikram Reddy        |               4 |    400000.00 |
|       9 | Aditya Joshi        |               3 |    243000.00 |
|      13 | Neha Agarwal        |               3 |    157000.00 |
|      20 | Sanjay Chopra       |               3 |    175000.00 |
|      25 | Gopal Krishnan      |               3 |    213000.00 |
|      29 | Farah Khan          |               3 |    198000.00 |
|      30 | Varun Kapoor        |               2 |    103000.00 |
|      17 | Divya Bhat          |               1 |     48000.00 |
|      26 | Lakshmi Subramanian |               1 |     50000.00 |
+---------+---------------------+-----------------+--------------+
13 rows in set (0.000 sec)
```

```text
-- R5. Depth of the hierarchy (number of levels)
--------------
WITH RECURSIVE lvl AS (
    SELECT emp_id, 1 AS depth FROM employee WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, l.depth + 1 FROM employee e JOIN lvl l ON e.manager_id = l.emp_id
)
SELECT depth, COUNT(*) AS employees_at_level FROM lvl GROUP BY depth ORDER BY depth
--------------

+-------+--------------------+
| depth | employees_at_level |
+-------+--------------------+
|     1 |                  1 |
|     2 |                  5 |
|     3 |                  9 |
|     4 |                 17 |
+-------+--------------------+
4 rows in set (0.000 sec)
```

```text
-- R6. Saving the recursive query as a view so it can be reused
--------------
CREATE OR REPLACE VIEW v_reporting_chain AS
WITH RECURSIVE up AS (
    SELECT emp_id AS start_emp, emp_id, manager_id, CAST(first_name AS CHAR(300)) AS chain
    FROM employee
    UNION ALL
    SELECT up.start_emp, m.emp_id, m.manager_id, CONCAT(up.chain, ' -> ', m.first_name)
    FROM up JOIN employee m ON m.emp_id = up.manager_id
)
SELECT start_emp AS emp_id, chain FROM up WHERE manager_id IS NULL
--------------

Query OK, 0 rows affected (0.001 sec)

--------------
SELECT * FROM v_reporting_chain WHERE emp_id IN (18, 23, 28, 32)
--------------

+--------+---------------------------------------+
| emp_id | chain                                 |
+--------+---------------------------------------+
|     18 | Manish -> Divya -> Suresh -> Rajesh   |
|     23 | Tanvi -> Sanjay -> Ritu -> Rajesh     |
|     28 | Swati -> Lakshmi -> Gopal -> Rajesh   |
|     32 | Siddharth -> Varun -> Farah -> Rajesh |
+--------+---------------------------------------+
4 rows in set (0.000 sec)
```

## Observations - view updatability

| Test | View type | Operation | Result |
|---|---|---|---|
| T1 | Single table + CHECK OPTION | UPDATE salary | Works, Base table updated |
| T2 | Single table, exposes all NOT NULL columns | INSERT | Works, Row inserted into `employee` |
| T2b | Projection that hides NOT NULL columns | INSERT | ERROR 1423 - field has no default |
| T3 | WITH CHECK OPTION | UPDATE dept 10 -> 20 | ERROR 1369 - CHECK OPTION failed |
| T4 | WITH CHECK OPTION | INSERT dept 30 | ERROR 1369 |
| T5 | Single table, no check option | UPDATE that moves the row out of the view | Works, the row "disappears" from the view |
| T6 / T7 | Aggregate (GROUP BY) | UPDATE / DELETE | ERROR 1288 - not updatable |
| T8 | LEFT JOIN view | UPDATE | ERROR 1288 |
| T9 | INNER JOIN view | UPDATE one table's column | Works |
| T10 | INNER JOIN view | UPDATE columns of two tables | ERROR 1393 |
| T11 | INNER JOIN view | DELETE | ERROR 1395 |
| T12 | INNER JOIN view | INSERT missing NOT NULL columns | ERROR 1423 |

* `ROLLBACK` restored the base table: employees 3, 7 and 9 have their original values, and employee 99 does not exist.
* The recursive CTE found a hierarchy **4 levels** deep (1 CEO -> 5 heads -> 9 managers/leads -> 17 staff). The CEO's total team covers all 31 other employees.

## Result

The department salary summary view and the employee hierarchy view were created. View updatability was tested for different types of views and all results matched MySQL's rules. A recursive CTE was used to show the reporting chain of every employee.

## Conclusion

Views make complex queries simple to use and can hide columns like salary. Only simple views (one view row = one table row) can be updated. WITH CHECK OPTION stops changes that would move a row out of the view. A recursive CTE can walk through a hierarchy of any depth in a single query.
