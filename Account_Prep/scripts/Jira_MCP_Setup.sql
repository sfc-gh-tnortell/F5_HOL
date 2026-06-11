
Use role accountadmin;
USE schema f5_prod.public;

-- Create the API integration using dynamic client registration (DCR)
CREATE API INTEGRATION jira_mcp_api_integration
  API_PROVIDER = external_mcp
  API_ALLOWED_PREFIXES = ('https://mcp.atlassian.com/v1/mcp')
  API_USER_AUTHENTICATION = (
    TYPE=OAUTH_DYNAMIC_CLIENT,
    OAUTH_RESOURCE_URL='https://mcp.atlassian.com/v1/mcp'
  )
  ENABLED = TRUE;

-- Create the external MCP server
CREATE EXTERNAL MCP SERVER atlassian_mcp_server
  WITH DISPLAY_NAME = 'Atlassian (Jira & Confluence)'
  URL='https://mcp.atlassian.com/v1/mcp'
  API_INTEGRATION = jira_mcp_api_integration;


DESCRIBE EXTERNAL MCP SERVER atlassian_mcp_server;

-- Grant access to the MCP server
GRANT USAGE ON EXTERNAL MCP SERVER atlassian_mcp_server TO ROLE PUBLIC;

-- Grant access to the underlying API integration
GRANT USAGE ON INTEGRATION jira_mcp_api_integration TO ROLE PUBLIC;


-- https://f5snowhol.atlassian.net/
-- https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp-connectors#set-up-supported-mcp-connectors