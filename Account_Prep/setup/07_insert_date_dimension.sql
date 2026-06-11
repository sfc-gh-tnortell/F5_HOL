-- ============================================================
-- F5 Hands-On Lab: Insert Date Dimension (Fiscal Calendar)
-- ============================================================
-- F5 fiscal year starts Feb 1, ends Jan 31
-- FY26 = Feb 1, 2025 - Jan 31, 2026
-- Generates 3 years of dates (FY24 - FY27)
-- Run as SYSADMIN after 06_insert_sales_teams.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

INSERT INTO DIM_DAY_DATE (
    DIM_DAY_DATE_KEY, CALENDAR_DATE, CAL_DAY_IN_WEEK, CAL_DAY_IN_WEEK_NUM,
    CAL_DAY_IN_MTH_NUM, CAL_WEEK_IN_YEAR_NUM, CAL_MTH_NUM, CAL_MTH_NAME,
    CAL_QTR_NUM, CAL_YEAR_NUM, FISCAL_YEAR_NUM, FISCAL_MTH_NAME,
    FISCAL_QTR_CODE, FISCAL_QTR_WEEK_NUM, CURRENT_FISCAL_MTH_FLAG,
    CURRENT_FISCAL_QTR_FLAG, CURRENT_FISCAL_YEAR_FLAG, CURRENT_FISCAL_WEEK_FLAG,
    FIRST_DAY_IN_QTR_DATE, LAST_DAY_IN_QTR_DATE, FISCAL_PERIOD_DESC, WEEK_DAY_FLAG
)
WITH date_spine AS (
    SELECT DATEADD(day, SEQ4(), '2023-02-01'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 1461)) -- ~4 years
    WHERE DATEADD(day, SEQ4(), '2023-02-01'::DATE) <= '2027-01-31'
),
enriched AS (
    SELECT
        dt,
        -- Calendar fields
        DAYNAME(dt) AS day_name,
        DAYOFWEEK(dt) AS dow_num,
        DAY(dt) AS day_in_month,
        WEEKOFYEAR(dt) AS week_in_year,
        MONTH(dt) AS cal_month,
        MONTHNAME(dt) AS cal_month_name,
        QUARTER(dt) AS cal_quarter,
        YEAR(dt) AS cal_year,
        -- Fiscal year (Feb start = +11 months offset for FY number)
        CASE WHEN MONTH(dt) >= 2 THEN YEAR(dt) + 1 ELSE YEAR(dt) END AS fiscal_year,
        -- Fiscal month (Feb=1, Mar=2, ... Jan=12)
        CASE WHEN MONTH(dt) >= 2 THEN MONTH(dt) - 1 ELSE 12 END AS fiscal_month_num,
        -- Fiscal quarter
        CASE
            WHEN MONTH(dt) IN (2,3,4) THEN 'Q1'
            WHEN MONTH(dt) IN (5,6,7) THEN 'Q2'
            WHEN MONTH(dt) IN (8,9,10) THEN 'Q3'
            ELSE 'Q4'
        END AS fiscal_qtr,
        -- Fiscal quarter start/end
        CASE
            WHEN MONTH(dt) IN (2,3,4) THEN DATE_TRUNC('year', dt) || '-02-01'
            WHEN MONTH(dt) IN (5,6,7) THEN DATE_TRUNC('year', dt) || '-05-01'
            WHEN MONTH(dt) IN (8,9,10) THEN DATE_TRUNC('year', dt) || '-08-01'
            WHEN MONTH(dt) IN (11,12) THEN DATE_TRUNC('year', dt) || '-11-01'
            ELSE DATEADD(year, -1, DATE_TRUNC('year', dt)) || '-11-01'
        END::DATE AS qtr_start,
        CASE
            WHEN MONTH(dt) IN (2,3,4) THEN LAST_DAY(DATE_TRUNC('year', dt) || '-04-01')
            WHEN MONTH(dt) IN (5,6,7) THEN LAST_DAY(DATE_TRUNC('year', dt) || '-07-01')
            WHEN MONTH(dt) IN (8,9,10) THEN LAST_DAY(DATE_TRUNC('year', dt) || '-10-01')
            WHEN MONTH(dt) IN (11,12) THEN (YEAR(dt)+1) || '-01-31'
            ELSE YEAR(dt) || '-01-31'
        END::DATE AS qtr_end
    FROM date_spine
)
SELECT
    TO_NUMBER(TO_CHAR(dt, 'YYYYMMDD')) AS DIM_DAY_DATE_KEY,
    dt AS CALENDAR_DATE,
    day_name,
    dow_num,
    day_in_month,
    week_in_year,
    cal_month,
    cal_month_name,
    cal_quarter,
    cal_year,
    fiscal_year,
    'FY' || fiscal_year || '-M' || LPAD(fiscal_month_num, 2, '0'),
    fiscal_qtr,
    CEIL(DATEDIFF(day, qtr_start, dt) / 7.0) + 1,
    CASE WHEN MONTH(CURRENT_DATE()) = MONTH(dt) AND YEAR(CURRENT_DATE()) = YEAR(dt) THEN 'Y' ELSE 'N' END,
    CASE WHEN fiscal_qtr = (CASE WHEN MONTH(CURRENT_DATE()) IN (2,3,4) THEN 'Q1' WHEN MONTH(CURRENT_DATE()) IN (5,6,7) THEN 'Q2' WHEN MONTH(CURRENT_DATE()) IN (8,9,10) THEN 'Q3' ELSE 'Q4' END)
         AND fiscal_year = (CASE WHEN MONTH(CURRENT_DATE()) >= 2 THEN YEAR(CURRENT_DATE()) + 1 ELSE YEAR(CURRENT_DATE()) END)
         THEN 'Y' ELSE 'N' END,
    CASE WHEN fiscal_year = (CASE WHEN MONTH(CURRENT_DATE()) >= 2 THEN YEAR(CURRENT_DATE()) + 1 ELSE YEAR(CURRENT_DATE()) END) THEN 'Y' ELSE 'N' END,
    CASE WHEN WEEKOFYEAR(CURRENT_DATE()) = week_in_year AND cal_year = YEAR(CURRENT_DATE()) THEN 'Y' ELSE 'N' END,
    qtr_start,
    qtr_end,
    'FY' || fiscal_year || ' ' || fiscal_qtr,
    CASE WHEN dow_num BETWEEN 1 AND 5 THEN 'Y' ELSE 'N' END
FROM enriched;

-- Verify
SELECT FISCAL_YEAR_NUM, FISCAL_QTR_CODE, COUNT(*) AS days
FROM DIM_DAY_DATE
GROUP BY 1, 2
ORDER BY 1, 2;
