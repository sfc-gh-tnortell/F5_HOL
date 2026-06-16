# Plan: Customer Growth Streamlit App

## Context

**Available data (all confirmed in Snowflake):**
- `F5_PROD.RAW.DIM_CUST_ACCT_SFDC` (184 accounts) - master account list
- `F5_PROD.RAW.SALES_ACCOUNT_TEAM` (184 rows) - AE, SE, region per account
- `F5_PROD.RAW.COL_XC_TELEMETRY` (47,450 rows) - daily telemetry signals
- `F5_PROD.RAW.DIM_SUPPORT_CASE` + `FACT_SUPPORT_CASE` (1,125 each) - support cases + metrics
- `F5_PROD.RAW.DIM_SALES_OPPORTUNITY` + `FACT_SALES_OPPORTUNITY` (641 each) - pipeline
- `F5_PROD.RAW.COL_SALES_OPPORTUNITY_LINE_ITEM` (1,757 rows) - product line items per deal
- `F5_PROD.RAW.COL_INSTALL_BASE` (343 rows) - deployed hardware/software
- `F5_PROD.RAW.COL_TERM_SUB_MONTHLY_USAGE_V2` (6,006 rows) - subscription utilization
- `F5_PROD.RAW.COL_XC_PRODUCT_HEALTHSCORE` (116 rows) - health scores
- `F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS` (920 rows) - ML model output
- `F5_PROD.FINAL.ZOOM_TRANSCRIPT_SOURCE` (69 rows) - call transcripts with ACCOUNT_NAME, CALL_DATE, TRANSCRIPT_TEXT

## App Structure

Single file `streamlit_app.py` with sidebar navigation and account filter.

### Sidebar
- Account selector (dropdown, all 184 accounts)
- Page navigation (radio buttons)
- Account team info displayed below selector (AE, SE, region)

### Page 1: Account Overview
- KPI tiles: total spend, products owned, open cases, expansion opportunities
- Current product portfolio (from line items)
- Health score + consumption pattern
- Telemetry signal classification badge

### Page 2: Expansion Recommendations
- Table of cross-sell recommendations for selected account (from CROSS_SELL_RECOMMENDATIONS)
- Confidence score as progress bars
- Recommendation type color-coded (cross-sell, upsell, capacity)
- Rationale displayed per row

### Page 3: Support & Health
- Open cases table with priority, product, age
- Utilization metrics (from COL_TERM_SUB_MONTHLY_USAGE_V2)
- Telemetry trend chart (last 90 days for key metrics)
- Health score gauge

### Page 4: Sales Pipeline
- Open opportunities table (stage, amount, close date)
- Won/Lost history
- Install base summary (products deployed, end-of-service dates)
- Renewal timeline

### Page 5: Call Transcripts
- List of transcripts for the selected account (from ZOOM_TRANSCRIPT_SOURCE)
- Expandable transcript text
- Call date and participants

## Implementation

Single Python file, deployed via Snowsight (Projects > Streamlit > Create).

Uses `st.connection("snowflake")` for data access with `@st.cache_data` for performance.

## Verification

- App loads without errors
- Account filter changes data on all pages
- Each page shows relevant data for the selected account
- Transcripts display correctly for accounts that have them

## Critical Files

- `HOL/streamlit_app.py` - The complete Streamlit app (single file)
