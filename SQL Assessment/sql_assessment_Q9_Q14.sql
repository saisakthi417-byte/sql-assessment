USE sql_assessment;

-- Q9

WITH ranked AS (
     SELECT
        department,
        salary,
        ROW_NUMBER() OVER (
            PARTITION BY department
            ORDER BY salary
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY department
        ) AS cnt
    FROM Employees
)
SELECT
    department,
    AVG(salary) AS median_salary
FROM ranked
WHERE rn IN (
    FLOOR((cnt + 1) / 2),
    FLOOR((cnt + 2) / 2)
)
GROUP BY department
ORDER BY department;



-- Q10 
SELECT
    name,
    salary,
    ROUND(
        salary / SUM(salary) OVER () * 100,
        2
    ) AS salary_percentage,
    SUM(salary) OVER (
        ORDER BY salary DESC, emp_id
        ROWS UNBOUNDED PRECEDING
    ) AS running_total
FROM Employees
WHERE department = 'Sales'
ORDER BY salary DESC, emp_id;



-- Q11 


WITH department_avg AS (
    SELECT
        department,
        name,
        salary,
        AVG(salary) OVER (
            PARTITION BY department
        ) AS avg_salary
    FROM Employees
)
SELECT
    department,
    name,
    salary
FROM department_avg
WHERE salary > avg_salary
ORDER BY department, salary DESC;


-- Q12

SELECT
    user_id,
    MIN(login_date) AS first_login_date,
    MAX(login_date) AS last_login_date,
    DATEDIFF(
        MAX(login_date),
        MIN(login_date)
    ) AS calendar_days_between,
    COUNT(DISTINCT login_date) AS active_days
FROM UserLogins
GROUP BY user_id
ORDER BY user_id;



-- Q13 
WITH login_history AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS previous_login
    FROM UserLogins
)
SELECT
    user_id,
    previous_login AS date_before_gap,
    login_date AS date_after_gap,
    DATEDIFF(
        login_date,
        previous_login
    ) - 1 AS days_missed
FROM login_history
WHERE DATEDIFF(
    login_date,
    previous_login
) > 1
ORDER BY user_id, login_date;

-- Q14 


SELECT
    MAX(salary) AS second_highest_salary
FROM Employees
WHERE salary < (
    SELECT MAX(salary)
    FROM Employees
);