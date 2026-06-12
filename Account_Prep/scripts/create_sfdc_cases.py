"""
Create Salesforce Accounts and Cases from Snowflake Support Case Table
======================================================================
Reads DIM_SUPPORT_CASE from Snowflake, creates matching Salesforce Account
and Case objects, then writes back the Salesforce CaseNumber to SUPPORT_CASE_NUM.

Workflow:
1. Authenticate to Salesforce (Connected App, username-password flow)
2. Create Account objects for each unique customer (~130)
3. Create Case objects linked to Accounts (~1,125)
4. Update DIM_SUPPORT_CASE.SUPPORT_CASE_NUM with Salesforce CaseNumber
5. Rebuild COL_SUPPORT_CASE with updated case numbers

Usage:
    SFDC_CLIENT_ID="<id>" SFDC_CLIENT_SECRET="<secret>" \
    SFDC_USERNAME="<user>" SFDC_PASSWORD="<pass>" SFDC_SECURITY_TOKEN="<token>" \
    python scripts/create_sfdc_cases.py

    Or with --resume to skip already-created accounts/cases.
"""

import os
import sys
import time
import json
import requests
import snowflake.connector

# ============================================================
# CONFIG
# ============================================================
SFDC_LOGIN_URL = "https://login.salesforce.com"
SFDC_INSTANCE_URL = "https://orgfarm-b5c32390d9-dev-ed.develop.my.salesforce.com"
SFDC_API_VERSION = "v61.0"

SNOWFLAKE_DB = "F5_PROD"
SNOWFLAKE_SCHEMA = "RAW"

# Priority mapping: Snowflake → Salesforce
PRIORITY_MAP = {
    "P1 - Critical": "Critical",
    "P2 - High": "High",
    "P3 - Medium": "Medium",
    "P4 - Low": "Low",
}

# Status mapping: Snowflake → Salesforce
STATUS_MAP = {
    "Open": "New",
    "In Progress": "Working",
    "Waiting on Customer": "On Hold",
    "Resolved": "Closed",
    "Closed": "Closed",
}


# ============================================================
# SALESFORCE AUTH
# ============================================================
def sfdc_authenticate():
    """Authenticate via OAuth2. Tries password flow first, falls back to browser-based auth code flow."""
    client_id = os.environ.get("SFDC_CLIENT_ID", "")
    client_secret = os.environ.get("SFDC_CLIENT_SECRET", "")
    username = os.environ.get("SFDC_USERNAME", "")
    password = os.environ.get("SFDC_PASSWORD", "")
    security_token = os.environ.get("SFDC_SECURITY_TOKEN", "")
    
    # Check for a saved access token first
    if os.path.exists("/tmp/sfdc_token.json"):
        with open("/tmp/sfdc_token.json") as f:
            token_data = json.load(f)
            # Verify token still works
            test = requests.get(
                f"{token_data['instance_url']}/services/data/{SFDC_API_VERSION}/sobjects",
                headers={"Authorization": f"Bearer {token_data['access_token']}"}
            )
            if test.status_code == 200:
                print(f"SFDC: Using cached token for {token_data['instance_url']}")
                return token_data["access_token"], token_data["instance_url"]

    if not client_id:
        print("ERROR: SFDC_CLIENT_ID env var required")
        sys.exit(1)

    # Try password flow if credentials provided
    if username and password:
        resp = requests.post(f"{SFDC_LOGIN_URL}/services/oauth2/token", data={
            "grant_type": "password",
            "client_id": client_id,
            "client_secret": client_secret,
            "username": username,
            "password": password + security_token,
        })
        if resp.status_code == 200:
            token_data = resp.json()
            _save_token(token_data)
            print(f"SFDC: Authenticated (password flow) to {token_data['instance_url']}")
            return token_data["access_token"], token_data["instance_url"]
        else:
            print(f"  Password flow failed ({resp.status_code}), falling back to browser auth...")

    # Browser-based authorization code flow with PKCE
    # Uses out-of-band manual paste (no localhost server needed)
    import urllib.parse
    import hashlib
    import base64
    import secrets

    # Generate PKCE code verifier and challenge
    code_verifier = secrets.token_urlsafe(64)[:128]
    code_challenge = base64.urlsafe_b64encode(
        hashlib.sha256(code_verifier.encode()).digest()
    ).rstrip(b"=").decode()

    redirect_uri = "https://login.salesforce.com/services/oauth2/success"
    auth_url = (
        f"{SFDC_LOGIN_URL}/services/oauth2/authorize?"
        f"response_type=code&client_id={client_id}"
        f"&redirect_uri={urllib.parse.quote(redirect_uri)}"
        f"&scope=api+refresh_token"
        f"&code_challenge={code_challenge}"
        f"&code_challenge_method=S256"
    )

    print("\n  Open this URL in your browser and authorize:\n")
    print(f"  {auth_url}\n")
    print("  After authorizing, you'll be redirected to a success page.")
    print("  Copy the FULL URL from your browser's address bar and paste it below.\n")
    
    callback_url = input("  Paste the redirect URL here: ").strip()
    
    # Extract auth code from the pasted URL
    parsed = urllib.parse.urlparse(callback_url)
    params = urllib.parse.parse_qs(parsed.query)
    if "code" not in params:
        print("ERROR: No authorization code found in URL")
        sys.exit(1)
    auth_code = params["code"][0]

    # Exchange code for token (with PKCE verifier)
    resp = requests.post(f"{SFDC_LOGIN_URL}/services/oauth2/token", data={
        "grant_type": "authorization_code",
        "client_id": client_id,
        "client_secret": client_secret,
        "code": auth_code,
        "redirect_uri": redirect_uri,
        "code_verifier": code_verifier,
    })
    
    if resp.status_code != 200:
        print(f"ERROR: Token exchange failed ({resp.status_code}): {resp.text[:200]}")
        sys.exit(1)

    token_data = resp.json()
    _save_token(token_data)
    print(f"SFDC: Authenticated (browser flow) to {token_data['instance_url']}")
    return token_data["access_token"], token_data["instance_url"]


def _save_token(token_data):
    """Cache token for resume runs."""
    with open("/tmp/sfdc_token.json", "w") as f:
        json.dump({"access_token": token_data["access_token"], 
                   "instance_url": token_data.get("instance_url", SFDC_INSTANCE_URL)}, f)


def sfdc_headers(access_token):
    return {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }


# ============================================================
# SALESFORCE API FUNCTIONS
# ============================================================
def create_account(access_token, instance_url, name):
    """Create a Salesforce Account. Returns AccountId."""
    url = f"{instance_url}/services/data/{SFDC_API_VERSION}/sobjects/Account"
    payload = {"Name": name}
    resp = requests.post(url, headers=sfdc_headers(access_token), json=payload)
    if resp.status_code == 201:
        return resp.json()["id"]
    elif resp.status_code == 400 and "DUPLICATE" in resp.text:
        # Account already exists, query for it
        return query_account_id(access_token, instance_url, name)
    else:
        print(f"  ERROR creating Account '{name}': {resp.status_code} - {resp.text[:150]}")
        return None


def query_account_id(access_token, instance_url, name):
    """Query for an existing Account by Name."""
    safe_name = name.replace("'", "\\'")
    url = f"{instance_url}/services/data/{SFDC_API_VERSION}/query"
    resp = requests.get(url, headers=sfdc_headers(access_token),
                        params={"q": f"SELECT Id FROM Account WHERE Name = '{safe_name}' LIMIT 1"})
    if resp.status_code == 200:
        records = resp.json().get("records", [])
        if records:
            return records[0]["Id"]
    return None


def create_case(access_token, instance_url, account_id, case_data):
    """Create a Salesforce Case. Returns CaseNumber."""
    url = f"{instance_url}/services/data/{SFDC_API_VERSION}/sobjects/Case"

    subject = case_data["SUPPORT_CASE_TITLE_TEXT"]
    status = STATUS_MAP.get(case_data["SUPPORT_CASE_STATUS_CODE"], "New")
    priority = PRIORITY_MAP.get(case_data["CURRENT_PRIORITY_CODE"], "Medium")
    product = case_data["PRODUCT_NAME"]
    area = case_data["AREA_NAME"]
    sub_area = case_data["SUB_AREA_NAME"]
    created = str(case_data["CREATED_DATETIME"])[:19]

    description = (
        f"Product: {product}\n"
        f"Area: {area} > {sub_area}\n"
        f"Original Created Date: {created}\n"
        f"Priority: {case_data['CURRENT_PRIORITY_CODE']}\n"
        f"Type: {case_data['SUPPORT_CASE_TYPE_CODE']}\n\n"
        f"Issue: {subject}"
    )

    payload = {
        "AccountId": account_id,
        "Subject": subject[:255],
        "Description": description[:32000],
        "Status": status,
        "Priority": priority,
        "Origin": "Web",
    }

    resp = requests.post(url, headers=sfdc_headers(access_token), json=payload)
    if resp.status_code == 201:
        case_id = resp.json()["id"]
        # Query back the CaseNumber (auto-generated)
        case_num = get_case_number(access_token, instance_url, case_id)
        return case_num
    else:
        print(f"  ERROR creating Case: {resp.status_code} - {resp.text[:150]}")
        return None


def get_case_number(access_token, instance_url, case_id):
    """Get the auto-generated CaseNumber for a Case."""
    url = f"{instance_url}/services/data/{SFDC_API_VERSION}/sobjects/Case/{case_id}"
    resp = requests.get(url, headers=sfdc_headers(access_token), params={"fields": "CaseNumber"})
    if resp.status_code == 200:
        return resp.json().get("CaseNumber")
    return None


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


def get_accounts_from_snowflake(conn):
    """Get unique account names that have telemetry data."""
    cur = conn.cursor()
    cur.execute(f"""
        SELECT DISTINCT a.SFDCF5_ACCT_ID, a.ACCT_NAME
        FROM {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_CUST_ACCT_SFDC a
        JOIN {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.COL_XC_TELEMETRY t ON a.SFDCF5_ACCT_ID = t.SFDCF5_ACCT_ID
        ORDER BY a.ACCT_NAME
    """)
    columns = [desc[0] for desc in cur.description]
    return [dict(zip(columns, row)) for row in cur.fetchall()]


def get_cases_from_snowflake(conn, resume=False):
    """Get support cases. If resume, only get ones without SFDC case numbers."""
    cur = conn.cursor()
    where = "WHERE sc.SUPPORT_CASE_NUM NOT LIKE '0%'" if resume else ""
    cur.execute(f"""
        SELECT sc.SUPPORT_CASE_ID, sc.SUPPORT_CASE_TITLE_TEXT,
               sc.PRODUCT_NAME, sc.AREA_NAME, sc.SUB_AREA_NAME,
               sc.CURRENT_PRIORITY_CODE, sc.SUPPORT_CASE_STATUS_CODE,
               sc.SUPPORT_CASE_TYPE_CODE, sc.CREATED_DATETIME,
               a.ACCT_NAME, sc.SFDCF5_ACCT_ID
        FROM {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_SUPPORT_CASE sc
        JOIN {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_CUST_ACCT_SFDC a 
            ON sc.SFDCF5_ACCT_ID = a.SFDCF5_ACCT_ID
        {where}
        ORDER BY sc.CREATED_DATETIME DESC
    """)
    columns = [desc[0] for desc in cur.description]
    return [dict(zip(columns, row)) for row in cur.fetchall()]


def update_case_number(conn, case_id, sfdc_case_number):
    """Update SUPPORT_CASE_NUM with Salesforce CaseNumber."""
    cur = conn.cursor()
    cur.execute(f"""
        UPDATE {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}.DIM_SUPPORT_CASE
        SET SUPPORT_CASE_NUM = %s
        WHERE SUPPORT_CASE_ID = %s
    """, (sfdc_case_number, case_id))


def sync_col_support_case(conn):
    """Rebuild COL_SUPPORT_CASE with updated case numbers."""
    cur = conn.cursor()
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
# MAIN
# ============================================================
def main():
    resume = "--resume" in sys.argv

    # Step 1: Authenticate to Salesforce
    access_token, instance_url = sfdc_authenticate()

    # Step 2: Connect to Snowflake
    print("Connecting to Snowflake...")
    conn = get_snowflake_connection()
    print(f"Snowflake: Connected to {SNOWFLAKE_DB}.{SNOWFLAKE_SCHEMA}\n")

    # Step 3: Create Accounts
    accounts = get_accounts_from_snowflake(conn)
    print(f"{'=' * 60}")
    print(f"Creating {len(accounts)} Accounts in Salesforce...")
    print(f"{'=' * 60}")

    account_id_map = {}  # ACCT_NAME -> SFDC AccountId
    created_accts = 0
    for i, acct in enumerate(accounts):
        name = acct["ACCT_NAME"]
        # Try to find existing first
        acct_id = query_account_id(access_token, instance_url, name)
        if not acct_id:
            acct_id = create_account(access_token, instance_url, name)
            if acct_id:
                created_accts += 1
        if acct_id:
            account_id_map[name] = acct_id
        if (i + 1) % 25 == 0:
            print(f"  Progress: {i + 1}/{len(accounts)} accounts processed")
        time.sleep(0.1)

    print(f"  -> {created_accts} new accounts created, {len(account_id_map)} total mapped\n")

    # Step 4: Create Cases
    cases = get_cases_from_snowflake(conn, resume=resume)
    print(f"{'=' * 60}")
    print(f"Creating {len(cases)} Cases in Salesforce...")
    print(f"{'=' * 60}")

    created_cases = 0
    for i, case in enumerate(cases):
        acct_name = case["ACCT_NAME"]
        account_id = account_id_map.get(acct_name)
        if not account_id:
            # Try to look it up
            account_id = query_account_id(access_token, instance_url, acct_name)
            if account_id:
                account_id_map[acct_name] = account_id

        if not account_id:
            print(f"  SKIP: No AccountId for '{acct_name}'")
            continue

        case_number = create_case(access_token, instance_url, account_id, case)
        if case_number:
            update_case_number(conn, case["SUPPORT_CASE_ID"], case_number)
            created_cases += 1
            if created_cases % 25 == 0:
                print(f"  Progress: {created_cases} cases created")

        time.sleep(0.2)

        # Rate limit pause every 100 cases
        if (i + 1) % 100 == 0:
            print(f"  Rate limit pause at {i + 1}...")
            time.sleep(3)

    print(f"  -> {created_cases} cases created\n")

    # Step 5: Sync COL_SUPPORT_CASE
    print("Syncing COL_SUPPORT_CASE...")
    sync_col_support_case(conn)

    # Summary
    print(f"\n{'=' * 60}")
    print(f"COMPLETE: {len(account_id_map)} accounts + {created_cases} cases in Salesforce")
    print(f"All SUPPORT_CASE_NUM values updated with Salesforce CaseNumbers")
    print(f"{'=' * 60}")

    conn.close()


if __name__ == "__main__":
    main()
