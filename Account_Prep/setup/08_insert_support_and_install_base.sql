-- ============================================================
-- F5 Hands-On Lab: Insert Support Cases, RMAs, Install Base
-- ============================================================
-- Generates support cases, support metrics, RMA orders,
-- and customer install base data
-- Run as SYSADMIN after 07_insert_date_dimension.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- SUPPORT CASES (DIM_SUPPORT_CASE)
-- ~3-5 cases per account = ~600-1000 cases
-- ============================================================
INSERT INTO DIM_SUPPORT_CASE (
    DIM_SUPPORT_CASE_KEY, SUPPORT_CASE_ID, SUPPORT_CASE_NUM,
    SFDCF5_ACCT_ID, SUPPORT_CASE_TITLE_TEXT, SUPPORT_CASE_STATUS_CODE,
    SUPPORT_CASE_SUB_STATUS_CODE, CURRENT_PRIORITY_CODE,
    INITIAL_PRIORITY_CODE, SUPPORT_CASE_TYPE_CODE, PRODUCT_NAME,
    PRODUCT_SKU_ID, AREA_NAME, SUB_AREA_NAME, CREATED_DATETIME,
    OPENED_DATETIME, RESOLVED_DATETIME, CLOSED_DATETIME,
    FIRST_RESPONSE_DATETIME, CONTACT_FULL_NAME,
    CONTACT_EMAIL_ADDRESS_TEXT, SERVICE_LEVEL_CODE
)
WITH case_templates AS (
    SELECT column1 AS title_template, column2 AS area, column3 AS sub_area,
           column4 AS product, column5 AS sku, column6 AS case_type
    FROM VALUES
        ('BIG-IP LTM failover not triggering during health check failure', 'Networking', 'High Availability', 'BIG-IP LTM', 'F5-BIG-LTM', 'Technical'),
        ('iRule performance degradation after upgrade to v17.1', 'Software', 'Performance', 'BIG-IP LTM', 'F5-BIG-LTM', 'Technical'),
        ('SSL certificate renewal failing on BIG-IP cluster', 'Security', 'Certificates', 'BIG-IP LTM', 'F5-BIG-LTM', 'Technical'),
        ('WAF false positives blocking legitimate API traffic', 'Security', 'WAF Policy', 'BIG-IP ASM', 'F5-BIG-ASM', 'Technical'),
        ('NGINX Plus upstream health checks timing out intermittently', 'Networking', 'Load Balancing', 'NGINX Plus', 'F5-NGINX-PLUS', 'Technical'),
        ('NGINX Ingress Controller OOM kills in Kubernetes cluster', 'Software', 'Kubernetes', 'NGINX Ingress', 'F5-NGINX-INGRESS', 'Technical'),
        ('Distributed Cloud WAF rule update not propagating to all PoPs', 'Security', 'WAF Policy', 'XC WAF', 'F5-XC-WAF', 'Technical'),
        ('XC Bot Defense blocking Googlebot crawler', 'Security', 'Bot Management', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Technical'),
        ('API Security discovery not detecting new endpoints after deploy', 'Security', 'API Discovery', 'XC API Security', 'F5-XC-API-SECURITY', 'Technical'),
        ('Multi-cloud networking latency spike between AWS and Azure sites', 'Networking', 'Connectivity', 'XC App Connect', 'F5-XC-APP-CONNECT', 'Technical'),
        ('BIG-IP hardware fan failure alert on i5600 chassis', 'Hardware', 'Appliance', 'BIG-IP i5600', 'F5-BIG-IP-I5600', 'Hardware'),
        ('License activation failure after RMA replacement unit received', 'Licensing', 'Activation', 'BIG-IP', 'F5-BIG-IP-I4600', 'Administrative'),
        ('Request to increase XC WAF request rate limit for Black Friday', 'Configuration', 'Capacity', 'XC WAF', 'F5-XC-WAF', 'Service Request'),
        ('Need assistance configuring DNS load balancing for disaster recovery', 'Networking', 'DNS', 'XC DNS', 'F5-XC-DNS', 'Technical'),
        ('BIG-IP memory utilization at 95% causing connection drops', 'Software', 'Performance', 'BIG-IP LTM', 'F5-BIG-IP-I7600', 'Technical'),
        ('XC DDoS mitigation did not activate during volumetric attack', 'Security', 'DDoS', 'XC DDoS', 'F5-XC-DDoS', 'Escalation'),
        ('APM session persistence failing after IdP SAML metadata rotation', 'Security', 'Access Management', 'BIG-IP APM', 'F5-BIG-APM', 'Technical'),
        ('Client-Side Defense script injection detection false alarm', 'Security', 'Client Protection', 'XC Client-Side', 'F5-XC-CLIENT-SIDE', 'Technical'),
        ('Request for product roadmap briefing - AI Gateway capabilities', 'Sales', 'Product Info', 'AI Gateway', 'F5-AI-GATEWAY', 'Service Request'),
        ('GTM GSLB not failing over to DR site during primary outage', 'Networking', 'DNS', 'BIG-IP GTM', 'F5-BIG-GTM', 'Escalation')
),
accounts AS (
    SELECT SFDCF5_ACCT_ID, ACCT_NAME,
           ROW_NUMBER() OVER (ORDER BY SFDCF5_ACCT_ID) AS rn
    FROM DIM_CUST_ACCT_SFDC
),
generated AS (
    SELECT
        a.SFDCF5_ACCT_ID,
        a.ACCT_NAME,
        ct.title_template,
        ct.area,
        ct.sub_area,
        ct.product,
        ct.sku,
        ct.case_type,
        ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID, ct.title_template) AS case_num
    FROM accounts a
    CROSS JOIN case_templates ct
    WHERE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || ct.title_template)), 100) < 25
)
SELECT
    MD5(SFDCF5_ACCT_ID || '-case-' || case_num) AS DIM_SUPPORT_CASE_KEY,
    'CS' || LPAD(case_num::VARCHAR, 8, '0') AS SUPPORT_CASE_ID,
    'C-' || LPAD(case_num::VARCHAR, 7, '0') AS SUPPORT_CASE_NUM,
    SFDCF5_ACCT_ID,
    title_template AS SUPPORT_CASE_TITLE_TEXT,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 10)
        WHEN 0 THEN 'Open'
        WHEN 1 THEN 'Open'
        WHEN 2 THEN 'In Progress'
        WHEN 3 THEN 'In Progress'
        WHEN 4 THEN 'Waiting on Customer'
        WHEN 5 THEN 'Resolved'
        WHEN 6 THEN 'Resolved'
        WHEN 7 THEN 'Closed'
        WHEN 8 THEN 'Closed'
        ELSE 'Closed'
    END AS SUPPORT_CASE_STATUS_CODE,
    NULL AS SUPPORT_CASE_SUB_STATUS_CODE,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'pri')), 4)
        WHEN 0 THEN 'P1 - Critical'
        WHEN 1 THEN 'P2 - High'
        WHEN 2 THEN 'P3 - Medium'
        ELSE 'P4 - Low'
    END AS CURRENT_PRIORITY_CODE,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'ipri')), 4)
        WHEN 0 THEN 'P1 - Critical'
        WHEN 1 THEN 'P2 - High'
        WHEN 2 THEN 'P3 - Medium'
        ELSE 'P4 - Low'
    END AS INITIAL_PRIORITY_CODE,
    case_type AS SUPPORT_CASE_TYPE_CODE,
    product AS PRODUCT_NAME,
    sku AS PRODUCT_SKU_ID,
    area AS AREA_NAME,
    sub_area AS SUB_AREA_NAME,
    DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cdt')), 365), CURRENT_TIMESTAMP()) AS CREATED_DATETIME,
    DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cdt')), 365), CURRENT_TIMESTAMP()) AS OPENED_DATETIME,
    CASE WHEN MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 10) >= 5
        THEN DATEADD(hour,
            MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'res')), 720) + 4,
            DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cdt')), 365), CURRENT_TIMESTAMP()))
        ELSE NULL
    END AS RESOLVED_DATETIME,
    CASE WHEN MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 10) >= 7
        THEN DATEADD(hour,
            MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cls')), 720) + 8,
            DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cdt')), 365), CURRENT_TIMESTAMP()))
        ELSE NULL
    END AS CLOSED_DATETIME,
    DATEADD(minute,
        MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'fr')), 240) + 15,
        DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cdt')), 365), CURRENT_TIMESTAMP())
    ) AS FIRST_RESPONSE_DATETIME,
    'Contact ' || MOD(case_num, 50) AS CONTACT_FULL_NAME,
    LOWER(REPLACE(ACCT_NAME, ' ', '.')) || '@' || LOWER(REPLACE(ACCT_NAME, ' ', '')) || '.com' AS CONTACT_EMAIL_ADDRESS_TEXT,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || 'sl')), 3)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Premium Plus'
        ELSE 'Standard'
    END AS SERVICE_LEVEL_CODE
FROM generated;

-- ============================================================
-- FACT_SUPPORT_CASE (Metrics)
-- ============================================================
INSERT INTO FACT_SUPPORT_CASE (
    SUPPORT_CASE_ID, CUST_SFDCF5_ACCT_ID, DIM_SUPPORT_CASE_KEY,
    TIME_TO_CLOSE_MINUTES_NUM, TIME_TO_RESPONSE_MINUTES_NUM,
    TIME_OVER_UNDER_SLA_MINUTES_NUM, TIME_TO_RESOLUTION_MINUTES_NUM
)
SELECT
    SUPPORT_CASE_ID,
    SFDCF5_ACCT_ID,
    DIM_SUPPORT_CASE_KEY,
    CASE WHEN CLOSED_DATETIME IS NOT NULL
        THEN DATEDIFF(minute, OPENED_DATETIME, CLOSED_DATETIME) ELSE NULL END,
    DATEDIFF(minute, OPENED_DATETIME, FIRST_RESPONSE_DATETIME),
    CASE WHEN RESOLVED_DATETIME IS NOT NULL
        THEN DATEDIFF(minute, OPENED_DATETIME, RESOLVED_DATETIME) -
             CASE CURRENT_PRIORITY_CODE
                 WHEN 'P1 - Critical' THEN 240
                 WHEN 'P2 - High' THEN 480
                 WHEN 'P3 - Medium' THEN 1440
                 ELSE 2880
             END
        ELSE NULL END,
    CASE WHEN RESOLVED_DATETIME IS NOT NULL
        THEN DATEDIFF(minute, OPENED_DATETIME, RESOLVED_DATETIME) ELSE NULL END
FROM DIM_SUPPORT_CASE;

-- ============================================================
-- COL_SUPPORT_CASE (Enriched flat table)
-- ============================================================
INSERT INTO COL_SUPPORT_CASE (
    SALES_SFDCF5_ACCT_ID, TERRITORY_OWNER_NAME, TERRITORY_NAME,
    DISTRICT_NAME, REGION_NAME, THEATER_NAME, SERIAL_NUM,
    SUPPORT_CASE_NUM, SUPPORT_CASE_TITLE_TEXT, STATUS, SEVERITY_CODE,
    PRODUCT_SKU_ID, OPEN_DATE, CLOSE_DATE, SUPPORT_CASE_OPEN_DAYS,
    CONTACT_FULL_NAME, CONTACT_EMAIL_ADDRESS_TEXT
)
SELECT
    sc.SFDCF5_ACCT_ID,
    sat.AE_NAME,
    sat.TERRITORY_NAME,
    sat.DISTRICT_NAME,
    sat.REGION_NAME,
    sat.THEATER_NAME,
    'SN' || LPAD(ABS(HASH(sc.SUPPORT_CASE_ID)) % 9999999, 7, '0'),
    sc.SUPPORT_CASE_NUM,
    sc.SUPPORT_CASE_TITLE_TEXT,
    sc.SUPPORT_CASE_STATUS_CODE,
    sc.CURRENT_PRIORITY_CODE,
    sc.PRODUCT_SKU_ID,
    sc.OPENED_DATETIME,
    sc.CLOSED_DATETIME,
    DATEDIFF(day, sc.OPENED_DATETIME, COALESCE(sc.CLOSED_DATETIME, CURRENT_TIMESTAMP())),
    sc.CONTACT_FULL_NAME,
    sc.CONTACT_EMAIL_ADDRESS_TEXT
FROM DIM_SUPPORT_CASE sc
LEFT JOIN SALES_ACCOUNT_TEAM sat ON sc.SFDCF5_ACCT_ID = sat.SFDCF5_ACCT_ID;

-- ============================================================
-- FACT_RMA_ORDER (~50 RMA orders for hardware issues)
-- ============================================================
INSERT INTO FACT_RMA_ORDER (
    ORDER_NUM, SFDCF5_ACCT_ID, ORDER_DATETIME, RMA_SYSTEM_PART_NUM,
    RMA_APPLIANCE_PART_NUM, RMA_SYSTEM_SERIAL_NUM,
    RMA_APPLIANCE_SERIAL_NUM, SHIPPED_QTY, STATUS_CODE, SHIP_DATE,
    SUPPORT_CASE_NUM, SYMPTOM_CLASS_CODE, SYMPTOM_DESC,
    RMA_DOA_FLAG, APPROVED_FLAG, CLOSED_FLAG,
    SHIP_TO_CITY_NAME, SHIP_TO_COUNTRY_NAME, SHIP_TO_STATE_ABV,
    REPLACEMENT_SERIAL_NUM, CREATED_DATETIME
)
SELECT
    'RMA' || LPAD(ROW_NUMBER() OVER (ORDER BY sc.SUPPORT_CASE_ID)::VARCHAR, 6, '0'),
    sc.SFDCF5_ACCT_ID,
    sc.CREATED_DATETIME,
    sc.PRODUCT_SKU_ID,
    sc.PRODUCT_SKU_ID || '-APL',
    'SYS' || LPAD(ABS(HASH(sc.SUPPORT_CASE_ID || 'sys')) % 999999, 6, '0'),
    'APL' || LPAD(ABS(HASH(sc.SUPPORT_CASE_ID || 'apl')) % 999999, 6, '0'),
    1,
    CASE MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'rma')), 3)
        WHEN 0 THEN 'Shipped'
        WHEN 1 THEN 'Closed'
        ELSE 'Approved'
    END,
    DATEADD(day, 3, sc.CREATED_DATETIME)::DATE,
    sc.SUPPORT_CASE_NUM,
    CASE MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'sym')), 5)
        WHEN 0 THEN 'Power Supply'
        WHEN 1 THEN 'Fan Module'
        WHEN 2 THEN 'Memory'
        WHEN 3 THEN 'Storage'
        ELSE 'Network Interface'
    END,
    CASE MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'sym')), 5)
        WHEN 0 THEN 'Power supply failed; system running on redundant PSU'
        WHEN 1 THEN 'Fan module reporting critical RPM; thermal warning triggered'
        WHEN 2 THEN 'ECC memory errors detected; DIMM replacement required'
        WHEN 3 THEN 'SSD reporting SMART failure prediction; proactive replacement'
        ELSE 'Network interface card link flapping; intermittent connectivity'
    END,
    CASE WHEN MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'doa')), 10) = 0 THEN 'Y' ELSE 'N' END,
    'Y',
    CASE WHEN MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'rma')), 3) = 1 THEN 'Y' ELSE 'N' END,
    a.BILLING_CITY_NAME,
    'United States',
    LEFT(a.BILLING_STATE_PROVINCE_NAME, 2),
    'RPL' || LPAD(ABS(HASH(sc.SUPPORT_CASE_ID || 'rpl')) % 999999, 6, '0'),
    sc.CREATED_DATETIME
FROM DIM_SUPPORT_CASE sc
JOIN DIM_CUST_ACCT_SFDC a ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
WHERE sc.AREA_NAME = 'Hardware'
   OR (sc.PRODUCT_SKU_ID LIKE 'F5-BIG-IP-I%' AND MOD(ABS(HASH(sc.SUPPORT_CASE_ID || 'rma')), 100) < 30);

-- ============================================================
-- COL_INSTALL_BASE (Hardware & software deployed at customers)
-- ============================================================
INSERT INTO COL_INSTALL_BASE (
    OFFER_SKU_ID, OFFER_DESC, CUST_SFDCF5_ACCT_ID, SALES_SFDCF5_ACCT_ID,
    ACCOUNT_NAME, CORE_PRODUCT_NAME, HARDWARE_PLATFORM_CODE, PLATFORM,
    SERIAL_NUM, SHIP_DATE, SOFTWARE_VERSION_NUM, SERVICE_END_DATETIME,
    ACCOUNT_OWNER, ETM_TERRITORY_NAME, ETM_REGION_NAME, ETM_THEATER_NAME,
    BILLING_COUNTRY_NAME
)
WITH products_to_install AS (
    SELECT PRODUCT_ID, OFFER_SKU_ID, OFFER_DESC, CORE_PRODUCT_NAME,
           HARDWARE_PLATFORM_CODE, PRODUCT_OFFERING_TYPE_NAME
    FROM DIM_PRODUCT_OFFER
    WHERE OFFER_STATUS_CODE = 'Active'
      AND PRODUCT_OFFERING_TYPE_NAME IN ('Hardware', 'Software', 'Software Module')
),
account_installs AS (
    SELECT
        a.SFDCF5_ACCT_ID, a.ACCT_NAME, a.ACCT_OWNER_NAME,
        a.ETM_TERRITORY_NAME, a.ETM_REGION_NAME, a.BILLING_COUNTRY_NAME,
        p.OFFER_SKU_ID, p.OFFER_DESC, p.CORE_PRODUCT_NAME,
        p.HARDWARE_PLATFORM_CODE, p.PRODUCT_OFFERING_TYPE_NAME,
        ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID, p.OFFER_SKU_ID) AS rn
    FROM DIM_CUST_ACCT_SFDC a
    CROSS JOIN products_to_install p
    WHERE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || p.OFFER_SKU_ID)), 100) < 12
)
SELECT
    OFFER_SKU_ID,
    OFFER_DESC,
    SFDCF5_ACCT_ID,
    SFDCF5_ACCT_ID,
    ACCT_NAME,
    CORE_PRODUCT_NAME,
    HARDWARE_PLATFORM_CODE,
    CASE WHEN PRODUCT_OFFERING_TYPE_NAME = 'Hardware' THEN HARDWARE_PLATFORM_CODE
         ELSE 'Virtual'
    END,
    'SN' || LPAD(rn::VARCHAR, 9, '0'),
    DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || OFFER_SKU_ID || 'ship')), 1095), CURRENT_TIMESTAMP()),
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || OFFER_SKU_ID || 'ver')), 4)
        WHEN 0 THEN '17.1.1'
        WHEN 1 THEN '16.1.4'
        WHEN 2 THEN '15.1.10'
        ELSE '17.0.0'
    END,
    DATEADD(day, MOD(ABS(HASH(SFDCF5_ACCT_ID || OFFER_SKU_ID || 'svc')), 730) + 30, CURRENT_TIMESTAMP()),
    ACCT_OWNER_NAME,
    ETM_TERRITORY_NAME,
    ETM_REGION_NAME,
    'Americas',
    BILLING_COUNTRY_NAME
FROM account_installs;

-- Verify counts
SELECT 'DIM_SUPPORT_CASE' AS tbl, COUNT(*) AS cnt FROM DIM_SUPPORT_CASE
UNION ALL SELECT 'FACT_SUPPORT_CASE', COUNT(*) FROM FACT_SUPPORT_CASE
UNION ALL SELECT 'COL_SUPPORT_CASE', COUNT(*) FROM COL_SUPPORT_CASE
UNION ALL SELECT 'FACT_RMA_ORDER', COUNT(*) FROM FACT_RMA_ORDER
UNION ALL SELECT 'COL_INSTALL_BASE', COUNT(*) FROM COL_INSTALL_BASE;
