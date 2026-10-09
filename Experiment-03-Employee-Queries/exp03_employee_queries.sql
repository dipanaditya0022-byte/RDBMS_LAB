-- Experiment 3: Employee - Department - Project queries
-- note: company_db is also used in exp 4, 5 and 6

DROP DATABASE IF EXISTS company_db;
CREATE DATABASE company_db;
USE company_db;

-- PART A : Schema

CREATE TABLE department (
    dept_id     INT PRIMARY KEY,
    dept_name   VARCHAR(40) NOT NULL UNIQUE,
    location    VARCHAR(40) NOT NULL,
    mgr_emp_id  INT NULL                 -- FK added after employee exists
);

CREATE TABLE employee (
    emp_id      INT PRIMARY KEY,
    first_name  VARCHAR(30) NOT NULL,
    last_name   VARCHAR(30) NOT NULL,
    gender      CHAR(1)     NOT NULL CHECK (gender IN ('M','F')),
    dob         DATE        NOT NULL,
    hire_date   DATE        NOT NULL,
    job_title   VARCHAR(40) NOT NULL,
    salary      DECIMAL(10,2) NOT NULL,   -- monthly salary in INR
    city        VARCHAR(30) NOT NULL,
    dept_id     INT NULL,
    manager_id  INT NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)    REFERENCES department(dept_id) ON DELETE SET NULL,
    CONSTRAINT fk_emp_mgr  FOREIGN KEY (manager_id) REFERENCES employee(emp_id)    ON DELETE SET NULL
);

CREATE TABLE project (
    project_id   INT PRIMARY KEY,
    project_name VARCHAR(50) NOT NULL UNIQUE,
    dept_id      INT NOT NULL,
    budget       DECIMAL(12,2) NOT NULL,
    start_date   DATE NOT NULL,
    end_date     DATE NULL,
    status       ENUM('Planned','Active','Completed') NOT NULL,
    CONSTRAINT fk_proj_dept FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

CREATE TABLE works_on (
    emp_id      INT NOT NULL,
    project_id  INT NOT NULL,
    role        VARCHAR(30) NOT NULL,
    hours_per_week DECIMAL(4,1) NOT NULL CHECK (hours_per_week BETWEEN 1 AND 48),
    PRIMARY KEY (emp_id, project_id),
    CONSTRAINT fk_wo_emp  FOREIGN KEY (emp_id)     REFERENCES employee(emp_id) ON DELETE CASCADE,
    CONSTRAINT fk_wo_proj FOREIGN KEY (project_id) REFERENCES project(project_id) ON DELETE CASCADE
);

-- PART B : Data (5 departments, 32 employees, 8 projects)

INSERT INTO department (dept_id, dept_name, location) VALUES
(10, 'Engineering',     'Bengaluru'),
(20, 'Sales',           'Mumbai'),
(30, 'Marketing',       'Delhi'),
(40, 'Finance',         'Pune'),
(50, 'Human Resources', 'Hyderabad');

INSERT INTO employee VALUES
( 1,'Rajesh','Sharma','M','1970-03-15','2005-06-01','Chief Executive Officer',350000,'Bengaluru',10,NULL),
-- Engineering
( 2,'Ananya','Iyer','F','1982-07-22','2010-02-15','Engineering Manager',220000,'Bengaluru',10,1),
( 3,'Vikram','Reddy','M','1986-11-05','2012-08-20','Tech Lead',160000,'Bengaluru',10,2),
( 4,'Priya','Nair','F','1990-01-18','2015-07-01','Senior Software Engineer',120000,'Bengaluru',10,3),
( 5,'Arjun','Mehta','M','1991-05-30','2016-01-11','Senior Software Engineer',115000,'Chennai',10,3),
( 6,'Sneha','Kulkarni','F','1995-09-12','2019-06-24','Software Engineer',85000,'Pune',10,3),
( 7,'Rohan','Gupta','M','1996-02-02','2020-07-15','Software Engineer',80000,'Bengaluru',10,3),
( 9,'Aditya','Joshi','M','1987-04-10','2013-03-18','Tech Lead',155000,'Bengaluru',10,2),
( 8,'Kavya','Menon','F','1997-12-25','2021-08-02','Software Engineer',78000,'Kochi',10,9),
(10,'Meera','Pillai','F','1994-06-14','2018-10-01','QA Engineer',70000,'Chennai',10,9),
(11,'Karthik','Rao','M','1992-08-08','2017-04-03','DevOps Engineer',95000,'Hyderabad',10,9),
-- Sales
(12,'Suresh','Patel','M','1978-10-19','2008-09-01','Head of Sales',200000,'Mumbai',20,1),
(13,'Neha','Agarwal','F','1985-03-03','2011-11-14','Regional Sales Manager',130000,'Mumbai',20,12),
(14,'Amit','Singh','M','1993-07-07','2018-02-05','Sales Executive',55000,'Delhi',20,13),
(15,'Pooja','Desai','F','1996-04-21','2020-01-20','Sales Executive',52000,'Ahmedabad',20,13),
(16,'Rahul','Verma','M','1997-09-17','2021-06-07','Sales Executive',50000,'Mumbai',20,13),
(17,'Divya','Bhat','F','1989-12-01','2014-05-26','Key Account Manager',90000,'Bengaluru',20,12),
(18,'Manish','Tiwari','M','1998-01-09','2022-03-14','Sales Executive',48000,'Lucknow',20,17),
-- Marketing
(19,'Ritu','Malhotra','F','1980-08-28','2009-07-13','Head of Marketing',190000,'Delhi',30,1),
(20,'Sanjay','Chopra','M','1986-05-16','2013-09-09','Brand Manager',110000,'Delhi',30,19),
(21,'Ishita','Banerjee','F','1993-02-11','2018-11-19','Content Strategist',70000,'Kolkata',30,20),
(22,'Nikhil','Saxena','M','1995-10-24','2019-04-15','SEO Analyst',60000,'Noida',30,20),
(23,'Tanvi','Shah','F','1999-03-08','2023-01-09','Social Media Executive',45000,'Mumbai',30,20),
(24,'Harsh','Vardhan','M','1994-11-30','2019-08-12','Digital Marketing Executive',52000,'Delhi',30,19),
-- Finance
(25,'Gopal','Krishnan','M','1979-06-06','2007-12-03','Chief Financial Officer',210000,'Pune',40,1),
(26,'Lakshmi','Subramanian','F','1988-09-19','2014-02-17','Senior Accountant',75000,'Pune',40,25),
(27,'Deepak','Jain','M','1990-04-04','2016-06-20','Financial Analyst',88000,'Mumbai',40,25),
(28,'Swati','Mishra','F','1997-07-27','2021-09-27','Accounts Executive',50000,'Pune',40,26),
-- Human Resources
(29,'Farah','Khan','F','1983-01-25','2010-10-04','Head of HR',170000,'Hyderabad',50,1),
(30,'Varun','Kapoor','M','1989-10-13','2015-03-02','HR Manager',95000,'Hyderabad',50,29),
(31,'Anjali','Dubey','F','1996-12-06','2020-11-16','Talent Acquisition Specialist',55000,'Bhopal',50,30),
(32,'Siddharth','Bose','M','1998-05-19','2022-07-18','HR Executive',48000,'Kolkata',50,30);

UPDATE department SET mgr_emp_id = CASE dept_id
    WHEN 10 THEN 2 WHEN 20 THEN 12 WHEN 30 THEN 19 WHEN 40 THEN 25 WHEN 50 THEN 29 END;

ALTER TABLE department
    ADD CONSTRAINT fk_dept_mgr FOREIGN KEY (mgr_emp_id) REFERENCES employee(emp_id) ON DELETE SET NULL;

INSERT INTO project VALUES
(101,'UPI Payments Gateway',     10, 8500000,'2024-04-01',NULL,        'Active'),
(102,'Mobile App Revamp',        10, 4200000,'2024-07-15',NULL,        'Active'),
(103,'Cloud Migration',          10, 6000000,'2023-10-01','2025-03-31','Completed'),
(104,'Diwali Festive Campaign',  30, 2500000,'2025-08-01','2025-11-15','Active'),
(105,'Tier-2 Dealer Expansion',  20, 3000000,'2024-01-10',NULL,        'Active'),
(106,'Payroll Automation',       40, 1800000,'2024-09-01',NULL,        'Active'),
(107,'Campus Hiring Drive 2025', 50,  900000,'2025-01-05','2025-06-30','Completed'),
(108,'AI Customer Chatbot',      10, 5500000,'2026-01-01',NULL,        'Planned');

INSERT INTO works_on VALUES
( 2,101,'Sponsor', 4),  ( 3,101,'Lead',30),     ( 4,101,'Developer',40), ( 5,101,'Developer',35),
( 6,101,'Developer',20),(11,101,'DevOps',15),   (10,101,'Tester',20),
( 9,102,'Lead',30),     ( 7,102,'Developer',40),( 8,102,'Developer',40), ( 6,102,'Developer',20),
(10,102,'Tester',20),   (20,102,'Brand Input',5),
( 3,103,'Architect',10),(11,103,'DevOps',25),   ( 5,103,'Developer',5),
(19,104,'Sponsor', 5),  (20,104,'Lead',30),     (21,104,'Content',35),   (22,104,'SEO',30),
(23,104,'Social Media',40),(24,104,'Ads',35),   (14,104,'Sales Input',8),
(12,105,'Sponsor', 6),  (13,105,'Lead',30),     (14,105,'Field Sales',32),(15,105,'Field Sales',40),
(16,105,'Field Sales',40),(18,105,'Field Sales',40),(27,105,'Finance',6),
(26,106,'Lead',25),     (27,106,'Analyst',20),  (28,106,'Data Entry',30),(11,106,'DevOps',5),
(30,106,'HR Input',6),
(29,107,'Sponsor', 4),  (30,107,'Lead',25),     (31,107,'Recruiter',40), (32,107,'Coordinator',40);
-- Project 108 is 'Planned' and has no employees yet.

SELECT (SELECT COUNT(*) FROM department) AS departments,
       (SELECT COUNT(*) FROM employee)   AS employees,
       (SELECT COUNT(*) FROM project)    AS projects,
       (SELECT COUNT(*) FROM works_on)   AS assignments;

-- PART C : Queries

-- Q1. SELECTION (sigma) : employees earning more than 1,00,000 per month
SELECT emp_id, first_name, last_name, job_title, salary
FROM employee
WHERE salary > 100000;

-- Q2. SELECTION with multiple conditions : female employees in Engineering hired after 2015
SELECT emp_id, first_name, last_name, hire_date
FROM employee
WHERE gender = 'F' AND dept_id = 10 AND hire_date > '2015-01-01';

-- Q3. SELECTION with IN, BETWEEN and LIKE
SELECT emp_id, first_name, last_name, city, salary
FROM employee
WHERE city IN ('Mumbai','Pune')
  AND salary BETWEEN 50000 AND 100000
  AND job_title LIKE '%Executive%';

-- Q4. PROJECTION (pi) : only names and job titles
SELECT first_name, last_name, job_title FROM employee LIMIT 10;

-- Q5. PROJECTION with DISTINCT : unique cities where employees live
SELECT DISTINCT city FROM employee ORDER BY city;

-- Q6. Computed columns : annual CTC and years of service
SELECT emp_id, CONCAT(first_name,' ',last_name) AS name,
       salary * 12                                   AS annual_ctc,
       TIMESTAMPDIFF(YEAR, hire_date, '2025-10-10')  AS years_of_service
FROM employee
ORDER BY years_of_service DESC
LIMIT 10;

-- Q7. AGGREGATE functions over the whole table
SELECT COUNT(*)              AS total_employees,
       SUM(salary)           AS monthly_payroll,
       ROUND(AVG(salary),2)  AS avg_salary,
       MIN(salary)           AS min_salary,
       MAX(salary)           AS max_salary
FROM employee;

-- Q8. GROUP BY : headcount and salary statistics per department
SELECT d.dept_name,
       COUNT(e.emp_id)          AS headcount,
       SUM(e.salary)            AS total_salary,
       ROUND(AVG(e.salary),0)   AS avg_salary,
       MAX(e.salary)            AS max_salary
FROM employee e
JOIN department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY total_salary DESC;

-- Q9. GROUP BY on two columns : headcount by department and gender
SELECT dept_id, gender, COUNT(*) AS headcount
FROM employee
GROUP BY dept_id, gender
ORDER BY dept_id, gender;

-- Q10. HAVING : departments whose average salary is above 1,00,000
SELECT dept_id, COUNT(*) AS headcount, ROUND(AVG(salary),0) AS avg_salary
FROM employee
GROUP BY dept_id
HAVING AVG(salary) > 100000;

-- Q11. WHERE + GROUP BY + HAVING : projects with more than 4 members
--      counting only people who spend at least 10 hours per week
SELECT p.project_name, COUNT(*) AS members, SUM(w.hours_per_week) AS total_hours
FROM works_on w
JOIN project p ON p.project_id = w.project_id
WHERE w.hours_per_week >= 10
GROUP BY p.project_name
HAVING COUNT(*) > 4
ORDER BY members DESC;

-- Q12. CASE expression : salary band of every employee
SELECT emp_id, CONCAT(first_name,' ',last_name) AS name, salary,
       CASE
           WHEN salary >= 200000 THEN 'Leadership'
           WHEN salary >= 100000 THEN 'Senior'
           WHEN salary >=  60000 THEN 'Mid-level'
           ELSE                       'Junior'
       END AS salary_band
FROM employee
ORDER BY salary DESC;

-- Q13. CASE inside an aggregate : salary band distribution per department (pivot)
SELECT d.dept_name,
       SUM(CASE WHEN e.salary >= 200000 THEN 1 ELSE 0 END)                       AS leadership,
       SUM(CASE WHEN e.salary >= 100000 AND e.salary < 200000 THEN 1 ELSE 0 END) AS senior,
       SUM(CASE WHEN e.salary >=  60000 AND e.salary < 100000 THEN 1 ELSE 0 END) AS mid_level,
       SUM(CASE WHEN e.salary <   60000 THEN 1 ELSE 0 END)                       AS junior
FROM employee e JOIN department d ON d.dept_id = e.dept_id
GROUP BY d.dept_name;

-- Q14. CASE for a proposed appraisal (different hike % per department)
SELECT emp_id, first_name, dept_id, salary AS current_salary,
       CASE dept_id
           WHEN 10 THEN ROUND(salary * 1.12, 0)
           WHEN 20 THEN ROUND(salary * 1.10, 0)
           ELSE         ROUND(salary * 1.08, 0)
       END AS proposed_salary
FROM employee
WHERE emp_id BETWEEN 2 AND 8 OR emp_id IN (13, 21, 26);

-- Q15. ORDER BY multiple columns : department ascending, salary descending
SELECT dept_id, emp_id, first_name, salary
FROM employee
ORDER BY dept_id ASC, salary DESC, first_name ASC;

-- Q16. ORDER BY with LIMIT : top 5 highest-paid employees
SELECT emp_id, first_name, last_name, job_title, salary
FROM employee
ORDER BY salary DESC
LIMIT 5;

-- Q17. ORDER BY a CASE expression : custom project status order
SELECT project_id, project_name, status, budget
FROM project
ORDER BY CASE status WHEN 'Active' THEN 1 WHEN 'Planned' THEN 2 ELSE 3 END,
         budget DESC;

-- Q18. Aggregates on project data : total budget by status
SELECT status, COUNT(*) AS projects, SUM(budget) AS total_budget
FROM project
GROUP BY status WITH ROLLUP;
