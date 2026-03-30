-- ============================================
-- Funnel Analysis & Product Adoption Metrics
-- Author: Sadhana S Kumar
-- Tools: Azure SQL, T-SQL
-- Description: End-to-end funnel tracking to
--              measure product adoption, drop-off
--              rates and conversion metrics
-- ============================================


-- 1. Product Onboarding Funnel
-- Tracks users through each stage of onboarding
SELECT
    funnel_stage,
    COUNT(DISTINCT user_id)   AS users_at_stage,
    LAG(COUNT(DISTINCT user_id)) OVER (
        ORDER BY stage_order
    )                         AS users_prev_stage,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0
        / NULLIF(
            FIRST_VALUE(COUNT(DISTINCT user_id)) OVER (
                ORDER BY stage_order
                ROWS BETWEEN UNBOUNDED PRECEDING
                         AND UNBOUNDED FOLLOWING
            ), 0),
    2)                        AS pct_of_total,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0
        / NULLIF(LAG(COUNT(DISTINCT user_id)) OVER (
            ORDER BY stage_order
        ), 0),
    2)                        AS stage_conversion_pct
FROM
    fact_user_funnel
WHERE
    event_date >= DATEADD(MONTH, -1, GETDATE())
GROUP BY
    funnel_stage,
    stage_order
ORDER BY
    stage_order;


-- 2. Feature Adoption Rate Over Time
-- Measures how quickly users adopt new features
SELECT
    feature_name,
    YEAR(first_used_date)     AS year,
    MONTH(first_used_date)    AS month,
    COUNT(DISTINCT user_id)   AS new_adopters,
    SUM(COUNT(DISTINCT user_id)) OVER (
        PARTITION BY feature_name
        ORDER BY
            YEAR(first_used_date),
            MONTH(first_used_date)
    )                         AS cumulative_adopters
FROM
    fact_feature_usage
GROUP BY
    feature_name,
    YEAR(first_used_date),
    MONTH(first_used_date)
ORDER BY
    feature_name, year, month;


-- 3. User Drop-off Analysis
-- Identifies where users are dropping off
SELECT
    current_stage,
    next_stage,
    COUNT(DISTINCT user_id)   AS dropped_users,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0
        / NULLIF(SUM(COUNT(DISTINCT user_id)) OVER (
            PARTITION BY current_stage
        ), 0),
    2)                        AS dropoff_rate_pct
FROM (
    SELECT
        user_id,
        funnel_stage           AS current_stage,
        LEAD(funnel_stage) OVER (
            PARTITION BY user_id
            ORDER BY stage_order
        )                      AS next_stage
    FROM
        fact_user_funnel
) AS funnel_stages
WHERE
    next_stage IS NULL
GROUP BY
    current_stage,
    next_stage
ORDER BY
    dropoff_rate_pct DESC;


-- 4. Monthly Active Users (MAU) Trend
SELECT
    YEAR(activity_date)       AS year,
    MONTH(activity_date)      AS month,
    COUNT(DISTINCT user_id)   AS monthly_active_users,
    LAG(COUNT(DISTINCT user_id)) OVER (
        ORDER BY
            YEAR(activity_date),
            MONTH(activity_date)
    )                         AS prev_month_mau,
    ROUND(
        (COUNT(DISTINCT user_id)
            - LAG(COUNT(DISTINCT user_id)) OVER (
                ORDER BY
                    YEAR(activity_date),
                    MONTH(activity_date)
            )) * 100.0
        / NULLIF(LAG(COUNT(DISTINCT user_id)) OVER (
            ORDER BY
                YEAR(activity_date),
                MONTH(activity_date)
        ), 0),
    2)                        AS mau_growth_pct
FROM
    fact_user_activity
GROUP BY
    YEAR(activity_date),
    MONTH(activity_date)
ORDER BY
    year, month;
