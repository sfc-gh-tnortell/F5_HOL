SUMMARY
Create Jira tickets from Snowflake support case data (correlated to telemetry).

REQUIREMENTS
1. 12-month coverage: 2 months open tickets, 10 months closed tickets
2. ~1000+ support cases in DIM_SUPPORT_CASE, each correlated to the account's
   dominant telemetry signal (bot-defense, waf, capacity, load-balancer, dns, performance)
3. Jira script reads directly from DIM_SUPPORT_CASE table (not hardcoded data)
4. After ticket creation, SUPPORT_CASE_NUM is updated with Jira key (KAN-xxx)
5. No duplicate symptoms within a single calendar month per account
6. Overlap between months is fine and desirable (shows trends over time)
7. No direct FK between telemetry and support cases -- correlation is discoverable 
   through category/product matching (the HOL exercise)

WORKFLOW ORDER
1. Extend telemetry to 12 months (setup/09_insert_telemetry_and_consumption.sql)
2. Regenerate support cases correlated to telemetry (setup/08_insert_support_and_install_base.sql)
3. Run Jira ticket script: reads DIM_SUPPORT_CASE, creates tickets, writes back KAN-xxx keys
   Command: JIRA_API_TOKEN="<token>" python scripts/create_jira_tickets.py

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

JIRA PROJECT
- URL: https://f5snowhol.atlassian.net
- Project key: KAN
- Issue type: Task
- Assignee: traviskn20@gmail.com

SCRIPT DETAILS (scripts/create_jira_tickets.py)
- Connects to Snowflake via snowflake-connector-python (default connection)
- Queries all rows from DIM_SUPPORT_CASE joined with DIM_CUST_ACCT_SFDC
- Creates Jira Task for each case (summary = "Account - Title")
- Open/In Progress cases stay open in Jira
- Closed/Resolved/Waiting cases transition to Done
- After each create, updates DIM_SUPPORT_CASE.SUPPORT_CASE_NUM with KAN-xxx
- Final step: rebuilds COL_SUPPORT_CASE with updated case numbers
- Rate limiting: 0.3s between creates, 3s pause every 50 tickets

MCP SETUP (scripts/Jira_MCP_Setup.sql)
- API integration: jira_mcp_api_integration
- External MCP server: atlassian_mcp_server
- URL: https://mcp.atlassian.com/v1/mcp
- Grants: PUBLIC role access

HOL EXERCISE GOAL
Attendees will build a Cortex Agent that:
1. Queries telemetry data to identify accounts with anomalous signals
2. Queries Jira (via MCP) or the support case tables to find related tickets
3. Discovers the correlation between telemetry spikes and support case categories
4. Provides proactive recommendations (e.g., "Amazon has sustained high bot traffic 
   AND 3 open bot defense tickets -- likely needs escalation")
