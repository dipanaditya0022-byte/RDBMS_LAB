-- Experiment 6: stored procedure and triggers
-- uses company_db (run exp 3 first, it also resets the data)

USE company_db;

-- PART A : Log / audit tables
DROP TABLE IF EXISTS transfer_log;
DROP TABLE IF EXISTS employee_audit;

CREATE TABLE transfer_log (
    log_id        INT AUTO_INCREMENT PRIMARY KEY,
    emp_id        INT NOT NULL,
    old_dept_id   INT,
    new_dept_id   INT NOT NULL,
    old_manager   INT,
    new_manager   INT,
    projects_released INT NOT NULL DEFAULT 0,
    transferred_by VARCHAR(80) NOT NULL,
    transferred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE employee_audit (
    audit_id    INT AUTO_INCREMENT PRIMARY KEY,
    emp_id      INT NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    column_name VARCHAR(30),
    old_value   VARCHAR(100),
    new_value   VARCHAR(100),
    changed_by  VARCHAR(80) NOT NULL,
    changed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- PART B : Stored procedure transfer_employee(emp_id, new_dept_id)
DROP PROCEDURE IF EXISTS transfer_employee;

DELIMITER $$
CREATE PROCEDURE transfer_employee(IN p_emp_id INT, IN p_new_dept_id INT)
BEGIN
    DECLARE v_old_dept    INT;
    DECLARE v_old_manager INT;
    DECLARE v_new_manager INT;
    DECLARE v_reports     INT;
    DECLARE v_released    INT DEFAULT 0;
    DECLARE v_count       INT;

    -- if any error comes, rollback and show the error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Parameter validation
    IF p_emp_id IS NULL OR p_new_dept_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: emp_id and new_dept_id must not be NULL';
    END IF;

    -- 2. Employee must exist
    SELECT COUNT(*) INTO v_count FROM employee WHERE emp_id = p_emp_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: employee does not exist';
    END IF;

    -- 3. Target department must exist
    SELECT COUNT(*) INTO v_count FROM department WHERE dept_id = p_new_dept_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: target department does not exist';
    END IF;

    SELECT dept_id, manager_id INTO v_old_dept, v_old_manager
    FROM employee WHERE emp_id = p_emp_id;

    -- 4. Must actually be a change of department
    IF v_old_dept = p_new_dept_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: employee is already in that department';
    END IF;

    -- 5. A department head cannot be transferred (department would be headless)
    SELECT COUNT(*) INTO v_count FROM department WHERE mgr_emp_id = p_emp_id;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: employee heads a department; appoint a new head first';
    END IF;

    -- 6. Employees who still have direct reports cannot be moved
    SELECT COUNT(*) INTO v_reports FROM employee WHERE manager_id = p_emp_id;
    IF v_reports > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'transfer_employee: employee has direct reports; reassign them first';
    END IF;

    SELECT mgr_emp_id INTO v_new_manager FROM department WHERE dept_id = p_new_dept_id;

    -- all checks ok, now do the transfer
    START TRANSACTION;

        -- release the employee from projects owned by the old department
        DELETE w FROM works_on w
        JOIN project p ON p.project_id = w.project_id
        WHERE w.emp_id = p_emp_id AND p.dept_id = v_old_dept;
        SET v_released = ROW_COUNT();

        UPDATE employee
        SET dept_id    = p_new_dept_id,
            manager_id = v_new_manager          -- reports to the new department head
        WHERE emp_id = p_emp_id;

        INSERT INTO transfer_log (emp_id, old_dept_id, new_dept_id, old_manager,
                                  new_manager, projects_released, transferred_by)
        VALUES (p_emp_id, v_old_dept, p_new_dept_id, v_old_manager,
                v_new_manager, v_released, CURRENT_USER());

    COMMIT;

    SELECT CONCAT('Employee ', p_emp_id, ' transferred from dept ', v_old_dept,
                  ' to dept ', p_new_dept_id, ' (', v_released,
                  ' project assignment(s) released)') AS result;
END$$
DELIMITER ;

-- PART C : Triggers - salary validation and audit logging
DROP TRIGGER IF EXISTS trg_emp_before_insert;
DROP TRIGGER IF EXISTS trg_emp_before_update;
DROP TRIGGER IF EXISTS trg_emp_after_insert;
DROP TRIGGER IF EXISTS trg_emp_after_update;
DROP TRIGGER IF EXISTS trg_emp_after_delete;

DELIMITER $$

-- Salary rules on INSERT: 15,000 <= salary <= 5,00,000
CREATE TRIGGER trg_emp_before_insert
BEFORE INSERT ON employee
FOR EACH ROW
BEGIN
    IF NEW.salary IS NULL OR NEW.salary < 15000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary validation: salary must be at least 15000 (minimum wage)';
    ELSEIF NEW.salary > 500000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary validation: salary cannot exceed 500000';
    END IF;
END$$

-- Salary rules on UPDATE: same range, no pay cut, max 30% hike at once
CREATE TRIGGER trg_emp_before_update
BEFORE UPDATE ON employee
FOR EACH ROW
BEGIN
    IF NEW.salary <> OLD.salary THEN
        IF NEW.salary < 15000 OR NEW.salary > 500000 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Salary validation: salary must be between 15000 and 500000';
        ELSEIF NEW.salary < OLD.salary THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Salary validation: salary reduction is not allowed';
        ELSEIF NEW.salary > OLD.salary * 1.30 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Salary validation: hike above 30% needs board approval';
        END IF;
    END IF;
END$$

-- Audit: new employee
CREATE TRIGGER trg_emp_after_insert
AFTER INSERT ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_audit (emp_id, action, column_name, old_value, new_value, changed_by)
    VALUES (NEW.emp_id, 'INSERT', 'salary', NULL, NEW.salary, CURRENT_USER());
END$$

-- Audit: salary / department / manager changes
CREATE TRIGGER trg_emp_after_update
AFTER UPDATE ON employee
FOR EACH ROW
BEGIN
    IF NOT (NEW.salary <=> OLD.salary) THEN
        INSERT INTO employee_audit (emp_id, action, column_name, old_value, new_value, changed_by)
        VALUES (NEW.emp_id, 'UPDATE', 'salary', OLD.salary, NEW.salary, CURRENT_USER());
    END IF;
    IF NOT (NEW.dept_id <=> OLD.dept_id) THEN
        INSERT INTO employee_audit (emp_id, action, column_name, old_value, new_value, changed_by)
        VALUES (NEW.emp_id, 'UPDATE', 'dept_id', OLD.dept_id, NEW.dept_id, CURRENT_USER());
    END IF;
    IF NOT (NEW.manager_id <=> OLD.manager_id) THEN
        INSERT INTO employee_audit (emp_id, action, column_name, old_value, new_value, changed_by)
        VALUES (NEW.emp_id, 'UPDATE', 'manager_id', OLD.manager_id, NEW.manager_id, CURRENT_USER());
    END IF;
END$$

-- Audit: employee removed
CREATE TRIGGER trg_emp_after_delete
AFTER DELETE ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_audit (emp_id, action, column_name, old_value, new_value, changed_by)
    VALUES (OLD.emp_id, 'DELETE', NULL,
            CONCAT(OLD.first_name, ' ', OLD.last_name, ' / ', OLD.job_title), NULL, CURRENT_USER());
END$$

DELIMITER ;

-- Triggers and procedures stored in the data dictionary
SELECT TRIGGER_NAME, ACTION_TIMING, EVENT_MANIPULATION, EVENT_OBJECT_TABLE
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'company_db'
ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING DESC, EVENT_MANIPULATION;

SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'company_db';

-- PART D : Testing the procedure (valid case + edge cases)

-- P1. Valid transfer: Nikhil (22, Marketing SEO Analyst) -> Sales (20)
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 22;
SELECT * FROM works_on WHERE emp_id = 22;
CALL transfer_employee(22, 20);
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 22;
SELECT * FROM works_on WHERE emp_id = 22;

-- P2. Edge case: employee does not exist
CALL transfer_employee(999, 20);

-- P3. Edge case: department does not exist
CALL transfer_employee(10, 60);

-- P4. Edge case: already in the target department
CALL transfer_employee(10, 10);

-- P5. Edge case: NULL arguments
CALL transfer_employee(NULL, 20);
CALL transfer_employee(10, NULL);

-- P6. Edge case: employee is a department head (Suresh, Head of Sales)
CALL transfer_employee(12, 30);

-- P7. Edge case: employee has direct reports (Vikram, Tech Lead)
CALL transfer_employee(3, 40);

-- P8. Failed calls changed nothing: only ONE row in transfer_log
SELECT * FROM transfer_log;

-- P9. Another valid transfer: Meera (10, QA, Engineering) -> Finance (40)
CALL transfer_employee(10, 40);

-- PART E : Testing the triggers

-- T1. Valid hike of 10% for Sneha (emp 6)
UPDATE employee SET salary = salary * 1.10 WHERE emp_id = 6;
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 6;

-- T2. Hike above 30% -> rejected by BEFORE UPDATE trigger
UPDATE employee SET salary = salary * 1.50 WHERE emp_id = 7;

-- T3. Salary cut -> rejected
UPDATE employee SET salary = 70000 WHERE emp_id = 7;

-- T4. Salary above the ceiling -> rejected
UPDATE employee SET salary = 600000 WHERE emp_id = 1;

-- T5. INSERT with salary below minimum -> rejected by BEFORE INSERT trigger
INSERT INTO employee VALUES
(40,'Low','Pay','M','2002-02-02','2025-10-01','Intern',5000,'Pune',40,25);

-- T6. INSERT with negative salary -> rejected
INSERT INTO employee VALUES
(41,'Neg','Pay','F','2002-02-02','2025-10-01','Intern',-100,'Pune',40,25);

-- T7. Valid INSERT -> audit row with action INSERT
INSERT INTO employee VALUES
(33,'Yash','Thakur','M','2001-03-14','2025-10-01','Graduate Engineer Trainee',30000,'Pune',10,3);

-- T8. Bulk raise (5%) for HR -> one audit row per employee
UPDATE employee SET salary = salary * 1.05 WHERE dept_id = 50;

-- T9. Statement atomicity: 40% raise for Finance fails on the first row,
--     so no salary of Finance is changed
SELECT emp_id, salary FROM employee WHERE dept_id = 40;
UPDATE employee SET salary = salary * 1.40 WHERE dept_id = 40;
SELECT emp_id, salary FROM employee WHERE dept_id = 40;

-- T10. Updating a non-salary column does not fire salary validation and
--      is not written to the audit log (only salary/dept/manager are audited)
UPDATE employee SET city = 'Gurugram' WHERE emp_id = 14;

-- T11. DELETE -> audit row with action DELETE
DELETE FROM employee WHERE emp_id = 33;

-- Final audit trail
SELECT audit_id, emp_id, action, column_name, old_value, new_value, changed_by
FROM employee_audit ORDER BY audit_id;

SELECT log_id, emp_id, old_dept_id, new_dept_id, old_manager, new_manager,
       projects_released, transferred_by
FROM transfer_log;
