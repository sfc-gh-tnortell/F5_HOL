# Plan: Switch from Jira to Salesforce MCP

## Context

### Current State
- `DIM_SUPPORT_CASE` has 1,125 cases with `SUPPORT_CASE_NUM = 'KAN-xxx'` (Jira keys)
- `scripts/create_jira_tickets.py` reads DIM_SUPPORT_CASE, creates Jira Tasks, writes back keys
- `scripts/Jira_MCP_Setup.sql` creates Atlassian MCP connector via SQL
- README Step 4 documents Jira MCP setup

### Target State
- `DIM_SUPPORT_CASE.SUPPORT_CASE_NUM` will contain Salesforce Case Numbers
- `scripts/create_sfdc_cases.py` creates SFDC Accounts + Cases, writes back Case Numbers
- `scripts/SFDC_MCP_Setup.sql` is reference-only (admin used UI to set up; file documents what was done)
- README Step 4 tells attendees to fill in a UI form in Snowsight with pre-provided values

### Attendee MCP Setup (UI-based, no SQL)

Attendees navigate to **AI & ML > Agents > Settings > Tools and Connectors > Browse Connectors > Salesforce** and fill in:

| Field | Value |
|-------|-------|
| Server URL | `https://agility-force-6304.my.salesforce.com/mcp` |
| Token endpoint | `https://agility-force-6304.my.salesforce.com/services/oauth2/token` |
| Authorization endpoint | `https://agility-force-6304.my.salesforce.com/services/oauth2/authorize` |
| OAuth Client ID | *(provided by instructor)* |
| OAuth Client Secret | *(provided by instructor)* |
| Scopes | `api refresh_token` |

After saving, they add the connector to their agent and authenticate via OAuth popup.

---

## Implementation Steps

### Step 1: Create `scripts/create_sfdc_cases.py`

Replace `create_jira_tickets.py`. Script workflow:

1. Authenticate to Salesforce (Connected App, username-password OAuth flow)
2. Query Snowflake for unique accounts from DIM_CUST_ACCT_SFDC (~130 with telemetry)
3. Create Account objects in SFDC (Name = ACCT_NAME)
4. Query Snowflake for all DIM_SUPPORT_CASE rows
5. Create Case objects in SFDC linked to AccountId
   - Subject = SUPPORT_CASE_TITLE_TEXT
   - Description = product, area, sub_area, priority, original created date
   - Priority: P1→Critical, P2→High, P3→Medium, P4→Low
   - Status: Open→New, In Progress→Working, Resolved→Closed, Closed→Closed, Waiting→On Hold
6. Update DIM_SUPPORT_CASE.SUPPORT_CASE_NUM with returned CaseNumber
7. Rebuild COL_SUPPORT_CASE

Env vars: `SFDC_CLIENT_ID`, `SFDC_CLIENT_SECRET`, `SFDC_USERNAME`, `SFDC_PASSWORD`, `SFDC_SECURITY_TOKEN`

### Step 2: Create `scripts/SFDC_MCP_Setup.sql` (reference doc)

Not for attendees to execute — this documents what was configured at the account level and serves as a reference for the admin. Contains the equivalent SQL that Snowsight generates behind the scenes when using the UI connector form.

### Step 3: Run script to populate Salesforce

Execute `create_sfdc_cases.py` to create ~130 Accounts and ~1,125 Cases. After completion:
- SUPPORT_CASE_NUM updated with SFDC CaseNumbers (numeric format)
- COL_SUPPORT_CASE rebuilt with new case numbers

### Step 4: Update `HOL/README.html` Step 4

Rewrite from "Connect Jira via MCP" to "Connect Salesforce via MCP". Content:

- Title: "Step 4: Connect Salesforce via MCP"
- Instructions are UI-based (no SQL for attendees):
  1. Navigate to AI & ML > Agents > Settings > Tools and Connectors
  2. Click Browse Connectors > Salesforce
  3. Fill in the form fields (table with pre-filled values from above)
  4. Client ID and Secret: "Get these from your instructor"
  5. Click Add
  6. Add the connector to F5_SUPPORT_AGENT
  7. First use: OAuth popup to authenticate with shared SFDC credentials
- Note: Case numbers in DIM_SUPPORT_CASE.SUPPORT_CASE_NUM match Salesforce Case Numbers

### Step 5: Update Step 5 test questions

Replace "Jira" with "Salesforce":
- "Find the Jira ticket" → "Find the Salesforce case"
- "Add a comment to the Jira ticket" → "Add a comment to the Salesforce case"
- "Create a new Jira ticket" → "Create a new Salesforce case"

### Step 6: Rename `Prompt_Jira_MCP.md` to `Prompt_SFDC_MCP.md`

Update all references: Jira→Salesforce, KAN-xxx→CaseNumber, atlassian endpoints→SFDC endpoints, script name→create_sfdc_cases.py

---

## Verification

1. **Script**: 130 Accounts + 1,125 Cases created in SFDC org without errors
2. **Snowflake data**: `SELECT SUPPORT_CASE_NUM FROM DIM_SUPPORT_CASE LIMIT 5` shows numeric CaseNumber format
3. **Attendee flow**: Follow the UI steps in README, verify connector appears and OAuth popup works
4. **End-to-end**: In CoWork ask "Show me open cases for Amazon" — agent returns SFDC case data via MCP

---

## Critical Files

- `Account_Prep/scripts/create_sfdc_cases.py` (new) — Creates SFDC Accounts + Cases from Snowflake data
- `Account_Prep/scripts/SFDC_MCP_Setup.sql` (new) — Reference doc of what the UI creates
- `HOL/README.html` — Step 4 rewrite (UI form instructions), Step 5 question updates
- `Account_Prep/coco_prompts/Prompt_SFDC_MCP.md` (renamed) — Updated requirements doc
