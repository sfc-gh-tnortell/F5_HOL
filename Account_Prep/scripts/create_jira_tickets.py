"""
Create Jira Tickets from Snowflake Support Case Table
=====================================================
Reads DIM_SUPPORT_CASE from Snowflake, creates matching Jira tickets,
then writes back the Jira key (KAN-xxx) to SUPPORT_CASE_NUM.

Workflow:
1. Connect to Snowflake (uses default connection from connections.toml)
2. Query all cases from DIM_SUPPORT_CASE
3. Create Jira tickets matching each case
4. Update SUPPORT_CASE_NUM with the returned Jira key
5. Update COL_SUPPORT_CASE to match

Usage:
    JIRA_API_TOKEN="<token>" python scripts/create_jira_tickets.py
"""

import os
import time
import requests
import snowflake.connector

# ============================================================
# CONFIG
# ============================================================
JIRA_URL = "https://f5snowhol.atlassian.net"
PROJECT_KEY = "KAN"
ASSIGNEE_EMAIL = "traviskn20@gmail.com"
HEADERS = {"Content-Type": "application/json", "Accept": "application/json"}

SNOWFLAKE_DB = "F5_PROD"
SNOWFLAKE_SCHEMA = "RAW"


def get_api_token():
    token = os.environ.get("JIRA_API_TOKEN", "")
    if token:
        return token
    if os.path.exists("/tmp/jira_token.txt"):
        with open("/tmp/jira_token.txt") as f:
            return f.read().strip()
    return ""


# ============================================================
# SNOWFLAKE CONNECTION
# ============================================================
def get_snowflake_connection():
    """Connect using named connection from ~/.snowflake/connections.toml."""
    conn = snowflake.connector.connect(
        connection_name="sfsenorthamerica-demo351_aws",
        database=SNOWFLAKE_DB,
        schema=SNOWFLAKE_SCHEMA,
    )
    return conn


def get_cases_from_snowflake(conn, resume=False):
    """Query support cases from DIM_SUPPORT_CASE. If resume=True, only get pending ones."""
    cur = conn.cursor()
    where_clause = "WHERE sc.SUPPORT_CASE_NUM NOT LIKE 'KAN-%'" if resume else ""
    cur.execute(f"""
        SELECT sc.SUPPORT_CASE_ID, sc.SUPPORT_CASE_TITLE_TEXT,
               sc.PRODUCT_NAME, sc.AREA_NAME, sc.SUB_AREA_NAME,
               sc.CURRENT_PRIORITY_CODE, sc.SUPPORT_CASE_STATUS_CODE,
               sc.SUPPORT_CASE_TYPE_CODE, sc.CREATED_DATETIME,
               a.ACCT_NAME
        FROM {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_SUPPORT_CASE sc
        JOIN {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_CUST_ACCT_SFDC a 
            ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
        {where_clause}
        ORDER BY sc.CREATED_DATETIME DESC
    """)
    columns = [desc[0] for desc in cur.description]
    rows = cur.fetchall()
    return [dict(zip(columns, row)) for row in rows]


def update_case_number(conn, case_id, jira_key):
    """Update SUPPORT_CASE_NUM with Jira key."""
    cur = conn.cursor()
    cur.execute(f"""
        UPDATE {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_SUPPORT_CASE
        SET SUPPORT_CASE_NUM = %s
        WHERE SUPPORT_CASE_ID = %s
    """, (jira_key, case_id))


def sync_col_support_case(conn):
    """Sync COL_SUPPORT_CASE.SUPPORT_CASE_NUM from DIM_SUPPORT_CASE."""
    cur = conn.cursor()
    # Rebuild COL_SUPPORT_CASE with updated case numbers
    cur.execute(f"TRUNCATE TABLE {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.COL_SUPPORT_CASE")
    cur.execute(f"""
        INSERT INTO {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.COL_SUPPORT_CASE (
            SALES_SFDCF5_ACCT_ID, TERRITORY_OWNER_NAME, TERRITORY_NAME,
            DISTRICT_NAME, REGION_NAME, THEATER_NAME, SERIAL_NUM,
            SUPPORT_CASE_NUM, SUPPORT_CASE_TITLE_TEXT, STATUS, SEVERITY_CODE,
            PRODUCT_SKU_ID, OPEN_DATE, CLOSE_DATE, SUPPORT_CASE_OPEN_DAYS,
            CONTACT_FULL_NAME, CONTACT_EMAIL_ADDRESS_TEXT
        )
        SELECT
            sc.SFDCF5_ACCT_ID, sat.AE_NAME, sat.TERRITORY_NAME,
            sat.DISTRICT_NAME, sat.REGION_NAME, sat.THEATER_NAME,
            'SN' || LPAD(ABS(HASH(sc.SUPPORT_CASE_ID)) % 9999999, 7, '0'),
            sc.SUPPORT_CASE_NUM, sc.SUPPORT_CASE_TITLE_TEXT,
            sc.SUPPORT_CASE_STATUS_CODE, sc.CURRENT_PRIORITY_CODE,
            sc.PRODUCT_SKU_ID, sc.OPENED_DATETIME, sc.CLOSED_DATETIME,
            DATEDIFF(day, sc.OPENED_DATETIME, COALESCE(sc.CLOSED_DATETIME, CURRENT_TIMESTAMP())),
            sc.CONTACT_FULL_NAME, sc.CONTACT_EMAIL_ADDRESS_TEXT
        FROM {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_SUPPORT_CASE sc
        LEFT JOIN {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.SALES_ACCOUNT_TEAM sat 
            ON sc.SFDCF5_ACCT_ID = sat.SFDCF5_ACCT_ID
    """)
    print("  COL_SUPPORT_CASE synced with updated case numbers.")


# ============================================================
# JIRA API FUNCTIONS
# ============================================================
def create_jira_issue(auth, case):
    """Create a Jira issue from a support case dict."""
    account = case["ACCT_NAME"]
    title = case["SUPPORT_CASE_TITLE_TEXT"]
    product = case["PRODUCT_NAME"]
    area = case["AREA_NAME"]
    sub_area = case["SUB_AREA_NAME"]
    priority = case["CURRENT_PRIORITY_CODE"]
    status = case["SUPPORT_CASE_STATUS_CODE"]

    summary = f"{account} - {title}"[:255]
    description = (
        f"Customer: {account}\n"
        f"Product: {product}\n"
        f"Area: {area} > {sub_area}\n"
        f"Priority: {priority}\n"
        f"Status: {status}\n\n"
        f"Issue: {title}"
    )

    payload = {
        "fields": {
            "project": {"key": PROJECT_KEY},
            "summary": summary,
            "description": {
                "type": "doc", "version": 1,
                "content": [{"type": "paragraph", "content": [{"type": "text", "text": description}]}]
            },
            "issuetype": {"name": "Task"},
        }
    }

    resp = requests.post(
        f"{JIRA_URL}/rest/api/3/issue",
        headers=HEADERS, auth=auth, json=payload
    )
    if resp.status_code in (200, 201):
        key = resp.json().get("key")
        return key
    else:
        print(f"  ERROR ({resp.status_code}): {resp.text[:150]}")
        return None


def transition_to_done(auth, issue_key):
    """Transition issue to Done status."""
    resp = requests.get(
        f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions",
        headers=HEADERS, auth=auth
    )
    if resp.status_code != 200:
        return False
    for t in resp.json().get("transitions", []):
        if any(x in t["name"].lower() for x in ["done", "closed", "resolved", "complete"]):
            resp = requests.post(
                f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions",
                headers=HEADERS, auth=auth,
                json={"transition": {"id": t["id"]}}
            )
            if resp.status_code == 204:
                return True
    return False


# ============================================================
# MAIN
# ============================================================
def main():
    import sys
    resume = "--resume" in sys.argv

    api_token = get_api_token()
    if not api_token:
        print("ERROR: No Jira API token found. Set JIRA_API_TOKEN env var or /tmp/jira_token.txt")
        return

    auth = (ASSIGNEE_EMAIL, api_token)

    # Verify Jira connection
    resp = requests.get(f"{JIRA_URL}/rest/api/3/myself", headers=HEADERS, auth=auth)
    if resp.status_code != 200:
        print(f"ERROR: Jira auth failed ({resp.status_code})")
        return
    print(f"Jira: Authenticated as {resp.json().get('displayName')}")

    # Connect to Snowflake
    print("Connecting to Snowflake...")
    conn = get_snowflake_connection()
    print(f"Snowflake: Connected to {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}")

    # Get cases from table
    cases = get_cases_from_snowflake(conn, resume=resume)
    if resume:
        print(f"RESUME MODE: Found {len(cases)} remaining cases (skipping already-created)\n")
    else:
        print(f"Found {len(cases)} support cases to create in Jira\n")

    # Separate open vs closed
    open_cases = [c for c in cases if c["SUPPORT_CASE_STATUS_CODE"] in ("Open", "In Progress")]
    closed_cases = [c for c in cases if c["SUPPORT_CASE_STATUS_CODE"] not in ("Open", "In Progress")]

    print(f"  Open/In Progress: {len(open_cases)}")
    print(f"  Closed/Resolved/Waiting: {len(closed_cases)}")
    print()

    # Create open tickets
    print("=" * 60)
    print("Creating OPEN tickets...")
    print("=" * 60)
    created = 0
    for i, case in enumerate(open_cases):
        key = create_jira_issue(auth, case)
        if key:
            update_case_number(conn, case["SUPPORT_CASE_ID"], key)
            created += 1
            if created % 10 == 0:
                print(f"  Progress: {created}/{len(open_cases)} open tickets created")
        time.sleep(0.3)
    print(f"  -> {created} open tickets created\n")

    # Create closed tickets
    print("=" * 60)
    print("Creating CLOSED tickets...")
    print("=" * 60)
    created_closed = 0
    for i, case in enumerate(closed_cases):
        key = create_jira_issue(auth, case)
        if key:
            transition_to_done(auth, key)
            update_case_number(conn, case["SUPPORT_CASE_ID"], key)
            created_closed += 1
            if created_closed % 25 == 0:
                print(f"  Progress: {created_closed}/{len(closed_cases)} closed tickets created")
        time.sleep(0.3)

        # Rate limit pause every 50 tickets
        if (i + 1) % 50 == 0:
            print(f"  Rate limit pause at {i + 1}...")
            time.sleep(3)

    print(f"  -> {created_closed} closed tickets created\n")

    # Sync COL_SUPPORT_CASE
    print("Syncing COL_SUPPORT_CASE with Jira keys...")
    sync_col_support_case(conn)

    # Summary
    total = created + created_closed
    print(f"\n{'=' * 60}")
    print(f"COMPLETE: {created} open + {created_closed} closed = {total} total Jira tickets")
    print(f"All SUPPORT_CASE_NUM values updated with KAN-xxx keys")
    print("=" * 60)

    conn.close()


if __name__ == "__main__":
    main()
