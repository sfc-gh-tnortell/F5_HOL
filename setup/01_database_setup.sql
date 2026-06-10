-- ============================================================
-- F5 Hands-On Lab: Database and Schema Setup
-- ============================================================
-- Run as SYSADMIN
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS F5_PROD;
CREATE SCHEMA IF NOT EXISTS F5_PROD.RAW;
CREATE SCHEMA IF NOT EXISTS F5_PROD.STAGING;

USE DATABASE F5_PROD;
USE SCHEMA RAW;
