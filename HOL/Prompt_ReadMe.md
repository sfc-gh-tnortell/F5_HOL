SUMMARY
Create a readme for the hands on lab.  Each step and module should be explained with prompts or steps to do.  I've put in if it's manual in the UI or with coco.

I want this designed the same as /Users/tnortell/Documents/GitHub/Okta_CoCo_HOL/Okta_CoCo_HOL/README.HTML

OUTPUT: HOL/README.html (already created)


REQUIREMENTS

Module 1:
1. Use the Account_Prep/setup/12_query_repository_support_cs.sql to analyze past sql statements that users have created to solve support and telemetry questions.  Review and distill down to 5 verified queries.  Create a reusable cortex skill (~/.snowflake/cortex/skills/query-analysis/SKILL.md). -- coco
   - Output: HOL/verified_queries.sql (plain SELECT statements with business question comments, NOT functions)
   - Output: ~/.snowflake/cortex/skills/query-analysis/SKILL.md (reusable for any domain)
2. From the verified queries create a semantic view for support and telemetry. Two options: -- coco OR manual UI
   - Option A (CoCo): Read verified_queries.sql and create semantic view
   - Option B (Manual): Use Snowsight semantic auto-generator, upload verified_queries.sql
   - Target: F5_PROD.FINAL.F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW
3. Create an agent for customer support in CoWork. -- manual
   - Name: F5_SUPPORT_AGENT
   - Model: auto
   - Time Limit: 600 seconds
   - Token Limit: 32000
   - Tool: Cortex Analyst with F5_SUPPORT_TELEMETRY_SEMANTIC_VIEW
   - Add sample questions for testing
4. Connect Jira via MCP -- manual (requires ACCOUNTADMIN)
   - SQL: Account_Prep/scripts/Jira_MCP_Setup.sql
   - Creates API integration + external MCP server (atlassian_mcp_server)
   - Add MCP tool to the agent after setup
   - First use requires OAuth sign-in to Atlassian
   - Jira project: KAN at f5snowhol.atlassian.net
5. Test the agent, try to find telemetry that matches open cases. If it matches write it back to the support case using Jira MCP -- manual

Module 2:
1. Create a Telemetry-Driven Churn Propensity Model. Build a lightweight ML model using the closed support cases and telemetry + health score data -- coco
2. Feature engineering (trend slopes on load balancer counts, WAF usage decline) -- coco
	- Combine with support case volume and health score patterns
	- Train a classification model (Snowpark ML or Cortex ML) predicting CONSUMPTION_PATTERN = 'Declining'
	- Register the model and serve predictions as a table the agent can query 
3. Add this back into the support agent -- manual
4. Interact and test, could we find/create a case before a problem starts? Internal investigation on telemetry trends -- manual

BASE_XC_TELEMETRY_NON_COMMERCIAL_BOT_STANDARD use this for deeper analysis and trends


DESIGN NOTES
- Navigation: "AI & ML → CoWork" (not Snowflake Intelligence -- renamed)
- Agent model: "auto" (not a specific model name)
- Format: HTML matching Okta HOL style with .badge-coco (blue) and .badge-manual (grey)
- CoCo prompts in div.coco blocks
- F5 brand color: #e4002b (red) for headings and table headers


<!-- Module 3:
1. Streamlit for customer success  -->
