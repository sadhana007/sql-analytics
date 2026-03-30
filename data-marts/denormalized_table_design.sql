-- ============================================
-- Denormalized Table & Data Mart Design
-- Author: Sadhana S Kumar
-- Tools: Azure SQL, Azure Data Factory
-- Description: Building denormalized tables and
--              data marts for fast BI reporting
-- ============================================


-- 1. Create Denormalized Business Performance Table
-- Flattens multiple tables into one for Power BI speed
CREATE TABLE mart_business_performance (
    record_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Client Details
    client_id          INT,
    client_name        VARCHAR(100),
    client_segment     VARCHAR(50),   -- Enterprise, SMB
    client_region      VARCHAR(50),
    -- Product Details
    product_id         INT,
    product_name       VARCHAR(100),
    product_category   VARCHAR(50),
    -- Transaction Details
    order_id           VARCHAR(50),
    transaction_date   DATE,
    year               INT,
    month              INT,
    quarter            VARCHAR(10),
    -- Financial KPIs
    revenue            DECIMAL(18,2),
    cost               DECIMAL(18,2),
    profit             DECIMAL(18,2),
    profit_margin_pct  DECIMAL(5,2),
    -- Operational KPIs
    processing_time    INT,           -- in minutes
    status             VARCHAR(20),
    is_completed       BIT,
    -- Audit
    created_at         DATETIME DEFAULT GETDATE(),
    updated_at         DATETIME DEFAULT GETDATE()
);


-- 2. Populate the Data Mart
-- Load denormalized data from source tables
INSERT INTO mart_business_performance (
    client_id, client_name, client_segment, client_region,
    product_id, product_name, product_category,
    order_id, transaction_date, year, month, quarter,
    revenue, cost, profit, profit_margin_pct,
    processing_time, status, is_completed
)
SELECT
    c.client_id,
    c.client_name,
    c.segment                              AS client_segment,
    c.region                               AS client_region,
    p.product_id,
    p.product_name,
    p.category                             AS product_category,
    t.order_id,
    t.transaction_date,
    YEAR(t.transaction_date)               AS year,
    MONTH(t.transaction_date)              AS month,
    'Q' + CAST(DATEPART(Q,
        t.transaction_date) AS VARCHAR)    AS quarter,
    t.revenue,
    t.cost,
    (t.revenue - t.cost)                  AS profit,
    ROUND(
        (t.revenue - t.cost) * 100.0
        / NULLIF(t.revenue, 0),
    2)                                     AS profit_margin_pct,
    t.processing_time,
    t.status,
    CASE WHEN t.status = 'completed'
         THEN 1 ELSE 0 END                AS is_completed
FROM
    fact_transactions t
JOIN dim_clients  c ON t.client_id  = c.client_id
JOIN dim_products p ON t.product_id = p.product_id;


-- 3. Create Index for Fast Power BI Queries
CREATE NONCLUSTERED INDEX idx_client_date
ON mart_business_performance (client_name, transaction_date)
INCLUDE (revenue, profit, status);

CREATE NONCLUSTERED INDEX idx_product_quarter
ON mart_business_performance (product_name, quarter)
INCLUDE (revenue, profit_margin_pct);


-- 4. Refresh Procedure — Run via Azure Data Factory
CREATE PROCEDURE usp_refresh_business_mart
AS
BEGIN
    -- Clear existing data
    TRUNCATE TABLE mart_business_performance;

    -- Reload fresh data
    INSERT INTO mart_business_performance (
        client_id, client_name, client_segment, client_region,
        product_id, product_name, product_category,
        order_id, transaction_date, year, month, quarter,
        revenue, cost, profit, profit_margin_pct,
        processing_time, status, is_completed
    )
    SELECT
        c.client_id, c.client_name, c.segment, c.region,
        p.product_id, p.product_name, p.category,
        t.order_id, t.transaction_date,
        YEAR(t.transaction_date),
        MONTH(t.transaction_date),
        'Q' + CAST(DATEPART(Q, t.transaction_date) AS VARCHAR),
        t.revenue, t.cost,
        (t.revenue - t.cost),
        ROUND((t.revenue - t.cost) * 100.0
            / NULLIF(t.revenue, 0), 2),
        t.processing_time, t.status,
        CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END
    FROM
        fact_transactions t
    JOIN dim_clients  c ON t.client_id  = c.client_id
    JOIN dim_products p ON t.product_id = p.product_id;

    PRINT 'Data Mart refreshed successfully at ' 
          + CAST(GETDATE() AS VARCHAR);
END;
