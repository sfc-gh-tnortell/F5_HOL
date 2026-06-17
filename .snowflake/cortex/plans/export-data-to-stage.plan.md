# Plan: Export Data to Stage (New Folder)

## Structure

```
HOL_data_setup/
├── 01_export_from_source.sql    (run by YOU once - exports RAW tables to stage as Parquet)
├── 02_create_environment.sql    (attendee runs - DB, schemas, warehouse, compute pool, tables)
├── 03_load_data.sql             (attendee runs - COPY INTO all tables from staged Parquet)
├── 04_upload_transcripts.sql    (attendee runs - creates stage + loads transcript files)
└── data/                        (Parquet files downloaded from stage, committed to repo)
```

## Scripts

### 01_export_from_source.sql (you run once)
- Creates `@F5_PROD.RAW.HOL_DATA_EXPORT` stage
- COPY INTO stage for all 27 RAW tables as Parquet
- After running, use GET to download files into `HOL_data_setup/data/`

### 02_create_environment.sql (attendee runs)
- USE ROLE SYSADMIN
- CREATE WAREHOUSE, COMPUTE POOL
- CREATE DATABASE F5_PROD
- CREATE SCHEMAS (RAW, STAGING, FINAL)
- CREATE all tables (DDL from existing 02_create_tables.sql)
- CREATE stage `@F5_PROD.RAW.HOL_DATA_STAGE`

### 03_load_data.sql (attendee runs after PUT)
- Attendees first PUT files: `PUT file://./data/*.parquet @F5_PROD.RAW.HOL_DATA_STAGE/`
- Then COPY INTO each table from its subfolder on stage
- Uses `MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE` for Parquet

### 04_upload_transcripts.sql (attendee runs)
- Creates `ZOOM_TRANSCRIPTS_STAGE` with directory enabled
- Instructions to PUT transcript .txt files
- Creates `ZOOM_TRANSCRIPT_SOURCE` table in FINAL schema

## Verification
- All 27 tables populated with correct row counts
- Transcripts accessible on stage

## Critical Files
- `HOL_data_setup/01_export_from_source.sql` - One-time export
- `HOL_data_setup/02_create_environment.sql` - Attendee environment setup
- `HOL_data_setup/03_load_data.sql` - Attendee data load
