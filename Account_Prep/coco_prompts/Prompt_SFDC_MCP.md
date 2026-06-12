SUMMARY
Create Salesforce Accounts and Cases from Snowflake support case data (correlated to telemetry).

REQUIREMENTS
1. 12-month coverage: 2 months open cases, 10 months closed cases
2. ~1000+ support cases in DIM_SUPPORT_CASE, each correlated to the account's
   dominant telemetry signal (bot-defense, waf, capacity, load-balancer, dns, performance)
3. Python script reads directly from DIM_SUPPORT_CASE table (not hardcoded data)
4. Script creates Accounts first, then Cases linked to AccountId
5. After case creation, SUPPORT_CASE_NUM is updated with Salesforce CaseNumber
6. No duplicate symptoms within a single calendar month per account
7. Overlap between months is fine and desirable (shows trends over time)
8. No direct FK between telemetry and support cases -- correlation is discoverable 
   through category/product matching (the HOL exercise)

WORKFLOW ORDER
1. Extend telemetry to 12 months (setup/09_insert_telemetry_and_consumption.sql)
2. Regenerate support cases correlated to telemetry (setup/08_insert_support_and_install_base.sql)
3. Run Salesforce script: reads DIM_SUPPORT_CASE, creates SFDC objects, writes back CaseNumbers
   Command: SFDC_CLIENT_ID="<id>" SFDC_CLIENT_SECRET="<secret>" SFDC_USERNAME="<user>" SFDC_PASSWORD="<pass>" SFDC_SECURITY_TOKEN="<token>" python scripts/create_sfdc_cases.py

SIGNAL-TO-CATEGORY MAPPING (thresholds from COL_XC_TELEMETRY)
- bot-defense: AVG(BOT_ADVANCED_TRANSACTION_CNT) > 300000 → XC Bot Defense / Bot Management
- waf: AVG(WAF_USAGE_QTY) > 25 → XC WAF / BIG-IP ASM / WAF Policy
- capacity: AVG(ACTIVE_ENDPOINT_QTY) > 150 → Configuration / Capacity
- load-balancer: AVG(ACTIVE_HTTP_LOAD_BALANCER_QTY) > 40 → BIG-IP LTM / NGINX Plus
- dns: AVG(DNS_ZONES_QTY) > 7 → XC DNS / BIG-IP GTM / DNS
- performance: default → BIG-IP LTM Performance / NGINX Plus

TABLES AFFECTED
- COL_XC_TELEMETRY: Extended to 365 days, 128 accounts, ~47K rows
- DIM_SUPPORT_CASE: Regenerated with telemetry correlation, ~1100 cases
- FACT_SUPPORT_CASE: Derived metrics (time-to-close, SLA)
- COL_SUPPORT_CASE: Enriched flat table with sales team join

SALESFORCE ORG
- Instance: agility-force-6304.my.salesforce.com
- MCP Server URL: https://agility-force-6304.my.salesforce.com/mcp
- Objects created: Account (~130), Case (~1100)
- Case linked to Account via AccountId FK

SCRIPT DETAILS (scripts/create_sfdc_cases.py)
- Connects to Snowflake via snowflake-connector-python (default connection)
- Authenticates to Salesforce via OAuth2 username-password flow
- Creates Account objects first (upsert pattern: check existing, create if needed)
- Creates Case objects linked to AccountId
  - Subject = SUPPORT_CASE_TITLE_TEXT
  - Status mapping: Open→New, In Progress→Working, Resolved→Closed, Closed→Closed, Waiting→On Hold
  - Priority mapping: P1→Critical, P2→High, P3→Medium, P4→Low
- After each Case create, updates DIM_SUPPORT_CASE.SUPPORT_CASE_NUM with CaseNumber
- Final step: rebuilds COL_SUPPORT_CASE with updated case numbers
- Rate limiting: 0.2s between creates, 3s pause every 100 cases
- Supports --resume flag to skip already-created cases

MCP SETUP (for HOL attendees - UI based, no SQL)
- Navigate: AI & ML > Agents > Settings > Tools and Connectors > Salesforce
- Server URL: https://agility-force-6304.my.salesforce.com/mcp
- Token Endpoint: https://agility-force-6304.my.salesforce.com/services/oauth2/token
- Auth Endpoint: https://agility-force-6304.my.salesforce.com/services/oauth2/authorize
- Client ID/Secret: provided by instructor
- Scopes: api refresh_token

HOL EXERCISE GOAL
Attendees will build a Cortex Agent that:
1. Queries telemetry data to identify accounts with anomalous signals
2. Queries Salesforce (via MCP) to find related Cases
3. Discovers the correlation between telemetry spikes and support case categories
4. Provides proactive recommendations (e.g., "Amazon has sustained high bot traffic 
   AND 3 open bot defense cases -- likely needs escalation")
5. Writes observations back to Salesforce Cases as comments
