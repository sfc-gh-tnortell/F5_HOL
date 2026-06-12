-- ============================================================
-- Salesforce MCP Setup (Reference)
-- ============================================================
-- This documents the Salesforce MCP connector configuration.
-- 
-- ADMIN: Run this SQL once OR use the Snowsight UI:
--   AI & ML > Agents > Settings > Tools and Connectors > Browse > Salesforce
--
-- ATTENDEES: Use the Snowsight UI to add the connector.
--   Fill in the fields below (Client ID/Secret from instructor).
-- ============================================================

-- SFDC Instance: agility-force-6304
-- MCP Hosted Server enabled on this org

-- ============================================================
-- UI Form Fields (for attendees)
-- ============================================================
-- Server URL:            https://api.salesforce.com/platform/mcp/v1/platform/sobject-all
-- Token Endpoint:        https://login.salesforce.com/services/oauth2/token
-- Authorization Endpoint: https://login.salesforce.com/services/oauth2/authorize
-- OAuth Client ID:       <provided by instructor>
-- OAuth Client Secret:   <provided by instructor>
-- Scopes:               mcp_api

-- ============================================================
-- Equivalent SQL (for admin reference only)
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA F5_PROD.PUBLIC;

CREATE API INTEGRATION sfdc_mcp_api_integration
  API_PROVIDER = external_mcp
  API_ALLOWED_PREFIXES = ('https://agility-force-6304.my.salesforce.com')
  API_USER_AUTHENTICATION = (
    TYPE = OAUTH,
    OAUTH_CLIENT_ID = '<consumer_key_from_connected_app>',
    OAUTH_CLIENT_SECRET = '<consumer_secret_from_connected_app>',
    OAUTH_TOKEN_ENDPOINT = 'https://agility-force-6304.my.salesforce.com/services/oauth2/token',
    OAUTH_AUTHORIZATION_ENDPOINT = 'https://agility-force-6304.my.salesforce.com/services/oauth2/authorize'
  )
  ENABLED = TRUE;

CREATE EXTERNAL MCP SERVER salesforce_mcp_server
  WITH DISPLAY_NAME = 'Salesforce CRM'
  URL = 'https://agility-force-6304.my.salesforce.com/mcp'
  API_INTEGRATION = sfdc_mcp_api_integration;

DESCRIBE EXTERNAL MCP SERVER salesforce_mcp_server;

GRANT USAGE ON EXTERNAL MCP SERVER salesforce_mcp_server TO ROLE PUBLIC;
GRANT USAGE ON INTEGRATION sfdc_mcp_api_integration TO ROLE PUBLIC;

-- ============================================================
-- Connected App Setup (Salesforce side - admin)
-- ============================================================
-- 1. Setup > App Manager > New Connected App
-- 2. Name: "Snowflake MCP"
-- 3. Enable OAuth Settings
-- 4. Callback URL: https://identity.snowflake.com/oauth2/callback
-- 5. Scopes: Manage user data via APIs (api), Perform requests at any time (refresh_token)
-- 6. Enable MCP Server scope if available
-- 7. Save > Wait 2-10 min for activation
-- 8. Copy Consumer Key and Consumer Secret
