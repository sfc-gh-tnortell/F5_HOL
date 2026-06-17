# <h1black>F5 Telemetry & Support Intelligence — </h1black><h1blue>Hands-On Lab</h1blue>

### <h1sub>Overview</h1sub>

Build a Cortex Agent that discovers hidden correlations between F5 Distributed Cloud telemetry signals and customer support cases. You'll analyze historical SQL queries, create semantic views, build agents, and train a cross-sell/upsell model, all using Snowflake Cortex Code and Intelligence.

---

## Table of Contents

- [Overview](#overview)
- [Your Assigned Customer](#your-assigned-customer)
- [Module 1: Support & Telemetry Agent](#module-1-support--telemetry-agent)
    - [Step 1: Analyze SQL Query Patterns (CoCo)](#step-1-analyze-sql-query-patterns)
    - [Step 2: Create Support/Telemetry Semantic View (CoCo)](#step-2-create-supporttelemetry-semantic-view)
    - [Step 3: Create Customer Support Agent (Manual)](#step-3-create-customer-support-agent)
    - [Step 4: Connect Salesforce via MCP (Manual)](#step-4-connect-salesforce-via-mcp)
    - [Step 5: Test - Find Telemetry/Case Correlations (Manual)](#step-5-test---find-telemetrycase-correlations)
    - [Step 6 (Optional): Build a Proactive Trend Model (CoCo)](#step-6-optional-build-a-proactive-trend-model)
- [Module 2: Cross-Sell & Upsell Recommendations](#module-2-cross-sell--upsell-recommendations)
    - [Step 1: Build Recommendation Model Notebook (CoCo)](#step-1-build-recommendation-model-notebook)
    - [Step 2: Review Recommendations (Manual)](#step-2-review-recommendations)
    - [Step 3: Add Recommendations to Sales Agent (Manual)](#step-3-add-recommendations-to-sales-agent)
    - [Step 4: Test Expansion Queries (Manual)](#step-4-test-expansion-queries)
    - [Step 5: Customer Growth Dashboard (Challenge)](#step-5-customer-growth-dashboard)
- [Data Summary](#data-summary)

---

## What You'll Build

- **Support/Telemetry Semantic View** derived from analyzing 60+ real SQL queries
- **Cortex Agent** that queries telemetry + support cases + Salesforce via MCP
- **Cross-Sell/Upsell Model** using Snowflake ML Feature Store + XGBoost + Model Registry
- **Customer Growth Dashboard** - interactive app with expansion opportunities and recommendations
- **Proactive Case Detection** using telemetry spikes to predict support issues before they're reported

### Architecture

```
+-----------------------------------------------------------------------+
|                           CoWork                                       |
|  +---------------------------------------------------------------+    |
|  |                F5 Customer Support Agent                       |    |
|  |  +--------------+  +--------------+  +---------------------+  |    |
|  |  |Cortex Analyst|  |Cortex Search |  |  Salesforce MCP     |  |    |
|  |  |(Support +    |  |(Zoom         |  |(External Tickets)   |  |    |
|  |  | Telemetry SV)|  | Transcripts) |  |                     |  |    |
|  |  +--------------+  +--------------+  +---------------------+  |    |
|  +---------------------------------------------------------------+    |
|                              |                                         |
|  +---------------------------------------------------------------+    |
|  |                    F5_PROD Database                             |    |
|  |  +----------------+  +-----------------+  +----------------+   |    |
|  |  | RAW Schema     |  | FINAL Schema    |  | ML Predictions |   |    |
|  |  | - Telemetry    |  | - Semantic View |  | - Churn Score  |   |    |
|  |  | - Support Cases|  | - Search Svc    |  | - Risk Table   |   |    |
|  |  | - Health Score |  | - Agent         |  |                |   |    |
|  |  +----------------+  +-----------------+  +----------------+   |    |
|  +---------------------------------------------------------------+    |
+-----------------------------------------------------------------------+
                               |
      Salesforce MCP Connector |     Cortex Code (CoCo)
    +-----------------------+  |  +-----------------------+
    | orgfarm (SFDC)       |  |  | SQL Analysis          |
    | - SFDC Cases          |  |  | Semantic View Builder |
    | - Open/Closed cases   |  |  | ML Model Training     |
    +-----------------------+  |  +-----------------------+
```

### Data Already Available

| Table | Description | Rows |
|-------|-------------|------|
| `COL_XC_TELEMETRY` | Daily XC usage metrics (12 months) | ~47,000 |
| `DIM_SUPPORT_CASE` | Support cases correlated to telemetry | ~1,100 |
| `FACT_SUPPORT_CASE` | Case resolution metrics (SLA, time-to-close) | ~1,100 |
| `COL_XC_PRODUCT_HEALTHSCORE` | Account health scores | ~130 |
| `DIM_CUST_ACCT_SFDC` | 184 Fortune 500 customer accounts | 184 |
| `COL_TERM_SUB_MONTHLY_USAGE_V2` | Monthly consumption/billing data | ~6,000 |

---

## Your Assigned Customer

Each attendee is assigned a specific F5 customer account to work with during the lab. Focus your agent queries and Salesforce updates on your assigned account to avoid conflicts with other attendees.

| # | Snowflake Account | Assigned Account | Signal Type |
|---|-------------------|-----------------|-------------|
| 1 | F5_HOL_BIABNL | Amazon | bot-defense |
| 2 | F5_HOL_ZEKKPR | Republic Services | bot-defense |
| 3 | F5_HOL_TVJWZL | Cloudflare | bot-defense |
| 4 | F5_HOL_ZCGUWB | Fidelity | bot-defense |
| 5 | F5_HOL_PUNPFP | Accenture | bot-defense |
| 6 | F5_HOL_WJNEMH | Morgan Stanley | bot-defense |
| 7 | F5_HOL_MCLDHV | Costco | bot-defense |
| 8 | F5_HOL_YABWEP | Comcast | bot-defense |
| 9 | F5_HOL_RKSGYH | Raytheon Technologies | bot-defense |
| 10 | F5_HOL_YSNNBK | CDW | bot-defense |
| 11 | F5_HOL_FSIDVS | Airbnb | waf |
| 12 | F5_HOL_RYDRLM | Delta Air Lines | waf |
| 13 | F5_HOL_ZGBVWK | Abbott Laboratories | waf |
| 14 | F5_HOL_AASUAF | Duke Energy | waf |
| 15 | F5_HOL_WMJUIZ | eBay | waf |
| 16 | F5_HOL_SEMCJS | Cardinal Health | waf |
| 17 | F5_HOL_NKGMLH | Cognizant | waf |
| 18 | F5_HOL_KJJPAF | Honeywell | waf |
| 19 | F5_HOL_IMDUJG | American Airlines | capacity |
| 20 | F5_HOL_TTZBRR | CVS Health | capacity |
| 21 | F5_HOL_ZEJLNK | Albertsons | capacity |
| 22 | F5_HOL_RTFILS | CrowdStrike | capacity |
| 23 | F5_HOL_FMEZJG | Caterpillar | capacity |
| 24 | F5_HOL_PERDEK | CSX | capacity |
| 25 | F5_HOL_DNEBWG | Johnson & Johnson | capacity |
| 26 | F5_HOL_CKVBZA | Palo Alto Networks | capacity |
| 27 | F5_HOL_HRVRBR | BlackRock | bot-defense |
| 28 | F5_HOL_KVWMPA | Dell Technologies | load-balancer |
| 29 | F5_HOL_SHSUJV | EOG Resources | load-balancer |
| 30 | F5_HOL_TZWAUX | Rockwell Automation | load-balancer |
| 31 | F5_HOL_JJGJWV | Qualcomm | load-balancer |
| 32 | F5_HOL_ZKSHWJ | AmerisourceBergen | dns |
| 33 | F5_HOL_ZHMTDX | Aon | load-balancer |
| 34 | F5_HOL_UKGRNB | Dish Network | dns |
| 35 | F5_HOL_EUVJDT | Elevance Health | dns |
| 36 | F5_HOL_GDKZEI | Visa | bot-defense |
| 37 | F5_HOL_DMLTUF | Netflix | bot-defense |
| 38 | F5_HOL_RIHNCY | Adobe | bot-defense |
| 39 | F5_HOL_ITMHRV | Goldman Sachs | capacity |
| 40 | F5_HOL_WPKXYL | Intel | waf |
| 41 | F5_HOL_PZKPYL | AT&T | bot-defense |
| 42 | F5_HOL_UTJGAD | Tesla | load-balancer |
| 43 | F5_HOL_UJPTEW | Splunk | dns |
| 44 | F5_HOL_RTSWPH | PayPal | waf |

!!! note "Instructions"
    When testing your agent or writing back to Salesforce, filter your queries to your assigned account. For example: "Show me telemetry and open cases for Amazon" or "Create a Salesforce case for the bot defense issue at Amazon."

---

## Module 1: Support & Telemetry Agent

In this module you'll build a Cortex Agent specialized for customer support and telemetry analysis. The goal: discover which customers have telemetry signals that correlate with open support cases.

---

### Step 1: Analyze SQL Query Patterns

`CoCo`{: .badge-coco }

We have 60 historical SQL queries written by different personas (Support Analyst, Data Engineer, Sales Ops, CSM, Executive). Analyze them to identify the most important patterns and distill them into 5 verified queries for a Cortex Skill.

!!! coco "Cortex Code Prompt"
    Open `Account_Prep/setup/12_query_repository_support_cs.sql` and use the following prompt:

    ```
    Analyze the 60 SQL queries in this file. These were written by different personas 
    to answer support and telemetry questions. I need you to:

    1. Identify the key dimensions, metrics, and join patterns used across all queries
    2. Group queries by intent (case analysis, telemetry correlation, SLA tracking, etc.)
    3. Find inconsistencies where different queries calculate the same metric differently 
       and recommend which calculation to standardize on
    4. Distill the top 5 most impactful queries that cover the broadest analytical needs
    5. For each of the 5 queries, write it as a clean SELECT statement with a comment 
       explaining the business question it answers and which persona asks it

    These will be used as verified query representations (VQRs) when building 
    a semantic view. Write them as plain SELECT statements, not functions.

    Also create a reusable Cortex Code skill (SKILL.md) that captures this 
    analysis workflow so I can repeat it on a different query repository in 
    another domain. Install it to ~/.snowflake/cortex/skills/query-analysis/
    ```

**Expected Output:**

- `HOL/verified_queries.sql` - 5 SELECT statements, each with business question + persona header
- `~/.snowflake/cortex/skills/query-analysis/SKILL.md` - Reusable Cortex Code skill for any domain
- Analysis summary: table frequency, join patterns, identified inconsistencies with recommendations

---

### Step 2: Create Support/Telemetry Semantic View

Using the verified queries from Step 1, create a semantic view. Choose one of the two options below:

#### Option A: Cortex Code

`CoCo`{: .badge-coco }

Open the verified queries file generated in Step 1 and use the following prompt:

!!! coco "Cortex Code Prompt"
    ```
    Using the verified queries in HOL/verified_queries.sql, create a semantic view 
    for support and telemetry analysis. The queries show the tables, joins, 
    dimensions, and metrics that matter most.

    Create it as: F5_PROD.FINAL.F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW

    Include the verified queries as VQRs in the semantic view definition.
    ```

#### Option B: Snowsight UI (Semantic Auto-Generator)

`Manual`{: .badge-manual }

1. Navigate to **AI & ML → Cortex Analyst → Semantic Views**
2. Click **+ Create Semantic View**
3. Select **Generate from verified queries**
4. Upload or paste the contents of `HOL/verified_queries.sql`
5. The auto-generator will infer tables, relationships, dimensions, metrics, and facts from the SQL
6. Review the generated semantic view structure:
    - Confirm tables: DIM_SUPPORT_CASE, FACT_SUPPORT_CASE, COL_XC_TELEMETRY, COL_XC_PRODUCT_HEALTHSCORE, DIM_CUST_ACCT_SFDC
    - Confirm relationships are joined on SFDCF5_ACCT_ID and SUPPORT_CASE_ID
    - Confirm metrics include: open_case_count, avg_resolution_hours, sla_breach_rate, avg_bot_transactions
7. Set the name to `F5_PROD.FINAL.F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW`
8. Click **Create**

!!! note "Key Insight"
    The telemetry signals (bot-defense, waf, capacity, load-balancer, dns) map directly to support case categories. This is the correlation the agent will discover, but it's not explicit in the schema.

---

### Step 3: Create Customer Support Agent

`Manual`{: .badge-manual }

Create the agent in the Snowflake UI that combines the semantic view with search and MCP tools.

1. Navigate to **AI & ML → CoWork**
2. Click **+ Create Agent**
3. Configure:

    | Setting | Value |
    |---------|-------|
    | Name | `F5_SUPPORT_AGENT` |
    | Model | `auto` |
    | Database | `F5_PROD` |
    | Schema | `FINAL` |
    | Time Limit | `600` seconds |
    | Token Limit | `32000` |

4. Add tools:

    | Tool Type | Name | Configuration |
    |-----------|------|---------------|
    | Cortex Analyst | SupportAnalyst | Semantic View: `F5_PROD.FINAL.F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW` |

5. Set the system prompt:

    ```
    You are an F5 customer support intelligence agent. You help identify accounts 
    where telemetry signals correlate with open support cases. When you find matches:
    1. Query telemetry data for anomalous signals (high bot traffic, WAF spikes, 
       endpoint growth, etc.)
    2. Check if matching support cases exist for those accounts
    3. Recommend proactive actions based on the correlation
    ```

6. Click **Save**

---

### Step 4: Connect Salesforce via MCP

`Manual`{: .badge-manual }

Set up the Salesforce MCP connector so the agent can read and create Cases in Salesforce.

#### 4a: Snowflake MCP Connector Setup

1. Navigate to **AI & ML → Agents → Settings → Tools and Connectors**
2. Click **Browse Connectors** → select **Salesforce**
3. Fill in the following fields:

    | Field | Value |
    |-------|-------|
    | Server URL | `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all` |
    | Token Endpoint | `https://login.salesforce.com/services/oauth2/token` |
    | Authorization Endpoint | `https://login.salesforce.com/services/oauth2/authorize` |
    | OAuth Client ID | *Provided by instructor* |
    | OAuth Client Secret | *Provided by instructor* |
    | Scopes | `mcp_api` |

4. Select a database and schema (e.g., `F5_PROD.PUBLIC`)
5. Click **Add**

#### 4b: Add to Agent and Authenticate

1. Navigate to **AI & ML → CoWork**
2. Find `F5_SUPPORT_AGENT` → click **Edit**
3. Click **+ Add Tool** → select **MCP** → select `salesforce_mcp`
4. Click **Save**
5. Open the agent in CoWork. In the **Sources** panel, click **Connect** next to Salesforce
6. Sign in with the shared Salesforce credentials:

    | Field | Value |
    |-------|-------|
    | Username | `hol_user.efdc4a845334@agentforce.com` |
    | Password | `F5hol_user` |

!!! note "Salesforce Cases"
    Support cases in `DIM_SUPPORT_CASE.SUPPORT_CASE_NUM` match Salesforce CaseNumbers. Each case is linked to an Account object in Salesforce with the same account names as in `DIM_CUST_ACCT_SFDC`.

---

### Step 5: Test - Find Telemetry/Case Correlations

`Manual`{: .badge-manual }

Use your agent to investigate your assigned customer. Follow this sequence to discover the telemetry-support correlation and write findings back to Salesforce.

#### Part A: Find Your Customer's Open Cases

Replace `[YOUR ACCOUNT]` with your assigned customer name from Section 3.

| # | Question to Ask the Agent |
|---|--------------------------|
| 1 | "What open support cases does **[YOUR ACCOUNT]** have? Show me the case title, priority, and product category." |
| 2 | "What is the telemetry profile for **[YOUR ACCOUNT]**? Show me their average bot transactions, WAF usage, endpoint count, and load balancers over the last 60 days." |

#### Part B: Discover the Correlation

| # | Question to Ask the Agent |
|---|--------------------------|
| 3 | "Compare the telemetry signals for **[YOUR ACCOUNT]** with their open case categories. Is there a correlation between what the telemetry shows and what they filed a case about?" |
| 4 | "Look at the telemetry trend for **[YOUR ACCOUNT]** over the past 6 months. Did the signal that matches their case category increase before the case was opened?" |

#### Part C: Write Observations Back to Salesforce

| # | Question to Ask the Agent |
|---|--------------------------|
| 5 | "Find the Salesforce case for **[YOUR ACCOUNT]**'s open issue. Add a comment noting the telemetry correlation you found. Include the specific metric values and the trend direction." |
| 6 | "Based on the telemetry trends for **[YOUR ACCOUNT]**, do you think this issue will get worse? If so, create a new Salesforce case recommending a proactive review with the customer." |

!!! success "Success Criteria"
    By the end of this step you should have:

    1. Identified that your customer's open case category matches their dominant telemetry signal
    2. Found telemetry evidence that supports (or preceded) the reported issue
    3. Written a comment on the existing Salesforce case with your telemetry findings
    4. Optionally created a proactive Salesforce case if the trend suggests escalation

---

### Step 6 (Optional): Build a Proactive Trend Model

`CoCo`{: .badge-coco }

If you finish Step 5 early, use Cortex Code to build a lightweight model that detects telemetry trends *before* they become support cases.

!!! coco "Cortex Code Prompt"
    ```
    Using the telemetry data in F5_PROD.RAW.COL_XC_TELEMETRY for my assigned 
    account [YOUR ACCOUNT], build a proactive trend detection model:

    1. Calculate the 30-day rolling slope for each telemetry signal 
       (bot transactions, WAF usage, endpoints, load balancers, DNS zones)
    2. Compare these slopes to the dates when support cases were opened 
       (from DIM_SUPPORT_CASE.CREATED_DATETIME)
    3. Identify which signal slopes were increasing in the 30 days BEFORE 
       each case was created
    4. Build a simple threshold rule: if a signal's 30-day slope exceeds 
       the pre-case average slope, flag it as "trending toward a case"
    5. Apply this rule to current telemetry and tell me if any signals 
       are currently trending in a way that preceded past cases

    Output a summary table showing: signal name, current slope, 
    pre-case average slope, and whether it's flagged.
    ```

!!! note "What this demonstrates"
    Telemetry trends are leading indicators of support cases. If bot transactions were climbing 5% daily for 2 weeks before a "credential stuffing" case was filed, that same pattern today means a case is likely coming, and we can act before it does.

---

## Module 2: Cross-Sell & Upsell Recommendations

Build a recommendation model that identifies which accounts are ready to expand and what products to pitch them, based on their current product mix, telemetry signals, utilization patterns, support history, and contract timing.

---

### Step 1: Build Recommendation Model Notebook

`CoCo`{: .badge-coco }

!!! coco "Cortex Code Prompt"
    ```
    You are a senior ML engineer. Create a Snowflake Notebook that builds a 
    cross-sell/upsell recommendation model for our F5 accounts following 
    classical ML best practices.

    This will run in Snowflake Workspaces (container-based). Train the model 
    locally in the container using sklearn and xgboost.

    The model should recommend additional products or capacity upgrades for 
    each account based on what they currently own, their telemetry usage, 
    support case patterns, utilization levels, and contract timing.

    Use historical expansion deals (won vs lost) as training labels.

    The notebook should walk through:
    1. Feature engineering from product ownership, telemetry, utilization, 
       support gaps, and renewal dates
    2. Feature Store registration
    3. Model training with proper train/test split, class weighting, 
       and hyperparameter tuning
    4. Model evaluation with classification metrics
    5. Register in Model Registry
    6. Batch inference - write to F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS

    Output should be MULTIPLE rows per account (one per recommendation) with 
    the recommended SKU, recommendation type (cross-sell/upsell/capacity), 
    confidence score, and a human-readable rationale explaining why in plain 
    business language (not raw feature names).

    Make each section a separate cell so I can run and review step by step.
    ```

!!! note "What you'll do"
    Run each cell in the notebook, review the features, inspect which products get recommended to which accounts, and confirm the output table makes sense for your assigned account.

#### Upload the Notebook to Snowflake Workspaces

1. In Snowsight, go to **Projects → Workspaces**
2. Click **+ Add New** → **Upload Files**
3. Select the notebook file CoCo generated
4. Configure the service settings:

    | Setting | Value |
    |---------|-------|
    | Compute Pool | `NOTEBOOK_POOL` |
    | Runtime | Latest available (v2.6+) |
    | Notebook Warehouse | `COMPUTE_WH` |
    | Database | `F5_PROD` |
    | Schema | `FINAL` |

5. Click **Create** and wait for the compute pool to start (1-2 minutes on first use)
6. Run cells one at a time (Shift+Enter) and review output at each step

!!! note "Why Workspaces?"
    The model trains locally in the container (not on the warehouse). SQL queries still run on COMPUTE_WH for data prep.

---

### Step 2: Review Recommendations

`Manual`{: .badge-manual }

After running the notebook:

1. Check how many recommendations were generated per account:

    ```sql
    SELECT ACCT_NAME, COUNT(*) as recommendations 
    FROM F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS 
    GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
    ```

2. Look at what your assigned account was recommended:

    ```sql
    SELECT * FROM F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS 
    WHERE ACCT_NAME = '[YOUR ACCOUNT]' 
    ORDER BY CONFIDENCE_SCORE DESC;
    ```

3. Verify the rationale makes sense. Does an account with heavy WAF telemetry but no Bot Defense get recommended Bot Defense?
4. Check that recommendation types are varied (cross-sell, upsell, capacity)

!!! note "Tip"
    If recommendations seem off, check the feature engineering cell. The model should be seeing what products each account owns today (from line items and subscriptions) vs. what's available in the catalog.

---

### Step 3: Add Recommendations to Sales Agent

`Manual`{: .badge-manual }

Add the recommendations table to your **sales semantic view** via Snowsight:

1. Go to **AI & ML → Semantic Views** → open your sales semantic view
2. Click **Add Table** → select `F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS`
3. Select the columns to include (search columns): SFDCF5_ACCT_ID, ACCT_NAME, RECOMMENDED_SKU, RECOMMENDATION_TYPE, CONFIDENCE_SCORE, RATIONALE, PRIORITY_RANK
4. Once added, edit the table to configure:
    - Set primary key: `SFDCF5_ACCT_ID, RECOMMENDED_SKU` (composite)
    - Review synonyms:
        - `RECOMMENDED_SKU` - `recommended product`, `suggestion`
        - `RECOMMENDATION_TYPE` - `type`, `cross-sell or upsell`
        - `RATIONALE` - `reason`, `why`
    - Add metric: `EXPANSION_OPPORTUNITY_COUNT` = `COUNT(RECOMMENDED_SKU)`
5. Add relationship: `CROSS_SELL_RECOMMENDATIONS.SFDCF5_ACCT_ID` → `ACCOUNTS.SFDCF5_ACCT_ID` (many-to-one)
6. Save the semantic view

Then update the agent (AI & ML → Cortex Agents → edit your agent → **Orchestration Instructions**, append):

```
When asked about expansion opportunities or what to recommend to an account,
check CROSS_SELL_RECOMMENDATIONS for product suggestions. Explain the 
rationale behind each recommendation and prioritize by confidence score.
```

---

### Step 4: Test Expansion Queries

`Manual`{: .badge-manual }

Test the enhanced agent with expansion-focused questions:

| # | Question | Expected Insight |
|---|----------|-----------------|
| 1 | "Which accounts are over 80% utilization and approaching renewal?" | Accounts that need capacity upgrades before their next renewal conversation |
| 2 | "What should we recommend to [YOUR ACCOUNT] based on their current products and telemetry?" | Specific product recommendations with rationale tied to their usage patterns |
| 3 | "Which accounts have high WAF telemetry but no Bot Defense product?" | Clear cross-sell gap where telemetry proves the need |
| 4 | "Show me the top 10 expansion opportunities by confidence score." | Prioritized list of accounts and products with the strongest signals |

!!! success "Success Criteria"
    The model identifies concrete product recommendations per account with clear rationale. Combined with the telemetry-support correlation from Module 1, the agent can now explain not just what's happening with an account but what to sell them next.

---

### Step 5: Customer Growth Dashboard

`Challenge`{: .badge-manual }

You just received this Slack message from your VP of Customer Growth:

!!! quote "#customer-growth - 9:14 AM"
    @here becoming a real problem. We're sitting on a huge customer base but I have no visibility into which accounts are ready to expand. Every quarter we scramble to find upsell opportunities based on gut instinct instead of data.

    I need to see which accounts should be buying more products, which ones need capacity upgrades, and what we should be recommending. If an account is likely to buy something, I want to know what and why.

    I've been using Tableau but it's static and always a week behind. Need something interactive in Snowflake where I can drill into any account.

    Need a working prototype by end of day.

    \- Sarah K, VP Customer Growth

**Your task:** Use CoCo to build a solution that addresses Sarah's request. Consider:

- What data do you have available? (Think about which tables from Module 1 and 2 are relevant)
- What does "drill into any account" mean for someone looking at expansion opportunities?
- How do you make it interactive vs. a static report?
- Sarah mentioned product recommendations, capacity, and the expansion model. How do you organize that?

!!! note "Hint"
    You have account data, telemetry, support cases, sales opportunities, install base, health scores, and expansion recommendations all in `F5_PROD`. Think about what Snowflake offers for building interactive data apps.

!!! success "Success Criteria"
    Sarah can open the solution, pick an account, and quickly understand: what products should we pitch them, why, how confident are we, and when is their renewal window.

---

## Data Summary

### Signal-to-Support Correlation (Hidden Pattern)

This is what attendees will discover through the agent:

| Telemetry Signal | Threshold | Support Case Category | Accounts |
|-----------------|-----------|----------------------|----------|
| Bot Defense Transactions | > 300,000 avg daily | XC Bot Defense / Bot Management | ~29 |
| WAF Usage | > 25 avg daily | XC WAF / WAF Policy | ~22 |
| Active Endpoints | > 150 avg | XC App Connect / Capacity | ~24 |
| HTTP Load Balancers | > 40 avg | BIG-IP LTM / NGINX Plus (incl. Performance) | ~43 |
| DNS Zones | > 7 avg | XC DNS / BIG-IP GTM | ~12 |

**Note:** Accounts below all thresholds default to "load-balancer" signal and correlate with BIG-IP LTM/NGINX Plus performance cases (latency, cache, memory). There is no separate "performance" category.

### Salesforce Integration

| Field | Value |
|-------|-------|
| SFDC Org | `orgfarm-b5c32390d9-dev-ed.develop.my.salesforce.com` |
| MCP Server URL | `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all` |
| Total Cases | ~1,125 (matching DIM_SUPPORT_CASE) |
| Case Number Link | `DIM_SUPPORT_CASE.SUPPORT_CASE_NUM` = Salesforce CaseNumber |
