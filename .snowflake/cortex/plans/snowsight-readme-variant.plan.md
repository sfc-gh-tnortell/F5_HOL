# Plan: Snowsight CoCo README Variant

## Approach
Copy the existing README.md and README.html to `README_SNOWSIGHT.md` and `README_SNOWSIGHT.html`, then modify only the sections that differ between Desktop and Snowsight CoCo. Most of the lab (80%+) is identical.

## Sections That Change

### 1. Prerequisites (lines 88-115)
**Desktop version:** Download CoCo Desktop, create connection, create F5_HOL folder
**Snowsight version:**
- Open Snowsight and log in to your assigned account
- Navigate to **Projects & Worksheets → Cortex Code** to open the CoCo panel
- No download, no folder, no connection setup needed

### 2. Module 1 Step 1 - Download/Setup (lines 186-223)
**Desktop version:** Download query_repository.sql from stage, drag into F5_HOL folder, "Open the file and prompt"
**Snowsight version:**
- Download query_repository.sql from stage (same)
- Open it in a worksheet OR copy/paste contents into CoCo chat
- Prompt references "the SQL queries I pasted" instead of "in this file"
- No skill creation (skills are Desktop-only) - remove the SKILL.md line
- Expected output: verified_queries shown in chat (copy to a worksheet for later)

### 3. Module 1 Step 2 - Semantic View Creation (lines 227-266)
**Desktop version:** "Open the verified queries file generated in Step 1" 
**Snowsight version:** "Paste the verified queries from Step 1" or reference them by describing them
- Option A prompt changes from file reference to "Using these verified queries: [paste]"
- Option B (Snowsight UI) stays the same

### 4. Module 1 Step 5 - Prove Predictive (lines 325-349)
**Desktop version:** Prompt is the same, but context assumes CoCo has file access
**Snowsight version:** Prompt is identical - CoCo in Snowsight can still run SQL against the account. No changes needed.

### 5. Minor wording throughout
- Remove references to "your F5_HOL folder" or "save to a file"
- Change "Open `verified_queries.sql`" to "Paste your verified queries"
- Remove skill creation references

## Files to Create
- `HOL/README_SNOWSIGHT.md` - Full copy with modifications
- `HOL/README_SNOWSIGHT.html` - Full copy with modifications

## Implementation
1. Copy README.md to README_SNOWSIGHT.md
2. Modify Prerequisites section
3. Modify Step 1 (query repository download and analysis prompt)
4. Modify Step 2 (semantic view creation prompt)
5. Remove SKILL.md references
6. Update any "save to file" language to "copy to worksheet"
7. Repeat for HTML version
