# Plan: Churn Propensity Model Notebook

## Context

**Data Profile:**
- 116 accounts have health scores (CONSUMPTION_PATTERN labels)
- 26 are "Declining" = positive class (22% prevalence — good class balance)
- 130 accounts have telemetry (365 days × 130 = 47,450 rows)
- 1,125 support cases across accounts
- Telemetry columns: HTTP LB, TCP LB, endpoints, WAF, bot txn (adv/std), DNS zones, namespaces, sites, users, virtual hosts
- Support fact: time_to_close, time_to_response, time_over_under_SLA, time_to_resolution

**Approach:**
- Feature engineer 1 row per account from aggregated telemetry + support + health data
- Signal classification as categorical feature (CASE on thresholds)
- XGBoost with GridSearch (dataset is small enough for fast CV)
- Feature Store + Model Registry for production pattern
- Batch inference on all 130 telemetry accounts (not just 116 with labels)

## Implementation: 8 Notebook Cells

### Cell 1: Setup and Connection
```python
# Imports, session setup, warehouse/database context
# snowflake.ml imports: FeatureStore, Registry, XGBClassifier, GridSearchCV, Pipeline, metrics
```

### Cell 2: Feature Engineering (SQL)
Build `F5_PROD.FINAL.CHURN_FEATURES` with one row per account:
- **Signal classification**: CASE WHEN on telemetry averages (60-day window) → categorical column DOMINANT_SIGNAL
- **Trend slopes**: REGR_SLOPE on each metric over 90 days (HTTP_LB_SLOPE, WAF_SLOPE, BOT_SLOPE, ENDPOINT_SLOPE, DNS_SLOPE)
- **Volume stats**: AVG + STDDEV for each telemetry metric (60-day window)
- **Support features**: open case count, total cases 180d, avg resolution hours, SLA breach count, P1/P2 escalation count
- **Health**: SKU_UTILIZATION_PCT
- **Target**: 1 if CONSUMPTION_PATTERN = 'Declining' else 0

Key SQL uses CTEs joining COL_XC_TELEMETRY, DIM_SUPPORT_CASE, FACT_SUPPORT_CASE, COL_XC_PRODUCT_HEALTHSCORE via SFDCF5_ACCT_ID.

### Cell 3: Feature Store Registration
```python
# Create FeatureStore in F5_PROD.FINAL
# Define ACCOUNT entity with join key SFDCF5_ACCT_ID
# Register FeatureView from CHURN_FEATURES table
# Generate training Dataset (spine = accounts with TARGET labels)
```

### Cell 4: Preprocessing Pipeline
```python
# OneHotEncoder on DOMINANT_SIGNAL (categorical)
# MinMaxScaler on all numeric features
# Split 80/20 stratified on TARGET
```

### Cell 5: Model Training with GridSearch
```python
# XGBClassifier with GridSearchCV
# Param grid: n_estimators [100,200,300], learning_rate [0.05,0.1,0.2], max_depth [3,4,5]
# 5-fold CV
# Print best params
```

### Cell 6: Model Evaluation
```python
# Predict on test set
# accuracy_score, precision_score, recall_score, f1_score, confusion_matrix
# Feature importance bar chart (top 10)
```

### Cell 7: Register in Model Registry
```python
# Registry(session, database_name='F5_PROD', schema_name='FINAL')
# Log model with metrics, sample input
# Print registered model info
```

### Cell 8: Batch Inference
```python
# Load model from registry
# Run predictions on ALL accounts with telemetry (130 accounts, not just 116 with labels)
# Write to F5_PROD.FINAL.CHURN_PREDICTIONS:
#   SFDCF5_ACCT_ID, ACCT_NAME, CHURN_RISK_SCORE, PREDICTED_PATTERN, 
#   DOMINANT_SIGNAL, TOP_RISK_FACTOR, PREDICTION_DATE
# Display top 10 highest risk accounts
```

## Verification

After running all cells:
1. `SELECT COUNT(*) FROM F5_PROD.FINAL.CHURN_PREDICTIONS` — should return ~130 rows
2. `SELECT * FROM F5_PROD.FINAL.CHURN_PREDICTIONS ORDER BY CHURN_RISK_SCORE DESC LIMIT 5` — verify predictions exist
3. Model metrics: F1 > 0.5 expected (26 positive / 116 total is decent)
4. Feature Store: `SHOW FEATURE VIEWS IN F5_PROD.FINAL` — view registered
5. Model Registry: `SHOW MODELS IN F5_PROD.FINAL` — model registered

## Risks

- **Small dataset (116 labeled samples)**: GridSearch with 5-fold CV on 116 samples means ~23 per fold in train. If this causes issues, fall back to a single XGBClassifier with n_estimators=200, max_depth=4.
- **Feature Store availability**: Feature Store requires specific Snowflake version. If unavailable, fall back to creating the feature table directly and skip FS registration (Cells 2 + 4-8 still work).
- **Class imbalance**: 26/116 positive = 22%, which is actually well-balanced. No need for SMOTE or class weights.

## Critical Files

- Notebook (new): `HOL/churn_model.ipynb` — The notebook to create
- `Account_Prep/setup/09_insert_telemetry_and_consumption.sql` — Source of telemetry data schema
- `Account_Prep/setup/08_insert_support_and_install_base.sql` — Source of support case data schema
- `HOL/README.html` — References F5_PROD.FINAL.CHURN_PREDICTIONS as the expected output
