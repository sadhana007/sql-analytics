-- ============================================
-- Business Performance KPI Tracking
-- Author: Sadhana S Kumar
-- Tools: Azure SQL, T-SQL
-- Description: KPI tracking queries for enterprise
--              clients - Walmart, Amazon, Home Depot
-- ============================================

-- 1. Monthly Revenue Growth Rate
SELECT
    client_name,
    YEAR(transaction_date)        AS year,
    MONTH(transaction_date)       AS month,
    SUM(revenue)                  AS total_revenue,
    LAG(SUM(revenue)) OVER (
        PARTITION BY client_name
        ORDER BY YEAR(transaction_date),
                 MONTH(transaction_date)
    )                             AS prev_month_revenue,
    ROUND(
        (SUM(revenue) - LAG(SUM(revenue)) OVER (
            PARTITION BY client_name
            ORDER BY YEAR(transaction_date),
                     MONTH(transaction_date)
        )) * 100.0
        / NULLIF(LAG(SUM(revenue)) OVER (
            PARTITION BY client_name
            ORDER BY YEAR(transaction_date),
                     MONTH(transaction_date)
        ), 0),
    2)                            AS revenue_growth_pct
FROM
    fact_transactions
WHERE
    client_name IN ('Walmart', 'Amazon', 'Home Depot')
GROUP BY
    client_name,
    YEAR(transaction_date),
    MONTH(transaction_date)
ORDER BY
    client_name,
    year,
    month;


-- 2. Product Adoption Rate by Client
SELECT
    client_name,
    product_name,
    COUNT(DISTINCT user_id)            AS active_users,
    COUNT(DISTINCT total_users.user_id) AS total_users,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0
        / NULLIF(COUNT(DISTINCT total_users.user_id), 0),
    2)                                 AS adoption_rate_pct
FROM
    fact_product_usage
JOIN
    dim_users total_users USING (client_id)
WHERE
    usage_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY
    client_name,
    product_name
ORDER BY
    adoption_rate_pct DESC;


-- 3. Operational Efficiency KPI
SELECT
    client_name,
    COUNT(order_id)               AS total_orders,
    AVG(processing_time_minutes)  AS avg_processing_time,
    SUM(CASE WHEN status = 'completed'
             THEN 1 ELSE 0 END)   AS completed_orders,
    ROUND(
        SUM(CASE WHEN status = 'completed'
                 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(order_id), 0),
    2)                            AS completion_rate_pct
FROM
    fact_orders
GROUP BY
    client_name
ORDER BY
    completion_rate_pct DESC;
