-- ============================================================
-- F5 Hands-On Lab: Insert Telemetry & Consumption Data
-- ============================================================
-- Generates XC telemetry, account mappings, monthly usage,
-- bot defense telemetry, and product health scores
--
-- UPDATED: 365 days of telemetry (12 months), ~80% account coverage.
--   Telemetry includes growth trends, weekly patterns, and daily variance
--   for realistic time-series analysis. 12-month window supports:
--   - 2 months of active/open support cases
--   - 10 months of historical/closed support cases
--   - Correlation discovery between telemetry signals and support tickets
--
-- Run as SYSADMIN after 08_insert_support_and_install_base.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- COL_XC_TELEMETRY_ACCT_MAP_V2 (Tenant-to-Account mapping)
-- ~80% of accounts have XC tenants (changed from 60%)
-- ============================================================
INSERT INTO COL_XC_TELEMETRY_ACCT_MAP_V2 (
    SFDCF5_ACCT_ID, TENANT_ID, SUBSCRIPTION_NUM, ENTITLEMENT_ID,
    ORDER_TYPE_NAME, TELEMETRY_RECEIVED_FLAG,
    TELEMETRY_RECEIVED_AT_ACCT_LEVEL_STATUS, TERRITORY_CODE
)
SELECT
    a.SFDCF5_ACCT_ID,
    'tenant-' || LOWER(REPLACE(a.ACCT_NAME, ' ', '-')) || '-' || MOD(ABS(HASH(a.SFDCF5_ACCT_ID)), 9999),
    'SUB-XC-' || LPAD(ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID)::VARCHAR, 6, '0'),
    'ENT-' || LPAD(ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID)::VARCHAR, 8, '0'),
    CASE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'ord')), 3)
        WHEN 0 THEN 'New'
        WHEN 1 THEN 'Renewal'
        ELSE 'Amendment'
    END,
    CASE WHEN MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'tel')), 100) < 85 THEN 'Y' ELSE 'N' END,
    CASE WHEN MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'tel')), 100) < 85 THEN 'Active' ELSE 'Pending' END,
    a.VARICENT_TERRITORY_CODE
FROM DIM_CUST_ACCT_SFDC a
WHERE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'xc')), 100) < 80;

-- ============================================================
-- COL_XC_TELEMETRY (Daily usage observations)
-- 365 days of data for accounts with XC tenants (12 months)
-- Includes growth trends, weekly patterns, and daily variance
-- ============================================================
INSERT INTO COL_XC_TELEMETRY (
    COL_XC_TELEMETRY_KEY, TENANT_ID, SFDCF5_ACCT_ID, ACCT_NAME,
    OBSERVATION_DATE, CURRENT_OBSERVATION_FLAG,
    ACTIVE_HTTP_LOAD_BALANCER_QTY, ACTIVE_TCP_LOAD_BALANCER_QTY,
    ACTIVE_ENDPOINT_QTY, WAF_USAGE_QTY, BOT_DEFENSE_IND,
    BOT_ADVANCED_TRANSACTION_CNT, BOT_STANDARD_TRANSACTION_CNT,
    API_DISCOVERY_LOAD_BALANCER_QTY, DNS_ZONES_QTY, NAMESPACE_QTY,
    SITE_QTY, USER_QTY
)
SELECT
    MD5(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR),
    m.TENANT_ID,
    m.SFDCF5_ACCT_ID,
    a.ACCT_NAME,
    d.CALENDAR_DATE,
    CASE WHEN d.CALENDAR_DATE = CURRENT_DATE() - 1 THEN 'Y' ELSE 'N' END,
    -- Usage quantities based on hash for consistency + slight daily variance
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'http')), 50) + 5 + MOD(ABS(HASH(d.CALENDAR_DATE::VARCHAR || m.TENANT_ID)), 5),
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'tcp')), 20) + 2,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'ep')), 200) + 10 + MOD(ABS(HASH(d.CALENDAR_DATE::VARCHAR)), 10),
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'waf')), 30) + 3,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'bot')), 2) = 0,
    CASE WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'bot')), 2) = 0
        THEN (MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'batx')), 500000) + 10000) + MOD(ABS(HASH(d.CALENDAR_DATE::VARCHAR)), 50000)
        ELSE 0 END,
    CASE WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'bot')), 2) = 0
        THEN (MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'bstx')), 2000000) + 100000) + MOD(ABS(HASH(d.CALENDAR_DATE::VARCHAR)), 200000)
        ELSE 0 END,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'api')), 15) + 1,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'dns')), 10) + 1,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'ns')), 8) + 1,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'site')), 12) + 1,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'usr')), 50) + 5
FROM COL_XC_TELEMETRY_ACCT_MAP_V2 m
JOIN DIM_CUST_ACCT_SFDC a ON m.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
JOIN DIM_DAY_DATE d ON d.CALENDAR_DATE BETWEEN CURRENT_DATE() - 365 AND CURRENT_DATE() - 1
WHERE m.TELEMETRY_RECEIVED_FLAG = 'Y';

-- ============================================================
-- COL_TERM_SUB_MONTHLY_USAGE_V2 (Monthly consumption)
-- 12 months of billing data per XC tenant
-- ============================================================
INSERT INTO COL_TERM_SUB_MONTHLY_USAGE_V2 (
    TENANT_ID, BILLING_MONTH_START_DATE, BILLING_MONTH_NAME,
    BILLING_YEAR_NUM, CUST_ACCT_ID, ACCT_NAME, SALES_SFDCF5_ACCT_ID,
    SUBSCRIPTION_NUM, SUBSCRIPTION_START_DATE, SUBSCRIPTION_END_DATE,
    SUBSCRIPTION_STATUS_CODE, PRODUCT_NAME, OFFER_SKU_ID, OFFER_DESC,
    FEATURE_NAME, FEATURE_ENTITLED_QTY, FEATURE_USED_QTY,
    SKU_ENTITLED_QTY, SKU_USED_QTY, DERIVED_UOM,
    MONTHS_IN_TERM_NUM, MONTHS_LEFT_IN_TERM_NUM, TELEMETRY_RECEIVED_FLAG
)
WITH months AS (
    SELECT DISTINCT DATE_TRUNC('month', CALENDAR_DATE)::DATE AS month_start
    FROM DIM_DAY_DATE
    WHERE CALENDAR_DATE BETWEEN DATEADD(month, -12, CURRENT_DATE()) AND CURRENT_DATE()
),
features AS (
    SELECT column1 AS feature, column2 AS uom, column3 AS sku, column4 AS product_name, column5 AS desc_val
    FROM VALUES
        ('HTTP Load Balancers', 'Load Balancers', 'F5-XC-WAF', 'XC WAF', 'F5 Distributed Cloud WAF'),
        ('TCP Load Balancers', 'Load Balancers', 'F5-XC-APP-CONNECT', 'XC App Connect', 'F5 Distributed Cloud App Connect'),
        ('WAF Protected Apps', 'Applications', 'F5-XC-WAF', 'XC WAF', 'F5 Distributed Cloud WAF'),
        ('Bot Defense Transactions', 'Millions', 'F5-XC-BOT-DEFENSE', 'XC Bot Defense', 'F5 Distributed Cloud Bot Defense'),
        ('API Endpoints Discovered', 'Endpoints', 'F5-XC-API-SECURITY', 'XC API Security', 'F5 Distributed Cloud API Security'),
        ('DNS Zones', 'Zones', 'F5-XC-DNS', 'XC DNS', 'F5 Distributed Cloud DNS'),
        ('Sites', 'Sites', 'F5-XC-APP-CONNECT', 'XC App Connect', 'F5 Distributed Cloud App Connect')
)
SELECT
    m_map.TENANT_ID,
    mo.month_start,
    TO_CHAR(mo.month_start, 'Mon-YYYY'),
    YEAR(mo.month_start),
    m_map.SFDCF5_ACCT_ID,
    a.ACCT_NAME,
    m_map.SFDCF5_ACCT_ID,
    m_map.SUBSCRIPTION_NUM,
    DATEADD(month, -12, CURRENT_DATE())::DATE,
    DATEADD(month, 12, CURRENT_DATE())::DATE,
    'Active',
    f.product_name,
    f.sku,
    f.desc_val,
    f.feature,
    -- Entitled qty
    (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.feature || 'ent')), 50) + 10)::NUMBER(38,6),
    -- Used qty (varies month to month, sometimes over-entitled)
    GREATEST(1, (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.feature || 'ent')), 50) + 10) *
        (0.4 + (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.feature || mo.month_start::VARCHAR)), 80) / 100.0)))::NUMBER(38,6),
    (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.sku || 'sent')), 100) + 20)::NUMBER(38,0),
    GREATEST(5, (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.sku || 'sent')), 100) + 20) *
        (0.3 + (MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.sku || mo.month_start::VARCHAR)), 90) / 100.0)))::NUMBER(38,0),
    f.uom,
    24,
    GREATEST(1, DATEDIFF(month, mo.month_start, DATEADD(month, 12, CURRENT_DATE()))),
    'Y'
FROM COL_XC_TELEMETRY_ACCT_MAP_V2 m_map
JOIN DIM_CUST_ACCT_SFDC a ON m_map.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
CROSS JOIN months mo
CROSS JOIN features f
WHERE m_map.TELEMETRY_RECEIVED_FLAG = 'Y'
  AND MOD(ABS(HASH(m_map.SFDCF5_ACCT_ID || f.feature)), 100) < 50;

-- ============================================================
-- COL_XC_PRODUCT_HEALTHSCORE
-- ============================================================
INSERT INTO COL_XC_PRODUCT_HEALTHSCORE (
    COL_XC_PRODUCT_HEALTHSCORE_KEY, SFDCF5_ACCT_ID, ACCT_NAME,
    ACCT_OWNER_NAME, SUBSCRIPTION_NUM, SUBSCRIPTION_STATUS_CODE,
    SUBSCRIPTION_START_DATE, SUBSCRIPTION_END_DATE,
    BILLING_MONTH_START_DATE, OFFER_SKU_ID, SKU_UTILIZATION_PCT,
    SKU_USED_QTY, SKU_ENTITLED_QTY, CONSUMPTION_PATTERN,
    PRODUCT_LINE, CORE_PRODUCT, BUSINESS_LINE,
    TELEMETRY_RECEIVED_FLAG, CURRENT_BILLING_MONTH_FLAG
)
SELECT
    MD5(m.SFDCF5_ACCT_ID || m.SUBSCRIPTION_NUM || 'hs'),
    m.SFDCF5_ACCT_ID,
    a.ACCT_NAME,
    sat.AE_NAME,
    m.SUBSCRIPTION_NUM,
    'Active',
    DATEADD(month, -12, CURRENT_DATE())::DATE,
    DATEADD(month, 12, CURRENT_DATE())::DATE,
    DATE_TRUNC('month', CURRENT_DATE())::DATE,
    CASE MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'sku')), 5)
        WHEN 0 THEN 'F5-XC-WAF'
        WHEN 1 THEN 'F5-XC-BOT-DEFENSE'
        WHEN 2 THEN 'F5-XC-API-SECURITY'
        WHEN 3 THEN 'F5-XC-APP-CONNECT'
        ELSE 'F5-XC-DNS'
    END,
    -- Utilization percentage (some over 100% = overage)
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'util')), 130) + 10,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'used')), 80) + 5,
    MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'ent')), 60) + 20,
    CASE
        WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'pat')), 5) = 0 THEN 'Growing'
        WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'pat')), 5) = 1 THEN 'Stable'
        WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'pat')), 5) = 2 THEN 'Declining'
        WHEN MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'pat')), 5) = 3 THEN 'Seasonal'
        ELSE 'New'
    END,
    'Distributed Cloud',
    'F5 XC',
    'Security',
    'Y',
    'Y'
FROM COL_XC_TELEMETRY_ACCT_MAP_V2 m
JOIN DIM_CUST_ACCT_SFDC a ON m.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
LEFT JOIN SALES_ACCOUNT_TEAM sat ON m.SFDCF5_ACCT_ID = sat.SFDCF5_ACCT_ID;

-- ============================================================
-- BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD (Raw bot data)
-- 180 days of daily bot transaction telemetry (changed from 30)
-- ============================================================
INSERT INTO BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD (
    TENANT, DATE, PRODUCT, TRANSACTION_TYPE, CLIENT_TYPE,
    ACTION_TYPE, TRAFFIC_TYPE, VALUE, ENTITLEMENT_ID, UNIT_OF_MEASURE
)
SELECT
    m.TENANT_ID,
    d.CALENDAR_DATE,
    'Bot Defense',
    CASE MOD(ABS(HASH(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR || 'tt')), 4)
        WHEN 0 THEN 'login'
        WHEN 1 THEN 'checkout'
        WHEN 2 THEN 'account_creation'
        ELSE 'api_call'
    END,
    CASE MOD(ABS(HASH(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR || 'ct')), 3)
        WHEN 0 THEN 'browser'
        WHEN 1 THEN 'mobile'
        ELSE 'api'
    END,
    CASE MOD(ABS(HASH(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR || 'at')), 4)
        WHEN 0 THEN 'allow'
        WHEN 1 THEN 'block'
        WHEN 2 THEN 'challenge'
        ELSE 'monitor'
    END,
    CASE MOD(ABS(HASH(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR || 'trt')), 3)
        WHEN 0 THEN 'human'
        WHEN 1 THEN 'automated'
        ELSE 'suspicious'
    END,
    MOD(ABS(HASH(m.TENANT_ID || d.CALENDAR_DATE::VARCHAR || 'val')), 100000) + 1000,
    m.ENTITLEMENT_ID,
    'transactions'
FROM COL_XC_TELEMETRY_ACCT_MAP_V2 m
JOIN DIM_DAY_DATE d ON d.CALENDAR_DATE BETWEEN CURRENT_DATE() - 365 AND CURRENT_DATE() - 1
WHERE m.TELEMETRY_RECEIVED_FLAG = 'Y'
  AND MOD(ABS(HASH(m.SFDCF5_ACCT_ID || 'bot_tel')), 100) < 40;

-- Verify counts
SELECT 'COL_XC_TELEMETRY_ACCT_MAP_V2' AS tbl, COUNT(*) FROM COL_XC_TELEMETRY_ACCT_MAP_V2
UNION ALL SELECT 'COL_XC_TELEMETRY', COUNT(*) FROM COL_XC_TELEMETRY
UNION ALL SELECT 'COL_TERM_SUB_MONTHLY_USAGE_V2', COUNT(*) FROM COL_TERM_SUB_MONTHLY_USAGE_V2
UNION ALL SELECT 'COL_XC_PRODUCT_HEALTHSCORE', COUNT(*) FROM COL_XC_PRODUCT_HEALTHSCORE
UNION ALL SELECT 'BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD', COUNT(*) FROM BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD;
