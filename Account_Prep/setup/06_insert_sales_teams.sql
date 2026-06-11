-- ============================================================
-- F5 Hands-On Lab: Insert Sales Account Teams
-- ============================================================
-- ~10 teams (AE + SE + SDR each), ~20 accounts per team
-- Aligned to regional territories by timezone
-- Run as SYSADMIN after 05_insert_opportunities.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- First, insert sales users for the account teams
-- ============================================================
INSERT INTO DIM_SALES_USER (
    DIM_SALES_USER_KEY, USER_ID, FIRST_NAME, LAST_NAME, FULL_NAME,
    EMAIL_ADDRESS_TEXT, TITLE_NAME, DEPARTMENT_NAME, ROLE_NAME,
    ROLE_ROLLUP_DESC, TEAM_ROLE_NAME, THEATER_NAME,
    CITY_NAME, STATE_PROVINCE_NAME, COUNTRY_NAME, ACTIVE_IND
)
SELECT MD5(col1), col1, col2, col3, col2 || ' ' || col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, 'United States', TRUE
FROM VALUES
-- West Region Teams
('USR-W1-AE', 'Sarah', 'Mitchell', 'sarah.mitchell@f5.com', 'Account Executive', 'Sales', 'AE - West 1', 'Sales Rep', 'Account Executive', 'Americas', 'San Francisco', 'California'),
('USR-W1-SE', 'Kevin', 'Nakamura', 'kevin.nakamura@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - West 1', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'San Francisco', 'California'),
('USR-W1-SDR', 'Ashley', 'Pham', 'ashley.pham@f5.com', 'Sales Development Rep', 'SDR', 'SDR - West 1', 'Inside Sales', 'SDR', 'Americas', 'San Francisco', 'California'),

('USR-W2-AE', 'Robert', 'Chen', 'robert.chen@f5.com', 'Account Executive', 'Sales', 'AE - West 2', 'Sales Rep', 'Account Executive', 'Americas', 'San Jose', 'California'),
('USR-W2-SE', 'Priya', 'Sharma', 'priya.sharma@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - West 2', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'San Jose', 'California'),
('USR-W2-SDR', 'Tyler', 'Brooks', 'tyler.brooks@f5.com', 'Sales Development Rep', 'SDR', 'SDR - West 2', 'Inside Sales', 'SDR', 'Americas', 'San Jose', 'California'),

('USR-W3-AE', 'Jessica', 'Torres', 'jessica.torres@f5.com', 'Account Executive', 'Sales', 'AE - West 3', 'Sales Rep', 'Account Executive', 'Americas', 'Seattle', 'Washington'),
('USR-W3-SE', 'Daniel', 'Kim', 'daniel.kim@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - West 3', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Seattle', 'Washington'),
('USR-W3-SDR', 'Morgan', 'Lee', 'morgan.lee@f5.com', 'Sales Development Rep', 'SDR', 'SDR - West 3', 'Inside Sales', 'SDR', 'Americas', 'Seattle', 'Washington'),

-- Mountain Region Teams
('USR-M1-AE', 'Michael', 'Park', 'michael.park@f5.com', 'Account Executive', 'Sales', 'AE - Mountain 1', 'Sales Rep', 'Account Executive', 'Americas', 'Denver', 'Colorado'),
('USR-M1-SE', 'Rachel', 'Gonzalez', 'rachel.gonzalez@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - Mountain 1', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Denver', 'Colorado'),
('USR-M1-SDR', 'Brandon', 'Scott', 'brandon.scott@f5.com', 'Sales Development Rep', 'SDR', 'SDR - Mountain 1', 'Inside Sales', 'SDR', 'Americas', 'Denver', 'Colorado'),

-- Central Region Teams
('USR-C1-AE', 'Amanda', 'Nguyen', 'amanda.nguyen@f5.com', 'Account Executive', 'Sales', 'AE - Central 1', 'Sales Rep', 'Account Executive', 'Americas', 'Chicago', 'Illinois'),
('USR-C1-SE', 'Eric', 'Johnson', 'eric.johnson@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - Central 1', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Chicago', 'Illinois'),
('USR-C1-SDR', 'Samantha', 'Williams', 'samantha.williams@f5.com', 'Sales Development Rep', 'SDR', 'SDR - Central 1', 'Inside Sales', 'SDR', 'Americas', 'Chicago', 'Illinois'),

('USR-C2-AE', 'David', 'Morrison', 'david.morrison@f5.com', 'Account Executive', 'Sales', 'AE - Central 2', 'Sales Rep', 'Account Executive', 'Americas', 'Dallas', 'Texas'),
('USR-C2-SE', 'Nicole', 'Martinez', 'nicole.martinez@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - Central 2', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Dallas', 'Texas'),
('USR-C2-SDR', 'Jake', 'Wilson', 'jake.wilson@f5.com', 'Sales Development Rep', 'SDR', 'SDR - Central 2', 'Inside Sales', 'SDR', 'Americas', 'Dallas', 'Texas'),

('USR-C3-AE', 'Lauren', 'Kim', 'lauren.kim@f5.com', 'Account Executive', 'Sales', 'AE - Central 3', 'Sales Rep', 'Account Executive', 'Americas', 'Houston', 'Texas'),
('USR-C3-SE', 'Chris', 'Anderson', 'chris.anderson@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - Central 3', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Houston', 'Texas'),
('USR-C3-SDR', 'Megan', 'Harris', 'megan.harris@f5.com', 'Sales Development Rep', 'SDR', 'SDR - Central 3', 'Inside Sales', 'SDR', 'Americas', 'Houston', 'Texas'),

-- East Region Teams
('USR-E1-AE', 'James', 'O''Brien', 'james.obrien@f5.com', 'Account Executive', 'Sales', 'AE - East 1', 'Sales Rep', 'Account Executive', 'Americas', 'New York', 'New York'),
('USR-E1-SE', 'Aisha', 'Washington', 'aisha.washington@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - East 1', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'New York', 'New York'),
('USR-E1-SDR', 'Ryan', 'Phillips', 'ryan.phillips@f5.com', 'Sales Development Rep', 'SDR', 'SDR - East 1', 'Inside Sales', 'SDR', 'Americas', 'New York', 'New York'),

('USR-E2-AE', 'Rachel', 'Patel', 'rachel.patel@f5.com', 'Account Executive', 'Sales', 'AE - East 2', 'Sales Rep', 'Account Executive', 'Americas', 'Atlanta', 'Georgia'),
('USR-E2-SE', 'Marcus', 'Thompson', 'marcus.thompson@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - East 2', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Atlanta', 'Georgia'),
('USR-E2-SDR', 'Lindsay', 'Clark', 'lindsay.clark@f5.com', 'Sales Development Rep', 'SDR', 'SDR - East 2', 'Inside Sales', 'SDR', 'Americas', 'Atlanta', 'Georgia'),

('USR-E3-AE', 'Christopher', 'Davis', 'christopher.davis@f5.com', 'Account Executive', 'Sales', 'AE - East 3', 'Sales Rep', 'Account Executive', 'Americas', 'Boston', 'Massachusetts'),
('USR-E3-SE', 'Emily', 'Rodriguez', 'emily.rodriguez@f5.com', 'Solutions Engineer', 'Sales Engineering', 'SE - East 3', 'Pre-Sales', 'Solutions Engineer', 'Americas', 'Boston', 'Massachusetts'),
('USR-E3-SDR', 'Justin', 'Taylor', 'justin.taylor@f5.com', 'Sales Development Rep', 'SDR', 'SDR - East 3', 'Inside Sales', 'SDR', 'Americas', 'Boston', 'Massachusetts')
AS t(col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12);

-- ============================================================
-- Populate SALES_ACCOUNT_TEAM by assigning accounts to teams
-- ============================================================
INSERT INTO SALES_ACCOUNT_TEAM (
    SFDCF5_ACCT_ID, ACCT_NAME, AE_USER_ID, AE_NAME, AE_EMAIL,
    SE_USER_ID, SE_NAME, SE_EMAIL, SDR_USER_ID, SDR_NAME, SDR_EMAIL,
    TERRITORY_NAME, DISTRICT_NAME, REGION_NAME, THEATER_NAME, TIMEZONE_REGION
)
WITH team_assignments AS (
    SELECT
        a.SFDCF5_ACCT_ID,
        a.ACCT_NAME,
        a.ETM_REGION_NAME,
        -- Assign to teams within region using hash for even distribution
        CASE a.ETM_REGION_NAME
            WHEN 'West' THEN
                CASE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'team')), 3)
                    WHEN 0 THEN 'W1'
                    WHEN 1 THEN 'W2'
                    ELSE 'W3'
                END
            WHEN 'Mountain' THEN 'M1'
            WHEN 'Central' THEN
                CASE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'team')), 3)
                    WHEN 0 THEN 'C1'
                    WHEN 1 THEN 'C2'
                    ELSE 'C3'
                END
            WHEN 'East' THEN
                CASE MOD(ABS(HASH(a.SFDCF5_ACCT_ID || 'team')), 3)
                    WHEN 0 THEN 'E1'
                    WHEN 1 THEN 'E2'
                    ELSE 'E3'
                END
        END AS team_code
    FROM DIM_CUST_ACCT_SFDC a
)
SELECT
    ta.SFDCF5_ACCT_ID,
    ta.ACCT_NAME,
    ae.USER_ID, ae.FULL_NAME, ae.EMAIL_ADDRESS_TEXT,
    se.USER_ID, se.FULL_NAME, se.EMAIL_ADDRESS_TEXT,
    sdr.USER_ID, sdr.FULL_NAME, sdr.EMAIL_ADDRESS_TEXT,
    ta.ETM_REGION_NAME || ' Territory ' || ta.team_code AS TERRITORY_NAME,
    ta.ETM_REGION_NAME || ' District' AS DISTRICT_NAME,
    ta.ETM_REGION_NAME AS REGION_NAME,
    'Americas' AS THEATER_NAME,
    CASE ta.ETM_REGION_NAME
        WHEN 'West' THEN 'Pacific'
        WHEN 'Mountain' THEN 'Mountain'
        WHEN 'Central' THEN 'Central'
        WHEN 'East' THEN 'Eastern'
    END AS TIMEZONE_REGION
FROM team_assignments ta
JOIN DIM_SALES_USER ae ON ae.USER_ID = 'USR-' || ta.team_code || '-AE'
JOIN DIM_SALES_USER se ON se.USER_ID = 'USR-' || ta.team_code || '-SE'
JOIN DIM_SALES_USER sdr ON sdr.USER_ID = 'USR-' || ta.team_code || '-SDR';

-- ============================================================
-- Verification
-- ============================================================

-- Accounts per team
SELECT AE_NAME, SE_NAME, REGION_NAME, COUNT(*) AS accounts_covered
FROM SALES_ACCOUNT_TEAM
GROUP BY 1, 2, 3
ORDER BY 3, 1;

-- Total coverage
SELECT COUNT(DISTINCT SFDCF5_ACCT_ID) AS total_accounts_with_teams
FROM SALES_ACCOUNT_TEAM;
