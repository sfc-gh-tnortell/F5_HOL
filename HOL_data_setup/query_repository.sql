-- ============================================================
-- F5 Hands-On Lab: Query Repository for Pattern Analysis
-- ============================================================
-- ~63 queries from different personas (Analyst, Data Engineer,
-- Sales Ops, CSM, Executive, Telemetry) with varying calculations.
-- Purpose: Discover patterns, dimensions, joins, and questions
-- to synthesize into a semantic view. Some calcs are intentionally
-- inconsistent to demonstrate the need for standardization.
--
-- Domain: Support & Customer Service
-- ============================================================
--
-- DOMAIN KNOWLEDGE: Signal-to-Product Correlation Mapping
-- ============================================================
-- Telemetry signals correlate to F5 product support cases as follows:
--   BOT_ADVANCED_TRANSACTION_CNT > 300000 = "bot-defense" signal
--       → correlates with XC Bot Defense product cases
--   WAF_USAGE_QTY > 25 = "waf" signal
--       → correlates with XC WAF product cases
--   ACTIVE_ENDPOINT_QTY > 150 = "capacity" signal
--       → correlates with XC App Connect product cases
--   ACTIVE_HTTP_LOAD_BALANCER_QTY > 40 = "load-balancer" signal
--       → correlates with BIG-IP LTM and NGINX Plus cases
--         (includes performance issues: latency, cache, memory)
--   DNS_ZONES_QTY > 7 = "dns" signal
--       → correlates with XC DNS and BIG-IP GTM product cases
--
-- Evaluate thresholds in the priority order listed above.
-- Accounts below ALL thresholds default to "load-balancer" signal.
-- The correlation: elevated infrastructure telemetry predicts which
-- product categories will generate support cases for that account.
--
-- RECOMMENDED AI_SQL_GENERATION for semantic view:
-- 'When correlating telemetry to support cases use this signal-to-product
-- mapping: BOT_ADVANCED_TRANSACTION_CNT > 300000 means bot-defense signal
-- correlating with XC Bot Defense cases. WAF_USAGE_QTY > 25 means waf
-- signal correlating with XC WAF cases. ACTIVE_ENDPOINT_QTY > 150 means
-- capacity signal correlating with XC App Connect cases.
-- ACTIVE_HTTP_LOAD_BALANCER_QTY > 40 means load-balancer signal
-- correlating with BIG-IP LTM and NGINX Plus cases including performance
-- issues like latency cache and memory pressure. DNS_ZONES_QTY > 7 means
-- dns signal correlating with XC DNS and BIG-IP GTM cases. Evaluate
-- thresholds in this priority order. Always JOIN telemetry to cases
-- through SFDCF5_ACCT_ID and aggregate telemetry over last 60 days.'
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- PERSONA: Support Analyst (Sarah)
-- Focus: Case volume, resolution times, SLA compliance
-- ============================================================

-- Q1: Total open cases by priority
SELECT CURRENT_PRIORITY_CODE AS priority, COUNT(*) AS open_case_count
FROM DIM_SUPPORT_CASE
WHERE SUPPORT_CASE_STATUS_CODE IN ('Open', 'In Progress')
GROUP BY 1 ORDER BY 2 DESC;

-- Q2: Average time to resolution by product
SELECT PRODUCT_NAME, AVG(TIME_TO_RESOLUTION_MINUTES_NUM) / 60.0 AS avg_resolution_hours
FROM FACT_SUPPORT_CASE f
JOIN DIM_SUPPORT_CASE d ON f.SUPPORT_CASE_ID = d.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 2 DESC;

-- Q3: SLA breach rate by service level
SELECT d.SERVICE_LEVEL_CODE,
    COUNT(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 END) AS breached,
    COUNT(*) AS total,
    ROUND(COUNT(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS breach_rate_pct
FROM FACT_SUPPORT_CASE f
JOIN DIM_SUPPORT_CASE d ON f.SUPPORT_CASE_ID = d.SUPPORT_CASE_ID
WHERE f.TIME_OVER_UNDER_SLA_MINUTES_NUM IS NOT NULL
GROUP BY 1;

-- Q4: Cases opened per month trend
SELECT DATE_TRUNC('month', CREATED_DATETIME) AS month, COUNT(*) AS cases_opened
FROM DIM_SUPPORT_CASE
GROUP BY 1 ORDER BY 1;

-- Q5: Top 10 accounts by open case count
SELECT a.ACCT_NAME, COUNT(*) AS open_cases
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- Q6: Average first response time by priority (minutes)
SELECT CURRENT_PRIORITY_CODE,
    AVG(TIME_TO_RESPONSE_MINUTES_NUM) AS avg_first_response_minutes
FROM FACT_SUPPORT_CASE f
JOIN DIM_SUPPORT_CASE d ON f.SUPPORT_CASE_ID = d.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 1;

-- Q7: Case distribution by area and sub-area
SELECT AREA_NAME, SUB_AREA_NAME, COUNT(*) AS case_count
FROM DIM_SUPPORT_CASE
GROUP BY 1, 2 ORDER BY 3 DESC;

-- Q8: Escalation cases (P1/P2) with no resolution in 48 hours
SELECT d.SUPPORT_CASE_NUM, d.SFDCF5_ACCT_ID, d.SUPPORT_CASE_TITLE_TEXT,
    d.CURRENT_PRIORITY_CODE, DATEDIFF(hour, d.OPENED_DATETIME, CURRENT_TIMESTAMP()) AS hours_open
FROM DIM_SUPPORT_CASE d
WHERE d.CURRENT_PRIORITY_CODE IN ('P1 - Critical', 'P2 - High')
  AND d.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
  AND DATEDIFF(hour, d.OPENED_DATETIME, CURRENT_TIMESTAMP()) > 48
ORDER BY hours_open DESC;

-- ============================================================
-- PERSONA: Data Engineer (Mike)
-- Focus: Data quality, join patterns, aggregations
-- ============================================================

-- Q9: Case count by account with install base correlation
SELECT a.ACCT_NAME, a.ETM_REGION_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    COUNT(DISTINCT ib.SERIAL_NUM) AS installed_assets,
    ROUND(COUNT(DISTINCT sc.SUPPORT_CASE_ID)::FLOAT / NULLIF(COUNT(DISTINCT ib.SERIAL_NUM), 0), 2) AS cases_per_asset
FROM DIM_CUST_ACCT_SFDC a
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
LEFT JOIN COL_INSTALL_BASE ib ON a.SFDCF5_ACCT_ID = ib.CUST_SFDCF5_ACCT_ID
GROUP BY 1, 2 ORDER BY 5 DESC NULLS LAST LIMIT 20;

-- Q10: RMA rate by product platform
SELECT ib.CORE_PRODUCT_NAME, ib.HARDWARE_PLATFORM_CODE,
    COUNT(DISTINCT ib.SERIAL_NUM) AS total_deployed,
    COUNT(DISTINCT r.ORDER_NUM) AS rma_count,
    ROUND(COUNT(DISTINCT r.ORDER_NUM)::FLOAT / NULLIF(COUNT(DISTINCT ib.SERIAL_NUM), 0) * 100, 2) AS rma_rate_pct
FROM COL_INSTALL_BASE ib
LEFT JOIN FACT_RMA_ORDER r ON ib.CUST_SFDCF5_ACCT_ID = r.SFDCF5_ACCT_ID
GROUP BY 1, 2 HAVING COUNT(DISTINCT ib.SERIAL_NUM) > 5
ORDER BY 5 DESC;

-- Q11: Support case to opportunity correlation (accounts with both open cases and open pipeline)
SELECT a.ACCT_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS open_cases,
    COUNT(DISTINCT o.OPPORTUNITY_ID) AS open_opps,
    SUM(DISTINCT f.OPPORTUNITY_AMT) AS pipeline_value
FROM DIM_CUST_ACCT_SFDC a
JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID AND sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
JOIN DIM_SALES_OPPORTUNITY o ON a.SFDCF5_ACCT_ID = o.SFDCF5_ACCT_ID AND o.OPPORTUNITY_CLOSED_IND = FALSE
JOIN FACT_SALES_OPPORTUNITY f ON o.OPPORTUNITY_ID = f.OPPORTUNITY_ID
GROUP BY 1 ORDER BY 2 DESC LIMIT 15;

-- Q12: Cases by software version (identify problematic releases)
SELECT ib.SOFTWARE_VERSION_NUM, COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS case_count
FROM COL_INSTALL_BASE ib
JOIN DIM_SUPPORT_CASE sc ON ib.CUST_SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
    AND sc.PRODUCT_SKU_ID LIKE '%BIG%'
GROUP BY 1 ORDER BY 2 DESC;

-- Q13: Time to close distribution (percentiles)
SELECT
    APPROX_PERCENTILE(TIME_TO_CLOSE_MINUTES_NUM, 0.50) AS p50_minutes,
    APPROX_PERCENTILE(TIME_TO_CLOSE_MINUTES_NUM, 0.75) AS p75_minutes,
    APPROX_PERCENTILE(TIME_TO_CLOSE_MINUTES_NUM, 0.90) AS p90_minutes,
    APPROX_PERCENTILE(TIME_TO_CLOSE_MINUTES_NUM, 0.95) AS p95_minutes
FROM FACT_SUPPORT_CASE
WHERE TIME_TO_CLOSE_MINUTES_NUM IS NOT NULL;

-- Q14: Repeat callers - accounts with more than 5 cases in 90 days
SELECT a.ACCT_NAME, COUNT(*) AS case_count_90d
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE sc.CREATED_DATETIME >= DATEADD(day, -90, CURRENT_TIMESTAMP())
GROUP BY 1 HAVING COUNT(*) > 5
ORDER BY 2 DESC;

-- ============================================================
-- PERSONA: Customer Success Manager (Jennifer)
-- Focus: Account health, churn risk, customer experience
-- ============================================================

-- Q15: Account health dashboard - cases + utilization + pipeline
SELECT a.ACCT_NAME, a.ETM_REGION_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    SUM(CASE WHEN sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS open_cases,
    MAX(h.SKU_UTILIZATION_PCT) AS max_utilization_pct,
    MAX(h.CONSUMPTION_PATTERN) AS consumption_trend
FROM DIM_CUST_ACCT_SFDC a
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
LEFT JOIN COL_XC_PRODUCT_HEALTHSCORE h ON a.SFDCF5_ACCT_ID = h.SFDCF5_ACCT_ID
GROUP BY 1, 2 ORDER BY 4 DESC LIMIT 20;

-- Q16: Churn risk indicators (high case volume + declining usage + at-risk opps)
SELECT a.ACCT_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS cases_last_180d,
    AVG(h.SKU_UTILIZATION_PCT) AS avg_utilization,
    h.CONSUMPTION_PATTERN,
    COUNT(DISTINCT CASE WHEN o.OPPORTUNITY_STAGE_NAME = 'Closed Lost' THEN o.OPPORTUNITY_ID END) AS lost_deals
FROM DIM_CUST_ACCT_SFDC a
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
    AND sc.CREATED_DATETIME >= DATEADD(day, -180, CURRENT_TIMESTAMP())
LEFT JOIN COL_XC_PRODUCT_HEALTHSCORE h ON a.SFDCF5_ACCT_ID = h.SFDCF5_ACCT_ID
LEFT JOIN DIM_SALES_OPPORTUNITY o ON a.SFDCF5_ACCT_ID = o.SFDCF5_ACCT_ID
GROUP BY 1, 4
HAVING COUNT(DISTINCT sc.SUPPORT_CASE_ID) > 3 OR AVG(h.SKU_UTILIZATION_PCT) < 30
ORDER BY 2 DESC;

-- Q17: CSAT proxy - cases resolved within SLA by account
-- NOTE: Different calc than Q3 - uses time_to_resolution vs time_over_under
SELECT a.ACCT_NAME,
    COUNT(*) AS total_resolved,
    SUM(CASE WHEN f.TIME_TO_RESOLUTION_MINUTES_NUM <= 1440 THEN 1 ELSE 0 END) AS resolved_within_24h,
    ROUND(SUM(CASE WHEN f.TIME_TO_RESOLUTION_MINUTES_NUM <= 1440 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS pct_resolved_24h
FROM FACT_SUPPORT_CASE f
JOIN DIM_SUPPORT_CASE d ON f.SUPPORT_CASE_ID = d.SUPPORT_CASE_ID
JOIN DIM_CUST_ACCT_SFDC a ON d.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE f.TIME_TO_RESOLUTION_MINUTES_NUM IS NOT NULL
GROUP BY 1 ORDER BY 4 ASC LIMIT 20;

-- Q18: Territory workload - cases per SE
SELECT sat.SE_NAME, sat.REGION_NAME,
    COUNT(DISTINCT sat.SFDCF5_ACCT_ID) AS accounts_covered,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    ROUND(COUNT(DISTINCT sc.SUPPORT_CASE_ID)::FLOAT / COUNT(DISTINCT sat.SFDCF5_ACCT_ID), 1) AS cases_per_account
FROM SALES_ACCOUNT_TEAM sat
LEFT JOIN DIM_SUPPORT_CASE sc ON sat.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
GROUP BY 1, 2 ORDER BY 4 DESC;

-- Q19: Accounts with expiring service contracts and open P1/P2 cases
SELECT a.ACCT_NAME, ib.SERVICE_END_DATETIME,
    DATEDIFF(day, CURRENT_DATE(), ib.SERVICE_END_DATETIME::DATE) AS days_to_expiry,
    sc.SUPPORT_CASE_NUM, sc.CURRENT_PRIORITY_CODE, sc.SUPPORT_CASE_TITLE_TEXT
FROM COL_INSTALL_BASE ib
JOIN DIM_CUST_ACCT_SFDC a ON ib.CUST_SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
    AND sc.CURRENT_PRIORITY_CODE IN ('P1 - Critical', 'P2 - High')
    AND sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
WHERE ib.SERVICE_END_DATETIME BETWEEN CURRENT_TIMESTAMP() AND DATEADD(day, 90, CURRENT_TIMESTAMP())
ORDER BY days_to_expiry;

-- Q20: Customer effort score proxy - avg case reopens and touches
SELECT a.ACCT_NAME,
    COUNT(*) AS total_cases,
    AVG(DATEDIFF(day, d.OPENED_DATETIME, COALESCE(d.CLOSED_DATETIME, CURRENT_TIMESTAMP()))) AS avg_days_open,
    SUM(CASE WHEN d.CURRENT_PRIORITY_CODE != d.INITIAL_PRIORITY_CODE THEN 1 ELSE 0 END) AS priority_escalations
FROM DIM_SUPPORT_CASE d
JOIN DIM_CUST_ACCT_SFDC a ON d.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
GROUP BY 1 HAVING COUNT(*) >= 3
ORDER BY 4 DESC LIMIT 20;

-- ============================================================
-- PERSONA: Sales Operations (Alex)
-- Focus: Revenue impact, territory analytics, cross-sell from support
-- NOTE: Uses DIFFERENT calculations for same metrics as Jennifer
-- ============================================================

-- Q21: Support case volume vs ARR by account (revenue at risk)
SELECT a.ACCT_NAME,
    SUM(f.ARR_AMT) AS total_arr,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS case_count,
    ROUND(SUM(f.ARR_AMT) / NULLIF(COUNT(DISTINCT sc.SUPPORT_CASE_ID), 0), 0) AS arr_per_case
FROM DIM_CUST_ACCT_SFDC a
JOIN FACT_SALES_OPPORTUNITY f ON a.SFDCF5_ACCT_ID = f.SFDCF5_ACCT_ID
JOIN DIM_SALES_OPPORTUNITY o ON f.OPPORTUNITY_ID = o.OPPORTUNITY_ID AND o.OPPORTUNITY_WON_IND = TRUE
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
GROUP BY 1 ORDER BY 3 DESC LIMIT 20;

-- Q22: Territory support load - DIFFERENT calc than Q18 (uses COL_SUPPORT_CASE)
SELECT REGION_NAME, TERRITORY_NAME,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN SEVERITY_CODE = 'P1 - Critical' THEN 1 ELSE 0 END) AS p1_cases,
    AVG(SUPPORT_CASE_OPEN_DAYS) AS avg_open_days
FROM COL_SUPPORT_CASE
GROUP BY 1, 2 ORDER BY 3 DESC;

-- Q23: Cross-sell opportunity from support - accounts buying BIG-IP but not XC
SELECT a.ACCT_NAME, a.INDUSTRY_NAME, a.ETM_REGION_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS bigip_cases,
    sat.AE_NAME
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
JOIN SALES_ACCOUNT_TEAM sat ON a.SFDCF5_ACCT_ID = sat.SFDCF5_ACCT_ID
WHERE sc.PRODUCT_SKU_ID LIKE '%BIG%'
  AND a.SFDCF5_ACCT_ID NOT IN (
      SELECT SFDCF5_ACCT_ID FROM COL_XC_TELEMETRY_ACCT_MAP_V2
  )
GROUP BY 1, 2, 3, 5 ORDER BY 4 DESC LIMIT 15;

-- Q24: Support impact on renewals - renewal win rate for accounts with P1s
SELECT
    CASE WHEN sc_count > 0 THEN 'Has P1 Cases' ELSE 'No P1 Cases' END AS p1_category,
    COUNT(*) AS renewal_count,
    SUM(CASE WHEN o.OPPORTUNITY_WON_IND THEN 1 ELSE 0 END) AS renewals_won,
    ROUND(SUM(CASE WHEN o.OPPORTUNITY_WON_IND THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS renewal_win_rate
FROM DIM_SALES_OPPORTUNITY o
LEFT JOIN (
    SELECT SFDCF5_ACCT_ID, COUNT(*) AS sc_count
    FROM DIM_SUPPORT_CASE
    WHERE CURRENT_PRIORITY_CODE = 'P1 - Critical'
    GROUP BY 1
) p1 ON o.SFDCF5_ACCT_ID = p1.SFDCF5_ACCT_ID
WHERE o.OPPORTUNITY_TYPE_CODE = 'Renewal' AND o.OPPORTUNITY_CLOSED_IND = TRUE
GROUP BY 1;

-- Q25: Average case resolution - INTENTIONALLY DIFFERENT CALC from Q2
-- Uses hours not minutes, and includes unresolved cases as NULL (wrong approach)
SELECT d.PRODUCT_NAME,
    AVG(f.TIME_TO_CLOSE_MINUTES_NUM) / 60 AS avg_close_hours,
    COUNT(*) AS case_count
FROM DIM_SUPPORT_CASE d
LEFT JOIN FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 2 DESC;

-- Q26: RMA correlation to lost deals
SELECT a.ACCT_NAME,
    COUNT(DISTINCT r.ORDER_NUM) AS rma_count,
    COUNT(DISTINCT CASE WHEN o.OPPORTUNITY_STAGE_NAME = 'Closed Lost' THEN o.OPPORTUNITY_ID END) AS lost_opps,
    SUM(DISTINCT CASE WHEN NOT o.OPPORTUNITY_WON_IND AND o.OPPORTUNITY_CLOSED_IND THEN f.OPPORTUNITY_AMT END) AS lost_revenue
FROM DIM_CUST_ACCT_SFDC a
JOIN FACT_RMA_ORDER r ON a.SFDCF5_ACCT_ID = r.SFDCF5_ACCT_ID
LEFT JOIN DIM_SALES_OPPORTUNITY o ON a.SFDCF5_ACCT_ID = o.SFDCF5_ACCT_ID
LEFT JOIN FACT_SALES_OPPORTUNITY f ON o.OPPORTUNITY_ID = f.OPPORTUNITY_ID
GROUP BY 1 HAVING COUNT(DISTINCT r.ORDER_NUM) > 0
ORDER BY 4 DESC NULLS LAST LIMIT 10;

-- ============================================================
-- PERSONA: Executive / VP of Customer Experience (David)
-- Focus: High-level KPIs, trends, board-ready metrics
-- ============================================================

-- Q27: Executive dashboard - overall support health
SELECT
    COUNT(*) AS total_cases_ytd,
    SUM(CASE WHEN SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS currently_open,
    SUM(CASE WHEN CURRENT_PRIORITY_CODE = 'P1 - Critical' AND SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS open_p1s,
    ROUND(AVG(CASE WHEN RESOLVED_DATETIME IS NOT NULL THEN DATEDIFF(hour, OPENED_DATETIME, RESOLVED_DATETIME) END), 1) AS avg_resolution_hours
FROM DIM_SUPPORT_CASE
WHERE CREATED_DATETIME >= DATEADD(month, -12, CURRENT_TIMESTAMP());

-- Q28: Support case trend - MoM growth
SELECT DATE_TRUNC('month', CREATED_DATETIME) AS month,
    COUNT(*) AS cases,
    LAG(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', CREATED_DATETIME)) AS prev_month,
    ROUND((COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', CREATED_DATETIME)))::FLOAT /
        NULLIF(LAG(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', CREATED_DATETIME)), 0) * 100, 1) AS mom_growth_pct
FROM DIM_SUPPORT_CASE
GROUP BY 1 ORDER BY 1;

-- Q29: Customer satisfaction proxy - % closed within SLA
-- NOTE: DIFFERENT from Q3 - uses different SLA thresholds
SELECT
    COUNT(*) AS total_closed,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM <= 0 THEN 1 ELSE 0 END) AS within_sla,
    ROUND(SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM <= 0 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS sla_compliance_pct
FROM FACT_SUPPORT_CASE f
WHERE f.TIME_OVER_UNDER_SLA_MINUTES_NUM IS NOT NULL;

-- Q30: Revenue at risk from unhappy accounts (cases + declining telemetry)
SELECT a.ACCT_NAME, a.ANNUAL_REVENUE_AMT,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS open_cases,
    h.CONSUMPTION_PATTERN,
    SUM(f.ARR_AMT) AS active_arr
FROM DIM_CUST_ACCT_SFDC a
JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
    AND sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
LEFT JOIN COL_XC_PRODUCT_HEALTHSCORE h ON a.SFDCF5_ACCT_ID = h.SFDCF5_ACCT_ID
LEFT JOIN FACT_SALES_OPPORTUNITY f ON a.SFDCF5_ACCT_ID = f.SFDCF5_ACCT_ID
    AND f.OPPORTUNITY_CLOSE_DATE >= DATEADD(year, -1, CURRENT_DATE())
WHERE h.CONSUMPTION_PATTERN IN ('Declining', 'New') OR COUNT(DISTINCT sc.SUPPORT_CASE_ID) > 5
GROUP BY 1, 2, 4 ORDER BY 3 DESC LIMIT 15;

-- Q31: Product reliability scorecard
SELECT d.PRODUCT_NAME,
    COUNT(*) AS total_cases,
    AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) AS avg_resolution_min,
    SUM(CASE WHEN d.CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END) AS high_sev_cases,
    ROUND(SUM(CASE WHEN d.CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS high_sev_pct
FROM DIM_SUPPORT_CASE d
JOIN FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 2 DESC;

-- ============================================================
-- PERSONA: Telemetry Analyst (Priya)
-- Focus: Usage patterns, capacity, proactive support
-- ============================================================

-- Q32: Accounts with high telemetry but no support engagement
SELECT a.ACCT_NAME, t.ACTIVE_HTTP_LOAD_BALANCER_QTY, t.WAF_USAGE_QTY,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS case_count
FROM COL_XC_TELEMETRY t
JOIN DIM_CUST_ACCT_SFDC a ON t.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
WHERE t.CURRENT_OBSERVATION_FLAG = 'Y'
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT sc.SUPPORT_CASE_ID) = 0 AND t.ACTIVE_HTTP_LOAD_BALANCER_QTY > 20
ORDER BY 2 DESC;

-- Q33: Bot defense anomalies - accounts with spike in blocked traffic
SELECT TENANT, DATE,
    SUM(CASE WHEN ACTION_TYPE = 'block' THEN VALUE ELSE 0 END) AS blocked_transactions,
    SUM(CASE WHEN ACTION_TYPE = 'allow' THEN VALUE ELSE 0 END) AS allowed_transactions,
    ROUND(SUM(CASE WHEN ACTION_TYPE = 'block' THEN VALUE ELSE 0 END)::FLOAT /
        NULLIF(SUM(VALUE), 0) * 100, 1) AS block_rate_pct
FROM BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD
GROUP BY 1, 2
HAVING block_rate_pct > 50
ORDER BY 3 DESC LIMIT 20;

-- Q34: Utilization trending - accounts approaching entitlement limits
SELECT u.ACCT_NAME, u.OFFER_SKU_ID, u.FEATURE_NAME,
    u.FEATURE_ENTITLED_QTY, u.FEATURE_USED_QTY,
    ROUND(u.FEATURE_USED_QTY / NULLIF(u.FEATURE_ENTITLED_QTY, 0) * 100, 1) AS utilization_pct
FROM COL_TERM_SUB_MONTHLY_USAGE_V2 u
WHERE u.BILLING_MONTH_START_DATE = (SELECT MAX(BILLING_MONTH_START_DATE) FROM COL_TERM_SUB_MONTHLY_USAGE_V2)
  AND u.FEATURE_USED_QTY / NULLIF(u.FEATURE_ENTITLED_QTY, 0) > 0.8
ORDER BY 6 DESC;

-- Q35: Telemetry gaps - accounts not sending data (potential outage)
SELECT m.SFDCF5_ACCT_ID, a.ACCT_NAME, m.TENANT_ID,
    MAX(t.OBSERVATION_DATE) AS last_observation,
    DATEDIFF(day, MAX(t.OBSERVATION_DATE), CURRENT_DATE()) AS days_since_data
FROM COL_XC_TELEMETRY_ACCT_MAP_V2 m
JOIN DIM_CUST_ACCT_SFDC a ON m.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
LEFT JOIN COL_XC_TELEMETRY t ON m.TENANT_ID = t.TENANT_ID
WHERE m.TELEMETRY_RECEIVED_FLAG = 'Y'
GROUP BY 1, 2, 3
HAVING DATEDIFF(day, MAX(t.OBSERVATION_DATE), CURRENT_DATE()) > 7
ORDER BY 5 DESC;

-- Q36: WAF usage vs cases - are high-WAF accounts creating more security cases?
SELECT a.ACCT_NAME,
    AVG(t.WAF_USAGE_QTY) AS avg_waf_rules,
    COUNT(DISTINCT CASE WHEN sc.AREA_NAME = 'Security' THEN sc.SUPPORT_CASE_ID END) AS security_cases
FROM DIM_CUST_ACCT_SFDC a
JOIN COL_XC_TELEMETRY t ON a.SFDCF5_ACCT_ID = t.SFDCF5_ACCT_ID
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
WHERE t.CURRENT_OBSERVATION_FLAG = 'Y'
GROUP BY 1 ORDER BY 3 DESC LIMIT 20;

-- Q37: Telemetry signal classification - which signal dominates per account?
-- Thresholds: bot>300K, waf>25, endpoints>150, http_lb>40, dns>7
-- Accounts below all thresholds still correlate to load-balancer (BIG-IP/NGINX)
SELECT t.SFDCF5_ACCT_ID, a.ACCT_NAME,
    AVG(t.BOT_ADVANCED_TRANSACTION_CNT) AS avg_bot_txn,
    AVG(t.WAF_USAGE_QTY) AS avg_waf,
    AVG(t.ACTIVE_ENDPOINT_QTY) AS avg_endpoints,
    AVG(t.ACTIVE_HTTP_LOAD_BALANCER_QTY) AS avg_http_lb,
    AVG(t.DNS_ZONES_QTY) AS avg_dns,
    CASE
        WHEN AVG(t.BOT_ADVANCED_TRANSACTION_CNT) > 300000 THEN 'bot-defense'
        WHEN AVG(t.WAF_USAGE_QTY) > 25 THEN 'waf'
        WHEN AVG(t.ACTIVE_ENDPOINT_QTY) > 150 THEN 'capacity'
        WHEN AVG(t.ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 THEN 'load-balancer'
        WHEN AVG(t.DNS_ZONES_QTY) > 7 THEN 'dns'
        ELSE 'load-balancer'
    END AS dominant_signal
FROM COL_XC_TELEMETRY t
JOIN DIM_CUST_ACCT_SFDC a ON t.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE t.OBSERVATION_DATE >= CURRENT_DATE() - 60
GROUP BY 1, 2
ORDER BY avg_bot_txn DESC;

-- Q38: Telemetry-to-support correlation - match dominant signal to open cases
WITH account_signals AS (
    SELECT t.SFDCF5_ACCT_ID, a.ACCT_NAME,
        AVG(t.BOT_ADVANCED_TRANSACTION_CNT) AS avg_bot_txn,
        AVG(t.WAF_USAGE_QTY) AS avg_waf,
        AVG(t.ACTIVE_ENDPOINT_QTY) AS avg_endpoints,
        AVG(t.ACTIVE_HTTP_LOAD_BALANCER_QTY) AS avg_http_lb,
        AVG(t.DNS_ZONES_QTY) AS avg_dns,
        CASE
            WHEN AVG(t.BOT_ADVANCED_TRANSACTION_CNT) > 300000 THEN 'bot-defense'
            WHEN AVG(t.WAF_USAGE_QTY) > 25 THEN 'waf'
            WHEN AVG(t.ACTIVE_ENDPOINT_QTY) > 150 THEN 'capacity'
            WHEN AVG(t.ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 THEN 'load-balancer'
            WHEN AVG(t.DNS_ZONES_QTY) > 7 THEN 'dns'
            ELSE 'load-balancer'
        END AS dominant_signal
    FROM COL_XC_TELEMETRY t
    JOIN DIM_CUST_ACCT_SFDC a ON t.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
    WHERE t.OBSERVATION_DATE >= CURRENT_DATE() - 60
    GROUP BY 1, 2
),
open_cases AS (
    SELECT SFDCF5_ACCT_ID, PRODUCT_NAME, SUB_AREA_NAME,
        CURRENT_PRIORITY_CODE, SUPPORT_CASE_TITLE_TEXT
    FROM DIM_SUPPORT_CASE
    WHERE SUPPORT_CASE_STATUS_CODE IN ('Open', 'In Progress')
)
SELECT s.ACCT_NAME, s.dominant_signal, s.avg_bot_txn, s.avg_waf,
    s.avg_endpoints, s.avg_http_lb, s.avg_dns,
    c.PRODUCT_NAME, c.SUB_AREA_NAME, c.CURRENT_PRIORITY_CODE,
    c.SUPPORT_CASE_TITLE_TEXT
FROM account_signals s
JOIN open_cases c ON s.SFDCF5_ACCT_ID = c.SFDCF5_ACCT_ID
ORDER BY s.avg_bot_txn DESC;

-- Q39: Signal distribution - how many accounts per signal category?
SELECT dominant_signal, COUNT(*) AS account_count
FROM (
    SELECT SFDCF5_ACCT_ID,
        CASE
            WHEN AVG(BOT_ADVANCED_TRANSACTION_CNT) > 300000 THEN 'bot-defense'
            WHEN AVG(WAF_USAGE_QTY) > 25 THEN 'waf'
            WHEN AVG(ACTIVE_ENDPOINT_QTY) > 150 THEN 'capacity'
            WHEN AVG(ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 THEN 'load-balancer'
            WHEN AVG(DNS_ZONES_QTY) > 7 THEN 'dns'
            ELSE 'load-balancer'
        END AS dominant_signal
    FROM COL_XC_TELEMETRY
    WHERE OBSERVATION_DATE >= CURRENT_DATE() - 60
    GROUP BY 1
)
GROUP BY 1 ORDER BY 2 DESC;

-- ============================================================
-- PERSONA: Support Manager (Carlos)
-- Focus: Team performance, workload distribution, backlog
-- ============================================================

-- Q40: Backlog aging buckets
SELECT
    CASE
        WHEN DATEDIFF(day, OPENED_DATETIME, CURRENT_TIMESTAMP()) <= 7 THEN '0-7 days'
        WHEN DATEDIFF(day, OPENED_DATETIME, CURRENT_TIMESTAMP()) <= 14 THEN '8-14 days'
        WHEN DATEDIFF(day, OPENED_DATETIME, CURRENT_TIMESTAMP()) <= 30 THEN '15-30 days'
        WHEN DATEDIFF(day, OPENED_DATETIME, CURRENT_TIMESTAMP()) <= 60 THEN '31-60 days'
        ELSE '60+ days'
    END AS age_bucket,
    COUNT(*) AS case_count
FROM DIM_SUPPORT_CASE
WHERE SUPPORT_CASE_STATUS_CODE NOT IN ('Closed', 'Resolved')
GROUP BY 1 ORDER BY MIN(DATEDIFF(day, OPENED_DATETIME, CURRENT_TIMESTAMP()));

-- Q41: Case volume by day of week (staffing optimization)
SELECT DAYNAME(CREATED_DATETIME) AS day_of_week,
    COUNT(*) AS cases_created,
    AVG(CASE WHEN CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END) * 100 AS pct_high_severity
FROM DIM_SUPPORT_CASE
GROUP BY 1 ORDER BY
    CASE DAYNAME(CREATED_DATETIME)
        WHEN 'Mon' THEN 1 WHEN 'Tue' THEN 2 WHEN 'Wed' THEN 3
        WHEN 'Thu' THEN 4 WHEN 'Fri' THEN 5 WHEN 'Sat' THEN 6 ELSE 7
    END;

-- Q42: First response SLA compliance by region
-- NOTE: DIFFERENT definition of "breach" than Q3 (uses absolute threshold vs dynamic SLA)
SELECT cs.REGION_NAME,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN f.TIME_TO_RESPONSE_MINUTES_NUM <= 60 THEN 1 ELSE 0 END) AS responded_within_1h,
    ROUND(SUM(CASE WHEN f.TIME_TO_RESPONSE_MINUTES_NUM <= 60 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS first_response_sla_pct
FROM COL_SUPPORT_CASE cs
JOIN FACT_SUPPORT_CASE f ON cs.SUPPORT_CASE_NUM = (SELECT SUPPORT_CASE_NUM FROM DIM_SUPPORT_CASE WHERE SUPPORT_CASE_ID = f.SUPPORT_CASE_ID)
GROUP BY 1;

-- Q43: Product area heatmap - where are we spending the most support effort?
SELECT AREA_NAME, SUB_AREA_NAME, PRODUCT_NAME,
    COUNT(*) AS case_count,
    AVG(DATEDIFF(day, OPENED_DATETIME, COALESCE(RESOLVED_DATETIME, CURRENT_TIMESTAMP()))) AS avg_days_to_resolve
FROM DIM_SUPPORT_CASE
GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 25;

-- ============================================================
-- PERSONA: Finance Analyst (Rachel)
-- Focus: Cost of support, warranty claims, service revenue
-- ============================================================

-- Q44: RMA cost exposure by symptom class
SELECT r.SYMPTOM_CLASS_CODE,
    COUNT(*) AS rma_count,
    COUNT(DISTINCT r.SFDCF5_ACCT_ID) AS affected_accounts
FROM FACT_RMA_ORDER r
GROUP BY 1 ORDER BY 2 DESC;

-- Q45: Support cost per account (proxy: cases * avg cost assumption)
SELECT a.ACCT_NAME, a.ETM_REGION_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) * 350 AS estimated_support_cost,
    SUM(DISTINCT f.ARR_AMT) AS account_arr,
    ROUND(COUNT(DISTINCT sc.SUPPORT_CASE_ID) * 350.0 / NULLIF(SUM(DISTINCT f.ARR_AMT), 0) * 100, 2) AS support_cost_pct_of_arr
FROM DIM_CUST_ACCT_SFDC a
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
LEFT JOIN FACT_SALES_OPPORTUNITY f ON a.SFDCF5_ACCT_ID = f.SFDCF5_ACCT_ID
GROUP BY 1, 2 ORDER BY 6 DESC NULLS LAST LIMIT 20;

-- Q46: Service level tier distribution and case load
SELECT d.SERVICE_LEVEL_CODE,
    COUNT(*) AS total_cases,
    AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60 AS avg_resolution_hours,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 ELSE 0 END) AS sla_breaches
FROM DIM_SUPPORT_CASE d
JOIN FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
WHERE f.TIME_TO_RESOLUTION_MINUTES_NUM IS NOT NULL
GROUP BY 1;

-- Q47: Warranty RMA vs out-of-warranty (are we covering expired assets?)
SELECT
    CASE WHEN ib.SERVICE_END_DATETIME > CURRENT_TIMESTAMP() THEN 'Under Warranty' ELSE 'Expired' END AS warranty_status,
    COUNT(DISTINCT r.ORDER_NUM) AS rma_count
FROM FACT_RMA_ORDER r
JOIN COL_INSTALL_BASE ib ON r.SFDCF5_ACCT_ID = ib.CUST_SFDCF5_ACCT_ID
GROUP BY 1;

-- ============================================================
-- PERSONA: Data Engineer #2 (Raj)
-- Focus: Same questions as Mike but with DIFFERENT join logic
-- Demonstrates inconsistency in how teams calculate metrics
-- ============================================================

-- Q48: Avg resolution time - DIFFERENT from Q2 (includes nulls, uses CLOSE not RESOLUTION)
SELECT d.PRODUCT_NAME,
    AVG(DATEDIFF(minute, d.OPENED_DATETIME, d.CLOSED_DATETIME)) / 60 AS avg_close_hours,
    COUNT(*) AS total
FROM DIM_SUPPORT_CASE d
WHERE d.CLOSED_DATETIME IS NOT NULL
GROUP BY 1 ORDER BY 2 DESC;

-- Q49: Case volume per account - DIFFERENT join path than Q5 (uses COL_SUPPORT_CASE)
SELECT cs.SALES_SFDCF5_ACCT_ID,
    a.ACCT_NAME, cs.REGION_NAME,
    COUNT(*) AS case_count,
    AVG(cs.SUPPORT_CASE_OPEN_DAYS) AS avg_days_open
FROM COL_SUPPORT_CASE cs
JOIN DIM_CUST_ACCT_SFDC a ON cs.SALES_SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE cs.STATUS NOT IN ('Closed', 'Resolved')
GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 10;

-- Q50: SLA calculation - THIRD different approach
-- Uses absolute time thresholds per priority instead of TIME_OVER_UNDER_SLA
SELECT d.CURRENT_PRIORITY_CODE,
    COUNT(*) AS total,
    SUM(CASE
        WHEN d.CURRENT_PRIORITY_CODE = 'P1 - Critical' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 30 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P2 - High' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 120 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P3 - Medium' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 480 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P4 - Low' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 1440 THEN 1
        ELSE 0
    END) AS met_sla,
    ROUND(SUM(CASE
        WHEN d.CURRENT_PRIORITY_CODE = 'P1 - Critical' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 30 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P2 - High' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 120 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P3 - Medium' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 480 THEN 1
        WHEN d.CURRENT_PRIORITY_CODE = 'P4 - Low' AND f.TIME_TO_RESPONSE_MINUTES_NUM <= 1440 THEN 1
        ELSE 0
    END)::FLOAT / COUNT(*) * 100, 1) AS sla_pct
FROM DIM_SUPPORT_CASE d
JOIN FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 1;

-- Q51: Install base coverage - assets with vs without support contracts
SELECT
    CASE WHEN ib.SERVICE_END_DATETIME > CURRENT_TIMESTAMP() THEN 'Active Support' ELSE 'Lapsed' END AS support_status,
    COUNT(*) AS asset_count,
    COUNT(DISTINCT ib.CUST_SFDCF5_ACCT_ID) AS account_count
FROM COL_INSTALL_BASE ib
GROUP BY 1;

-- ============================================================
-- PERSONA: Product Manager (Lena)
-- Focus: Feature-level insights, product roadmap input
-- ============================================================

-- Q52: Top case drivers by product and area (feature request signal)
SELECT PRODUCT_NAME, AREA_NAME, SUB_AREA_NAME,
    COUNT(*) AS cases,
    COUNT(DISTINCT SFDCF5_ACCT_ID) AS affected_accounts
FROM DIM_SUPPORT_CASE
GROUP BY 1, 2, 3
HAVING COUNT(*) >= 5
ORDER BY 4 DESC;

-- Q53: XC vs BIG-IP case comparison
SELECT
    CASE WHEN PRODUCT_SKU_ID LIKE '%XC%' OR PRODUCT_SKU_ID LIKE '%NGINX%' THEN 'Cloud/SaaS'
         WHEN PRODUCT_SKU_ID LIKE '%BIG%' THEN 'BIG-IP'
         ELSE 'Other' END AS product_category,
    COUNT(*) AS case_count,
    AVG(DATEDIFF(hour, OPENED_DATETIME, COALESCE(RESOLVED_DATETIME, CURRENT_TIMESTAMP()))) AS avg_hours_open,
    SUM(CASE WHEN CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High') THEN 1 ELSE 0 END) AS high_sev
FROM DIM_SUPPORT_CASE
GROUP BY 1;

-- Q54: Version-specific issues (which SW versions generate most cases?)
SELECT ib.SOFTWARE_VERSION_NUM, ib.CORE_PRODUCT_NAME,
    COUNT(DISTINCT ib.SERIAL_NUM) AS deployed_count,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS case_count,
    ROUND(COUNT(DISTINCT sc.SUPPORT_CASE_ID)::FLOAT / NULLIF(COUNT(DISTINCT ib.SERIAL_NUM), 0) * 100, 2) AS case_rate_pct
FROM COL_INSTALL_BASE ib
LEFT JOIN DIM_SUPPORT_CASE sc ON ib.CUST_SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
GROUP BY 1, 2
HAVING COUNT(DISTINCT ib.SERIAL_NUM) >= 3
ORDER BY 5 DESC LIMIT 15;

-- Q55: Bot defense false positive signal from support cases
SELECT a.ACCT_NAME,
    SUM(CASE WHEN b.ACTION_TYPE = 'block' THEN b.VALUE ELSE 0 END) AS total_blocks,
    COUNT(DISTINCT CASE WHEN sc.SUB_AREA_NAME = 'Bot Management' THEN sc.SUPPORT_CASE_ID END) AS bot_cases
FROM DIM_CUST_ACCT_SFDC a
JOIN COL_XC_TELEMETRY_ACCT_MAP_V2 m ON a.SFDCF5_ACCT_ID = m.SFDCF5_ACCT_ID
JOIN BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD b ON m.TENANT_ID = b.TENANT
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
GROUP BY 1
HAVING bot_cases > 0
ORDER BY 3 DESC;

-- ============================================================
-- PERSONA: Regional VP (Marcus)
-- Focus: Region-level performance, team comparison
-- ============================================================

-- Q56: Regional support scorecard
SELECT a.ETM_REGION_NAME AS region,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    COUNT(DISTINCT a.SFDCF5_ACCT_ID) AS accounts_with_cases,
    ROUND(AVG(f.TIME_TO_RESPONSE_MINUTES_NUM), 0) AS avg_response_min,
    ROUND(AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60, 1) AS avg_resolution_hrs,
    SUM(CASE WHEN f.TIME_OVER_UNDER_SLA_MINUTES_NUM > 0 THEN 1 ELSE 0 END) AS sla_breaches
FROM DIM_CUST_ACCT_SFDC a
JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
JOIN FACT_SUPPORT_CASE f ON sc.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
GROUP BY 1 ORDER BY 2 DESC;

-- Q57: Case severity by industry (which verticals need most help?)
SELECT a.INDUSTRY_NAME,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN sc.CURRENT_PRIORITY_CODE = 'P1 - Critical' THEN 1 ELSE 0 END) AS p1_cases,
    ROUND(SUM(CASE WHEN sc.CURRENT_PRIORITY_CODE = 'P1 - Critical' THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) AS p1_pct
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
GROUP BY 1 ORDER BY 2 DESC;

-- Q58: Support team coverage gaps
SELECT sat.AE_NAME, sat.SE_NAME, sat.REGION_NAME,
    COUNT(DISTINCT sat.SFDCF5_ACCT_ID) AS total_accounts,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS total_cases,
    SUM(CASE WHEN sc.CURRENT_PRIORITY_CODE IN ('P1 - Critical','P2 - High')
        AND sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS open_high_sev
FROM SALES_ACCOUNT_TEAM sat
LEFT JOIN DIM_SUPPORT_CASE sc ON sat.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
GROUP BY 1, 2, 3 ORDER BY 6 DESC;

-- ============================================================
-- PERSONA: Compliance / Security (Anita)
-- Focus: Security cases, data patterns, audit readiness
-- ============================================================

-- Q59: Security-related cases by product
SELECT PRODUCT_NAME, COUNT(*) AS security_cases
FROM DIM_SUPPORT_CASE
WHERE AREA_NAME = 'Security'
GROUP BY 1 ORDER BY 2 DESC;

-- Q60: High-priority cases with long first response (potential audit flag)
SELECT d.SUPPORT_CASE_NUM, d.SFDCF5_ACCT_ID, d.SUPPORT_CASE_TITLE_TEXT,
    d.CURRENT_PRIORITY_CODE, f.TIME_TO_RESPONSE_MINUTES_NUM,
    d.SERVICE_LEVEL_CODE
FROM DIM_SUPPORT_CASE d
JOIN FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
WHERE d.CURRENT_PRIORITY_CODE = 'P1 - Critical'
  AND f.TIME_TO_RESPONSE_MINUTES_NUM > 60
ORDER BY f.TIME_TO_RESPONSE_MINUTES_NUM DESC;

-- Q61: Case escalation pattern (priority changed from low to high)
SELECT d.SUPPORT_CASE_NUM, a.ACCT_NAME,
    d.INITIAL_PRIORITY_CODE, d.CURRENT_PRIORITY_CODE,
    d.SUPPORT_CASE_TITLE_TEXT
FROM DIM_SUPPORT_CASE d
JOIN DIM_CUST_ACCT_SFDC a ON d.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE d.INITIAL_PRIORITY_CODE IN ('P3 - Medium', 'P4 - Low')
  AND d.CURRENT_PRIORITY_CODE IN ('P1 - Critical', 'P2 - High');

-- Q62: DDoS and WAF cases correlated with telemetry spikes
SELECT a.ACCT_NAME, sc.SUPPORT_CASE_NUM, sc.CREATED_DATETIME,
    t.OBSERVATION_DATE, t.WAF_USAGE_QTY, t.BOT_ADVANCED_TRANSACTION_CNT
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
JOIN COL_XC_TELEMETRY t ON a.SFDCF5_ACCT_ID = t.SFDCF5_ACCT_ID
    AND t.OBSERVATION_DATE BETWEEN sc.CREATED_DATETIME::DATE - 1 AND sc.CREATED_DATETIME::DATE + 1
WHERE sc.SUB_AREA_NAME IN ('DDoS', 'WAF Policy', 'Bot Management')
ORDER BY t.BOT_ADVANCED_TRANSACTION_CNT DESC LIMIT 20;

-- Q63: Complete case lifecycle summary per account (exec-level)
SELECT a.ACCT_NAME, a.INDUSTRY_NAME, a.ETM_REGION_NAME,
    sat.AE_NAME, sat.SE_NAME,
    COUNT(DISTINCT sc.SUPPORT_CASE_ID) AS lifetime_cases,
    SUM(CASE WHEN sc.SUPPORT_CASE_STATUS_CODE NOT IN ('Closed','Resolved') THEN 1 ELSE 0 END) AS currently_open,
    ROUND(AVG(f.TIME_TO_RESOLUTION_MINUTES_NUM) / 60, 1) AS avg_resolution_hours,
    COUNT(DISTINCT r.ORDER_NUM) AS rma_count,
    MAX(h.CONSUMPTION_PATTERN) AS usage_trend,
    MAX(h.SKU_UTILIZATION_PCT) AS peak_utilization
FROM DIM_CUST_ACCT_SFDC a
LEFT JOIN SALES_ACCOUNT_TEAM sat ON a.SFDCF5_ACCT_ID = sat.SFDCF5_ACCT_ID
LEFT JOIN DIM_SUPPORT_CASE sc ON a.SFDCF5_ACCT_ID = sc.SFDCF5_ACCT_ID
LEFT JOIN FACT_SUPPORT_CASE f ON sc.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
LEFT JOIN FACT_RMA_ORDER r ON a.SFDCF5_ACCT_ID = r.SFDCF5_ACCT_ID
LEFT JOIN COL_XC_PRODUCT_HEALTHSCORE h ON a.SFDCF5_ACCT_ID = h.SFDCF5_ACCT_ID
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(DISTINCT sc.SUPPORT_CASE_ID) > 0
ORDER BY 6 DESC LIMIT 30;
