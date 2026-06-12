-- ============================================================
-- F5 Hands-On Lab: Database and Schema Setup
-- ============================================================
-- Run as SYSADMIN
-- ============================================================

USE ROLE SYSADMIN;

-- Create warehouse if it doesn't exist
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS F5_PROD;
CREATE SCHEMA IF NOT EXISTS F5_PROD.RAW;
CREATE SCHEMA IF NOT EXISTS F5_PROD.STAGING;
CREATE SCHEMA IF NOT EXISTS F5_PROD.FINAL;

USE DATABASE F5_PROD;
USE SCHEMA RAW;
