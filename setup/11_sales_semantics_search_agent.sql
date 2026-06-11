-- ============================================================
-- F5 Hands-On Lab: Sales Semantics, Search, and Agent
-- ============================================================
-- Creates the FINAL schema with:
--   1. Cortex Search Service for Zoom transcripts
--   2. Sales Semantic View (accounts, opps, products, teams)
--   3. Cortex Agent for CoWork
-- Run as SYSADMIN after all setup/0x scripts are complete
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;

-- ============================================================
-- Step 1: Create FINAL schema
-- ============================================================
CREATE SCHEMA IF NOT EXISTS F5_PROD.FINAL;
USE SCHEMA FINAL;

-- ============================================================
-- Step 2: File format + transcript source table
-- ============================================================
CREATE OR REPLACE FILE FORMAT F5_PROD.FINAL.RAW_TEXT_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = NONE
    RECORD_DELIMITER = NONE
    ESCAPE_UNENCLOSED_FIELD = NONE;

CREATE OR REPLACE TABLE F5_PROD.FINAL.ZOOM_TRANSCRIPT_SOURCE AS
SELECT
    METADATA$FILENAME AS file_path,
    REPLACE(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(METADATA$FILENAME, '.*/', ''), '_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.txt$', '')), '_', ' ') AS account_name,
    TRY_TO_DATE(REGEXP_SUBSTR(METADATA$FILENAME, '[0-9]{4}-[0-9]{2}-[0-9]{2}')) AS call_date,
    $1::VARCHAR AS transcript_text
FROM @F5_PROD.RAW.ZOOM_TRANSCRIPTS_STAGE
    (FILE_FORMAT => 'F5_PROD.FINAL.RAW_TEXT_FORMAT');

-- ============================================================
-- Step 3: Cortex Search Service
-- ============================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE F5_PROD.FINAL.ZOOM_TRANSCRIPT_SEARCH
    ON transcript_text
    ATTRIBUTES account_name, call_date
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 day'
AS (
    SELECT transcript_text, account_name, call_date, file_path
    FROM F5_PROD.FINAL.ZOOM_TRANSCRIPT_SOURCE
);

-- ============================================================
-- Step 4: Sales Semantic View
-- ============================================================
CREATE OR REPLACE SEMANTIC VIEW F5_PROD.FINAL.F5_SALES_SEMANTIC_VIEW

  TABLES (
    accounts AS F5_PROD.RAW.DIM_CUST_ACCT_SFDC PRIMARY KEY (SFDCF5_ACCT_ID) WITH SYNONYMS ('customers', 'customer accounts') COMMENT = 'F5 customer accounts Fortune 500 companies',
    opportunities AS F5_PROD.RAW.DIM_SALES_OPPORTUNITY PRIMARY KEY (OPPORTUNITY_ID) WITH SYNONYMS ('deals', 'opps') COMMENT = 'Sales opportunities won lost and open',
    opp_facts AS F5_PROD.RAW.FACT_SALES_OPPORTUNITY PRIMARY KEY (OPPORTUNITY_ID) COMMENT = 'Opportunity dollar amounts',
    line_items AS F5_PROD.RAW.FACT_SALES_OPPORTUNITY_LINE_ITEM PRIMARY KEY (LINE_ITEM_ID) COMMENT = 'Products on opportunities with pricing',
    products AS F5_PROD.RAW.DIM_PRODUCT_OFFER PRIMARY KEY (PRODUCT_ID) COMMENT = 'F5 product catalog',
    sales_team AS F5_PROD.RAW.SALES_ACCOUNT_TEAM UNIQUE (SFDCF5_ACCT_ID) COMMENT = 'Account team assignments'
  )

  RELATIONSHIPS (
    opp_to_account AS opportunities (SFDCF5_ACCT_ID) REFERENCES accounts,
    opp_facts_to_opp AS opp_facts (OPPORTUNITY_ID) REFERENCES opportunities,
    line_items_to_opp AS line_items (OPPORTUNITY_ID) REFERENCES opportunities,
    line_items_to_product AS line_items (PRODUCT_ID) REFERENCES products,
    sales_team_to_account AS sales_team (SFDCF5_ACCT_ID) REFERENCES accounts
  )

  FACTS (
    opp_facts.opportunity_amount AS OPPORTUNITY_AMT,
    opp_facts.arr_amount AS ARR_AMT,
    opp_facts.total_contract_booking AS TOTAL_CONTRACT_BOOKING_AMT,
    opp_facts.term_months AS TERM_DURATION_MONTHS_NUM,
    line_items.line_item_price AS TOTAL_PRICE_AMT,
    line_items.line_item_net_price AS NET_PRICE_AMT,
    line_items.product_quantity AS PRODUCT_QTY,
    line_items.contract_months AS CONTRACT_LENGTH_MTH_NUM
  )

  DIMENSIONS (
    accounts.account_name AS ACCT_NAME WITH SYNONYMS = ('customer name', 'company name') COMMENT = 'Customer account name',
    accounts.industry AS INDUSTRY_NAME WITH SYNONYMS = ('vertical', 'sector') COMMENT = 'Industry classification',
    accounts.industry_group AS INDUSTRY_GROUPING_CODE COMMENT = 'Industry grouping',
    accounts.region AS ETM_REGION_NAME WITH SYNONYMS = ('territory region', 'geographic region') COMMENT = 'Sales region West Mountain Central East',
    accounts.state AS BILLING_STATE_PROVINCE_NAME COMMENT = 'Billing state',
    accounts.annual_revenue AS ANNUAL_REVENUE_AMT COMMENT = 'Customer annual revenue',
    accounts.employee_count AS EMPLOYEE_CNT COMMENT = 'Number of employees',
    accounts.ticker AS TICKER_SYMBOL_CODE COMMENT = 'Stock ticker symbol',
    opportunities.opportunity_name AS OPPORTUNITY_NAME COMMENT = 'Opportunity name',
    opportunities.opportunity_type AS OPPORTUNITY_TYPE_CODE WITH SYNONYMS = ('deal type', 'business type') COMMENT = 'New Business Expansion or Renewal',
    opportunities.stage AS OPPORTUNITY_STAGE_NAME WITH SYNONYMS = ('deal stage', 'opportunity status') COMMENT = 'Current opportunity stage',
    opportunities.close_date AS OPPORTUNITY_CLOSE_DATE COMMENT = 'Close date',
    opportunities.close_probability AS OPPORTUNITY_CLOSE_PROBABILITY_PCT COMMENT = 'Win probability percentage',
    opportunities.forecast_category AS FORECAST_CATEGORY_NAME WITH SYNONYMS = ('forecast') COMMENT = 'Forecast category',
    opportunities.is_won AS OPPORTUNITY_WON_IND COMMENT = 'Won indicator',
    opportunities.is_closed AS OPPORTUNITY_CLOSED_IND COMMENT = 'Closed indicator',
    opportunities.competitor AS PRIMARY_COMPETITOR_NAME WITH SYNONYMS = ('competitive threat', 'lost to') COMMENT = 'Primary competitor',
    opportunities.loss_reason AS PRIMARY_REASON_WON_LOST_ABANDONED_CODE WITH SYNONYMS = ('why we lost', 'loss reason') COMMENT = 'Reason deal was lost',
    opportunities.loss_description AS REASON_WON_LOST_ABANDONED_DESC COMMENT = 'Loss reason description',
    opportunities.owner_name AS OPPORTUNITY_OWNER_NAME COMMENT = 'Opportunity owner name',
    opportunities.renewal_flag AS RENEWAL_FLAG COMMENT = 'Y if renewal N if not',
    products.brand AS BRAND_NAME WITH SYNONYMS = ('product line', 'product brand') COMMENT = 'BIG-IP NGINX Distributed Cloud Calypso AI or F5',
    products.sku AS OFFER_SKU_ID COMMENT = 'Product SKU',
    products.product_description AS OFFER_DESC COMMENT = 'Product description',
    products.product_family AS F5_PRODUCT_OFFER_FAMILY_NAME COMMENT = 'Product family',
    products.product_type AS PRODUCT_OFFERING_TYPE_NAME COMMENT = 'Hardware Software SaaS or Support',
    products.list_price AS STANDARD_LIST_PRICE_AMT COMMENT = 'Standard list price',
    sales_team.ae_name AS AE_NAME WITH SYNONYMS = ('account executive', 'AE', 'sales rep') COMMENT = 'Account executive name',
    sales_team.se_name AS SE_NAME WITH SYNONYMS = ('solutions engineer', 'SE') COMMENT = 'Solutions engineer name',
    sales_team.sdr_name AS SDR_NAME COMMENT = 'SDR name',
    sales_team.territory AS TERRITORY_NAME COMMENT = 'Sales territory',
    sales_team.sales_region AS REGION_NAME COMMENT = 'Region name',
    sales_team.timezone AS TIMEZONE_REGION COMMENT = 'Pacific Mountain Central or Eastern'
  )

  METRICS (
    opportunities.total_pipeline_value AS SUM(opp_facts.opportunity_amount) WITH SYNONYMS = ('pipeline value', 'total pipeline') COMMENT = 'Total pipeline value in dollars',
    opportunities.total_arr AS SUM(opp_facts.arr_amount) WITH SYNONYMS = ('annual recurring revenue', 'total ARR') COMMENT = 'Total annual recurring revenue',
    opportunities.total_bookings AS SUM(opp_facts.total_contract_booking) WITH SYNONYMS = ('total contract value', 'TCV', 'bookings') COMMENT = 'Total contract bookings for won deals',
    opportunities.deal_count AS COUNT(OPPORTUNITY_ID) WITH SYNONYMS = ('number of deals', 'opportunity count') COMMENT = 'Count of opportunities',
    opportunities.average_deal_size AS AVG(opp_facts.opportunity_amount) WITH SYNONYMS = ('avg deal size') COMMENT = 'Average opportunity dollar amount',
    opportunities.win_rate AS AVG(CASE WHEN OPPORTUNITY_CLOSED_IND THEN CASE WHEN OPPORTUNITY_WON_IND THEN 1.0 ELSE 0.0 END ELSE NULL END) WITH SYNONYMS = ('close rate', 'conversion rate') COMMENT = 'Win rate for closed opportunities',
    line_items.total_line_item_value AS SUM(line_items.line_item_price) COMMENT = 'Total value of all line items',
    accounts.account_count AS COUNT(accounts.SFDCF5_ACCT_ID) COMMENT = 'Count of accounts'
  )

  COMMENT = 'F5 Sales semantic view for accounts opportunities pipeline products and sales teams. Covers sales contracts and opportunity data only. Does not include telemetry or support data.'

  AI_SQL_GENERATION 'Round dollar amounts to 2 decimal places. For win rate only include closed opportunities where OPPORTUNITY_CLOSED_IND is TRUE. Region values are West Mountain Central East. Brand values are BIG-IP NGINX Distributed Cloud Calypso AI F5. When asked about failed expansions filter for OPPORTUNITY_TYPE_CODE = Expansion AND OPPORTUNITY_WON_IND = FALSE AND OPPORTUNITY_CLOSED_IND = TRUE.'

  AI_QUESTION_CATEGORIZATION 'This view covers sales pipeline and opportunity data. If asked about support cases telemetry product usage or health scores say this data is not available in the sales view. If asked about a specific account without providing the name ask which account they mean.';

-- ============================================================
-- Step 5: Cortex Agent for CoWork
-- ============================================================
-- KEY LEARNINGS:
--   tool_resources for cortex_analyst_text_to_sql requires:
--     execution_environment:
--       type: warehouse
--       warehouse: "WAREHOUSE_NAME"
--   tool_resources for cortex_search requires:
--     search_service: "DB.SCHEMA.SERVICE_NAME"  (NOT "name:")
-- ============================================================
CREATE OR REPLACE AGENT F5_PROD.FINAL.F5_SALES_AGENT
  COMMENT = 'F5 Sales Intelligence Agent'
  PROFILE = '{"display_name": "F5 Sales Intelligence", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 600
      tokens: 32000

  instructions:
    response: "You are an F5 sales intelligence assistant. Provide concise, data-driven answers about customer accounts, pipeline, opportunities, products, and sales team coverage. Format dollar amounts with $ and commas. If asked about support, telemetry, or product usage data, explain that this agent covers sales data only."
    orchestration: "Use SalesAnalytics for any question about accounts, pipeline, revenue, opportunities, products, deals, territories, or sales teams. Use TranscriptSearch for questions about customer conversations, call notes, or meeting insights. Use WebSearch for public company information like earnings, news, 10-K filings, or press releases."
    sample_questions:
      - question: "What is the total pipeline value by region?"
      - question: "Which accounts have failed expansion proposals and why?"
      - question: "Show me the top 10 accounts by ARR"
      - question: "Which competitors do we lose to most often?"
      - question: "What did Intel say about their cloud migration plans?"
      - question: "What is Nvidia's latest quarterly revenue?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "SalesAnalytics"
        description: "Queries structured sales data including customer accounts, opportunities, pipeline, products, sales teams, territories, quotes, and contracts. Use for any quantitative question about accounts, revenue, ARR, deal sizes, win rates, competitor analysis, product mix, or territory coverage."
    - tool_spec:
        type: "cortex_search"
        name: "TranscriptSearch"
        description: "Searches Zoom call transcripts from customer meetings. Contains conversations between F5 sales teams and customer stakeholders discussing product feedback, competitive threats, budget planning, technology changes, and business strategy."
    - tool_spec:
        type: "web_search"
        name: "WebSearch"
        description: "Searches the public internet for company information including SEC filings, 10-K and 10-Q reports, press releases, LinkedIn posts, recent news, earnings reports, acquisitions, or industry trends."

  tool_resources:
    SalesAnalytics:
      execution_environment:
        type: warehouse
        warehouse: "COMPUTE_WH"
      semantic_view: "F5_PROD.FINAL.F5_SALES_SEMANTIC_VIEW"
    TranscriptSearch:
      search_service: "F5_PROD.FINAL.ZOOM_TRANSCRIPT_SEARCH"
      max_results: 5
      title_column: "account_name"
      id_column: "file_path"
    WebSearch:
      max_results: 10
  $$;

-- Grant public access to agent and dependencies
GRANT USAGE ON DATABASE F5_PROD TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA F5_PROD.FINAL TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA F5_PROD.RAW TO ROLE PUBLIC;
GRANT USAGE ON AGENT F5_PROD.FINAL.F5_SALES_AGENT TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA F5_PROD.RAW TO ROLE PUBLIC;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW F5_PROD.FINAL.F5_SALES_SEMANTIC_VIEW TO ROLE PUBLIC;
GRANT USAGE ON CORTEX SEARCH SERVICE F5_PROD.FINAL.ZOOM_TRANSCRIPT_SEARCH TO ROLE PUBLIC;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PUBLIC;

-- ============================================================
-- Verification queries
-- ============================================================

-- Test Cortex Search
SELECT value:account_name::VARCHAR AS account, LEFT(value:transcript_text::VARCHAR, 100) AS preview
FROM TABLE(FLATTEN(PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'F5_PROD.FINAL.ZOOM_TRANSCRIPT_SEARCH',
    '{"query": "budget constraints competitor", "columns": ["account_name", "transcript_text"], "limit": 3}'
  ))['results']));

-- Test Semantic View
SELECT * FROM SEMANTIC_VIEW(
  F5_PROD.FINAL.F5_SALES_SEMANTIC_VIEW
  DIMENSIONS accounts.region
  METRICS opportunities.total_pipeline_value, opportunities.deal_count, opportunities.win_rate
);

-- Test failed expansions
SELECT * FROM SEMANTIC_VIEW(
  F5_PROD.FINAL.F5_SALES_SEMANTIC_VIEW
  DIMENSIONS accounts.account_name, opportunities.loss_reason, opportunities.competitor
  METRICS opportunities.deal_count, opportunities.total_pipeline_value
  WHERE opportunities.is_closed = TRUE AND opportunities.is_won = FALSE AND opportunities.loss_reason IS NOT NULL
)
ORDER BY total_pipeline_value DESC LIMIT 10;
