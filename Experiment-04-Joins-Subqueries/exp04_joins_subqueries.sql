-- Experiment 4: joins, subqueries, intersect/except, explain
-- uses company_db (run exp 3 first)

USE company_db;

-- PART A : Joins

-- J1. INNER JOIN : every employee with department name and location
SELECT e.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee,
       d.dept_name, d.location
FROM employee e
INNER JOIN department d ON e.dept_id = d.dept_id
ORDER BY d.dept_name, e.emp_id
LIMIT 12;

-- J2. INNER JOIN with aggregation : department head and headcount
SELECT d.dept_name, CONCAT(m.first_name,' ',m.last_name) AS dept_head,
       COUNT(e.emp_id) AS headcount
FROM department d
INNER JOIN employee m ON m.emp_id  = d.mgr_emp_id
INNER JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_name, dept_head;

-- J3. LEFT JOIN : all projects with number of members (project 108 has none)
SELECT p.project_id, p.project_name, p.status, COUNT(w.emp_id) AS members
FROM project p
LEFT JOIN works_on w ON w.project_id = p.project_id
GROUP BY p.project_id, p.project_name, p.status
ORDER BY members;

-- J4. LEFT JOIN ... IS NULL : employees not assigned to any project (anti-join)
SELECT e.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee, e.job_title
FROM employee e
LEFT JOIN works_on w ON w.emp_id = e.emp_id
WHERE w.emp_id IS NULL;

-- J5. SELF JOIN : employee with his/her manager
SELECT e.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee, e.job_title,
       CONCAT(m.first_name,' ',m.last_name)              AS manager,
       m.job_title                                       AS manager_title
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.emp_id
ORDER BY e.emp_id
LIMIT 15;

-- J6. SELF JOIN : number of direct reports for every manager
SELECT m.emp_id, CONCAT(m.first_name,' ',m.last_name) AS manager,
       COUNT(e.emp_id) AS direct_reports
FROM employee m
JOIN employee e ON e.manager_id = m.emp_id
GROUP BY m.emp_id, manager
ORDER BY direct_reports DESC;

-- J7. SELF JOIN : pairs of colleagues in the same department and same city
SELECT a.first_name AS emp1, b.first_name AS emp2, a.city, a.dept_id
FROM employee a
JOIN employee b ON a.dept_id = b.dept_id AND a.city = b.city AND a.emp_id < b.emp_id
ORDER BY a.dept_id, a.city;

-- J8. 3-WAY JOIN : employee - works_on - project
SELECT CONCAT(e.first_name,' ',e.last_name) AS employee, p.project_name,
       w.role, w.hours_per_week
FROM employee e
JOIN works_on w ON w.emp_id     = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.project_id IN (101, 104)
ORDER BY p.project_name, w.hours_per_week DESC;

-- J9. 4-WAY JOIN : employees working on a project owned by ANOTHER department
SELECT CONCAT(e.first_name,' ',e.last_name) AS employee,
       ed.dept_name AS home_dept, p.project_name, pd.dept_name AS project_dept
FROM employee e
JOIN department ed ON ed.dept_id   = e.dept_id
JOIN works_on   w  ON w.emp_id     = e.emp_id
JOIN project    p  ON p.project_id = w.project_id
JOIN department pd ON pd.dept_id   = p.dept_id
WHERE e.dept_id <> p.dept_id;

-- PART B : Subqueries and EXISTS

-- S1. Non-correlated subquery : employees earning above the company average
SELECT emp_id, first_name, salary
FROM employee
WHERE salary > (SELECT AVG(salary) FROM employee)
ORDER BY salary DESC;

-- S2. CORRELATED subquery : employees earning more than their own department's average
SELECT e.emp_id, e.first_name, e.dept_id, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary)
                  FROM employee e2
                  WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC;

-- S3. CORRELATED subquery : lowest-paid employee of each department
SELECT e.dept_id, e.first_name, e.last_name, e.salary
FROM employee e
WHERE e.salary = (SELECT MIN(salary) FROM employee x WHERE x.dept_id = e.dept_id);

-- S4. Correlated subquery in SELECT list : number of projects per employee
SELECT e.emp_id, e.first_name,
       (SELECT COUNT(*) FROM works_on w WHERE w.emp_id = e.emp_id) AS project_count
FROM employee e
WHERE e.dept_id = 10;

-- S5. EXISTS : departments that own at least one Completed project
SELECT d.dept_id, d.dept_name
FROM department d
WHERE EXISTS (SELECT 1 FROM project p
              WHERE p.dept_id = d.dept_id AND p.status = 'Completed');

-- S6. NOT EXISTS : employees who are not working on any project
SELECT e.emp_id, e.first_name, e.last_name
FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id);

-- S7. EXISTS : managers who have at least one report earning > 1,00,000
SELECT m.emp_id, m.first_name, m.job_title
FROM employee m
WHERE EXISTS (SELECT 1 FROM employee e
              WHERE e.manager_id = m.emp_id AND e.salary > 100000);

-- PART C : Simulated INTERSECT and EXCEPT

-- I1. INTERSECT (simulated with IN) : employees working on BOTH project 101 AND 102
SELECT emp_id FROM works_on WHERE project_id = 101
  AND emp_id IN (SELECT emp_id FROM works_on WHERE project_id = 102);

-- I2. INTERSECT (simulated with INNER JOIN) - same result
SELECT a.emp_id, e.first_name
FROM works_on a
JOIN works_on b ON a.emp_id = b.emp_id AND b.project_id = 102
JOIN employee e ON e.emp_id = a.emp_id
WHERE a.project_id = 101;

-- I3. INTERSECT (simulated with EXISTS) : cities that have both Engineering and Sales staff
SELECT DISTINCT e.city
FROM employee e
WHERE e.dept_id = 10
  AND EXISTS (SELECT 1 FROM employee s WHERE s.dept_id = 20 AND s.city = e.city);

-- E1. EXCEPT (simulated with NOT IN) : on project 101 but NOT on project 102
SELECT emp_id FROM works_on WHERE project_id = 101
  AND emp_id NOT IN (SELECT emp_id FROM works_on WHERE project_id = 102);

-- E2. EXCEPT (simulated with LEFT JOIN ... IS NULL) - same result
SELECT a.emp_id, e.first_name
FROM works_on a
LEFT JOIN works_on b ON a.emp_id = b.emp_id AND b.project_id = 102
JOIN employee e ON e.emp_id = a.emp_id
WHERE a.project_id = 101 AND b.emp_id IS NULL;

-- E3. EXCEPT (simulated with NOT EXISTS) : cities with Engineering staff but no Sales staff
SELECT DISTINCT e.city
FROM employee e
WHERE e.dept_id = 10
  AND NOT EXISTS (SELECT 1 FROM employee s WHERE s.dept_id = 20 AND s.city = e.city);

-- V1. Verification with native set operators (available from MySQL 8.0.31)
SELECT emp_id FROM works_on WHERE project_id = 101
INTERSECT
SELECT emp_id FROM works_on WHERE project_id = 102;

SELECT emp_id FROM works_on WHERE project_id = 101
EXCEPT
SELECT emp_id FROM works_on WHERE project_id = 102;

-- PART D : Comparing execution plans with EXPLAIN

-- Refresh optimizer statistics so that row estimates are accurate
ANALYZE TABLE employee, department, project, works_on;

-- X1. Correlated subquery (S2) - traditional EXPLAIN
EXPLAIN FORMAT=TRADITIONAL
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id);

-- X2. Same result rewritten as a JOIN with a derived table
EXPLAIN FORMAT=TRADITIONAL
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
JOIN (SELECT dept_id, AVG(salary) AS avg_sal FROM employee GROUP BY dept_id) d
  ON d.dept_id = e.dept_id
WHERE e.salary > d.avg_sal;

-- X3. Tree format shows the iterator plan
EXPLAIN FORMAT=TREE
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id);

EXPLAIN FORMAT=TREE
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
JOIN (SELECT dept_id, AVG(salary) AS avg_sal FROM employee GROUP BY dept_id) d
  ON d.dept_id = e.dept_id
WHERE e.salary > d.avg_sal;

-- X4. Anti-join written three ways: NOT EXISTS vs NOT IN vs LEFT JOIN/IS NULL
EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id);

EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
WHERE e.emp_id NOT IN (SELECT w.emp_id FROM works_on w);

EXPLAIN FORMAT=TRADITIONAL SELECT e.emp_id FROM employee e
LEFT JOIN works_on w ON w.emp_id = e.emp_id
WHERE w.emp_id IS NULL;

-- X5. 3-way join plan, then EXPLAIN ANALYZE (actually executes, shows real row counts/time)
EXPLAIN FORMAT=TRADITIONAL
SELECT e.first_name, p.project_name
FROM employee e
JOIN works_on w ON w.emp_id = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.status = 'Active';

EXPLAIN ANALYZE
SELECT e.first_name, p.project_name
FROM employee e
JOIN works_on w ON w.emp_id = e.emp_id
JOIN project  p ON p.project_id = w.project_id
WHERE p.status = 'Active';

-- X6. Effect of an index on a filter column (full table scan ALL -> index lookup ref)
EXPLAIN FORMAT=TRADITIONAL SELECT emp_id, first_name FROM employee WHERE city = 'Mumbai';
CREATE INDEX idx_emp_city ON employee(city);
EXPLAIN FORMAT=TRADITIONAL SELECT emp_id, first_name FROM employee WHERE city = 'Mumbai';
DROP INDEX idx_emp_city ON employee;
