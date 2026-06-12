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
-- ~1000+ cases correlated to each account's telemetry signal
-- Cases from last 2 months = Open/In Progress
-- Cases from months 3-12 = Closed/Resolved
-- No duplicate symptoms within a single calendar month per account
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
WITH acct_signals AS (
    SELECT a.ACCT_NAME, a.SFDCF5_ACCT_ID,
        CASE
            WHEN AVG(t.BOT_ADVANCED_TRANSACTION_CNT) > 300000 THEN 'bot-defense'
            WHEN AVG(t.WAF_USAGE_QTY) > 25 THEN 'waf'
            WHEN AVG(t.ACTIVE_ENDPOINT_QTY) > 150 THEN 'capacity'
            WHEN AVG(t.ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 THEN 'load-balancer'
            WHEN AVG(t.DNS_ZONES_QTY) > 7 THEN 'dns'
            ELSE 'load-balancer'
        END as primary_signal
    FROM COL_XC_TELEMETRY t
    JOIN DIM_CUST_ACCT_SFDC a ON t.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
    GROUP BY 1, 2
),
case_templates AS (
    SELECT column1 AS signal_cat, column2 AS template_idx, column3 AS title,
           column4 AS product, column5 AS sku, column6 AS area, column7 AS sub_area, column8 AS case_type
    FROM VALUES
    -- bot-defense (8)
    ('bot-defense', 1, 'Legitimate checkout flow being challenged during flash sale event', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    ('bot-defense', 2, 'Mobile app users blocked after OS update - bot SDK false positive', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    ('bot-defense', 3, 'Partner API integration classified as automated traffic', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    ('bot-defense', 4, 'Credential stuffing bypassing detection on /auth endpoint', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Escalation'),
    ('bot-defense', 5, 'Bot score regression after model update causing false positives', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    ('bot-defense', 6, 'JavaScript challenge breaking single-page application navigation', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    ('bot-defense', 7, 'Geo-distributed scraping attack evading IP-based detection', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Escalation'),
    ('bot-defense', 8, 'Webhook callbacks from payment processors being blocked', 'XC Bot Defense', 'F5-XC-BOT-DEFENSE', 'Security', 'Bot Management', 'Technical'),
    -- waf (8)
    ('waf', 1, 'GraphQL introspection queries triggering SQL injection rules', 'XC WAF', 'F5-XC-WAF', 'Security', 'WAF Policy', 'Technical'),
    ('waf', 2, 'CORS preflight requests denied after WAF rule propagation', 'XC WAF', 'F5-XC-WAF', 'Security', 'WAF Policy', 'Technical'),
    ('waf', 3, 'File upload endpoint blocking legitimate PDF attachments', 'BIG-IP ASM', 'F5-BIG-ASM', 'Security', 'WAF Policy', 'Technical'),
    ('waf', 4, 'REST API request body exceeding WAF inspection buffer limit', 'XC WAF', 'F5-XC-WAF', 'Configuration', 'Capacity', 'Technical'),
    ('waf', 5, 'Rate limiting rules conflicting with internal service mesh traffic', 'XC WAF', 'F5-XC-WAF', 'Security', 'WAF Policy', 'Technical'),
    ('waf', 6, 'Custom security header stripped by WAF transformation rules', 'BIG-IP ASM', 'F5-BIG-ASM', 'Security', 'WAF Policy', 'Technical'),
    ('waf', 7, 'WebSocket upgrade blocked after rule set version change', 'XC WAF', 'F5-XC-WAF', 'Security', 'WAF Policy', 'Escalation'),
    ('waf', 8, 'Multipart form data with unicode filenames triggering encoding rule', 'XC WAF', 'F5-XC-WAF', 'Security', 'WAF Policy', 'Technical'),
    -- capacity (8)
    ('capacity', 1, 'Endpoint count at 92% of contracted entitlement growing 3% weekly', 'XC WAF', 'F5-XC-WAF', 'Configuration', 'Capacity', 'Service Request'),
    ('capacity', 2, 'Namespace resource quota preventing new service deployments', 'XC App Connect', 'F5-XC-APP-CONNECT', 'Configuration', 'Capacity', 'Technical'),
    ('capacity', 3, 'Concurrent connection count exceeding tier during peak hours', 'XC WAF', 'F5-XC-WAF', 'Configuration', 'Capacity', 'Technical'),
    ('capacity', 4, 'WAF request processing at capacity causing increased latency', 'XC WAF', 'F5-XC-WAF', 'Configuration', 'Capacity', 'Escalation'),
    ('capacity', 5, 'API call volume projected to exceed monthly quota within 2 weeks', 'XC API Security', 'F5-XC-API-SECURITY', 'Configuration', 'Capacity', 'Service Request'),
    ('capacity', 6, 'Security event log storage exceeding retention policy threshold', 'XC WAF', 'F5-XC-WAF', 'Configuration', 'Capacity', 'Technical'),
    ('capacity', 7, 'Site count approaching hard limit for current subscription tier', 'XC App Connect', 'F5-XC-APP-CONNECT', 'Configuration', 'Capacity', 'Service Request'),
    ('capacity', 8, 'Load balancer pool member count maxed causing health check overhead', 'BIG-IP LTM', 'F5-BIG-LTM', 'Configuration', 'Capacity', 'Technical'),
    -- load-balancer (16 templates - includes performance issues on LB products)
    ('load-balancer', 1, 'Health check failures during blue-green deployment cutover', 'BIG-IP LTM', 'F5-BIG-LTM', 'Networking', 'High Availability', 'Technical'),
    ('load-balancer', 2, 'Connection draining not completing before new deployment activates', 'NGINX Plus', 'F5-NGINX-PLUS', 'Networking', 'Load Balancing', 'Technical'),
    ('load-balancer', 3, 'Origin TLS certificate chain validation failing intermittently', 'BIG-IP LTM', 'F5-BIG-LTM', 'Security', 'Certificates', 'Technical'),
    ('load-balancer', 4, 'Sticky session persistence breaking during horizontal scale events', 'BIG-IP LTM', 'F5-BIG-LTM', 'Networking', 'High Availability', 'Technical'),
    ('load-balancer', 5, 'Weighted routing not reflecting updated backend capacity ratios', 'BIG-IP LTM', 'F5-BIG-LTM', 'Networking', 'Load Balancing', 'Technical'),
    ('load-balancer', 6, 'IPv6 to IPv4 translation causing source IP preservation issues', 'NGINX Plus', 'F5-NGINX-PLUS', 'Networking', 'Load Balancing', 'Technical'),
    ('load-balancer', 7, 'TCP connection pool exhaustion under sustained high throughput', 'BIG-IP LTM', 'F5-BIG-LTM', 'Software', 'Performance', 'Escalation'),
    ('load-balancer', 8, 'HTTP/2 server push not functioning through load balancer proxy', 'NGINX Plus', 'F5-NGINX-PLUS', 'Networking', 'Load Balancing', 'Technical'),
    ('load-balancer', 9, 'P99 latency regression after configuration deployment last Tuesday', 'BIG-IP LTM', 'F5-BIG-LTM', 'Software', 'Performance', 'Technical'),
    ('load-balancer', 10, 'Cache hit ratio collapsed from 82% to 34% after origin failover', 'BIG-IP LTM', 'F5-BIG-LTM', 'Software', 'Performance', 'Technical'),
    ('load-balancer', 11, 'TLS handshake overhead adding 65ms for clients with older ciphers', 'BIG-IP LTM', 'F5-BIG-LTM', 'Security', 'Certificates', 'Technical'),
    ('load-balancer', 12, 'Edge function cold start latency exceeding 800ms SLA threshold', 'XC App Connect', 'F5-XC-APP-CONNECT', 'Software', 'Performance', 'Technical'),
    ('load-balancer', 13, 'Connection keep-alive timeout mismatch causing premature resets', 'NGINX Plus', 'F5-NGINX-PLUS', 'Networking', 'Load Balancing', 'Technical'),
    ('load-balancer', 14, 'Response compression not activating for application/json content', 'NGINX Plus', 'F5-NGINX-PLUS', 'Software', 'Performance', 'Technical'),
    ('load-balancer', 15, 'iRule execution time degradation after upgrade to v17.1', 'BIG-IP LTM', 'F5-BIG-LTM', 'Software', 'Performance', 'Escalation'),
    ('load-balancer', 16, 'Memory utilization at 95% causing intermittent connection drops', 'BIG-IP LTM', 'F5-BIG-LTM', 'Software', 'Performance', 'Technical'),
    -- dns (8)
    ('dns', 1, 'Zone transfer propagation taking 18 minutes between edge PoPs', 'XC DNS', 'F5-XC-DNS', 'Networking', 'DNS', 'Technical'),
    ('dns', 2, 'GSLB not detecting primary site health degradation', 'BIG-IP GTM', 'F5-BIG-GTM', 'Networking', 'DNS', 'Escalation'),
    ('dns', 3, 'CNAME flattening producing unexpected resolution for apex domain', 'XC DNS', 'F5-XC-DNS', 'Networking', 'DNS', 'Technical'),
    ('dns', 4, 'Geo-routing sending VPN users to incorrect regional endpoint', 'BIG-IP GTM', 'F5-BIG-GTM', 'Networking', 'DNS', 'Technical'),
    ('dns', 5, 'DNSSEC validation failures for records signed with expiring ZSK', 'XC DNS', 'F5-XC-DNS', 'Networking', 'DNS', 'Technical'),
    ('dns', 6, 'Split-horizon DNS not separating internal from external resolution', 'BIG-IP GTM', 'F5-BIG-GTM', 'Networking', 'DNS', 'Technical'),
    ('dns', 7, 'DNS failover SLA breach during datacenter maintenance window', 'XC DNS', 'F5-XC-DNS', 'Networking', 'DNS', 'Escalation'),
    ('dns', 8, 'Recursive resolver timeout causing intermittent name resolution', 'BIG-IP GTM', 'F5-BIG-GTM', 'Networking', 'DNS', 'Technical')
),
month_template_combos AS (
    SELECT
        s.value::INT as month_offset,
        t.value::INT as template_pick
    FROM TABLE(FLATTEN(ARRAY_GENERATE_RANGE(0, 12))) s,
         TABLE(FLATTEN(ARRAY_GENERATE_RANGE(1, 17))) t
),
generated AS (
    SELECT
        a.SFDCF5_ACCT_ID, a.ACCT_NAME, a.primary_signal,
        ct.title, ct.product, ct.sku, ct.area, ct.sub_area, ct.case_type,
        ct.template_idx, mc.month_offset,
        ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID, mc.month_offset, ct.template_idx) as case_num
    FROM acct_signals a
    JOIN month_template_combos mc ON 1=1
    JOIN case_templates ct ON ct.signal_cat = a.primary_signal AND ct.template_idx = mc.template_pick
    WHERE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || ct.template_idx::VARCHAR || mc.month_offset::VARCHAR)), 100) < 9
),
deduped AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY SFDCF5_ACCT_ID, title, FLOOR(month_offset)
        ORDER BY case_num
    ) as rn
    FROM generated
)
SELECT
    MD5(SFDCF5_ACCT_ID || '-case-' || case_num) AS DIM_SUPPORT_CASE_KEY,
    'CS' || LPAD(case_num::VARCHAR, 8, '0') AS SUPPORT_CASE_ID,
    'C-' || LPAD(case_num::VARCHAR, 7, '0') AS SUPPORT_CASE_NUM,
    SFDCF5_ACCT_ID,
    title AS SUPPORT_CASE_TITLE_TEXT,
    CASE
        WHEN month_offset < 2 THEN
            CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 2)
                WHEN 0 THEN 'Open' ELSE 'In Progress' END
        ELSE
            CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 5)
                WHEN 0 THEN 'Resolved' WHEN 1 THEN 'Resolved'
                WHEN 2 THEN 'Closed' WHEN 3 THEN 'Closed'
                ELSE 'Waiting on Customer' END
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
    DATEADD(day,
        -(month_offset * 30 + MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'day')), 28)),
        CURRENT_TIMESTAMP()) AS CREATED_DATETIME,
    DATEADD(day,
        -(month_offset * 30 + MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'day')), 28)),
        CURRENT_TIMESTAMP()) AS OPENED_DATETIME,
    CASE WHEN month_offset >= 2 THEN
        DATEADD(hour,
            MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'res')), 720) + 4,
            DATEADD(day, -(month_offset * 30 + MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'day')), 28)), CURRENT_TIMESTAMP()))
        ELSE NULL END AS RESOLVED_DATETIME,
    CASE WHEN month_offset >= 2 AND MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'st')), 5) IN (2,3) THEN
        DATEADD(hour,
            MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'cls')), 720) + 8,
            DATEADD(day, -(month_offset * 30 + MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'day')), 28)), CURRENT_TIMESTAMP()))
        ELSE NULL
    END AS CLOSED_DATETIME,
    DATEADD(minute,
        MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'fr')), 240) + 15,
        DATEADD(day, -(month_offset * 30 + MOD(ABS(HASH(SFDCF5_ACCT_ID || case_num::VARCHAR || 'day')), 28)), CURRENT_TIMESTAMP())
    ) AS FIRST_RESPONSE_DATETIME,
    'Contact ' || MOD(case_num, 50) AS CONTACT_FULL_NAME,
    LOWER(REPLACE(ACCT_NAME, ' ', '.')) || '@' || LOWER(REPLACE(ACCT_NAME, ' ', '')) || '.com' AS CONTACT_EMAIL_ADDRESS_TEXT,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || 'sl')), 3)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Premium Plus'
        ELSE 'Standard'
    END AS SERVICE_LEVEL_CODE
FROM deduped
WHERE rn = 1;

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
