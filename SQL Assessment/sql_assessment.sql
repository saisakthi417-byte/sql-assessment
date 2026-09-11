USE sql_assessment;
-- Q1

WITH numbered AS (
    SELECT
        user_id,
        login_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS rn
    FROM UserLogins
),
grouped AS (
    SELECT
        user_id,
        login_date,
        DATE_SUB(login_date, INTERVAL rn DAY) AS grp
    FROM numbered
),
streaks AS (
    SELECT
        user_id,
        MIN(login_date) AS streak_start_date,
        MAX(login_date) AS streak_end_date,
        COUNT(*) AS streak_length
    FROM grouped
    GROUP BY user_id, grp
)
SELECT
    user_id,
    streak_start_date,
    streak_end_date,
    streak_length
FROM (
    SELECT
        user_id,
        streak_start_date,
        streak_end_date,
        streak_length,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY streak_length DESC, streak_start_date
        ) AS rnk
    FROM streaks
) AS final_result
WHERE rnk = 1
ORDER BY user_id;

-- Q2 

WITH ranked AS (
    SELECT
        emp_id,
        name,
        department,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department
            ORDER BY salary DESC
        ) AS salary_rank
    FROM Employees
)
SELECT
    department,
    salary AS third_highest_salary
FROM ranked
WHERE salary_rank = 3
ORDER BY department;

-- 03

WITH sessions AS (
    SELECT
        user_id,
        event_time,
        CASE
            WHEN LAG(event_time) OVER (
                PARTITION BY user_id
                ORDER BY event_time
            ) IS NULL
            OR TIMESTAMPDIFF(
                MINUTE,
                LAG(event_time) OVER (
                    PARTITION BY user_id
                    ORDER BY event_time
                ),
                event_time
            ) >= 30
            THEN 1
            ELSE 0
        END AS new_session
    FROM Clickstream
),
session_groups AS (
    SELECT
        user_id,
        event_time,
        SUM(new_session) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS session_id
    FROM sessions
)
SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    TIMESTAMPDIFF(
        MINUTE,
        MIN(event_time),
        MAX(event_time)
    ) AS duration_minutes
FROM session_groups
GROUP BY user_id, session_id
ORDER BY user_id, session_start;

-- Q4

SELECT
    student_id,
    COALESCE(MAX(CASE
        WHEN subject = 'Math' THEN score
    END), 0) AS Math,
    COALESCE(MAX(CASE
        WHEN subject = 'Science' THEN score
    END), 0) AS Science,
    COALESCE(MAX(CASE
        WHEN subject = 'English' THEN score
    END), 0) AS English
FROM Scores
GROUP BY student_id
ORDER BY student_id;

-- Q5

DELETE FROM Contacts
WHERE id IN (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY email
                ORDER BY created_at DESC, id DESC
            ) AS rn
        FROM Contacts
    ) AS ranked
    WHERE rn > 1
);

SELECT *
FROM Contacts
ORDER BY email, created_at;

-- Q6 

WITH running_values AS (
    SELECT
        d.sale_date AS run_date,
        d2.sales
    FROM DailySales d
    JOIN DailySales d2
        ON d2.sale_date <= d.sale_date
),
ranked AS (
    SELECT
        run_date,
        sales,
        ROW_NUMBER() OVER (
            PARTITION BY run_date
            ORDER BY sales
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY run_date
        ) AS cnt
    FROM running_values
)
SELECT
    run_date AS sale_date,
    AVG(sales) AS running_median
FROM ranked
WHERE rn IN (
    FLOOR((cnt + 1) / 2),
    FLOOR((cnt + 2) / 2)
)
GROUP BY run_date
ORDER BY run_date;

-- Q7

WITH RECURSIVE hierarchy AS (
    SELECT
        manager_id AS root_manager,
        emp_id AS report_id,
        CAST(
            CONCAT(',', manager_id, ',', emp_id, ',')
            AS CHAR(1000)
        ) AS path,
        0 AS cycle
    FROM Employees
    WHERE manager_id IS NOT NULL

    UNION ALL

    SELECT
        h.root_manager,
        e.emp_id AS report_id,
        CONCAT(h.path, e.emp_id, ',') AS path,
        CASE
            WHEN FIND_IN_SET(
                e.emp_id,
                TRIM(BOTH ',' FROM h.path)
            ) > 0 THEN 1
            ELSE 0
        END AS cycle
    FROM hierarchy h
    JOIN Employees e
        ON e.manager_id = h.report_id
    WHERE h.cycle = 0
      AND FIND_IN_SET(
          e.emp_id,
          TRIM(BOTH ',' FROM h.path)
      ) = 0
),
report_counts AS (
    SELECT
        root_manager AS emp_id,
        COUNT(DISTINCT report_id) AS total_reports
    FROM hierarchy
    GROUP BY root_manager
),
cycle_nodes AS (
    SELECT
        emp_id AS start_emp,
        manager_id AS next_manager,
        CAST(
            CONCAT(',', emp_id, ',')
            AS CHAR(1000)
        ) AS path,
        0 AS has_cycle
    FROM Employees

    UNION ALL

    SELECT
        c.start_emp,
        e.manager_id,
        CONCAT(c.path, e.emp_id, ',') AS path,
        CASE
            WHEN FIND_IN_SET(
                e.emp_id,
                TRIM(BOTH ',' FROM c.path)
            ) > 0 THEN 1
            ELSE 0
        END AS has_cycle
    FROM cycle_nodes c
    JOIN Employees e
        ON e.emp_id = c.next_manager
    WHERE c.has_cycle = 0
      AND c.next_manager IS NOT NULL
),
cycle_flags AS (
    SELECT
        start_emp AS emp_id,
        MAX(has_cycle) AS has_circular_chain
    FROM cycle_nodes
    GROUP BY start_emp
)
SELECT
    e.emp_id,
    e.name,
    COALESCE(r.total_reports, 0) AS total_reports,
    CASE
        WHEN COALESCE(c.has_circular_chain, 0) = 1
            THEN 'YES'
        ELSE 'NO'
    END AS circular_reporting_chain
FROM Employees e
LEFT JOIN report_counts r
    ON r.emp_id = e.emp_id
LEFT JOIN cycle_flags c
    ON c.emp_id = e.emp_id
ORDER BY e.emp_id;

-- Q8

SELECT
    a.account_id,
    a.txn_id AS txn_id_1,
    b.txn_id AS txn_id_2,
    a.txn_time AS txn_time_1,
    b.txn_time AS txn_time_2,
    a.amount AS amount_1,
    b.amount AS amount_2,
    ROUND(
        ABS(a.amount - b.amount)
        / NULLIF(ABS(a.amount), 0) * 100,
        4
    ) AS percent_difference
FROM Transactions a
JOIN Transactions b
    ON a.account_id = b.account_id
    AND a.txn_id < b.txn_id
    AND ABS(
        TIMESTAMPDIFF(
            SECOND,
            a.txn_time,
            b.txn_time
        )
    ) <= 60
WHERE a.amount <> 0
    AND ABS(a.amount - b.amount)
        / ABS(a.amount) < 0.01
ORDER BY
    a.account_id,
    a.txn_time,
    b.txn_time;
