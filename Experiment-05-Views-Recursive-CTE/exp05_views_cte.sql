-- Experiment 5: views and recursive CTE
-- uses company_db (run exp 3 first)

USE company_db;

DROP VIEW IF EXISTS v_dept_salary_summary, v_employee_hierarchy,
                    v_engineering_staff, v_high_earners, v_emp_basic, v_emp_dept;

-- PART A : Creating views

-- V1. Department salary summary (aggregate view)
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
GROUP BY d.dept_id, d.dept_name, d.location;

SELECT * FROM v_dept_salary_summary ORDER BY monthly_payroll DESC;

-- V2. Employee hierarchy view (self join: employee -> manager)
CREATE VIEW v_employee_hierarchy AS
SELECT e.emp_id,
       CONCAT(e.first_name, ' ', e.last_name)  AS employee_name,
       e.job_title,
       e.dept_id,
       e.manager_id,
       CONCAT(m.first_name, ' ', m.last_name)  AS manager_name,
       m.job_title                             AS manager_title
FROM employee e
LEFT JOIN employee m ON m.emp_id = e.manager_id;

SELECT * FROM v_employee_hierarchy WHERE dept_id = 10 ORDER BY emp_id;

-- Views can be queried like tables: managers with more than 2 direct reports
SELECT manager_name, COUNT(*) AS reports
FROM v_employee_hierarchy
WHERE manager_id IS NOT NULL
GROUP BY manager_name
HAVING COUNT(*) > 2;

-- V3. Simple single-table view WITH CHECK OPTION (updatable)
CREATE VIEW v_engineering_staff AS
SELECT emp_id, first_name, last_name, gender, dob, hire_date, job_title,
       salary, city, dept_id
FROM employee
WHERE dept_id = 10
WITH CHECK OPTION;

-- V4. Simple single-table view WITHOUT check option
CREATE VIEW v_high_earners AS
SELECT emp_id, first_name, salary, dept_id
FROM employee
WHERE salary > 150000;

-- V5. Projection-only view (hides salary column)
CREATE VIEW v_emp_basic AS
SELECT emp_id, first_name, last_name, job_title, dept_id FROM employee;

-- V6. Inner-join view (employee + department)
CREATE VIEW v_emp_dept AS
SELECT e.emp_id, e.first_name, e.job_title, e.salary, d.dept_name, d.location
FROM employee e
INNER JOIN department d ON d.dept_id = e.dept_id;

-- Data dictionary: which views does MySQL consider updatable?
SELECT TABLE_NAME AS view_name, IS_UPDATABLE, CHECK_OPTION
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'company_db'
ORDER BY TABLE_NAME;

-- PART B : Testing updatability (inside a transaction, rolled back later)
START TRANSACTION;

-- T1. UPDATE through a simple view -> works, base table changes
UPDATE v_engineering_staff SET salary = salary + 5000 WHERE emp_id = 7;
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 7;

-- T2. INSERT through a view that exposes every NOT NULL column -> works
INSERT INTO v_engineering_staff
VALUES (99, 'Test', 'Intern', 'M', '2003-01-01', '2025-10-01', 'Intern', 25000, 'Bengaluru', 10);
SELECT emp_id, first_name, job_title, dept_id FROM employee WHERE emp_id = 99;

-- T2b. INSERT through a projection view that HIDES NOT NULL columns
--      (gender, dob, hire_date, salary, city have no default) -> ERROR 1423
INSERT INTO v_emp_basic (emp_id, first_name, last_name, job_title, dept_id)
VALUES (98, 'Hidden', 'Cols', 'Intern', 10);

-- T3. WITH CHECK OPTION : moving an employee out of the view's WHERE -> ERROR 1369
UPDATE v_engineering_staff SET dept_id = 20 WHERE emp_id = 7;

-- T4. WITH CHECK OPTION : inserting a row that does not satisfy dept_id = 10 -> ERROR 1369
INSERT INTO v_engineering_staff
VALUES (97, 'Out', 'Side', 'F', '2000-01-01', '2025-10-01', 'Analyst', 50000, 'Delhi', 30);

-- T5. Same update through a view WITHOUT check option -> works,
--     the row simply "disappears" from the view
SELECT * FROM v_high_earners WHERE emp_id = 3;
UPDATE v_high_earners SET salary = 140000 WHERE emp_id = 3;
SELECT * FROM v_high_earners WHERE emp_id = 3;
SELECT emp_id, salary FROM employee WHERE emp_id = 3;

-- T6. UPDATE on an aggregate view (GROUP BY) -> ERROR 1288 (not updatable)
UPDATE v_dept_salary_summary SET avg_salary = 100000 WHERE dept_id = 10;

-- T7. DELETE from an aggregate view -> ERROR 1288
DELETE FROM v_dept_salary_summary WHERE dept_id = 50;

-- T8. Join view with LEFT JOIN (v_employee_hierarchy) -> ERROR 1288 (not updatable)
UPDATE v_employee_hierarchy SET job_title = 'Senior Tech Lead' WHERE emp_id = 9;

-- T9. INNER JOIN view: updating columns of ONE base table -> works
UPDATE v_emp_dept SET job_title = 'Senior Tech Lead' WHERE emp_id = 9;
SELECT emp_id, first_name, job_title, dept_name FROM v_emp_dept WHERE emp_id = 9;

-- T10. INNER JOIN view: one UPDATE touching columns of TWO base tables -> ERROR 1393
UPDATE v_emp_dept SET salary = 160000, location = 'Mysuru' WHERE emp_id = 9;

-- T11. INNER JOIN view: DELETE is not allowed on a multi-table view -> ERROR 1395
DELETE FROM v_emp_dept WHERE emp_id = 32;

-- T12. INNER JOIN view: INSERT into columns of a single base table is allowed only
--      if that table's NOT NULL columns are covered; here they are not -> ERROR 1423
INSERT INTO v_emp_dept (emp_id, first_name, job_title, salary) VALUES (96, 'A', 'B', 1000);

ROLLBACK;

-- After ROLLBACK the base table is unchanged
SELECT emp_id, first_name, job_title, salary FROM employee WHERE emp_id IN (3, 7, 9, 99);

-- PART C : Recursive CTE - reporting chains

-- R1. Top-down: whole organisation tree starting from the CEO
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
ORDER BY reporting_path;

-- R2. Bottom-up: complete reporting chain of one employee (Kavya, emp 8) up to the CEO
WITH RECURSIVE chain AS (
    SELECT emp_id, manager_id, CONCAT(first_name,' ',last_name) AS name, job_title, 1 AS step
    FROM employee WHERE emp_id = 8
    UNION ALL
    SELECT m.emp_id, m.manager_id, CONCAT(m.first_name,' ',m.last_name), m.job_title, c.step + 1
    FROM employee m
    JOIN chain c ON m.emp_id = c.manager_id
)
SELECT step, emp_id, name, job_title FROM chain ORDER BY step;

-- R3. Chain as a single string for every Engineering employee
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
ORDER BY start_emp;

-- R4. Total team size (direct + indirect reports) and team payroll for every manager
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
ORDER BY total_team_size DESC;

-- R5. Depth of the hierarchy (number of levels)
WITH RECURSIVE lvl AS (
    SELECT emp_id, 1 AS depth FROM employee WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, l.depth + 1 FROM employee e JOIN lvl l ON e.manager_id = l.emp_id
)
SELECT depth, COUNT(*) AS employees_at_level FROM lvl GROUP BY depth ORDER BY depth;

-- R6. Saving the recursive query as a view so it can be reused
CREATE OR REPLACE VIEW v_reporting_chain AS
WITH RECURSIVE up AS (
    SELECT emp_id AS start_emp, emp_id, manager_id, CAST(first_name AS CHAR(300)) AS chain
    FROM employee
    UNION ALL
    SELECT up.start_emp, m.emp_id, m.manager_id, CONCAT(up.chain, ' -> ', m.first_name)
    FROM up JOIN employee m ON m.emp_id = up.manager_id
)
SELECT start_emp AS emp_id, chain FROM up WHERE manager_id IS NULL;

SELECT * FROM v_reporting_chain WHERE emp_id IN (18, 23, 28, 32);
