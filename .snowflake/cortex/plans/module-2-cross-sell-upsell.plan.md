# Plan: Replace Module 2 with Cross-Sell/Upsell Model

## Context

Same data sources as before but the model output is multi-row recommendations per account (not binary churn). Step 3 adds to the **sales semantic view** (from script 11) rather than the support/telemetry one. Step 5 uses the Option B Slack message.

## Implementation

### README Changes

**Module 2 header**: "Cross-Sell & Upsell Recommendations"

**Step 1 (CoCo)**: Notebook prompt asking CoCo to build a recommendation model using product ownership, telemetry, utilization, support patterns, and contract timing. Multi-label output.

**Step 2 (Manual)**: Review cells, verify CROSS_SELL_RECOMMENDATIONS table has multiple rows per account with relevant SKUs and rationale.

**Step 3 (Manual)**: Add CROSS_SELL_RECOMMENDATIONS to the **sales semantic view** (not support/telemetry). UI instructions for adding table, join on SFDCF5_ACCT_ID, dimensions (RECOMMENDED_SKU, RECOMMENDATION_TYPE, RATIONALE), fact (CONFIDENCE_SCORE), metric (expansion opportunity count).

**Step 4 (Manual)**: Test questions focused on expansion:
- "Which accounts are over 80% utilization and approaching renewal?"
- "What should we recommend to [MY ACCOUNT] based on their telemetry and current products?"
- "Which accounts have WAF cases but no XC Bot Defense?"
- "Create a Salesforce case for accounts that need capacity upgrades"

**Step 5 (Challenge)**: Slack message from Sarah K, VP Customer Growth (Option B):

> @here becoming a real problem. We're sitting on a huge customer base but I have no visibility into which accounts are ready to expand. Every quarter we scramble to find upsell opportunities based on gut instinct instead of data.
>
> I need to see which accounts should be buying more products, which ones need capacity upgrades, and what our expansion model is predicting. If an account is likely to buy something, I want to know what and why.
>
> I've been using Tableau but it's static and always a week behind. Need something interactive in Snowflake where I can drill into any account.
>
> Need a working prototype by end of day.
>
> - Sarah K, VP Customer Growth

### Notebook (HOL/recommendation_model.ipynb)

8-cell structure:
1. Setup and connection
2. Feature engineering: product ownership matrix (which SKUs each account has), whitespace (catalog minus owned), utilization signals, telemetry-to-product gaps, support product areas, contract months remaining
3. Feature Store registration
4. Preprocessing (OHE on product categories, scaling on numerics)
5. Model training (multi-output XGBoost or rule+ML hybrid with GridSearch)
6. Evaluation (precision per recommendation type)
7. Model Registry
8. Batch inference -> CROSS_SELL_RECOMMENDATIONS (multiple rows per account with: SFDCF5_ACCT_ID, ACCT_NAME, RECOMMENDED_SKU, RECOMMENDATION_TYPE, CONFIDENCE_SCORE, RATIONALE, PRIORITY_RANK, PREDICTION_DATE)

### Cleanup

- Delete HOL/churn_model.ipynb (replaced by recommendation_model.ipynb)
- Update Overview "What You'll Build" list
- Update Data Summary if needed
- Update troubleshooting section (remove churn-specific entries)

## Verification

- CROSS_SELL_RECOMMENDATIONS has 3-5 rows per account
- Recommendations make sense: high WAF accounts get Bot Defense, high-utilization accounts get capacity
- Sales agent can answer "what should we recommend to X?"

## Critical Files

- `HOL/README.html` - Module 2 rewrite
- `HOL/recommendation_model.ipynb` - New notebook (replaces churn_model.ipynb)
