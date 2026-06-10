-- ============================================================
-- LEGACY: Generate Gong Transcript Table Data
-- ============================================================
-- This script creates the GONG_TRANSCRIPT table and populates it
-- with synthetic data. Use this if you need to recreate the
-- transcript data without the .txt files.
--
-- NOTE: The current workflow uses uploaded .txt files parsed via
-- setup/10_gong_analysis/02_create_source_table.sql instead.
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE DEFAULT_WH;
USE DATABASE PROD;
USE SCHEMA RAW;

-- Create the GONG_TRANSCRIPT table
CREATE OR REPLACE TABLE PROD.RAW.GONG_TRANSCRIPT (
    TRANSCRIPT_ID VARCHAR(18) PRIMARY KEY,
    ACCOUNT_ID VARCHAR(18),
    ACCOUNT_NAME VARCHAR(255),
    CALL_DATE DATE,
    CALL_DURATION_MINUTES NUMBER(10,2),
    CALL_TYPE VARCHAR(50),
    PARTICIPANTS VARCHAR(1000),
    SUMMARY VARCHAR(4000),
    KEY_INSIGHTS VARCHAR(4000),
    NEXT_STEPS VARCHAR(2000),
    SENTIMENT VARCHAR(50),
    TRANSCRIPT_TEXT VARCHAR(16777216),
    FILE_NAME VARCHAR(255),
    CREATED_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Generate synthetic transcript data for accounts
-- This creates ~134 transcripts (80% account coverage with varied call types)
INSERT INTO PROD.RAW.GONG_TRANSCRIPT
WITH account_sample AS (
    SELECT 
        ACCOUNT_ID,
        ACCOUNT_NAME,
        INDUSTRY,
        HEALTHSCORE,
        BILLING_CITY,
        BILLING_STATE,
        NUMBER_OF_EMPLOYEES,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) as rn
    FROM PROD.RAW.SFDC_ACCOUNT
    WHERE ACCOUNT_STATUS = 'Active'
    QUALIFY rn <= 134
),
call_types AS (
    SELECT column1 AS call_type, column2 AS duration_base
    FROM VALUES 
        ('QBR', 45),
        ('Executive Briefing', 60),
        ('Technical Review', 30),
        ('Renewal Discussion', 45),
        ('Expansion Planning', 40),
        ('Support Escalation', 25),
        ('Product Demo', 35)
),
sentiment_map AS (
    SELECT column1 AS health, column2 AS sentiment_options
    FROM VALUES
        ('Excellent', ARRAY_CONSTRUCT('Very Positive', 'Positive')),
        ('Healthy', ARRAY_CONSTRUCT('Positive', 'Neutral')),
        ('Good', ARRAY_CONSTRUCT('Positive', 'Neutral', 'Mixed')),
        ('At Risk', ARRAY_CONSTRUCT('Mixed', 'Negative', 'Concerned')),
        ('Critical', ARRAY_CONSTRUCT('Negative', 'Very Negative', 'Frustrated'))
)
SELECT
    'GTR' || LPAD(ROW_NUMBER() OVER (ORDER BY a.ACCOUNT_ID)::VARCHAR, 6, '0') AS TRANSCRIPT_ID,
    a.ACCOUNT_ID,
    a.ACCOUNT_NAME,
    DATEADD(day, -MOD(ABS(HASH(a.ACCOUNT_ID || 'date')), 180), CURRENT_DATE()) AS CALL_DATE,
    ct.duration_base + MOD(ABS(HASH(a.ACCOUNT_ID || 'dur')), 20) - 10 AS CALL_DURATION_MINUTES,
    ct.call_type AS CALL_TYPE,
    'Sarah Johnson (Account Executive), ' || 
    CASE MOD(ABS(HASH(a.ACCOUNT_ID || 'se')), 3)
        WHEN 0 THEN 'Mike Chen (SE)'
        WHEN 1 THEN 'Emily Rodriguez (SE)'
        ELSE 'David Kim (SE)'
    END || ', ' ||
    'Client: ' || 
    CASE MOD(ABS(HASH(a.ACCOUNT_ID || 'title')), 5)
        WHEN 0 THEN 'VP of IT'
        WHEN 1 THEN 'CISO'
        WHEN 2 THEN 'Director of Security'
        WHEN 3 THEN 'IT Manager'
        ELSE 'CTO'
    END AS PARTICIPANTS,
    -- Summary based on health score
    CASE a.HEALTHSCORE
        WHEN 'Excellent' THEN 'Excellent relationship with ' || a.ACCOUNT_NAME || '. Customer very satisfied with current implementation. Strong expansion opportunity identified.'
        WHEN 'Healthy' THEN 'Good conversation with ' || a.ACCOUNT_NAME || '. Customer is satisfied with service and sees value in current products.'
        WHEN 'Good' THEN 'Productive call with ' || a.ACCOUNT_NAME || '. Discussed current usage and potential areas for improvement.'
        WHEN 'At Risk' THEN 'Concerning call with ' || a.ACCOUNT_NAME || '. Customer expressed frustration with recent issues. Need immediate attention.'
        ELSE 'Critical escalation with ' || a.ACCOUNT_NAME || '. Customer considering alternatives. Urgent action required to save account.'
    END AS SUMMARY,
    -- Key insights based on health and industry
    CASE 
        WHEN a.HEALTHSCORE IN ('At Risk', 'Critical') AND a.INDUSTRY = 'Technology' 
            THEN 'Customer mentioned evaluating Azure AD and Ping Identity. Budget constraints due to recent layoffs. Q3 fiscal planning underway.'
        WHEN a.HEALTHSCORE IN ('At Risk', 'Critical') AND a.INDUSTRY = 'Financial Services'
            THEN 'Compliance audit coming up. Customer concerned about integration complexity. Mentioned competitor Sailpoint offering lower pricing.'
        WHEN a.HEALTHSCORE IN ('At Risk', 'Critical')
            THEN 'Budget cuts announced. IT team downsizing. Customer needs to justify ROI for renewal. Asked about usage analytics.'
        WHEN a.HEALTHSCORE = 'Excellent' AND a.INDUSTRY = 'Technology'
            THEN 'Strong advocate for our platform. Interested in PAM and IGA expansion. Planning cloud migration - good timing for additional services.'
        WHEN a.HEALTHSCORE = 'Excellent'
            THEN 'Customer sees significant value. Willing to be a reference. Interested in advanced features and premium support tier.'
        ELSE 'Standard engagement. Customer satisfied with core features. May have interest in Adaptive MFA for enhanced security.'
    END AS KEY_INSIGHTS,
    -- Next steps
    CASE a.HEALTHSCORE
        WHEN 'Excellent' THEN 'Schedule expansion discussion. Prepare ROI report. Invite to customer advisory board.'
        WHEN 'Healthy' THEN 'Send usage report. Schedule product roadmap review. Identify expansion opportunities.'
        WHEN 'Good' THEN 'Follow up on feature requests. Send best practices guide. Schedule training session.'
        WHEN 'At Risk' THEN 'Escalate to management. Schedule executive sponsor meeting. Prepare retention offer.'
        ELSE 'Emergency executive escalation. Prepare comprehensive recovery plan. Daily check-ins until stabilized.'
    END AS NEXT_STEPS,
    -- Sentiment
    CASE a.HEALTHSCORE
        WHEN 'Excellent' THEN 'Very Positive'
        WHEN 'Healthy' THEN 'Positive'
        WHEN 'Good' THEN 'Neutral'
        WHEN 'At Risk' THEN 'Concerned'
        ELSE 'Frustrated'
    END AS SENTIMENT,
    -- Full transcript text (simulated)
    'GONG CALL TRANSCRIPT\n' ||
    '==================\n\n' ||
    'Call Date: ' || DATEADD(day, -MOD(ABS(HASH(a.ACCOUNT_ID || 'date')), 180), CURRENT_DATE())::VARCHAR || '\n' ||
    'Account: ' || a.ACCOUNT_NAME || '\n' ||
    'Type: ' || ct.call_type || '\n\n' ||
    '[00:00] Sarah Johnson: Thank you for joining today''s call. Let''s discuss your current experience...\n\n' ||
    '[05:00] ' || 
    CASE a.HEALTHSCORE
        WHEN 'Excellent' THEN 'Client: We''re very happy with the platform. The team loves the SSO experience and MFA has been seamless.'
        WHEN 'Healthy' THEN 'Client: Things are going well overall. We have some minor feature requests but nothing blocking.'
        WHEN 'Good' THEN 'Client: It''s working for us. We''d like to see some improvements in reporting and analytics.'
        WHEN 'At Risk' THEN 'Client: Honestly, we''ve been having some concerns. The recent outages affected our team significantly.'
        ELSE 'Client: I''ll be direct - we''re evaluating alternatives. The value proposition needs to improve dramatically.'
    END || '\n\n' ||
    '[15:00] Sarah Johnson: I understand. Let me share some updates that might address your concerns...\n\n' ||
    '[25:00] ' ||
    CASE 
        WHEN a.INDUSTRY IN ('Technology', 'Financial Services') 
            THEN 'Client: Our security team has been asking about your roadmap for passwordless authentication and zero trust integration.'
        ELSE 'Client: We need to ensure our investment aligns with our digital transformation goals for the coming year.'
    END || '\n\n' ||
    '[35:00] Sarah Johnson: Great discussion today. I''ll follow up with the materials we discussed.\n\n' ||
    '[END OF TRANSCRIPT]' AS TRANSCRIPT_TEXT,
    LOWER(REPLACE(a.ACCOUNT_NAME, ' ', '_')) || '_call_' || 
    TO_VARCHAR(DATEADD(day, -MOD(ABS(HASH(a.ACCOUNT_ID || 'date')), 180), CURRENT_DATE()), 'YYYY-MM-DD') || '.txt' AS FILE_NAME,
    CURRENT_TIMESTAMP() AS CREATED_DATE
FROM account_sample a
CROSS JOIN (SELECT * FROM call_types ORDER BY RANDOM() LIMIT 1) ct;

-- Verify data
SELECT COUNT(*) AS transcript_count FROM PROD.RAW.GONG_TRANSCRIPT;
SELECT SENTIMENT, COUNT(*) FROM PROD.RAW.GONG_TRANSCRIPT GROUP BY SENTIMENT;
