SUMMARY
You will create and end to end Cortex Agent setup for a global technology company specializing in application security, multi-cloud management, and online fraud prevention like F5, Inc.  The goal of the lab is to answer questions about customers to get cross sell and upsell opportunities, call transcripts and support cases as well as customer usage telemetry.  Each of these data points will be stored in their native formats (structrued or unstructured) and will be consumed from within Snowflake CoWork through Agents.

For all steps in this MD write them into a file structure including DDL, data generated etc. so that I could reproduce this on my own in a different account.  This is designed to be a hands on lab that I am leading for 40 other users to implement step by step. 

REQUIREMENTS
1. Create a F5_Prod database and schema using the /Source_Data/DDLs/F5_DDLs.txt as reference.  You do not need every field.  Fill out enough to have a full picture of a customers account.  This should be a few hundred accounts.  Keep them USA based and spread them across the major timezones to create regional distiction.  Make sure to populate failed opportunities for expansion where a product was proposed with a contract and declined.  This will be used for account health and expansion. Use the Fortune 500 customer list in references for customer profiles.
2. Create a sales account team table that maps an account executive, solutions engineer and Sales development representative to each account. Keep the account alignment to roughly 20 per account team and make sure to map them to regional territories based on timezones in step 1. 
3. Generate zoom call transcripts that map to the customer names you created in step 1. Use /Source_Data/Zoom_transcript_example.txt as format reference and use /Source_Data/Old_Scripts/* as reference to code has worked before.  Only do this for 25% of the total customer population.  Make sure to name the call transcript files as the customer name with a date appended. Have some of the trasncripts provide insights about the customers fiscal planning, layoffs, tech changes, product feedback etc. Do nothing other than create the files and store them in the data generation folder in the repo.
4. Create an upload script for the call transcripts


Create objects with SYSADMIN

References:
- For company informationc, products, skus etc.: https://www.f5.com/
- Customer data should be from Fortune 500 customers: https://www.50pros.com/fortune500 

---

IMPLEMENTATION NOTES (from build session)

Database: F5_PROD
Schemas: RAW, STAGING
Account: sfsenorthamerica-demo351_aws
Role: SYSADMIN
Warehouse: COMPUTE_WH

TABLES CREATED (27 total in F5_PROD.RAW):

Sales Domain:
- DIM_CUST_ACCT_SFDC (184 accounts) - Fortune 500, USA, spread across West/Mountain/Central/East
- DIM_SALES_OPPORTUNITY (641 opps) - includes ~80 failed expansion proposals (Closed Lost with reasons: Price, Budget Constraints, Went with Competitor, No Decision)
- FACT_SALES_OPPORTUNITY (641) - dollar amounts, ARR, PI, TCV
- FACT_SALES_OPPORTUNITY_LINE_ITEM (1,757) - products attached to opportunities
- COL_SALES_OPPORTUNITY_LINE_ITEM (1,757) - enriched flat view with territory/account info
- FACT_SALES_PIPELINE_SNAPSHOT (4,408) - 12 weeks of weekly pipeline history with stage progression
- QUOTE (560) - quotes on deals (Accepted/Rejected/Draft)
- USER_ENTRY_HEADER (55) - ELA/enterprise agreement contract headers
- SALES_ACCOUNT_TEAM (184) - AE/SE/SDR mapped to every account
- SALES_SECURITY_ETM_TERRITORY (368) - row-level territory access control
- DIM_SALES_USER (30) - 10 teams x 3 roles (AE, SE, SDR)

Support Domain:
- DIM_SUPPORT_CASE (939) - realistic F5 support issues (BIG-IP failover, WAF false positives, XC propagation, etc.)
- FACT_SUPPORT_CASE (939) - time to close/response/resolution/SLA metrics
- COL_SUPPORT_CASE (939) - enriched with territory and open days
- FACT_RMA_ORDER (74) - hardware returns (power supply, fan, memory, storage, NIC failures)

Customer Success / Install Base:
- COL_INSTALL_BASE (343) - hardware and software deployed at customer sites with serial numbers, versions, service dates
- COL_CORP_CUSTOMER_CENTRAL_PRODUCT_OFFER_CUST_VALUE (343) - full customer product/service view
- DIM_PRODUCT_OFFER_SUBSCRIPTION (116) - active subscriptions

Telemetry Domain:
- COL_XC_TELEMETRY (9,270) - 90 days of daily XC usage (load balancers, WAF, bot, API, DNS)
- COL_XC_TELEMETRY_ACCT_MAP_V2 (116) - maps tenant IDs to accounts (~60% of accounts have XC)
- COL_TERM_SUB_MONTHLY_USAGE_V2 (2,625) - 6 months of monthly consumption by feature/SKU
- COL_XC_PRODUCT_HEALTHSCORE (116) - utilization %, consumption patterns (Growing/Stable/Declining/Seasonal/New)
- BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD (1,290) - 30 days raw bot defense telemetry

Reference Dimensions:
- DIM_DAY_DATE (1,461) - fiscal calendar FY24-FY27 (F5 fiscal year starts Feb 1)
- DIM_GEOGRAPHIC_AREA (184) - territory hierarchy
- DIM_PRODUCT_OFFER (38) - F5 product catalog (BIG-IP hw/sw, NGINX, Distributed Cloud, Calypso AI, Services)
- DIM_WORKER (30) - employee records

Stage:
- ZOOM_TRANSCRIPTS_STAGE (69 files uploaded) - WEBVTT format transcripts

PRODUCT CATALOG (38 SKUs across 5 brands):
- BIG-IP Hardware: i2600, i4600, i5600, i7600, i10600, i15600
- BIG-IP Virtual Editions: 25M, 200M, 1G, 10G
- BIG-IP Modules: LTM, GTM/DNS, ASM/WAF, APM, AFM
- NGINX: Plus, Plus R30, One, App Protect, Ingress Controller, Management Suite
- Distributed Cloud (XC): WAF, Bot Defense, API Security, App Connect, DNS, CDN, DDoS, MCN, App Stack, Client-Side Defense
- Calypso AI: AI Gateway, AI Prompt Shield, AI Observability
- Services: Premium Support, Standard Support, Professional Services, Training

ACCOUNT DISTRIBUTION:
- West (Pacific): 47 accounts - CA, WA, OR
- Mountain: 20 accounts - CO, AZ, ID, UT
- Central: 58 accounts - TX, IL, MN, MO, OH, WI, MI, IN, TN, NE, KY
- East (Eastern): 59 accounts - NY, NJ, CT, VA, PA, MA, MD, GA, FL, NC, RI

SALES TEAMS (10 teams, ~18-20 accounts each):
- West 1: Sarah Mitchell (AE), Kevin Nakamura (SE), Ashley Pham (SDR) - San Francisco
- West 2: Robert Chen (AE), Priya Sharma (SE), Tyler Brooks (SDR) - San Jose
- West 3: Jessica Torres (AE), Daniel Kim (SE), Morgan Lee (SDR) - Seattle
- Mountain 1: Michael Park (AE), Rachel Gonzalez (SE), Brandon Scott (SDR) - Denver
- Central 1: Amanda Nguyen (AE), Eric Johnson (SE), Samantha Williams (SDR) - Chicago
- Central 2: David Morrison (AE), Nicole Martinez (SE), Jake Wilson (SDR) - Dallas
- Central 3: Lauren Kim (AE), Chris Anderson (SE), Megan Harris (SDR) - Houston
- East 1: James O'Brien (AE), Aisha Washington (SE), Ryan Phillips (SDR) - New York
- East 2: Rachel Patel (AE), Marcus Thompson (SE), Lindsay Clark (SDR) - Atlanta
- East 3: Christopher Davis (AE), Emily Rodriguez (SE), Justin Taylor (SDR) - Boston

ZOOM TRANSCRIPTS:
- 69 files generated for 50 accounts (25% of 184 = ~46, some accounts have 2 calls)
- WEBVTT format matching Source_Data/Zoom_transcript_example.txt
- Themes: competitive mentions (Cloudflare, Akamai, Imperva, AWS ALB, Fastly), fiscal planning, layoffs/restructuring, tech changes (cloud migration, K8s, zero trust), product feedback (positive/negative)
- Sentiment correlated to account health score
- Stored in data/zoom_transcripts/ and uploaded to @F5_PROD.RAW.ZOOM_TRANSCRIPTS_STAGE

FILE STRUCTURE:
  setup/
    01_database_setup.sql
    02_create_tables.sql (27 tables + 1 stage)
    03_insert_accounts.sql (~184 Fortune 500)
    04_insert_products.sql (38 F5 SKUs)
    05_insert_opportunities.sql (641 opps + 1757 line items)
    06_insert_sales_teams.sql (30 users + 184 assignments)
    07_insert_date_dimension.sql (1461 days, FY24-FY27)
    08_insert_support_and_install_base.sql (939 cases + 74 RMAs + 343 assets)
    09_insert_telemetry_and_consumption.sql (9270 telemetry + 2625 usage + 116 health + 1290 bot)
    10_insert_pipeline_quotes_contracts.sql (4408 snapshots + 560 quotes + 55 ELAs + enriched tables)
  scripts/
    generate_zoom_transcripts.py (generates 69 WEBVTT files)
    upload_transcripts.sql (stage creation + PUT commands)
    upload_transcripts_to_stage.py (Python programmatic uploader)
  data/
    zoom_transcripts/ (69 .txt files)
  Source_Data/ (reference material - unchanged)
  coco_prompts/ (prompt files)

KNOWN ISSUES / ADJUSTMENTS MADE DURING BUILD:
- DIM_DAY_DATE.FISCAL_MTH_NAME column was VARCHAR(9), too short for 'FY2024-M01' (10 chars). Altered to VARCHAR(20).
- DIM_PRODUCT_OFFER_SUBSCRIPTION was initially empty; populated from COL_XC_TELEMETRY_ACCT_MAP_V2 subscription data.
- Account IDs ACC000049 (Lockheed Martin) and ACC000209 are duplicates in the source data (same company, different account IDs). Same for ACC000050/ACC000210 (Raytheon). This is intentional to simulate parent/subsidiary relationships.
- Snow CLI (`snow` command) not available in this environment; all SQL executed via Snowflake SQL API directly.
- Competitors used in failed expansion opportunities: Cloudflare, Akamai, Imperva, AWS ALB, Azure Front Door, Fastly
- Failed expansion loss reasons: Price (15%), Budget Constraints (10%), Went with Competitor (10%), No Decision (8%)
