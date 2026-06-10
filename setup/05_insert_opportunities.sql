-- ============================================================
-- F5 Hands-On Lab: Insert Opportunities
-- ============================================================
-- Mix: ~40% Closed-Won, ~25% Closed-Lost (with failed expansions),
--      ~20% Open pipeline, ~15% Renewals
-- Run as SYSADMIN after 04_insert_products.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- Generate opportunities using account data
-- ============================================================
INSERT INTO DIM_SALES_OPPORTUNITY (
    DIM_SALES_OPPORTUNITY_KEY, OPPORTUNITY_ID, OPPORTUNITY_NAME,
    OPPORTUNITY_TYPE_CODE, OPPORTUNITY_STAGE_NAME, OPPORTUNITY_CLOSE_DATE,
    OPPORTUNITY_CLOSE_PROBABILITY_PCT, OPPORTUNITY_CREATED_DATE,
    OPPORTUNITY_OWNER_NAME, SFDCF5_ACCT_ID, FORECAST_CATEGORY_NAME,
    BUSINESS_TYPE_CODE, DEAL_TYPE_CODE, COMPETITOR_NAME,
    PRIMARY_COMPETITOR_NAME, PRIMARY_REASON_WON_LOST_ABANDONED_CODE,
    REASON_WON_LOST_ABANDONED_DESC, OPPORTUNITY_WON_IND,
    OPPORTUNITY_CLOSED_IND, RENEWAL_FLAG, THEATER_NAME,
    TERRITORY_CREDITED_REGION_NAME
)
WITH accounts AS (
    SELECT SFDCF5_ACCT_ID, ACCT_NAME, ETM_REGION_NAME, INDUSTRY_NAME,
           ROW_NUMBER() OVER (ORDER BY SFDCF5_ACCT_ID) AS rn,
           COUNT(*) OVER () AS total_accounts
    FROM DIM_CUST_ACCT_SFDC
),
-- Generate multiple opportunity types per account
opp_types AS (
    SELECT column1 AS opp_type, column2 AS stage, column3 AS prob,
           column4 AS won_ind, column5 AS closed_ind, column6 AS forecast_cat,
           column7 AS renewal_flag, column8 AS reason_code, column9 AS reason_desc
    FROM VALUES
        -- Closed-Won opportunities
        ('New Business', 'Closed Won', 100, TRUE, TRUE, 'Closed', 'N', 'Best Product Fit', 'Customer chose F5 for superior feature set and reliability'),
        ('Expansion', 'Closed Won', 100, TRUE, TRUE, 'Closed', 'N', 'Existing Relationship', 'Expanded based on success with existing deployment'),
        ('Renewal', 'Closed Won', 100, TRUE, TRUE, 'Closed', 'Y', 'Product Satisfaction', 'Renewed due to strong platform performance'),
        -- Closed-Lost (Failed Expansions - KEY REQUIREMENT)
        ('Expansion', 'Closed Lost', 0, FALSE, TRUE, 'Omitted', 'N', 'Price', 'Customer found competitor pricing more attractive for expansion'),
        ('Expansion', 'Closed Lost', 0, FALSE, TRUE, 'Omitted', 'N', 'Budget Constraints', 'Budget was cut mid-cycle; expansion deferred indefinitely'),
        ('Expansion', 'Closed Lost', 0, FALSE, TRUE, 'Omitted', 'N', 'Went with Competitor', 'Customer chose Cloudflare for XC-equivalent functionality'),
        ('Expansion', 'Closed Lost', 0, FALSE, TRUE, 'Omitted', 'N', 'No Decision', 'Proposal presented but customer chose to maintain status quo'),
        -- Open Pipeline
        ('New Business', 'Discovery', 20, FALSE, FALSE, 'Pipeline', 'N', NULL, NULL),
        ('Expansion', 'Technical Evaluation', 50, FALSE, FALSE, 'Best Case', 'N', NULL, NULL),
        ('Expansion', 'Proposal Sent', 75, FALSE, FALSE, 'Commit', 'N', NULL, NULL),
        ('New Business', 'Negotiation', 85, FALSE, FALSE, 'Commit', 'N', NULL, NULL),
        -- Renewals upcoming
        ('Renewal', 'Renewal Pending', 90, FALSE, FALSE, 'Commit', 'Y', NULL, NULL)
),
-- Assign competitors based on deal type
competitors AS (
    SELECT column1 AS comp_name FROM VALUES
        ('Cloudflare'), ('Akamai'), ('Imperva'), ('AWS ALB/CloudFront'),
        ('Azure Front Door'), ('Citrix'), ('HAProxy'), ('Kong'), ('Fastly')
),
-- Generate one opportunity per account-type combination
generated AS (
    SELECT
        a.SFDCF5_ACCT_ID,
        a.ACCT_NAME,
        a.ETM_REGION_NAME,
        o.opp_type,
        o.stage,
        o.prob,
        o.won_ind,
        o.closed_ind,
        o.forecast_cat,
        o.renewal_flag,
        o.reason_code,
        o.reason_desc,
        ROW_NUMBER() OVER (ORDER BY a.SFDCF5_ACCT_ID, o.stage) AS opp_num
    FROM accounts a
    CROSS JOIN opp_types o
    -- Assign opportunities based on account position
    WHERE (
        -- All accounts get a won deal (historical)
        (o.stage = 'Closed Won' AND o.opp_type = 'New Business' AND a.rn <= a.total_accounts)
        -- ~60% get a renewal won
        OR (o.stage = 'Closed Won' AND o.opp_type = 'Renewal' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'ren')), 100) < 60)
        -- ~30% get a won expansion
        OR (o.stage = 'Closed Won' AND o.opp_type = 'Expansion' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'exp')), 100) < 30)
        -- ~15% get a failed expansion (price)
        OR (o.stage = 'Closed Lost' AND o.reason_code = 'Price' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'lp')), 100) < 15)
        -- ~10% get a failed expansion (budget)
        OR (o.stage = 'Closed Lost' AND o.reason_code = 'Budget Constraints' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'lb')), 100) < 10)
        -- ~10% get a failed expansion (competitor)
        OR (o.stage = 'Closed Lost' AND o.reason_code = 'Went with Competitor' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'lc')), 100) < 10)
        -- ~8% get a failed expansion (no decision)
        OR (o.stage = 'Closed Lost' AND o.reason_code = 'No Decision' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'ln')), 100) < 8)
        -- ~20% have open pipeline
        OR (o.stage IN ('Discovery', 'Technical Evaluation', 'Proposal Sent', 'Negotiation')
            AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || o.stage)), 100) < 20)
        -- ~25% have upcoming renewals
        OR (o.stage = 'Renewal Pending' AND MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'rp')), 100) < 25)
    )
)
SELECT
    MD5(SFDCF5_ACCT_ID || '-' || opp_num) AS DIM_SALES_OPPORTUNITY_KEY,
    'OPP' || LPAD(opp_num::VARCHAR, 7, '0') AS OPPORTUNITY_ID,
    ACCT_NAME || ' - ' || opp_type ||
        CASE stage
            WHEN 'Closed Won' THEN ' (Won)'
            WHEN 'Closed Lost' THEN ' - ' || reason_code
            WHEN 'Renewal Pending' THEN ' FY26'
            ELSE ''
        END AS OPPORTUNITY_NAME,
    opp_type AS OPPORTUNITY_TYPE_CODE,
    stage AS OPPORTUNITY_STAGE_NAME,
    CASE
        WHEN closed_ind THEN DATEADD(day, -MOD(ABS(HASH(SFDCF5_ACCT_ID || opp_num::VARCHAR)), 365), CURRENT_DATE())
        WHEN stage = 'Renewal Pending' THEN DATEADD(day, MOD(ABS(HASH(SFDCF5_ACCT_ID || 'rd')), 180) + 30, CURRENT_DATE())
        ELSE DATEADD(day, MOD(ABS(HASH(SFDCF5_ACCT_ID || 'cd')), 90) + 14, CURRENT_DATE())
    END AS OPPORTUNITY_CLOSE_DATE,
    prob AS OPPORTUNITY_CLOSE_PROBABILITY_PCT,
    DATEADD(day, -(MOD(ABS(HASH(SFDCF5_ACCT_ID || opp_num::VARCHAR || 'cr')), 180) + 30), CURRENT_DATE())::TIMESTAMP_TZ AS OPPORTUNITY_CREATED_DATE,
    CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || 'own')), 10)
        WHEN 0 THEN 'Sarah Mitchell'
        WHEN 1 THEN 'Robert Chen'
        WHEN 2 THEN 'Jessica Torres'
        WHEN 3 THEN 'Michael Park'
        WHEN 4 THEN 'Amanda Nguyen'
        WHEN 5 THEN 'David Morrison'
        WHEN 6 THEN 'Lauren Kim'
        WHEN 7 THEN 'James O''Brien'
        WHEN 8 THEN 'Rachel Patel'
        ELSE 'Christopher Davis'
    END AS OPPORTUNITY_OWNER_NAME,
    SFDCF5_ACCT_ID,
    forecast_cat AS FORECAST_CATEGORY_NAME,
    opp_type AS BUSINESS_TYPE_CODE,
    CASE opp_type WHEN 'Expansion' THEN 'Upsell' WHEN 'Renewal' THEN 'Renewal' ELSE 'Land' END AS DEAL_TYPE_CODE,
    CASE
        WHEN stage = 'Closed Lost' THEN
            CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || 'comp')), 9)
                WHEN 0 THEN 'Cloudflare'
                WHEN 1 THEN 'Akamai'
                WHEN 2 THEN 'Imperva'
                WHEN 3 THEN 'AWS ALB/CloudFront'
                WHEN 4 THEN 'Azure Front Door'
                WHEN 5 THEN 'Citrix'
                WHEN 6 THEN 'HAProxy'
                WHEN 7 THEN 'Kong'
                ELSE 'Fastly'
            END
        ELSE NULL
    END AS COMPETITOR_NAME,
    CASE
        WHEN stage = 'Closed Lost' THEN
            CASE MOD(ABS(HASH(SFDCF5_ACCT_ID || 'comp')), 9)
                WHEN 0 THEN 'Cloudflare'
                WHEN 1 THEN 'Akamai'
                WHEN 2 THEN 'Imperva'
                WHEN 3 THEN 'AWS ALB/CloudFront'
                WHEN 4 THEN 'Azure Front Door'
                WHEN 5 THEN 'Citrix'
                WHEN 6 THEN 'HAProxy'
                WHEN 7 THEN 'Kong'
                ELSE 'Fastly'
            END
        ELSE NULL
    END AS PRIMARY_COMPETITOR_NAME,
    reason_code AS PRIMARY_REASON_WON_LOST_ABANDONED_CODE,
    reason_desc AS REASON_WON_LOST_ABANDONED_DESC,
    won_ind AS OPPORTUNITY_WON_IND,
    closed_ind AS OPPORTUNITY_CLOSED_IND,
    renewal_flag AS RENEWAL_FLAG,
    'Americas' AS THEATER_NAME,
    ETM_REGION_NAME AS TERRITORY_CREDITED_REGION_NAME
FROM generated;

-- ============================================================
-- Insert matching FACT_SALES_OPPORTUNITY with dollar amounts
-- ============================================================
INSERT INTO FACT_SALES_OPPORTUNITY (
    FACT_SALES_OPPORTUNITY_KEY, OPPORTUNITY_ID, SFDCF5_ACCT_ID,
    OPPORTUNITY_CLOSE_DATE, OPPORTUNITY_CREATED_DATE,
    OPPORTUNITY_AMT, PI_AMT, ARR_AMT, TOTAL_CONTRACT_BOOKING_AMT,
    TERM_DURATION_MONTHS_NUM, TERM_START_DATE, TERM_END_DATE,
    VARICENT_TERRITORY_CODE
)
SELECT
    MD5(d.OPPORTUNITY_ID || '-fact'),
    d.OPPORTUNITY_ID,
    d.SFDCF5_ACCT_ID,
    d.OPPORTUNITY_CLOSE_DATE,
    d.OPPORTUNITY_CREATED_DATE::TIMESTAMP_NTZ,
    -- Generate realistic deal sizes based on type
    CASE
        WHEN d.OPPORTUNITY_TYPE_CODE = 'New Business' AND d.OPPORTUNITY_WON_IND THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'amt')), 200000) + 50000)::NUMBER(35,17)
        WHEN d.OPPORTUNITY_TYPE_CODE = 'Expansion' THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'amt')), 150000) + 25000)::NUMBER(35,17)
        WHEN d.OPPORTUNITY_TYPE_CODE = 'Renewal' THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'amt')), 100000) + 30000)::NUMBER(35,17)
        ELSE (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'amt')), 250000) + 40000)::NUMBER(35,17)
    END AS OPPORTUNITY_AMT,
    -- PI amount (slightly different)
    CASE
        WHEN d.OPPORTUNITY_TYPE_CODE = 'New Business' THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'pi')), 180000) + 45000)::NUMBER(35,17)
        ELSE (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'pi')), 120000) + 20000)::NUMBER(35,17)
    END AS PI_AMT,
    -- ARR
    CASE
        WHEN d.OPPORTUNITY_TYPE_CODE IN ('Expansion', 'Renewal') THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'arr')), 80000) + 15000)::NUMBER(35,17)
        ELSE (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'arr')), 120000) + 25000)::NUMBER(35,17)
    END AS ARR_AMT,
    -- Total contract booking
    CASE
        WHEN d.OPPORTUNITY_WON_IND THEN
            (MOD(ABS(HASH(d.OPPORTUNITY_ID || 'tcb')), 300000) + 75000)::NUMBER(35,17)
        ELSE NULL
    END AS TOTAL_CONTRACT_BOOKING_AMT,
    -- Term duration (12, 24, or 36 months)
    CASE MOD(ABS(HASH(d.OPPORTUNITY_ID || 'term')), 3)
        WHEN 0 THEN 12
        WHEN 1 THEN 24
        ELSE 36
    END AS TERM_DURATION_MONTHS_NUM,
    d.OPPORTUNITY_CLOSE_DATE AS TERM_START_DATE,
    DATEADD(month,
        CASE MOD(ABS(HASH(d.OPPORTUNITY_ID || 'term')), 3) WHEN 0 THEN 12 WHEN 1 THEN 24 ELSE 36 END,
        d.OPPORTUNITY_CLOSE_DATE
    ) AS TERM_END_DATE,
    a.VARICENT_TERRITORY_CODE
FROM DIM_SALES_OPPORTUNITY d
JOIN DIM_CUST_ACCT_SFDC a ON d.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID;

-- ============================================================
-- Insert opportunity line items (products attached to opps)
-- ============================================================
INSERT INTO FACT_SALES_OPPORTUNITY_LINE_ITEM (
    FACT_SALES_OPPORTUNITY_LINE_ITEM_KEY, LINE_ITEM_ID,
    OPPORTUNITY_ID, SFDCF5_ACCT_ID, PRODUCT_ID, PRODUCT_SKU_ID,
    BRAND_NAME, F5_PRODUCT_FAMILY_NAME, LINE_ITEM_NAME,
    PRODUCT_QTY, TOTAL_PRICE_AMT, NET_PRICE_AMT, ARR_AMT,
    CONTRACT_LENGTH_MTH_NUM, LINE_ITEM_START_DATE, LINE_ITEM_END_DATE,
    OPPORTUNITY_CLOSE_DATE
)
SELECT
    MD5(d.OPPORTUNITY_ID || '-' || p.PRODUCT_ID) AS FACT_SALES_OPPORTUNITY_LINE_ITEM_KEY,
    'LI' || LPAD(ROW_NUMBER() OVER (ORDER BY d.OPPORTUNITY_ID, p.PRODUCT_ID)::VARCHAR, 8, '0') AS LINE_ITEM_ID,
    d.OPPORTUNITY_ID,
    d.SFDCF5_ACCT_ID,
    p.PRODUCT_ID,
    p.OFFER_SKU_ID,
    p.BRAND_NAME,
    p.F5_PRODUCT_OFFER_FAMILY_NAME,
    p.OFFER_DESC,
    CASE WHEN p.PRODUCT_OFFERING_TYPE_NAME = 'Hardware' THEN MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 5) + 1
         ELSE MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 20) + 1
    END AS PRODUCT_QTY,
    p.STANDARD_LIST_PRICE_AMT * (MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 5) + 1) AS TOTAL_PRICE_AMT,
    p.STANDARD_LIST_PRICE_AMT * (MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 5) + 1) * 0.85 AS NET_PRICE_AMT,
    CASE WHEN p.PRODUCT_LINE_TYPE IN ('SaaS', 'Subscription') THEN
        p.STANDARD_LIST_PRICE_AMT * (MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 5) + 1)
    ELSE NULL END AS ARR_AMT,
    CASE MOD(ABS(HASH(d.OPPORTUNITY_ID || 'term')), 3) WHEN 0 THEN 12 WHEN 1 THEN 24 ELSE 36 END AS CONTRACT_LENGTH_MTH_NUM,
    d.OPPORTUNITY_CLOSE_DATE AS LINE_ITEM_START_DATE,
    DATEADD(month,
        CASE MOD(ABS(HASH(d.OPPORTUNITY_ID || 'term')), 3) WHEN 0 THEN 12 WHEN 1 THEN 24 ELSE 36 END,
        d.OPPORTUNITY_CLOSE_DATE
    ) AS LINE_ITEM_END_DATE,
    d.OPPORTUNITY_CLOSE_DATE
FROM DIM_SALES_OPPORTUNITY d
-- Assign 1-3 products per opportunity based on deal type
JOIN DIM_PRODUCT_OFFER p ON (
    -- New Business gets BIG-IP products
    (d.OPPORTUNITY_TYPE_CODE = 'New Business' AND d.OPPORTUNITY_WON_IND
     AND p.BRAND_NAME = 'BIG-IP'
     AND MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 100) < 15)
    -- Expansion gets XC or NGINX
    OR (d.OPPORTUNITY_TYPE_CODE = 'Expansion'
        AND p.BRAND_NAME IN ('Distributed Cloud', 'NGINX', 'Calypso AI')
        AND MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 100) < 20)
    -- Renewals get the same mix
    OR (d.OPPORTUNITY_TYPE_CODE = 'Renewal'
        AND MOD(ABS(HASH(d.OPPORTUNITY_ID || p.PRODUCT_ID)), 100) < 8)
)
WHERE p.OFFER_STATUS_CODE = 'Active';

-- ============================================================
-- Verification queries
-- ============================================================

-- Opportunity stage distribution
SELECT OPPORTUNITY_STAGE_NAME, COUNT(*) AS cnt
FROM DIM_SALES_OPPORTUNITY
GROUP BY 1 ORDER BY 2 DESC;

-- Failed expansion proposals specifically
SELECT
    d.OPPORTUNITY_NAME,
    d.SFDCF5_ACCT_ID,
    a.ACCT_NAME,
    d.PRIMARY_REASON_WON_LOST_ABANDONED_CODE AS LOSS_REASON,
    d.PRIMARY_COMPETITOR_NAME AS COMPETITOR,
    f.OPPORTUNITY_AMT
FROM DIM_SALES_OPPORTUNITY d
JOIN DIM_CUST_ACCT_SFDC a ON d.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
LEFT JOIN FACT_SALES_OPPORTUNITY f ON d.OPPORTUNITY_ID = f.OPPORTUNITY_ID
WHERE d.OPPORTUNITY_WON_IND = FALSE
  AND d.OPPORTUNITY_CLOSED_IND = TRUE
  AND d.OPPORTUNITY_TYPE_CODE = 'Expansion'
ORDER BY f.OPPORTUNITY_AMT DESC
LIMIT 20;
