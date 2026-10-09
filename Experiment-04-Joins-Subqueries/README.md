# Experiment 4 - Joins, Subqueries, EXISTS, Simulated INTERSECT / EXCEPT and EXPLAIN

| Name | UID No | Course | Subject | Submitted To |
|---|---|---|---|---|
| Aditya Sharma | 25LBCS3150 | B.Tech CSE (AI/ML-2) | RDBMS (25CSH-210) | Mr. Amit Kumar Sir |

## Aim

Using the Employee schema, write queries with **INNER JOIN, LEFT JOIN, self join, 3-way join, correlated subqueries, EXISTS, and simulated INTERSECT and EXCEPT**, and compare their execution plans using `EXPLAIN`.

## Software / Tools Used

MySQL Server 8.0+ (uses `company_db` from Experiment 3), MySQL command-line client, VS Code

## Theory

### Joins

| Join | Returns |
|---|---|
| `INNER JOIN` | Only the rows that match in both tables |
| `LEFT [OUTER] JOIN` | All rows of the left table; NULLs where the right side has no match |
| `RIGHT [OUTER] JOIN` | All rows of the right table |
| Self join | A table joined with itself through aliases (employee ↔ manager) |
| Multi-way join | Three or more tables chained by join conditions |
| Anti-join | Rows of A with **no** match in B (`LEFT JOIN ... WHERE b.key IS NULL`, `NOT EXISTS`) |

### Subqueries

* **Non-correlated subquery:** runs once, independently of the outer query.
* **Correlated subquery:** refers to a column of the outer query, so logically it runs once per outer row.
* **`EXISTS` / `NOT EXISTS`:** true if the subquery returns at least one / zero rows. It stops at the first match, and `NOT EXISTS` handles NULLs safely (unlike `NOT IN`).

### INTERSECT and EXCEPT

MySQL added `INTERSECT` and `EXCEPT` only in version 8.0.31. On older versions (and in many exam questions) they are **simulated**:

| Set operation | Simulation |
|---|---|
| A ∩ B (INTERSECT) | `IN (subquery)`, `INNER JOIN`, or `EXISTS` |
| A − B (EXCEPT / MINUS) | `NOT IN (subquery)`, `LEFT JOIN ... IS NULL`, or `NOT EXISTS` |

### EXPLAIN

`EXPLAIN` shows the optimizer's plan without running the query. The most important columns are:

* **type** - access method, from worst to best: `ALL` (full scan) -> `index` -> `range` -> `ref` -> `eq_ref` -> `const`.
* **key** - the index actually used.
* **rows** - estimated rows examined.
* **Extra** - e.g. `Using where`, `Using index` (covering index), `Using temporary`, `Using filesort`, `Not exists` (anti-join optimization).

`EXPLAIN FORMAT=TREE` prints the iterator tree. `EXPLAIN ANALYZE` actually runs the query and adds the real time, rows and loops for each step.

## Procedure

1. Selected `company_db` (created in Experiment 3).
2. Wrote 9 join queries (J1-J9), 7 subquery / EXISTS queries (S1-S7), and 6 INTERSECT / EXCEPT simulations (I1-I3, E1-E3).
3. Verified the simulations against the native `INTERSECT` / `EXCEPT` (V1).
4. Ran `ANALYZE TABLE` to refresh statistics, then compared plans with `EXPLAIN`, `EXPLAIN FORMAT=TREE` and `EXPLAIN ANALYZE` (X1-X6).

## How to Run

```bash
mysql -u root -t -vvv < ../Experiment-03-Employee-Queries/exp03_employee_queries.sql   # once
mysql -u root -t -vvv < exp04_joins_subqueries.sql
```

## Source Code

[exp04_joins_subqueries.sql](exp04_joins_subqueries.sql)

## Output

Full output: [output.txt](output.txt)

### Joins

```text
-- J2. INNER JOIN with aggregation : department head and headcount
--------------
SELECT d.dept_name, CONCAT(m.first_name,' ',m.last_name) AS dept_head,
       COUNT(e.emp_id) AS headcount
FROM department d
INNER JOIN employee m ON m.emp_id  = d.mgr_emp_id
INNER JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_name, dept_head
--------------

+-----------------+----------------+-----------+
| dept_name       | dept_head      | headcount |
+-----------------+----------------+-----------+
| Engineering     | Ananya Iyer    |        11 |
| Sales           | Suresh Patel   |         7 |
| Marketing       | Ritu Malhotra  |         6 |
| Finance         | Gopal Krishnan |         4 |
| Human Resources | Farah Khan     |         4 |
+-----------------+----------------+-----------+
5 rows in set (0.000 sec)
```

```text
-- J3. LEFT JOIN : all projects with number of members (project 108 has none)
--------------
SELECT p.project_id, p.project_name, p.status, COUNT(w.emp_id) AS members
FROM project p
LEFT JOIN works_on w ON w.project_id = p.project_id
GROUP BY p.project_id, p.project_name, p.status
ORDER BY members
--------------

+------------+--------------------------+-----------+---------+
| project_id | project_name             | status    | members |
+------------+--------------------------+-----------+---------+
|        108 | AI Customer Chatbot      | Planned   |       0 |
|        103 | Cloud Migration          | Completed |       3 |
|        107 | Campus Hiring Drive 2025 | Completed |       4 |
|        106 | Payroll Automation       | Active    |       5 |
|        102 | Mobile App Revamp        | Active    |       6 |
|        101 | UPI Payments Gateway     | Active    |       7 |
|        104 | Diwali Festive Campaign  | Active    |       7 |
|        105 | Tier-2 Dealer Expansion  | Active    |       7 |
+------------+--------------------------+-----------+---------+
8 rows in set (0.000 sec)
```

```text
-- J4. LEFT JOIN ... IS NULL : employees not assigned to any project (anti-join)
--------------
SELECT e.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee, e.job_title
FROM employee e
LEFT JOIN works_on w ON w.emp_id = e.emp_id
WHERE w.emp_id IS NULL
--------------

+--------+----------------+-------------------------+
| emp_id | employee       | job_title               |
+--------+----------------+-------------------------+
|      1 | Rajesh Sharma  | Chief Executive Officer |
|     17 | Divya Bhat     | Key Account Manager     |
|     25 | Gopal Krishnan | Chief Financial Officer |
+--------+----------------+-------------------------+
3 rows in set (0.000 sec)
```

```text
-- J5. SELF JOIN : employee with his/her manager
--------------
SELECT e.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee, e.job_title,
       CONCAT(m.first_name,' ',m.last_name)              AS manager,
       m.job_title                                       AS manager_title
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.emp_id
ORDER BY e.emp_id
LIMIT 15
--------------

+--------+----------------+--------------------------+---------------+-------------------------+
| emp_id | employee       | job_title                | manager       | manager_title           |
+--------+----------------+--------------------------+---------------+-------------------------+
|      1 | Rajesh Sharma  | Chief Executive Officer  | NULL          | NULL                    |
|      2 | Ananya Iyer    | Engineering Manager      | Rajesh Sharma | Chief Executive Officer |
|      3 | Vikram Reddy   | Tech Lead                | Ananya Iyer   | Engineering Manager     |
|      4 | Priya Nair     | Senior Software Engineer | Vikram Reddy  | Tech Lead               |
|      5 | Arjun Mehta    | Senior Software Engineer | Vikram Reddy  | Tech Lead               |
|      6 | Sneha Kulkarni | Software Engineer        | Vikram Reddy  | Tech Lead               |
|      7 | Rohan Gupta    | Software Engineer        | Vikram Reddy  | Tech Lead               |
|      8 | Kavya Menon    | Software Engineer        | Aditya Joshi  | Tech Lead               |
|      9 | Aditya Joshi   | Tech Lead                | Ananya Iyer   | Engineering Manager     |
|     10 | Meera Pillai   | QA Engineer              | Aditya Joshi  | Tech Lead               |
|     11 | Karthik Rao    | DevOps Engineer          | Aditya Joshi  | Tech Lead               |
|     12 | Suresh Patel   | Head of Sales            | Rajesh Sharma | Chief Executive Officer |
|     13 | Neha Agarwal   | Regional Sales Manager   | Suresh Patel  | Head of Sales           |
|     14 | Amit Singh     | Sales Executive          | Neha Agarwal  | Regional Sales Manager  |
|     15 | Pooja Desai    | Sales Executive          | Neha Agarwal  | Regional Sales Manager  |
+--------+----------------+--------------------------+---------------+-------------------------+
15 rows in set (0.000 sec)
```

```text
-- J6. SELF JOIN : number of direct reports for every manager
--------------
SELECT m.emp_id, CONCAT(m.first_name,' ',m.last_name) AS manager,
       COUNT(e.emp_id) AS direct_reports
FROM employee m
JOIN employee e ON e.manager_id = m.emp_id
GROUP BY m.emp_id, manager
ORDER BY direct_reports DESC
--------------

+--------+---------------------+----------------+
| emp_id | manager             | direct_reports |
+--------+---------------------+----------------+
|      1 | Rajesh Sharma       |              5 |
|      3 | Vikram Reddy        |              4 |
|      9 | Aditya Joshi        |              3 |
|     13 | Neha Agarwal        |              3 |
|     20 | Sanjay Chopra       |              3 |
|      2 | Ananya Iyer         |              2 |
|     12 | Suresh Patel        |              2 |
|     19 | Ritu Malhotra       |              2 |
|     25 | Gopal Krishnan      |              2 |
|     30 | Varun Kapoor        |              2 |
|     17 | Divya Bhat          |              1 |
|     26 | Lakshmi Subramanian |              1 |
|     29 | Farah Khan          |              1 |
+--------+---------------------+----------------+
13 rows in set (0.000 sec)
```

```text
-- J8. 3-WAY JOIN : employee - works_on - project
--------------
SELECT CONCAT(e.first_name,' ',e.last_name) AS employee, p.project_name,
       w.role, w.hours_per_week
FROM employee e
JOIN works_on w ON w.emp_id     = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.project_id IN (101, 104)
ORDER BY p.project_name, w.hours_per_week DESC
--------------

+-----------------+-------------------------+--------------+----------------+
| employee        | project_name            | role         | hours_per_week |
+-----------------+-------------------------+--------------+----------------+
| Tanvi Shah      | Diwali Festive Campaign | Social Media |           40.0 |
| Harsh Vardhan   | Diwali Festive Campaign | Ads          |           35.0 |
| Ishita Banerjee | Diwali Festive Campaign | Content      |           35.0 |
| Nikhil Saxena   | Diwali Festive Campaign | SEO          |           30.0 |
| Sanjay Chopra   | Diwali Festive Campaign | Lead         |           30.0 |
| Amit Singh      | Diwali Festive Campaign | Sales Input  |            8.0 |
| Ritu Malhotra   | Diwali Festive Campaign | Sponsor      |            5.0 |
| Priya Nair      | UPI Payments Gateway    | Developer    |           40.0 |
| Arjun Mehta     | UPI Payments Gateway    | Developer    |           35.0 |
| Vikram Reddy    | UPI Payments Gateway    | Lead         |           30.0 |
| Meera Pillai    | UPI Payments Gateway    | Tester       |           20.0 |
| Sneha Kulkarni  | UPI Payments Gateway    | Developer    |           20.0 |
| Karthik Rao     | UPI Payments Gateway    | DevOps       |           15.0 |
| Ananya Iyer     | UPI Payments Gateway    | Sponsor      |            4.0 |
+-----------------+-------------------------+--------------+----------------+
14 rows in set (0.000 sec)
```

```text
-- J9. 4-WAY JOIN : employees working on a project owned by ANOTHER department
--------------
SELECT CONCAT(e.first_name,' ',e.last_name) AS employee,
       ed.dept_name AS home_dept, p.project_name, pd.dept_name AS project_dept
FROM employee e
JOIN department ed ON ed.dept_id   = e.dept_id
JOIN works_on   w  ON w.emp_id     = e.emp_id
JOIN project    p  ON p.project_id = w.project_id
JOIN department pd ON pd.dept_id   = p.dept_id
WHERE e.dept_id <> p.dept_id
--------------

+---------------+-----------------+-------------------------+--------------+
| employee      | home_dept       | project_name            | project_dept |
+---------------+-----------------+-------------------------+--------------+
| Sanjay Chopra | Marketing       | Mobile App Revamp       | Engineering  |
| Amit Singh    | Sales           | Diwali Festive Campaign | Marketing    |
| Deepak Jain   | Finance         | Tier-2 Dealer Expansion | Sales        |
| Varun Kapoor  | Human Resources | Payroll Automation      | Finance      |
| Karthik Rao   | Engineering     | Payroll Automation      | Finance      |
+---------------+-----------------+-------------------------+--------------+
5 rows in set (0.000 sec)
```

### Correlated subqueries and EXISTS

```text
-- S2. CORRELATED subquery : employees earning more than their own department's average
--------------
SELECT e.emp_id, e.first_name, e.dept_id, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary)
                  FROM employee e2
                  WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC
--------------

+--------+------------+---------+-----------+
| emp_id | first_name | dept_id | salary    |
+--------+------------+---------+-----------+
|      1 | Rajesh     |      10 | 350000.00 |
|      2 | Ananya     |      10 | 220000.00 |
|      3 | Vikram     |      10 | 160000.00 |
|      9 | Aditya     |      10 | 155000.00 |
|     12 | Suresh     |      20 | 200000.00 |
|     13 | Neha       |      20 | 130000.00 |
|     17 | Divya      |      20 |  90000.00 |
|     19 | Ritu       |      30 | 190000.00 |
|     20 | Sanjay     |      30 | 110000.00 |
|     25 | Gopal      |      40 | 210000.00 |
|     29 | Farah      |      50 | 170000.00 |
|     30 | Varun      |      50 |  95000.00 |
+--------+------------+---------+-----------+
12 rows in set (0.000 sec)
```

```text
-- S3. CORRELATED subquery : lowest-paid employee of each department
--------------
SELECT e.dept_id, e.first_name, e.last_name, e.salary
FROM employee e
WHERE e.salary = (SELECT MIN(salary) FROM employee x WHERE x.dept_id = e.dept_id)
--------------

+---------+------------+-----------+----------+
| dept_id | first_name | last_name | salary   |
+---------+------------+-----------+----------+
|      10 | Meera      | Pillai    | 70000.00 |
|      20 | Manish     | Tiwari    | 48000.00 |
|      30 | Tanvi      | Shah      | 45000.00 |
|      40 | Swati      | Mishra    | 50000.00 |
|      50 | Siddharth  | Bose      | 48000.00 |
+---------+------------+-----------+----------+
5 rows in set (0.000 sec)
```

```text
-- S5. EXISTS : departments that own at least one Completed project
--------------
SELECT d.dept_id, d.dept_name
FROM department d
WHERE EXISTS (SELECT 1 FROM project p
              WHERE p.dept_id = d.dept_id AND p.status = 'Completed')
--------------

+---------+-----------------+
| dept_id | dept_name       |
+---------+-----------------+
|      10 | Engineering     |
|      50 | Human Resources |
+---------+-----------------+
2 rows in set (0.000 sec)
```

```text
-- S6. NOT EXISTS : employees who are not working on any project
--------------
SELECT e.emp_id, e.first_name, e.last_name
FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id)
--------------

+--------+------------+-----------+
| emp_id | first_name | last_name |
+--------+------------+-----------+
|      1 | Rajesh     | Sharma    |
|     17 | Divya      | Bhat      |
|     25 | Gopal      | Krishnan  |
+--------+------------+-----------+
3 rows in set (0.000 sec)
```

```text
-- S7. EXISTS : managers who have at least one report earning > 1,00,000
--------------
SELECT m.emp_id, m.first_name, m.job_title
FROM employee m
WHERE EXISTS (SELECT 1 FROM employee e
              WHERE e.manager_id = m.emp_id AND e.salary > 100000)
--------------

+--------+------------+-------------------------+
| emp_id | first_name | job_title               |
+--------+------------+-------------------------+
|      1 | Rajesh     | Chief Executive Officer |
|      2 | Ananya     | Engineering Manager     |
|      3 | Vikram     | Tech Lead               |
|     12 | Suresh     | Head of Sales           |
|     19 | Ritu       | Head of Marketing       |
+--------+------------+-------------------------+
5 rows in set (0.000 sec)
```

### Simulated INTERSECT / EXCEPT

```text
-- I1. INTERSECT (simulated with IN) : employees working on BOTH project 101 AND 102
--------------
SELECT emp_id FROM works_on WHERE project_id = 101
  AND emp_id IN (SELECT emp_id FROM works_on WHERE project_id = 102)
--------------

+--------+
| emp_id |
+--------+
|      6 |
|     10 |
+--------+
2 rows in set (0.000 sec)
```

```text
-- I2. INTERSECT (simulated with INNER JOIN) - same result
--------------
SELECT a.emp_id, e.first_name
FROM works_on a
JOIN works_on b ON a.emp_id = b.emp_id AND b.project_id = 102
JOIN employee e ON e.emp_id = a.emp_id
WHERE a.project_id = 101
--------------

+--------+------------+
| emp_id | first_name |
+--------+------------+
|      6 | Sneha      |
|     10 | Meera      |
+--------+------------+
2 rows in set (0.000 sec)
```

```text
-- I3. INTERSECT (simulated with EXISTS) : cities that have both Engineering and Sales staff
--------------
SELECT DISTINCT e.city
FROM employee e
WHERE e.dept_id = 10
  AND EXISTS (SELECT 1 FROM employee s WHERE s.dept_id = 20 AND s.city = e.city)
--------------

+-----------+
| city      |
+-----------+
| Bengaluru |
+-----------+
1 row in set (0.000 sec)
```

```text
-- E1. EXCEPT (simulated with NOT IN) : on project 101 but NOT on project 102
--------------
SELECT emp_id FROM works_on WHERE project_id = 101
  AND emp_id NOT IN (SELECT emp_id FROM works_on WHERE project_id = 102)
--------------

+--------+
| emp_id |
+--------+
|      2 |
|      3 |
|      4 |
|      5 |
|     11 |
+--------+
5 rows in set (0.000 sec)
```

```text
-- E2. EXCEPT (simulated with LEFT JOIN ... IS NULL) - same result
--------------
SELECT a.emp_id, e.first_name
FROM works_on a
LEFT JOIN works_on b ON a.emp_id = b.emp_id AND b.project_id = 102
JOIN employee e ON e.emp_id = a.emp_id
WHERE a.project_id = 101 AND b.emp_id IS NULL
--------------

+--------+------------+
| emp_id | first_name |
+--------+------------+
|      2 | Ananya     |
|      3 | Vikram     |
|      4 | Priya      |
|      5 | Arjun      |
|     11 | Karthik    |
+--------+------------+
5 rows in set (0.000 sec)
```

```text
-- E3. EXCEPT (simulated with NOT EXISTS) : cities with Engineering staff but no Sales staff
--------------
SELECT DISTINCT e.city
FROM employee e
WHERE e.dept_id = 10
  AND NOT EXISTS (SELECT 1 FROM employee s WHERE s.dept_id = 20 AND s.city = e.city)
--------------

+-----------+
| city      |
+-----------+
| Chennai   |
| Pune      |
| Kochi     |
| Hyderabad |
+-----------+
4 rows in set (0.000 sec)
```

```text
-- V1. Verification with native set operators (available from MySQL 8.0.31)
--------------
SELECT emp_id FROM works_on WHERE project_id = 101
INTERSECT
SELECT emp_id FROM works_on WHERE project_id = 102
--------------

+--------+
| emp_id |
+--------+
|      6 |
|     10 |
+--------+
2 rows in set (0.000 sec)

--------------
SELECT emp_id FROM works_on WHERE project_id = 101
EXCEPT
SELECT emp_id FROM works_on WHERE project_id = 102
--------------

+--------+
| emp_id |
+--------+
|      2 |
|      3 |
|      4 |
|      5 |
|     11 |
+--------+
5 rows in set (0.000 sec)
```

### Execution plans

```text
-- X1. Correlated subquery (S2) - traditional EXPLAIN
--------------
EXPLAIN FORMAT=TRADITIONAL
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id)
--------------

+----+--------------------+-------+------------+------+---------------+-------------+---------+----------------------+------+----------+-------------+
| id | select_type        | table | partitions | type | possible_keys | key         | key_len | ref                  | rows | filtered | Extra       |
+----+--------------------+-------+------------+------+---------------+-------------+---------+----------------------+------+----------+-------------+
|  1 | PRIMARY            | e     | NULL       | ALL  | NULL          | NULL        | NULL    | NULL                 |   32 |   100.00 | Using where |
|  2 | DEPENDENT SUBQUERY | e2    | NULL       | ref  | fk_emp_dept   | fk_emp_dept | 5       | company_db.e.dept_id |    6 |   100.00 | NULL        |
+----+--------------------+-------+------------+------+---------------+-------------+---------+----------------------+------+----------+-------------+
2 rows in set, 2 warnings (0.000 sec)
```

```text
-- X2. Same result rewritten as a JOIN with a derived table
--------------
EXPLAIN FORMAT=TRADITIONAL
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
JOIN (SELECT dept_id, AVG(salary) AS avg_sal FROM employee GROUP BY dept_id) d
  ON d.dept_id = e.dept_id
WHERE e.salary > d.avg_sal
--------------

+----+-------------+------------+------------+-------+---------------+-------------+---------+----------------------+------+----------+--------------------------+
| id | select_type | table      | partitions | type  | possible_keys | key         | key_len | ref                  | rows | filtered | Extra                    |
+----+-------------+------------+------------+-------+---------------+-------------+---------+----------------------+------+----------+--------------------------+
|  1 | PRIMARY     | e          | NULL       | ALL   | fk_emp_dept   | NULL        | NULL    | NULL                 |   32 |   100.00 | Using where              |
|  1 | PRIMARY     | <derived2> | NULL       | ref   | <auto_key0>   | <auto_key0> | 5       | company_db.e.dept_id |    4 |    33.33 | Using where; Using index |
|  2 | DERIVED     | employee   | NULL       | index | fk_emp_dept   | fk_emp_dept | 5       | NULL                 |   32 |   100.00 | NULL                     |
+----+-------------+------------+------------+-------+---------------+-------------+---------+----------------------+------+----------+--------------------------+
3 rows in set, 1 warning (0.000 sec)
```

```text
-- X3. Tree format shows the iterator plan
--------------
EXPLAIN FORMAT=TREE
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id)
--------------

EXPLAIN plan:
-> Filter: (e.salary > (select #2))  (cost=3.45 rows=32)
    -> Table scan on e  (cost=3.45 rows=32)
    -> Select #2 (subquery in condition; dependent)
        -> Aggregate: avg(e2.salary)  (cost=2.86 rows=1)
            -> Index lookup on e2 using fk_emp_dept (dept_id = e.dept_id)  (cost=1.39 rows=6.4)
1 row in set, 1 warning (0.000 sec)

--------------
EXPLAIN FORMAT=TREE
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
JOIN (SELECT dept_id, AVG(salary) AS avg_sal FROM employee GROUP BY dept_id) d
  ON d.dept_id = e.dept_id
WHERE e.salary > d.avg_sal
--------------

EXPLAIN plan:
-> Nested loop inner join  (cost=48.2 rows=42.7)
    -> Filter: (e.dept_id is not null)  (cost=3.45 rows=32)
        -> Table scan on e  (cost=3.45 rows=32)
    -> Filter: (e.salary > d.avg_sal)  (cost=1 rows=1.33)
        -> Covering index lookup on d using <auto_key0> (dept_id = e.dept_id)  (cost=12.2..13 rows=4)
            -> Materialize  (cost=12..12 rows=5)
                -> Group aggregate: avg(employee.salary)  (cost=10.8 rows=5)
                    -> Index scan on employee using fk_emp_dept  (cost=3.45 rows=32)
1 row in set (0.000 sec)
```

```text
-- X4. Anti-join written three ways: NOT EXISTS vs NOT IN vs LEFT JOIN/IS NULL
--------------
EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id)
--------------

+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
| id | select_type  | table       | partitions | type   | possible_keys       | key                 | key_len | ref                 | rows | filtered | Extra                   |
+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
|  1 | SIMPLE       | e           | NULL       | index  | NULL                | fk_emp_dept         | 5       | NULL                |   32 |   100.00 | Using index             |
|  1 | SIMPLE       | <subquery2> | NULL       | eq_ref | <auto_distinct_key> | <auto_distinct_key> | 5       | company_db.e.emp_id |    1 |   100.00 | Using where; Not exists |
|  2 | MATERIALIZED | w           | NULL       | index  | PRIMARY             | fk_wo_proj          | 4       | NULL                |   39 |   100.00 | Using index             |
+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
3 rows in set, 2 warnings (0.000 sec)

--------------
EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
WHERE e.emp_id NOT IN (SELECT w.emp_id FROM works_on w)
--------------

+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
| id | select_type  | table       | partitions | type   | possible_keys       | key                 | key_len | ref                 | rows | filtered | Extra                   |
+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
|  1 | SIMPLE       | e           | NULL       | index  | NULL                | fk_emp_dept         | 5       | NULL                |   32 |   100.00 | Using index             |
|  1 | SIMPLE       | <subquery2> | NULL       | eq_ref | <auto_distinct_key> | <auto_distinct_key> | 5       | company_db.e.emp_id |    1 |   100.00 | Using where; Not exists |
|  2 | MATERIALIZED | w           | NULL       | index  | PRIMARY             | fk_wo_proj          | 4       | NULL                |   39 |   100.00 | Using index             |
+----+--------------+-------------+------------+--------+---------------------+---------------------+---------+---------------------+------+----------+-------------------------+
3 rows in set, 1 warning (0.000 sec)

--------------
EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
LEFT JOIN works_on w ON w.emp_id = e.emp_id
WHERE w.emp_id IS NULL
--------------

+----+-------------+-------+------------+-------+---------------+-------------+---------+---------------------+------+----------+--------------------------------------+
| id | select_type | table | partitions | type  | possible_keys | key         | key_len | ref                 | rows | filtered | Extra                                |
+----+-------------+-------+------------+-------+---------------+-------------+---------+---------------------+------+----------+--------------------------------------+
|  1 | SIMPLE      | e     | NULL       | index | NULL          | fk_emp_dept | 5       | NULL                |   32 |   100.00 | Using index                          |
|  1 | SIMPLE      | w     | NULL       | ref   | PRIMARY       | PRIMARY     | 4       | company_db.e.emp_id |    1 |   100.00 | Using where; Not exists; Using index |
+----+-------------+-------+------------+-------+---------------+-------------+---------+---------------------+------+----------+--------------------------------------+
2 rows in set, 1 warning (0.000 sec)
```

```text
-- X5. 3-way join plan, then EXPLAIN ANALYZE (actually executes, shows real row counts/time)
--------------
EXPLAIN FORMAT=TRADITIONAL
SELECT e.first_name, p.project_name
FROM employee e
JOIN works_on w ON w.emp_id = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.status = 'Active'
--------------

+----+-------------+-------+------------+--------+--------------------+------------+---------+-------------------------+------+----------+-------------+
| id | select_type | table | partitions | type   | possible_keys      | key        | key_len | ref                     | rows | filtered | Extra       |
+----+-------------+-------+------------+--------+--------------------+------------+---------+-------------------------+------+----------+-------------+
|  1 | SIMPLE      | p     | NULL       | ALL    | PRIMARY            | NULL       | NULL    | NULL                    |    8 |    33.33 | Using where |
|  1 | SIMPLE      | w     | NULL       | ref    | PRIMARY,fk_wo_proj | fk_wo_proj | 4       | company_db.p.project_id |    5 |   100.00 | Using index |
|  1 | SIMPLE      | e     | NULL       | eq_ref | PRIMARY            | PRIMARY    | 4       | company_db.w.emp_id     |    1 |   100.00 | NULL        |
+----+-------------+-------+------------+--------+--------------------+------------+---------+-------------------------+------+----------+-------------+
3 rows in set, 1 warning (0.000 sec)

--------------
EXPLAIN ANALYZE
SELECT e.first_name, p.project_name
FROM employee e
JOIN works_on w ON w.emp_id = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.status = 'Active'
--------------

EXPLAIN plan:
-> Nested loop inner join  (cost=8.41 rows=14.9) (actual time=0.00758..0.0337 rows=32 loops=1)
    -> Nested loop inner join  (cost=3.21 rows=14.9) (actual time=0.00617..0.0145 rows=32 loops=1)
        -> Filter: (p.`status` = 'Active')  (cost=1.05 rows=2.67) (actual time=0.00367..0.00529 rows=5 loops=1)
            -> Table scan on p  (cost=1.05 rows=8) (actual time=0.00304..0.00396 rows=8 loops=1)
        -> Covering index lookup on w using fk_wo_proj (project_id = p.project_id)  (cost=0.461 rows=5.57) (actual time=975e-6..0.00147 rows=6.4 loops=5)
    -> Single-row index lookup on e using PRIMARY (emp_id = w.emp_id)  (cost=0.257 rows=1) (actual time=465e-6..486e-6 rows=1 loops=32)
1 row in set (0.000 sec)
```

```text
-- X6. Effect of an index on a filter column (full table scan ALL -> index lookup ref)
--------------
EXPLAIN FORMAT=TRADITIONAL SELECT emp_id, first_name FROM employee WHERE city = 'Mumbai'
--------------

+----+-------------+----------+------------+------+---------------+------+---------+------+------+----------+-------------+
| id | select_type | table    | partitions | type | possible_keys | key  | key_len | ref  | rows | filtered | Extra       |
+----+-------------+----------+------------+------+---------------+------+---------+------+------+----------+-------------+
|  1 | SIMPLE      | employee | NULL       | ALL  | NULL          | NULL | NULL    | NULL |   32 |    10.00 | Using where |
+----+-------------+----------+------------+------+---------------+------+---------+------+------+----------+-------------+
1 row in set, 1 warning (0.000 sec)

--------------
CREATE INDEX idx_emp_city ON employee(city)
--------------

Query OK, 0 rows affected (0.018 sec)
Records: 0  Duplicates: 0  Warnings: 0

--------------
EXPLAIN FORMAT=TRADITIONAL SELECT emp_id, first_name FROM employee WHERE city = 'Mumbai'
--------------

+----+-------------+----------+------------+------+---------------+--------------+---------+-------+------+----------+-------+
| id | select_type | table    | partitions | type | possible_keys | key          | key_len | ref   | rows | filtered | Extra |
+----+-------------+----------+------------+------+---------------+--------------+---------+-------+------+----------+-------+
|  1 | SIMPLE      | employee | NULL       | ref  | idx_emp_city  | idx_emp_city | 122     | const |    5 |   100.00 | NULL  |
+----+-------------+----------+------------+------+---------------+--------------+---------+-------+------+----------+-------+
1 row in set, 1 warning (0.000 sec)

--------------
DROP INDEX idx_emp_city ON employee
--------------

Query OK, 0 rows affected (0.004 sec)
Records: 0  Duplicates: 0  Warnings: 0
```

## Observations

| Comparison | What EXPLAIN showed |
|---|---|
| Correlated subquery (X1) vs JOIN with derived table (X2) | X1 is a `DEPENDENT SUBQUERY`: an index lookup on `fk_emp_dept` repeated for every outer row. X2 computes the department averages **once** (`DERIVED`, then `<auto_key0>`) and joins to them. |
| `NOT EXISTS` vs `NOT IN` vs `LEFT JOIN ... IS NULL` (X4) | The optimizer turns all three into an **anti-join** (`Not exists`, "Nested loop antijoin"); their costs are about the same. `NOT IN` is materialized as a subquery. |
| 3-way join (X5) | The optimizer starts from the most selective table (`project` filtered on status), then uses `ref` on `fk_wo_proj` and `eq_ref` on the employee PRIMARY key. `EXPLAIN ANALYZE` confirmed 32 actual rows. |
| Filter without vs with index (X6) | `type = ALL`, 32 rows -> `type = ref` on `idx_emp_city`, 5 rows. |

* All the simulated INTERSECT queries returned the same rows as the native `INTERSECT`, and all the simulated EXCEPT queries returned the same rows as the native `EXCEPT`.
* The LEFT JOIN (J3) keeps project 108, which has 0 members. An INNER JOIN would have dropped it.

## Result

All the join types, correlated subqueries, EXISTS / NOT EXISTS, and simulated INTERSECT and EXCEPT were written and checked. The simulated INTERSECT and EXCEPT gave the same output as MySQL's own INTERSECT and EXCEPT. The execution plans were compared using EXPLAIN.

## Conclusion

The same query can be written in different ways (subquery, join, EXISTS), and EXPLAIN shows how MySQL actually runs each one. A correlated subquery runs once for each outer row, so writing it as a join or keeping an index on the column used in the condition makes it faster.
