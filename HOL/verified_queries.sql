-- ============================================================
-- F5 Support & Telemetry: Verified Queries
-- ============================================================
-- Distilled from 60 historical queries across 8 personas.
-- These are the standardized, canonical queries for use as
-- verified query representations (VQRs) in a semantic view.
-- ============================================================

-- ============================================================
-- VQ1: Telemetry-to-Support Correlation
-- ============================================================
-- Business Question: Which accounts have elevated telemetry signals
-- AND matching open support cases?
-- Persona: Customer Success Manager, Support Analyst
-- ============================================================

WITH account_signals AS (
    SELECT SFDCF5_ACCT_ID, ACCT_NAME,
        AVG(BOT_ADVANCED_TRANSACTION_CNT) AS avg_bot_txn,
        AVG(WAF_USAGE_QTY) AS avg_waf,
        AVG(ACTIVE_ENDPOINT_QTY) AS avg_endpoints,
        AVG(ACTIVE_HTTP_LOAD_BALANCER_QTY) AS avg_http_lb,
        AVG(DNS_ZONES_QTY) AS avg_dns,
        CASE 
            WHEN AVG(BOT_ADVANCED_TRANSACTION_CNT) > 300000 THEN 'bot-defense'
            WHEN AVG(WAF_USAGE_QTY) > 25 THEN 'waf'
            WHEN AVG(ACTIVE_ENDPOINT_QTY) > 150 THEN 'capacity'
            WHEN AVG(ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 THEN 'load-balancer'
            WHEN AVG(DNS_ZONES_QTY) > 7 THEN 'dns'
            ELSE 'load-balancer'
        END AS dominant_signal
    FROM F5_PROD.RAW.COL_XC_TELEMETRY
    WHERE OBSERVATION_DATE >= CURRENT_DATE() - 60
    GROUP BY 1, 2
),
open_cases AS (
    SELECT SFDCF5_ACCT_ID, PRODUCT_NAME, AREA_NAME, SUB_AREA_NAME,
        SUPPORT_CASE_TITLE_TEXT, CURRENT_PRIORITY_CODE
    FROM F5_PROD.RAW.DIM_SUPPORT_CASE
    WHERE SUPPORT_CASE_STATUS_CODE IN ('Open', 'In Progress')
)
SELECT s.ACCT_NAME, s.dominant_signal, s.avg_bot_txn, s.avg_waf, s.avg_endpoints,
    c.PRODUCT_NAME, c.SUB_AREA_NAME, c.CURRENT_PRIORITY_CODE, c.SUPPORT_CASE_TITLE_TEXT
FROM account_signals s
JOIN open_cases c ON s.SFDCF5_ACCT_ID = c.SFDCF5_ACCT_ID
ORDER BY s.avg_bot_txn DESC;


-- ============================================================
-- VQ2: Account Risk Scorecard
-- ============================================================
-- Business Question: Which accounts have the most compounding
-- risk signals (open cases + declining consumption + SLA breaches)?
-- Persona: VP Customer Experience, Customer Success Manager
-- ============================================================

SELECT a.ACCT_NAME, a.INDUSTRY_NAME, a.ETM_REGION_NAME,
    COUNT(DISTINCT CASE WHEN sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') 
        THEN sc.SUPPORT_CASE_ID END) AS open_cases,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases_12mo,
    ROUND(AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60, 1) AS avg_resolution_hours,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 ELSE 0 END) AS sla_breaches,
    MAX(h.CONSUMPTION_PATTERN) AS consumption_trend,
    MAX(h.SKU_UTILIZATION_PCT) AS utilization_pct
FROM F5_PROD.RAW.DIM_CUST_ACCT_SFDC a
LEFT JOIN F5_PROD.RAW.DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
LEFT JOIN F5_PROD.RAW.FACT_SUPPORT_CASE f ON sc.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
LEFT JOIN F5_PROD.RAW.COL_XC_PRODUCT_HEALTHSCORE h ON a.SFDCF5_ACCT_ID = h.SFDCF5_ACCT_ID
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT CASE WHEN sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') 
    THEN sc.SUPPORT_CASE_ID END) > 0
ORDER BY open_cases DESC, sla_breaches DESC;


-- ============================================================
-- VQ3: SLA Performance by Priority
-- ============================================================
-- Business Question: What's our SLA compliance rate by priority
-- tier, and how fast are we responding and resolving?
-- Persona: Support Manager, Executive
-- ============================================================

SELECT d.CURRENT_PRIORITY_CODE AS priority,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM <= 0 THEN 1 ELSE 0 END) AS within_sla,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 ELSE 0 END) AS breached,
    ROUND(SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM <= 0 THEN 1 ELSE 0 END)::FLOAT 
        / COUNT(*) * 100, 1) AS sla_compliance_pct,
    ROUND(AVG(f.TIME_TO_RESPONSE_MINUTES_NUM), 0) AS avg_first_response_min,
    ROUND(AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60, 1) AS avg_resolution_hours
FROM F5_PROD.RAW.DIM_SUPPORT_CASE d
JOIN F5_PROD.RAW.FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
WHERE f.TIME_OVER_UNDER_SLA_MINUTES_NUM IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- VQ4: Monthly Case Trend with Telemetry Context
-- ============================================================
-- Business Question: How does case volume trend month-over-month,
-- and do telemetry changes precede case spikes?
-- Persona: Telemetry Analyst, Data Engineer, Executive
-- ============================================================

WITH monthly_cases AS (
    SELECT DATE_TRUNC('month', CREATED_DATETIME)::DATE AS month,
        COUNT(*) AS cases_opened,
        SUM(CASE WHEN CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END) AS high_sev_cases
    FROM F5_PROD.RAW.DIM_SUPPORT_CASE
    GROUP BY 1
),
monthly_telemetry AS (
    SELECT DATE_TRUNC('month', OBSERVATION_DATE)::DATE AS month,
        AVG(BOT_ADVANCED_TRANSACTION_CNT) AS avg_bot_txn,
        AVG(WAF_USAGE_QTY) AS avg_waf,
        AVG(ACTIVE_ENDPOINT_QTY) AS avg_endpoints
    FROM F5_PROD.RAW.COL_XC_TELEMETRY
    GROUP BY 1
)
SELECT c.month, c.cases_opened, c.high_sev_cases,
    t.avg_bot_txn, t.avg_waf, t.avg_endpoints,
    LAG(t.avg_bot_txn) OVER (ORDER BY c.month) AS prev_month_bot,
    LAG(t.avg_waf) OVER (ORDER BY c.month) AS prev_month_waf
FROM monthly_cases c
LEFT JOIN monthly_telemetry t ON c.month = t.month
ORDER BY c.month;


-- ============================================================
-- VQ5: Product Reliability Scorecard
-- ============================================================
-- Business Question: Which products generate the most support
-- load, impact the most customers, and have the worst SLA?
-- Persona: Product Manager, Executive, Support Manager
-- ============================================================

SELECT d.PRODUCT_NAME,
    COUNT(*) AS total_cases,
    COUNT(DISTINCT d.SFDCF5_ACCT_ID) AS affected_accounts,
    SUM(CASE WHEN d.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS currently_open,
    SUM(CASE WHEN d.CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END) AS high_severity,
    ROUND(AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60, 1) AS avg_resolution_hours,
    ROUND(SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 ELSE 0 END)::FLOAT 
        / NULLIF(COUNT(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM IS NOT NULL THEN 1 END), 0) * 100, 1) AS sla_breach_pct
FROM F5_PROD.RAW.DIM_SUPPORT_CASE d
LEFT JOIN F5_PROD.RAW.FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
GROUP BY 1
ORDER BY 2 DESC;
