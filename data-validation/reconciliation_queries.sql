-- ============================================
-- Data Validation & Reconciliation Queries
-- Author: Sadhana S Kumar
-- Tools: Azure SQL, T-SQL
-- Description: Reconciling SQL results with DAX
--              measures to ensure data accuracy
-- ============================================


-- 1. Revenue Reconciliation — SQL vs Power BI DAX
-- Run this to verify Power BI numbers match SQL source
SELECT
    client_name,
    YEAR(transaction_date)   AS year,
    MONTH(transaction_date)  AS month,
    SUM(revenue)             AS sql_total_revenue,
    -- Compare this output with DAX measure in Power BI
    -- DAX: Total Revenue = SUMX(fact_transactions, [revenue])
    COUNT(DISTINCT order_id) AS total_orders,
    AVG(revenue)             AS avg_order_value
FROM
    fact_transactions
WHERE
    status = 'completed'
GROUP BY
    client_name,
    YEAR(transaction_date),
    MONTH(transaction_date)
ORDER BY
    client_name, year, month;


-- 2. Null & Missing Data Check
-- Identify records with missing critical fields
SELECT
    'fact_transactions'     AS table_name,
    COUNT(*)                AS total_records,
    SUM(CASE WHEN client_name IS NULL
             THEN 1 ELSE 0 END) AS missing_client,
    SUM(CASE WHEN revenue IS NULL
             THEN 1 ELSE 0 END) AS missing_revenue,
    SUM(CASE WHEN transaction_date IS NULL
             THEN 1 ELSE 0 END) AS missing_date,
    ROUND(
        SUM(CASE WHEN client_name IS NULL
                 OR revenue IS NULL
                 OR transaction_date IS NULL
                 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0),
    2)                      AS data_quality_issue_pct
FROM
    fact_transactions;


-- 3. Duplicate Records Check
-- Find duplicate entries that can skew KPIs
SELECT
    order_id,
    client_name,
    transaction_date,
    revenue,
    COUNT(*)  AS duplicate_count
FROM
    fact_transactions
GROUP BY
    order_id,
    client_name,
    transaction_date,
    revenue
HAVING
    COUNT(*) > 1
ORDER BY
    duplicate_count DESC;


-- 4. Data Freshness Check
-- Ensure pipelines are loading data on time
SELECT
    table_name,
    MAX(load_date)           AS last_loaded,
    DATEDIFF(
        HOUR,
        MAX(load_date),
        GETDATE()
    )                        AS hours_since_last_load,
    CASE
        WHEN DATEDIFF(HOUR, MAX(load_date), GETDATE()) > 24
        THEN '⚠️ STALE DATA - Check Pipeline!'
        ELSE '✅ Data is Fresh'
    END                      AS data_status
FROM
    etl_audit_log
GROUP BY
    table_name
ORDER BY
    hours_since_last_load DESC;
