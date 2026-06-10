-- ============================================================
-- F5 Hands-On Lab: Upload Zoom Transcripts to Snowflake Stage
-- ============================================================
-- This script uploads the generated transcript files to the
-- internal stage for use with Cortex Search.
--
-- OPTION 1: Run via SnowSQL CLI
-- OPTION 2: Run via Snowflake worksheet (PUT requires local access)
-- OPTION 3: Use the Python uploader below
--
-- Run as SYSADMIN after generating transcripts with:
--   python scripts/generate_zoom_transcripts.py
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

-- ============================================================
-- Ensure stage exists
-- ============================================================
CREATE OR REPLACE STAGE ZOOM_TRANSCRIPTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Zoom call transcript files in WEBVTT format for Cortex Search';

-- ============================================================
-- OPTION 1: PUT from SnowSQL or Snowflake CLI
-- Run this from SnowSQL replacing the path with your local path:
-- ============================================================
-- PUT file:///path/to/F5_HOL/data/zoom_transcripts/*.txt
--     @F5_PROD.RAW.ZOOM_TRANSCRIPTS_STAGE
--     AUTO_COMPRESS = FALSE
--     OVERWRITE = TRUE;

-- ============================================================
-- OPTION 2: If running from a Snowflake Worksheet with
-- local file browser enabled:
-- ============================================================
-- Use the "Upload" button in the stage browser UI

-- ============================================================
-- Verify upload
-- ============================================================
LIST @ZOOM_TRANSCRIPTS_STAGE;

-- Check file count
SELECT COUNT(*) AS file_count
FROM DIRECTORY(@ZOOM_TRANSCRIPTS_STAGE);

-- Preview a file
SELECT
    RELATIVE_PATH,
    SIZE,
    LAST_MODIFIED
FROM DIRECTORY(@ZOOM_TRANSCRIPTS_STAGE)
ORDER BY LAST_MODIFIED DESC
LIMIT 10;
