SUMMARY
Generate support cases for JIRA 


REQUIREMENTS
1. Use the telemetry data created in prompt.md to generate JIRA support tickets through the MCP Connection in the F5_prod.public schema. 
2. The Jira's should be mapped to customers, for now they can all be assinged to one user.  
3. There should be no direct reference between the telemetry you're using to create the jira and the jira itself.  The goal of this to have the users use cowork to build an agent that will analyze telemetry and jira support cases and link them together.  So, use the telemetry to build them but without a direct link to the actual data stored in Snowflake. I want that done later as part of the hands on lab. 
4. Use the 2 months of data as active jira tickets that are open.  Use the other 4 months of telemetry data for historical jira tickets that are been closed and solved.


Tables for telemetry:
- COL_XC_TELEMETRY_ACCT_MAP_V2	
- COL_XC_TELEMETRY
- COL_TERM_SUB_MONTHLY_USAGE_V2
- BASE_XC_TELEMETRY_BOT