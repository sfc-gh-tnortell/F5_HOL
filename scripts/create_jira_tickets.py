"""
Generate Telemetry-Correlated Jira Support Tickets (v3)
========================================================
1. Cleans up existing tickets in the KAN project
2. Queries actual telemetry signals to determine ticket categories
3. Creates OPEN tickets (recent 2 months) and CLOSED tickets (historical 4 months)
4. Each ticket correlates to the account's real telemetry signal
   but with NO direct database link (no tenant IDs, no table refs)

Usage:
    JIRA_API_TOKEN="<token>" python scripts/create_jira_tickets.py
"""

import os
import requests
import hashlib
import time

# ============================================================
# CONFIG
# ============================================================
JIRA_URL = "https://f5snowhol.atlassian.net"
PROJECT_KEY = "KAN"
ASSIGNEE_EMAIL = "traviskn20@gmail.com"
HEADERS = {"Content-Type": "application/json", "Accept": "application/json"}
API_TOKEN = None
AUTH = None


def get_api_token():
    token = os.environ.get("JIRA_API_TOKEN", "")
    if token:
        return token
    if os.path.exists("/tmp/jira_token.txt"):
        with open("/tmp/jira_token.txt") as f:
            return f.read().strip()
    return ""


def hash_val(s):
    return int(hashlib.md5(s.encode()).hexdigest(), 16)


# ============================================================
# ACCOUNT-TO-SIGNAL MAPPING (from actual telemetry queries)
# ============================================================
# Derived from: SELECT ACCT_NAME, primary_signal FROM COL_XC_TELEMETRY
# WHERE OBSERVATION_DATE >= CURRENT_DATE() - 60 (recent 2 months)

RECENT_SIGNALS = {
    # bot-defense (avg bot_txn > 300K in recent 2 months)
    "Amazon": "bot-defense",
    "AT&T": "bot-defense",
    "Accenture": "bot-defense",
    "Adobe": "bot-defense",
    "Centene": "bot-defense",
    "Cloudflare": "bot-defense",
    "Colgate-Palmolive": "bot-defense",
    "Comcast": "bot-defense",
    "Costco": "bot-defense",
    "Datadog": "bot-defense",
    "CDW": "bot-defense",
    "Fidelity": "bot-defense",
    # waf (avg waf > 25 in recent 2 months)
    "Airbnb": "waf",
    "Abbott Laboratories": "waf",
    "Amentum": "waf",
    "Delta Air Lines": "waf",
    "Duke Energy": "waf",
    "Charles Schwab": "waf",
    "Cardinal Health": "waf",
    "Cognizant": "waf",
    # capacity (avg endpoints > 150)
    "American Airlines": "capacity",
    "Albertsons": "capacity",
    "Autodesk": "capacity",
    "Baxter International": "capacity",
    "CSX": "capacity",
    "CVS Health": "capacity",
    "Caterpillar": "capacity",
    "ConocoPhillips": "capacity",
    "CrowdStrike": "capacity",
    # load-balancer (avg http_lb > 40)
    "Applied Materials": "load-balancer",
    "BlackRock": "load-balancer",
    "Dell Technologies": "load-balancer",
    "EOG Resources": "load-balancer",
    # dns (avg dns zones > 7)
    "AmerisourceBergen": "dns",
    "Aon": "dns",
    "Dish Network": "dns",
    "Elevance Health": "dns",
    # performance (default/other)
    "Best Buy": "performance",
    "Broadcom": "performance",
    "Cisco Systems": "performance",
    "Chevron": "performance",
    "Citigroup": "performance",
}

# Historical 4 months (slightly different distribution)
HISTORICAL_SIGNALS = {
    "Intel": "waf",
    "Nvidia": "capacity",
    "Microsoft": "bot-defense",
    "Netflix": "bot-defense",
    "Morgan Stanley": "bot-defense",
    "JPMorgan Chase": "bot-defense",
    "Boeing": "load-balancer",
    "Salesforce": "performance",
    "Goldman Sachs": "capacity",
    "Home Depot": "capacity",
    "Capital One": "waf",
    "Best Buy": "bot-defense",
    "Tesla": "performance",
    "ExxonMobil": "dns",
    "UPS": "load-balancer",
    "Verizon": "capacity",
    "T-Mobile": "waf",
    "Honeywell": "load-balancer",
    "Nike": "performance",
    "IBM": "dns",
    "PayPal": "bot-defense",
    "Mastercard": "bot-defense",
    "Broadcom": "load-balancer",
    "CrowdStrike": "capacity",
    "Fortinet": "waf",
    "Alphabet": "performance",
    "Airbnb": "waf",
    "Delta Air Lines": "waf",
    "Costco": "capacity",
    "Comcast": "bot-defense",
}

# ============================================================
# TICKET CONTENT GENERATORS (unique per account)
# ============================================================
INDUSTRIES = {
    "Amazon": "e-commerce", "AT&T": "telecommunications", "Cloudflare": "technology",
    "Fidelity": "financial services", "Accenture": "consulting", "Morgan Stanley": "financial services",
    "Costco": "retail", "Microsoft": "technology", "Netflix": "media streaming",
    "Comcast": "telecommunications", "Pfizer": "pharmaceuticals", "Datadog": "technology",
    "Micron Technology": "semiconductors", "Boeing": "aerospace", "JPMorgan Chase": "financial services",
    "Intel": "semiconductors", "Nvidia": "technology", "Cisco Systems": "networking",
    "Adobe": "software", "Salesforce": "SaaS", "Goldman Sachs": "financial services",
    "Home Depot": "retail", "Capital One": "financial services", "Best Buy": "retail",
    "Tesla": "automotive", "ExxonMobil": "energy", "Delta Air Lines": "transportation",
    "UPS": "logistics", "Verizon": "telecommunications", "T-Mobile": "telecommunications",
    "Honeywell": "industrial", "Nike": "retail", "IBM": "technology",
    "PayPal": "fintech", "Mastercard": "payments", "Broadcom": "semiconductors",
    "CrowdStrike": "cybersecurity", "Fortinet": "cybersecurity", "Alphabet": "technology",
    "Airbnb": "hospitality tech", "CDW": "IT distribution", "Centene": "healthcare",
    "American Airlines": "transportation", "Albertsons": "grocery retail",
    "Abbott Laboratories": "healthcare", "Autodesk": "software",
    "Baxter International": "healthcare", "CSX": "transportation",
    "CVS Health": "healthcare", "Caterpillar": "heavy equipment",
    "ConocoPhillips": "energy", "Applied Materials": "semiconductors",
    "BlackRock": "asset management", "Dell Technologies": "technology",
    "EOG Resources": "energy", "AmerisourceBergen": "healthcare distribution",
    "Aon": "insurance", "Dish Network": "media", "Elevance Health": "healthcare",
    "Colgate-Palmolive": "consumer goods", "Duke Energy": "utilities",
    "Charles Schwab": "financial services", "Cardinal Health": "healthcare",
    "Cognizant": "IT services", "Amentum": "government services",
}

REPORTERS = [
    "Network Operations Center", "VP of Infrastructure", "CISO Office",
    "DevOps Team Lead", "SRE On-Call", "Cloud Architecture Team",
    "Platform Engineering", "Security Operations", "IT Director",
    "Application Performance Team",
]

BOT_SYMPTOMS = [
    ("legitimate checkout flow being challenged during flash sale event", "Conversion rate dropped 23% during the promotional window. Customer support lines flooded with complaints about CAPTCHA challenges on payment page."),
    ("mobile app users getting blocked after OS update", "After the latest Android/iOS update, the bot defense SDK is incorrectly flagging native app traffic. Approximately 15% of mobile sessions failing."),
    ("partner API integration classified as automated traffic", "Automated data feeds from their supply chain partners are being blocked. Partner SLA at risk, potential contract penalty if not resolved within 48 hours."),
    ("credential stuffing bypassing detection on /auth endpoint", "Security team identified sustained credential stuffing attack averaging 400K+ attempts daily. Current rules only catching 60% of malicious traffic."),
    ("bot score regression after model update causing false positives", "Following Tuesday's detection model update, false positive rate jumped from 0.1% to 3.2%. Legitimate API consumers being rate-limited incorrectly."),
    ("JavaScript challenge breaking single-page application navigation", "Bot challenge injection causing hydration errors in their React SPA. Users see blank pages after challenge completion. Critical path affected."),
    ("geo-distributed scraping attack not detected due to IP rotation", "Sophisticated scraping operation using residential proxies evading IP-based detection. Estimated 2M+ unauthorized page loads per day impacting CDN costs."),
    ("webhook callbacks from payment processors being blocked", "Stripe and Adyen webhook deliveries failing bot challenge. Payment confirmations delayed, causing order fulfillment backlog."),
]

WAF_SYMPTOMS = [
    ("GraphQL introspection queries triggering SQL injection rules", "Development team unable to use standard GraphQL tooling. Schema introspection blocked by SQLi detection pattern matching on nested query syntax."),
    ("CORS preflight requests denied after WAF rule propagation", "Cross-origin requests from their CDN subdomains failing. Frontend assets loading but API calls from browser being rejected with 403."),
    ("file upload endpoint blocking legitimate PDF attachments", "Insurance claim documents being rejected. WAF content inspection flagging embedded JavaScript in PDF metadata as XSS attempt."),
    ("REST API request body exceeding inspection buffer limit", "Large batch import payloads (>2MB JSON) being dropped silently. No error returned to client, causing data sync inconsistencies."),
    ("rate limiting rules conflicting with internal service mesh traffic", "East-west traffic between microservices hitting per-IP rate limits because pods share egress IPs. Service-to-service calls intermittently failing."),
    ("custom security header being stripped by WAF transformation rules", "Their proprietary X-Internal-Auth header removed during request normalization. Backend services returning 401 for requests that pass through WAF."),
    ("WebSocket upgrade blocked after rule set version change", "Real-time trading dashboard connections failing. WebSocket handshake being classified as protocol violation since last rule update."),
    ("multipart form data with unicode filenames triggering encoding rule", "International users unable to upload files with non-ASCII characters in filename. Affects their Japanese and Korean market operations."),
]

CAPACITY_SYMPTOMS = [
    ("endpoint count at 92% of contracted entitlement, growing 3% weekly", "Current trajectory will exceed contract limit within 3 weeks. Need to discuss expansion options before hard limit triggers service degradation."),
    ("namespace resource quota preventing new service deployments", "Team unable to deploy new microservices. Hit namespace limit during sprint planning. Blocking release of Q3 product features."),
    ("concurrent connection count exceeding tier during peak business hours", "Between 9 AM - 11 AM ET, connection count regularly hits ceiling. Auto-scaling not kicking in fast enough. Customer experiencing 429 errors."),
    ("WAF request processing at capacity causing increased latency", "P99 response times degraded from 45ms to 280ms during US business hours. WAF inspection queue depth growing faster than processing rate."),
    ("API call volume projected to exceed monthly quota within 2 weeks", "Current consumption rate will exhaust monthly API call allocation by the 18th. Customer requesting emergency capacity increase."),
    ("storage utilization for security event logs exceeding retention policy", "Log storage at 87% capacity. If not addressed, oldest security events will be purged before compliance-required 90-day retention window."),
    ("site count approaching hard limit for current subscription tier", "Currently at 14 of 15 allowed sites. Multi-region expansion blocked until tier upgrade. Impacting their APAC launch timeline."),
    ("load balancer pool member count maxed causing health check overhead", "150+ backend targets per pool causing health check storms. Probe traffic consuming 8% of total bandwidth. Need pool segmentation."),
]

LB_SYMPTOMS = [
    ("health check failures during blue-green deployment cutover", "Zero-downtime deployment strategy broken. Health probes timing out during DNS propagation window causing 30-second service gaps."),
    ("connection draining not completing before new deployment activates", "Long-lived gRPC streams being terminated abruptly during releases. Clients experiencing disconnects every deployment cycle."),
    ("origin TLS certificate chain validation failing intermittently", "Approximately 2% of requests to one origin returning 502. Certificate chain incomplete due to missing intermediate cert on 1 of 6 origins."),
    ("sticky session persistence breaking during horizontal scale events", "Shopping cart data lost when new instances join pool. Session affinity cookie not being honored for 60-90 seconds after scale-out."),
    ("weighted routing not reflecting updated backend capacity ratios", "New high-capacity servers receiving same traffic share as older hardware despite weight adjustment 48 hours ago. Manual refresh needed."),
    ("IPv6 to IPv4 translation causing source IP preservation issues", "Backend access logs showing NAT gateway IP instead of real client IP. Geo-restrictions and rate limiting not functioning correctly for IPv6 users."),
    ("TCP connection pool exhaustion under sustained high throughput", "During batch processing windows, connection reuse rate drops to 20%. New connections queuing with 5-second wait times."),
    ("HTTP/2 server push not functioning through load balancer proxy", "Performance optimization via server push disabled by proxy layer. Customer seeing 15% slower page load times compared to direct origin."),
]

DNS_SYMPTOMS = [
    ("zone transfer propagation taking 18 minutes between edge PoPs", "DR failover test showed unacceptable delay. SLA requires <5 minute failover, current architecture delivering 15-18 minutes."),
    ("GSLB not detecting primary site health degradation", "Latency-based routing continued sending traffic to degraded primary for 12 minutes before failover triggered. Customer reported downtime."),
    ("CNAME flattening producing unexpected resolution for apex domain", "Root domain resolving to stale IP after origin change. CNAME flattening cache not invalidating despite TTL expiry."),
    ("geo-routing sending VPN users to incorrect regional endpoint", "Corporate VPN users in Asia being routed to US data center based on VPN egress IP rather than actual location."),
    ("DNSSEC validation failures for records signed with expiring ZSK", "Zone signing key approaching rotation deadline. Validation warnings appearing for resolvers with strict DNSSEC enforcement."),
    ("split-horizon DNS not separating internal from external resolution", "Internal service names leaking to public DNS responses. Security team flagged as information disclosure vulnerability."),
]

PERF_SYMPTOMS = [
    ("P99 latency regression after configuration deployment last Tuesday", "No code changes made. Configuration rollout introduced suboptimal routing path. Response times 3x higher for US-West region users."),
    ("cache hit ratio collapsed from 82% to 34% after origin failover event", "Failover event last week caused cache invalidation across all PoPs. Cache rebuild taking longer than expected due to origin rate limiting."),
    ("TLS handshake overhead adding 65ms for clients negotiating older ciphers", "10% of their user base on older devices negotiating TLS 1.2 with RSA key exchange instead of ECDHE. Noticeably slower first-byte time."),
    ("edge function cold start latency exceeding 800ms SLA threshold", "Serverless edge compute functions taking 500-800ms on first invocation. Impacts user experience for geo-distributed application."),
    ("connection keep-alive timeout mismatch causing premature resets", "Origin keep-alive set to 60s, proxy at 90s. Proxy attempting to reuse connections that origin already closed. Intermittent 502 errors."),
    ("response compression not activating for application/json content type", "API responses delivered uncompressed (avg 45KB). Compression would reduce to ~8KB. Bandwidth costs elevated, mobile users impacted."),
]

SYMPTOM_MAP = {
    "bot-defense": BOT_SYMPTOMS,
    "waf": WAF_SYMPTOMS,
    "capacity": CAPACITY_SYMPTOMS,
    "load-balancer": LB_SYMPTOMS,
    "dns": DNS_SYMPTOMS,
    "performance": PERF_SYMPTOMS,
}


def generate_ticket(account, signal, idx, is_open=True):
    """Generate a unique, telemetry-correlated ticket."""
    seed = hash_val(account + signal + str(idx))
    symptoms = SYMPTOM_MAP[signal]
    symptom_title, symptom_detail = symptoms[seed % len(symptoms)]
    reporter = REPORTERS[seed % len(REPORTERS)]
    industry = INDUSTRIES.get(account, "technology")

    if is_open:
        summary = f"{account} - {symptom_title}"
        description = (
            f"Reported by: {reporter}\n"
            f"Customer: {account} ({industry})\n"
            f"Category: {signal.replace('-', ' ').title()}\n\n"
            f"Issue Description:\n{symptom_detail}\n\n"
            f"Business Impact: "
            f"{'Revenue-impacting - customer escalating to executive sponsor.' if seed % 3 == 0 else 'Operational disruption affecting production workloads.'}"
            f"{' Compliance deadline approaching.' if industry in ('financial services', 'healthcare', 'pharmaceuticals') else ''}\n\n"
            f"Customer Priority: {'Critical - production down' if seed % 4 == 0 else 'High - degraded service' if seed % 3 == 0 else 'Medium - workaround available'}"
        )
    else:
        resolution_days = (seed % 12) + 2
        summary = f"{account} - [RESOLVED] {symptom_title}"
        description = (
            f"Reported by: {reporter}\n"
            f"Customer: {account} ({industry})\n"
            f"Category: {signal.replace('-', ' ').title()}\n\n"
            f"Original Issue:\n{symptom_detail}\n\n"
            f"Resolution (resolved in {resolution_days} days):\n"
            f"{'Root cause identified and configuration corrected. Deployed fix to all affected PoPs.' if seed % 4 == 0 else ''}"
            f"{'Tuned detection thresholds based on customer traffic baseline. Monitoring for 7 days confirmed no recurrence.' if seed % 4 == 1 else ''}"
            f"{'Escalated to engineering. Hotfix released in platform update. Customer verified resolution.' if seed % 4 == 2 else ''}"
            f"{'Applied workaround with custom rule. Permanent fix included in next quarterly release.' if seed % 4 == 3 else ''}\n\n"
            f"Post-resolution: No recurrence observed. Customer confirmed satisfaction."
        )

    labels = [signal, industry.replace(" ", "-")]
    return summary[:255], description, labels


# ============================================================
# JIRA API FUNCTIONS
# ============================================================
def create_issue(summary, description, labels):
    """Create a Jira issue."""
    payload = {
        "fields": {
            "project": {"key": PROJECT_KEY},
            "summary": summary,
            "description": {
                "type": "doc", "version": 1,
                "content": [{"type": "paragraph", "content": [{"type": "text", "text": description}]}]
            },
            "issuetype": {"name": "Task"},
            "labels": labels,
        }
    }
    resp = requests.post(f"{JIRA_URL}/rest/api/3/issue", headers=HEADERS, auth=AUTH, json=payload)
    if resp.status_code == 400 and "labels" in resp.text.lower():
        del payload["fields"]["labels"]
        resp = requests.post(f"{JIRA_URL}/rest/api/3/issue", headers=HEADERS, auth=AUTH, json=payload)
    if resp.status_code in (200, 201):
        key = resp.json().get("key")
        print(f"  Created: {key} - {summary[:55]}...")
        return key
    else:
        print(f"  ERROR ({resp.status_code}): {resp.text[:150]}")
        return None


def transition_to_done(issue_key):
    """Transition issue to Done status."""
    resp = requests.get(f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions", headers=HEADERS, auth=AUTH)
    if resp.status_code != 200:
        return False
    for t in resp.json().get("transitions", []):
        if any(x in t["name"].lower() for x in ["done", "closed", "resolved", "complete"]):
            resp = requests.post(
                f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions",
                headers=HEADERS, auth=AUTH,
                json={"transition": {"id": t["id"]}}
            )
            if resp.status_code == 204:
                print(f"    Closed: {issue_key}")
                return True
    return False


# ============================================================
# MAIN
# ============================================================
def main():
    global API_TOKEN, AUTH
    API_TOKEN = get_api_token()
    AUTH = (ASSIGNEE_EMAIL, API_TOKEN)

    if not API_TOKEN:
        print("ERROR: No Jira API token found. Set JIRA_API_TOKEN env var or /tmp/jira_token.txt")
        return

    # Verify connection
    resp = requests.get(f"{JIRA_URL}/rest/api/3/myself", headers=HEADERS, auth=AUTH)
    if resp.status_code != 200:
        print(f"ERROR: Auth failed ({resp.status_code})")
        return
    print(f"Authenticated as: {resp.json().get('displayName')}")
    print(f"Project: {PROJECT_KEY} | URL: {JIRA_URL}\n")

    # Create OPEN tickets (recent 2 months telemetry)
    print("=" * 60)
    print("Creating OPEN tickets (recent 2-month telemetry signals)")
    print("=" * 60)
    open_accounts = list(RECENT_SIGNALS.keys())[:25]
    open_keys = []
    for i, account in enumerate(open_accounts):
        signal = RECENT_SIGNALS[account]
        summary, description, labels = generate_ticket(account, signal, i, is_open=True)
        key = create_issue(summary, description, labels)
        if key:
            open_keys.append(key)
        time.sleep(0.3)

    print(f"\n-> {len(open_keys)} OPEN tickets created\n")

    # Create CLOSED tickets (historical 4-month telemetry)
    print("=" * 60)
    print("Creating CLOSED tickets (historical 4-month signals)")
    print("=" * 60)
    closed_accounts = list(HISTORICAL_SIGNALS.keys())[:30]
    closed_keys = []
    for i, account in enumerate(closed_accounts):
        signal = HISTORICAL_SIGNALS[account]
        summary, description, labels = generate_ticket(account, signal, i + 50, is_open=False)
        key = create_issue(summary, description, labels)
        if key:
            closed_keys.append(key)
        time.sleep(0.3)

    print(f"\n-> {len(closed_keys)} tickets created, transitioning to Done...\n")
    for key in closed_keys:
        transition_to_done(key)
        time.sleep(0.2)

    # Summary
    print(f"\n{'=' * 60}")
    print(f"COMPLETE: {len(open_keys)} open + {len(closed_keys)} closed = {len(open_keys) + len(closed_keys)} total")
    print("=" * 60)


if __name__ == "__main__":
    main()
