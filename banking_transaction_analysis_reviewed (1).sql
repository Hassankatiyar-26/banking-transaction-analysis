/*
PROJECT: Banking Transaction Analysis
DATABASE: PostgreSQL

SETUP:
1. Connect to PostgreSQL (for example, using pgAdmin).
2. Run this command separately if the database does not exist:
       CREATE DATABASE banking_db;
3. Connect to banking_db.
4. Run the schema, sample data, and analysis queries below.

Note: This script creates tables and inserts sample data. Run it only once in a
fresh database unless you first remove the existing tables/data.
*/

-- =========================================================
-- 1. TABLES
-- =========================================================

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    gender VARCHAR(10),
    city VARCHAR(50),
    account_open_date DATE
);

CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    account_type VARCHAR(30) NOT NULL,
    branch_name VARCHAR(100) NOT NULL,
    opening_balance NUMERIC(12,2) NOT NULL CHECK (opening_balance >= 0)
);

CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY,
    account_id INT NOT NULL REFERENCES accounts(account_id),
    transaction_date TIMESTAMP NOT NULL,
    transaction_type VARCHAR(20) NOT NULL
        CHECK (transaction_type IN ('Deposit', 'Withdrawal')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0)
);

-- =========================================================
-- 2. SAMPLE DATA
-- =========================================================

INSERT INTO customers
    (customer_id, customer_name, gender, city, account_open_date)
VALUES
    (1, 'Rahul Sharma', 'Male', 'Mumbai', '2023-01-10'),
    (2, 'Priya Verma', 'Female', 'Delhi', '2023-02-18'),
    (3, 'Amit Patel', 'Male', 'Pune', '2023-04-12'),
    (4, 'Sneha Joshi', 'Female', 'Bangalore', '2023-05-22'),
    (5, 'Rohan Gupta', 'Male', 'Hyderabad', '2023-08-01');

INSERT INTO accounts
    (account_id, customer_id, account_type, branch_name, opening_balance)
VALUES
    (101, 1, 'Savings', 'Mumbai', 50000),
    (102, 2, 'Savings', 'Delhi', 35000),
    (103, 3, 'Current', 'Pune', 100000),
    (104, 4, 'Savings', 'Bangalore', 45000),
    (105, 5, 'Current', 'Hyderabad', 75000);

INSERT INTO transactions
    (transaction_id, account_id, transaction_date, transaction_type, amount)
VALUES
    (1001, 101, '2025-01-05 10:15:00', 'Deposit', 15000),
    (1002, 101, '2025-01-06 12:30:00', 'Withdrawal', 5000),
    (1003, 102, '2025-01-07 14:20:00', 'Deposit', 25000),
    (1004, 103, '2025-01-08 16:10:00', 'Withdrawal', 30000),
    (1005, 104, '2025-01-09 09:45:00', 'Deposit', 12000),
    (1006, 105, '2025-01-10 11:00:00', 'Withdrawal', 10000);

-- =========================================================
-- 3. EXPLORATORY QUERIES
-- =========================================================

-- 00. Preview tables
SELECT * FROM customers ORDER BY customer_id;
SELECT * FROM accounts ORDER BY account_id;
SELECT * FROM transactions ORDER BY transaction_id;

-- 01. Total transaction amount (deposits + withdrawals)
SELECT SUM(amount) AS total_transaction_amount
FROM transactions;

-- 02. Total deposits
SELECT COALESCE(SUM(amount), 0) AS total_deposit_amount
FROM transactions
WHERE transaction_type = 'Deposit';

-- 03. Total withdrawals
SELECT COALESCE(SUM(amount), 0) AS total_withdrawal_amount
FROM transactions
WHERE transaction_type = 'Withdrawal';

-- 04. Net cash flow (deposits minus withdrawals)
SELECT COALESCE(
    SUM(CASE
        WHEN transaction_type = 'Deposit' THEN amount
        WHEN transaction_type = 'Withdrawal' THEN -amount
        ELSE 0
    END), 0
) AS net_cash_flow
FROM transactions;

-- 05. Current balance for every account, including accounts with no transactions
SELECT
    A.account_id,
    A.opening_balance
      + COALESCE(SUM(CASE
            WHEN T.transaction_type = 'Deposit' THEN T.amount
            WHEN T.transaction_type = 'Withdrawal' THEN -T.amount
            ELSE 0
        END), 0) AS current_balance
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.account_id, A.opening_balance
ORDER BY A.account_id;

-- 06. Branch-wise transaction amount
SELECT
    A.branch_name,
    COALESCE(SUM(T.amount), 0) AS total_transaction_amount
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.branch_name
ORDER BY total_transaction_amount DESC, A.branch_name;

-- 07. Transaction amount by account type
SELECT
    A.account_type,
    COALESCE(SUM(T.amount), 0) AS total_transaction_amount
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.account_type
ORDER BY total_transaction_amount DESC, A.account_type;

-- 08. Customers ranked by gross transaction value
SELECT
    C.customer_id,
    C.customer_name,
    COALESCE(SUM(T.amount), 0) AS transaction_value
FROM customers C
LEFT JOIN accounts A ON A.customer_id = C.customer_id
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY C.customer_id, C.customer_name
ORDER BY transaction_value DESC, C.customer_id;

-- 09. High-value customers: gross transaction value greater than 20,000
SELECT
    C.customer_id,
    C.customer_name,
    SUM(T.amount) AS transaction_value
FROM customers C
JOIN accounts A ON A.customer_id = C.customer_id
JOIN transactions T ON T.account_id = A.account_id
GROUP BY C.customer_id, C.customer_name
HAVING SUM(T.amount) > 20000
ORDER BY transaction_value DESC;

-- 10. Daily transaction volume
SELECT
    transaction_date::date AS transaction_day,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY transaction_date::date
ORDER BY transaction_day;

-- 11. Monthly transaction trend
SELECT
    DATE_TRUNC('month', transaction_date)::date AS transaction_month,
    SUM(amount) AS monthly_transaction_amount
FROM transactions
GROUP BY DATE_TRUNC('month', transaction_date)
ORDER BY transaction_month;

-- 12. Rank customers by gross transaction value
SELECT
    C.customer_id,
    C.customer_name,
    SUM(T.amount) AS transaction_amount,
    RANK() OVER (ORDER BY SUM(T.amount) DESC) AS customer_rank
FROM customers C
JOIN accounts A ON A.customer_id = C.customer_id
JOIN transactions T ON T.account_id = A.account_id
GROUP BY C.customer_id, C.customer_name
ORDER BY customer_rank, C.customer_id;

-- 13. Peak transaction hours
SELECT
    EXTRACT(HOUR FROM transaction_date)::int AS transaction_hour,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY EXTRACT(HOUR FROM transaction_date)
ORDER BY transaction_count DESC, transaction_hour;

-- 14. Most active customers by transaction count
SELECT
    C.customer_id,
    C.customer_name,
    COUNT(T.transaction_id) AS transaction_count
FROM customers C
LEFT JOIN accounts A ON A.customer_id = C.customer_id
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY C.customer_id, C.customer_name
ORDER BY transaction_count DESC, C.customer_id;

-- 15. Dormant accounts (accounts with no transactions)
SELECT
    A.account_id,
    COUNT(T.transaction_id) AS transaction_count
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.account_id
HAVING COUNT(T.transaction_id) = 0
ORDER BY A.account_id;

-- 16. Deposit vs. withdrawal totals per account
SELECT
    A.account_id,
    COALESCE(SUM(T.amount) FILTER (WHERE T.transaction_type = 'Deposit'), 0)
        AS deposit_amount,
    COALESCE(SUM(T.amount) FILTER (WHERE T.transaction_type = 'Withdrawal'), 0)
        AS withdrawal_amount
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.account_id
ORDER BY A.account_id;

-- 17. Customer growth by month (chronological order)
SELECT
    DATE_TRUNC('month', account_open_date)::date AS opening_month,
    COUNT(*) AS new_customers
FROM customers
WHERE account_open_date IS NOT NULL
GROUP BY DATE_TRUNC('month', account_open_date)
ORDER BY opening_month;

-- 18. Average opening balance by branch
SELECT
    branch_name,
    ROUND(AVG(opening_balance), 2) AS average_opening_balance
FROM accounts
GROUP BY branch_name
ORDER BY average_opening_balance DESC, branch_name;

-- 19. Deposit-to-withdrawal ratio
WITH cash_totals AS (
    SELECT
        COALESCE(SUM(amount) FILTER (WHERE transaction_type = 'Deposit'), 0)
            AS deposit_amount,
        COALESCE(SUM(amount) FILTER (WHERE transaction_type = 'Withdrawal'), 0)
            AS withdrawal_amount
    FROM transactions
)
SELECT
    deposit_amount,
    withdrawal_amount,
    ROUND(deposit_amount / NULLIF(withdrawal_amount, 0), 2) AS deposit_withdrawal_ratio
FROM cash_totals;

-- 20. High-value transaction alerts (not proof of fraud)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_type,
    amount,
    CASE
        WHEN amount > 10000 THEN 'High-Value Alert'
        ELSE 'Normal'
    END AS transaction_alert
FROM transactions
ORDER BY transaction_date, transaction_id;

-- 21. Transactions greater than that customer's average transaction amount
SELECT
    C.customer_id,
    C.customer_name,
    T.transaction_id,
    T.amount
FROM customers C
JOIN accounts A ON A.customer_id = C.customer_id
JOIN transactions T ON T.account_id = A.account_id
WHERE T.amount > (
    SELECT AVG(T2.amount)
    FROM accounts A2
    JOIN transactions T2 ON T2.account_id = A2.account_id
    WHERE A2.customer_id = C.customer_id
)
ORDER BY C.customer_id, T.amount DESC;

-- 22. Running total of transaction amounts
SELECT
    transaction_id,
    transaction_date,
    amount,
    SUM(amount) OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_transaction_total
FROM transactions
ORDER BY transaction_date, transaction_id;

-- 23. Compare daily transaction totals with the previous available transaction day
WITH daily_transactions AS (
    SELECT
        transaction_date::date AS transaction_day,
        SUM(amount) AS daily_transaction_amount
    FROM transactions
    GROUP BY transaction_date::date
)
SELECT
    transaction_day,
    daily_transaction_amount,
    LAG(daily_transaction_amount) OVER (ORDER BY transaction_day)
        AS previous_available_day_amount,
    daily_transaction_amount
      - LAG(daily_transaction_amount) OVER (ORDER BY transaction_day)
        AS change_from_previous_available_day
FROM daily_transactions
ORDER BY transaction_day;

-- 24. Customers with no transactions (including customers with no accounts)
SELECT
    C.customer_id,
    C.customer_name
FROM customers C
LEFT JOIN accounts A ON A.customer_id = C.customer_id
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY C.customer_id, C.customer_name
HAVING COUNT(T.transaction_id) = 0
ORDER BY C.customer_id;

-- 25. Highest transaction amount per account
SELECT
    A.account_id,
    MAX(T.amount) AS highest_transaction_amount
FROM accounts A
LEFT JOIN transactions T ON T.account_id = A.account_id
GROUP BY A.account_id
ORDER BY highest_transaction_amount DESC NULLS LAST, A.account_id;

-- 26. Rank accounts by current balance
WITH account_balances AS (
    SELECT
        A.account_id,
        A.opening_balance
          + COALESCE(SUM(CASE
                WHEN T.transaction_type = 'Deposit' THEN T.amount
                WHEN T.transaction_type = 'Withdrawal' THEN -T.amount
                ELSE 0
            END), 0) AS current_balance
    FROM accounts A
    LEFT JOIN transactions T ON T.account_id = A.account_id
    GROUP BY A.account_id, A.opening_balance
)
SELECT
    account_id,
    current_balance,
    RANK() OVER (ORDER BY current_balance DESC) AS balance_rank
FROM account_balances
ORDER BY balance_rank, account_id;
