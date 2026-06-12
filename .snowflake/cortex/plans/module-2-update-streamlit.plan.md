# Plan: Update Module 2 + Add Streamlit App

## Context

Module 2 currently has 4 steps for a churn propensity model using a basic approach (REGR_SLOPE + simple classification). The Snowflake ML Quickstart guide shows a more production-ready pattern using Feature Store, Model Registry, XGBoost with GridSearch, and batch inferencing. We also need to:
- Incorporate the updated telemetry signal classification (no more "performance" — ELSE = 'load-balancer')
- Add a Step 5 for a Customer Success Streamlit dashboard

## Changes

### Task 1: Update Module 2 Churn Model Approach (Steps 1-2)

**Current approach**: Simple REGR_SLOPE trend calculation + Cortex ML classification  
**New approach**: Snowflake ML Feature Store + XGBoost + Model Registry (aligned with Quickstart)

Revised **Step 1** prompt will instruct CoCo to:
1. Create a feature table with engineered features:
   - **Telemetry signal classification** (using the 5 thresholds + ELSE 'load-balancer')
   - Trend slopes (REGR_SLOPE over 90 days for HTTP LB, WAF, bot, endpoints, DNS)
   - Telemetry volume stats (avg, stddev, min, max over 60 days)
   - Support case features (open count, avg resolution, SLA breach count, escalation count)
   - Health score features (SKU utilization, consumption pattern encoded)
2. Register features in a Feature Store (Snowflake Feature Store pattern)
3. Target variable: `CONSUMPTION_PATTERN = 'Declining'` (binary)

Revised **Step 2** prompt will instruct CoCo to:
1. Create a Snowflake ML preprocessing pipeline (OneHotEncoder + MinMaxScaler)
2. Train XGBoost classifier with GridSearch hyperparameter tuning
3. Evaluate with accuracy, precision, recall, F1, confusion matrix
4. Log best model to Snowflake Model Registry with metrics
5. Run batch inference and write predictions to `F5_PROD.FINAL.CHURN_PREDICTIONS`

**Key difference from Quickstart**: We use REAL domain data (not synthetic), and our features are derived from actual F5 telemetry/support signals. The signal classification thresholds become categorical features that help the model understand which "type" of account it's looking at.

### Task 2: Update Data Summary Section

Remove the "Performance (default)" row from the signal-to-support correlation table. Update to:

| Signal | Threshold | Product | Accounts |
|--------|-----------|---------|----------|
| Bot Defense | > 300K | XC Bot Defense | ~29 |
| WAF | > 25 | XC WAF | ~22 |
| Endpoints | > 150 | XC App Connect | ~24 |
| HTTP Load Balancers | > 40 | BIG-IP LTM / NGINX Plus | ~43 |
| DNS Zones | > 7 | XC DNS / BIG-IP GTM | ~12 |

Also update SFDC org references to the correct orgfarm org.

### Task 3: Add Step 5 — Customer Success Streamlit App

Add a new **Step 5** after the current Step 4 (Proactive Investigation). This step uses CoCo to build a Streamlit-in-Snowflake app that serves as the CSM's daily dashboard — a place to get metrics without needing to query the Cortex Agent.

**App Layout** (multi-page Streamlit):

**Page 1: Account Overview**
- Account selector dropdown (from DIM_CUST_ACCT_SFDC)
- KPI row: Churn Risk Score, Open Cases, SKU Utilization, Consumption Trend
- Telemetry signal gauge (which signal dominates, using the threshold logic)
- Sparkline: 90-day telemetry trend for the dominant signal

**Page 2: Support & SLA**
- Open cases table with priority, product, age
- SLA compliance donut chart
- Avg resolution time by priority
- Case volume trend (MoM)

**Page 3: Sales & Renewals**
- Pipeline summary from DIM_SALES_OPPORTUNITY / FACT_SALES_OPPORTUNITY
- Active ARR from won opportunities
- Upcoming renewals (from QUOTE or DIM_SALES_OPPORTUNITY where type='Renewal')
- Install base summary (from COL_INSTALL_BASE)

**Page 4: Model Predictions**
- Accounts ranked by churn risk score (from CHURN_PREDICTIONS)
- Feature importance visualization
- "Accounts at risk but no open cases" highlight table
- Recommended actions based on dominant signal + risk score

**Data sources used**:
- `F5_PROD.RAW.DIM_CUST_ACCT_SFDC` — account master
- `F5_PROD.RAW.COL_XC_TELEMETRY` — telemetry signals
- `F5_PROD.RAW.DIM_SUPPORT_CASE` + `FACT_SUPPORT_CASE` — cases & metrics
- `F5_PROD.RAW.COL_XC_PRODUCT_HEALTHSCORE` — health scores
- `F5_PROD.RAW.DIM_SALES_OPPORTUNITY` + `FACT_SALES_OPPORTUNITY` — pipeline
- `F5_PROD.RAW.QUOTE` — quotes/renewals
- `F5_PROD.RAW.COL_INSTALL_BASE` — installed assets
- `F5_PROD.RAW.SALES_ACCOUNT_TEAM` — account ownership
- `F5_PROD.FINAL.CHURN_PREDICTIONS` — model output

The CoCo prompt will be detailed enough that attendees can paste it and get a working app deployed to Snowflake.

### Task 4: Validate HTML

- Update TOC to include Step 5
- Ensure anchor IDs are consistent (m2s5)
- Verify badge classes (CoCo vs Manual)
- Check no broken internal links

## File Changes

| File | Change |
|------|--------|
| `HOL/README.html` | Update Steps 1-2 prompts, update data summary table, add Step 5, fix TOC |

## Risks / Notes

- The Feature Store requires `ACCOUNTADMIN` or specific schema grants — attendees have SYSADMIN which should work but may need `CREATE FEATURE STORE` privileges
- XGBoost training on 130 accounts × 365 days of telemetry is fast (small dataset) — no need for Snowpark-Optimized warehouse
- The Streamlit app uses ~9 tables but they're all small — no performance concerns
- Signal classification as a feature gives the model explicit domain knowledge (which threshold bracket the account falls into), improving interpretability over raw numeric features alone
