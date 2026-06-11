"""
Generate Zoom Call Transcripts for F5 HOL
==========================================
Creates WEBVTT-format transcript files for ~25% of accounts.
Transcripts include business insights about fiscal planning,
layoffs, tech changes, product feedback, and competitive mentions.

Usage:
    python scripts/generate_zoom_transcripts.py

Output: data/zoom_transcripts/{Customer_Name}_{YYYY-MM-DD}.txt
"""

import os
import hashlib
from datetime import datetime, timedelta
import random

# Output directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_DIR, "data", "zoom_transcripts")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Account data - 25% of ~200 = ~50 accounts
# Format: (account_id, company_name, industry, health_score, city, state, region)
ACCOUNTS = [
    ("ACC000002", "Amazon", "Technology", "At Risk", "Seattle", "WA", "West"),
    ("ACC000009", "Alphabet", "Technology", "At Risk", "Mountain View", "CA", "West"),
    ("ACC000018", "JPMorgan Chase", "Financial Services", "Excellent", "New York", "NY", "East"),
    ("ACC000024", "Home Depot", "Retail", "At Risk", "Atlanta", "GA", "East"),
    ("ACC000029", "AT&T", "Telecommunications", "Good", "Dallas", "TX", "Central"),
    ("ACC000034", "Citigroup", "Financial Services", "Good", "New York", "NY", "East"),
    ("ACC000036", "Tesla", "Automotive", "Good", "Austin", "TX", "Central"),
    ("ACC000041", "Johnson & Johnson", "Healthcare", "At Risk", "New Brunswick", "NJ", "East"),
    ("ACC000044", "T-Mobile", "Telecommunications", "Excellent", "Bellevue", "WA", "West"),
    ("ACC000046", "Boeing", "Industrial", "Excellent", "Arlington", "VA", "East"),
    ("ACC000055", "Intel", "Technology", "At Risk", "Santa Clara", "CA", "West"),
    ("ACC000057", "Nvidia", "Technology", "At Risk", "Santa Clara", "CA", "West"),
    ("ACC000060", "IBM", "Technology", "Good", "Armonk", "IL", "Central"),
    ("ACC000064", "Pfizer", "Healthcare", "Critical", "New York", "NY", "East"),
    ("ACC000067", "Cisco Systems", "Technology", "Excellent", "San Jose", "CA", "West"),
    ("ACC000071", "United Airlines", "Transportation", "Critical", "Chicago", "IL", "Central"),
    ("ACC000074", "Nike", "Consumer Goods", "Critical", "Beaverton", "OR", "West"),
    ("ACC000075", "Goldman Sachs", "Financial Services", "Critical", "New York", "NY", "East"),
    ("ACC000080", "Best Buy", "Retail", "Excellent", "Richfield", "MN", "Central"),
    ("ACC000085", "Capital One", "Financial Services", "Good", "McLean", "VA", "East"),
    ("ACC000086", "Broadcom", "Technology", "Excellent", "San Jose", "CA", "West"),
    ("ACC000089", "Arrow Electronics", "Distribution", "Critical", "Centennial", "CO", "Mountain"),
    ("ACC000092", "Honeywell", "Industrial", "Excellent", "Charlotte", "NC", "East"),
    ("ACC000094", "Salesforce", "Technology", "Excellent", "San Francisco", "CA", "West"),
    ("ACC000097", "Micron Technology", "Technology", "Critical", "Boise", "ID", "Mountain"),
    ("ACC000098", "PayPal", "Technology", "Healthy", "San Jose", "CA", "West"),
    ("ACC000105", "Fidelity", "Financial Services", "At Risk", "Boston", "MA", "East"),
    ("ACC000109", "Mastercard", "Financial Services", "Excellent", "Purchase", "NY", "East"),
    ("ACC000114", "CDW", "Distribution", "Critical", "Vernon Hills", "IL", "Central"),
    ("ACC000119", "Truist Financial", "Financial Services", "At Risk", "Charlotte", "NC", "East"),
    ("ACC000121", "Block", "Technology", "Critical", "San Francisco", "CA", "West"),
    ("ACC000125", "Adobe", "Technology", "Good", "San Jose", "CA", "West"),
    ("ACC000130", "Fiserv", "Financial Services", "Excellent", "Milwaukee", "WI", "Central"),
    ("ACC000131", "Texas Instruments", "Technology", "Healthy", "Dallas", "TX", "Central"),
    ("ACC000132", "Dominion Energy", "Energy", "Critical", "Richmond", "VA", "East"),
    ("ACC000137", "Intuit", "Technology", "Critical", "Mountain View", "CA", "West"),
    ("ACC000140", "Nordstrom", "Retail", "At Risk", "Seattle", "WA", "West"),
    ("ACC000149", "Airbnb", "Technology", "Healthy", "San Francisco", "CA", "West"),
    ("ACC000151", "Palo Alto Networks", "Technology", "Critical", "Santa Clara", "CA", "West"),
    ("ACC000155", "Fortinet", "Technology", "Excellent", "Sunnyvale", "CA", "West"),
    ("ACC000159", "CrowdStrike", "Technology", "Healthy", "Austin", "CA", "West"),
    ("ACC000161", "Cloudflare", "Technology", "Healthy", "San Francisco", "CA", "West"),
    ("ACC000167", "Costco", "Retail", "Good", "Issaquah", "WA", "West"),
    ("ACC000192", "Deere & Company", "Industrial", "Good", "Moline", "IL", "Central"),
    ("ACC000196", "Marathon Petroleum", "Energy", "At Risk", "Findlay", "OH", "Central"),
    ("ACC000198", "Abbott Laboratories", "Healthcare", "Good", "Abbott Park", "IL", "Central"),
    ("ACC000207", "Bank of America", "Financial Services", "Good", "Charlotte", "NC", "East"),
    ("ACC000003", "ExxonMobil", "Energy", "Good", "Irving", "TX", "Central"),
    ("ACC000005", "UnitedHealth Group", "Healthcare", "At Risk", "Minnetonka", "MN", "Central"),
    ("ACC000013", "Microsoft", "Technology", "Good", "Redmond", "VA", "East"),
]

# F5 sales team members (by region)
TEAMS = {
    "West": [
        {"ae": "Sarah Mitchell", "se": "Kevin Nakamura", "sdr": "Ashley Pham"},
        {"ae": "Robert Chen", "se": "Priya Sharma", "sdr": "Tyler Brooks"},
        {"ae": "Jessica Torres", "se": "Daniel Kim", "sdr": "Morgan Lee"},
    ],
    "Mountain": [
        {"ae": "Michael Park", "se": "Rachel Gonzalez", "sdr": "Brandon Scott"},
    ],
    "Central": [
        {"ae": "Amanda Nguyen", "se": "Eric Johnson", "sdr": "Samantha Williams"},
        {"ae": "David Morrison", "se": "Nicole Martinez", "sdr": "Jake Wilson"},
        {"ae": "Lauren Kim", "se": "Chris Anderson", "sdr": "Megan Harris"},
    ],
    "East": [
        {"ae": "James O'Brien", "se": "Aisha Washington", "sdr": "Ryan Phillips"},
        {"ae": "Rachel Patel", "se": "Marcus Thompson", "sdr": "Lindsay Clark"},
        {"ae": "Christopher Davis", "se": "Emily Rodriguez", "sdr": "Justin Taylor"},
    ],
}

CUSTOMER_TITLES = [
    "VP of Infrastructure", "CISO", "Director of Network Security",
    "Head of Cloud Architecture", "VP of Engineering", "IT Director",
    "Director of Platform Engineering", "CTO", "SVP of Technology",
]

# Conversation templates by theme
FISCAL_PLANNING_TOPICS = [
    "We're in Q4 budget planning right now, and the board wants a 15% reduction across all vendor spend. We need to understand our total F5 commitment before renewals hit.",
    "Our fiscal year starts in April, and we've been asked to consolidate security vendors. F5 is on the short list to keep, but we need to see the full value stack.",
    "We just got approval for a major security initiative in FY26. There's budget earmarked for WAF and bot protection modernization. Your timing is actually perfect.",
    "Finance froze all new capital expenditure until next quarter. We can't commit to any hardware refresh right now, but SaaS models might still fit our opex budget.",
    "The CFO is pushing for multi-year agreements across all vendors to lock in pricing. What kind of terms can you offer on a 3-year for Distributed Cloud?",
]

LAYOFF_RESTRUCTURING_TOPICS = [
    "We went through a 20% reduction in IT staff last month. The team running our BIG-IP infrastructure was cut in half, so we need to discuss managed services options.",
    "There's a reorganization happening. The security team is being merged with infrastructure under a new CTO. All vendor relationships are being reviewed.",
    "We lost our lead network engineer who managed all the F5 config. Can you connect us with professional services to bridge the gap?",
    "After the layoffs, we're moving to a platform engineering model. Manual infrastructure management is out. Everything needs to be API-driven and self-service.",
    "Our DevOps team was reduced but workload didn't change. We need to automate more. NGINX Ingress Controller could help reduce the operational burden.",
]

TECH_CHANGE_TOPICS = [
    "We're migrating 70% of workloads to AWS and Azure over the next 18 months. The on-prem BIG-IP strategy needs to evolve. What does F5 offer for multi-cloud?",
    "We're adopting a service mesh architecture with Istio. How does NGINX or F5 Distributed Cloud fit into that? We don't want overlapping tools.",
    "The team is evaluating a move from hardware ADCs to cloud-native load balancing. AWS ALB is 'good enough' for most use cases. Why should we keep F5?",
    "We're building a zero-trust architecture. Every service needs mTLS and identity-aware access. How does F5 support that model?",
    "Our API gateway strategy is evolving. We're using Kong for some things, Apigee for others. The F5 API security story is interesting but needs to integrate.",
    "Kubernetes adoption hit 80% of production workloads. We need ingress controllers that scale. NGINX vs Envoy vs Traefik - help me understand the tradeoffs.",
]

PRODUCT_FEEDBACK_POSITIVE = [
    "The BIG-IP LTM has been rock solid for us. Zero unplanned downtime in 3 years. When it works, it really works.",
    "Distributed Cloud WAF caught a zero-day exploitation attempt last month before our SOC even saw it. That justified the entire investment.",
    "NGINX Plus performance has been incredible. We went from 50ms latency on our old gateway to sub-5ms. The engineering team loves it.",
    "The bot defense product has saved us millions in fraud prevention. Our e-commerce team considers it indispensable.",
    "We deployed XC App Connect across three clouds in two weeks. The multi-cloud networking story is genuinely differentiated.",
]

PRODUCT_FEEDBACK_NEGATIVE = [
    "Honestly, the BIG-IP management interface feels like it's from 2010. Terraform support is incomplete and the API is inconsistent. My team hates it.",
    "We had three unplanned outages on the Distributed Cloud platform in the past quarter. For a security product, that's unacceptable.",
    "The NGINX licensing model is confusing. We can't figure out what we're paying for versus what's open source versus what needs Plus.",
    "Support response times have gotten worse. Our last P1 took 6 hours for initial response. That's not enterprise-grade.",
    "The upgrade path from BIG-IP v15 to v17 broke our iRules. Three weeks of regression testing we didn't plan for. Not happy.",
    "Distributed Cloud onboarding took 4 months. Your professional services team was overwhelmed. We expected better from a $200K deal.",
]

COMPETITIVE_MENTIONS = [
    "Cloudflare Workers has been getting a lot of internal attention. Their edge compute + security bundle is compelling at the price point.",
    "Akamai sent us a proposal that undercuts your pricing by 40%. I need a reason to justify staying with F5 beyond just incumbency.",
    "AWS Shield Advanced plus ALB gives us most of what XC DDoS and WAF do, and it's already in our cloud bill. Why should we add another vendor?",
    "Imperva acquired a bot defense company and their integrated story is looking strong. How does F5 Bot Defense compare?",
    "We're evaluating Fastly for CDN and edge security. Their developer experience is significantly better than what we've seen from F5.",
    "Kong Gateway handles our API management today. Adding F5 API Security on top feels like vendor sprawl. Convince me otherwise.",
]


def hash_val(s):
    return int(hashlib.md5(s.encode()).hexdigest(), 16)


def get_team_for_account(region, account_id):
    teams = TEAMS.get(region, TEAMS["East"])
    idx = hash_val(account_id) % len(teams)
    return teams[idx]


def pick_from_list(lst, seed):
    return lst[hash_val(seed) % len(lst)]


def format_timestamp(seconds):
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    ms = (hash_val(str(seconds)) % 999)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def generate_conversation(account, call_num):
    account_id, company, industry, health, city, state, region = account
    seed = account_id + str(call_num)
    h = hash_val(seed)

    team = get_team_for_account(region, account_id)
    ae = team["ae"]
    se = team["se"]
    customer_title = pick_from_list(CUSTOMER_TITLES, seed + "title")
    customer_name = f"{pick_from_list(['John', 'Maria', 'David', 'Sarah', 'Mike', 'Jennifer', 'Alex', 'Karen', 'Tom', 'Lisa'], seed + 'fn')} {pick_from_list(['Williams', 'Garcia', 'Anderson', 'Lee', 'Jackson', 'Murphy', 'Patel', 'Zhang', 'Brown', 'Miller'], seed + 'ln')}"

    # Pick conversation themes based on health score and hash
    lines = []
    current_time = 30  # Start at 30 seconds

    # Opening
    lines.append((current_time, ae, f"Thanks for joining, {customer_name}. Good to connect with you and the {company} team."))
    current_time += 8

    lines.append((current_time, customer_name, f"Good to see you both. {ae}, {se} - thanks for making the time."))
    current_time += 6

    lines.append((current_time, ae, f"Of course. We wanted to check in on how things are going and see where we can help. How's everything on your end?"))
    current_time += 12

    # Main conversation body - pick 2-3 themes
    themes_used = []

    # Theme 1: Always include based on health
    if health in ("Critical", "At Risk"):
        # Negative feedback or competitive threat
        if h % 2 == 0:
            topic = pick_from_list(PRODUCT_FEEDBACK_NEGATIVE, seed + "neg")
            themes_used.append("product_feedback_negative")
        else:
            topic = pick_from_list(COMPETITIVE_MENTIONS, seed + "comp")
            themes_used.append("competitive")
        lines.append((current_time, customer_name, topic))
        current_time += 20

        lines.append((current_time, ae, "I appreciate you being direct about that. Let me address this head-on."))
        current_time += 8

        lines.append((current_time, se, "From a technical perspective, I want to make sure we're looking at the full picture here. Can you walk me through the specific issues your team is seeing?"))
        current_time += 15

        lines.append((current_time, customer_name, "Sure. The main pain point is " + pick_from_list([
            "operational complexity. Our team is stretched thin and managing the platform takes too much effort.",
            "reliability. We've had too many incidents that impacted production workloads.",
            "cost per transaction. When we benchmark against cloud-native alternatives, the economics don't always work.",
            "lack of integration with our CI/CD pipeline. Everything else is GitOps but F5 config is still manual.",
            "feature parity. Competitors are shipping faster and their UX is more modern.",
        ], seed + "pain")))
        current_time += 18

    elif health == "Excellent":
        topic = pick_from_list(PRODUCT_FEEDBACK_POSITIVE, seed + "pos")
        themes_used.append("product_feedback_positive")
        lines.append((current_time, customer_name, topic))
        current_time += 15

        lines.append((current_time, ae, "That's great to hear! We love when the technology delivers real value."))
        current_time += 8

        lines.append((current_time, customer_name, "Absolutely. In fact, that success is why we're looking at expanding. " + pick_from_list([
            "The security team wants to extend WAF coverage to our new microservices platform.",
            "We're interested in the AI Gateway product for protecting our internal LLM deployments.",
            "Bot Defense has proven itself on our main site. Now we want it across all customer-facing properties.",
            "The multi-cloud networking piece is interesting. We're adding GCP and need consistent policy.",
            "NGINX Ingress is working great in staging. We want to roll it out to production clusters.",
        ], seed + "expand")))
        current_time += 20

    else:
        # Neutral/Good - tech change or fiscal planning
        topic = pick_from_list(TECH_CHANGE_TOPICS, seed + "tech")
        themes_used.append("tech_changes")
        lines.append((current_time, customer_name, topic))
        current_time += 18

        lines.append((current_time, se, "Great question. Let me share what we're seeing with customers in similar situations."))
        current_time += 10

        lines.append((current_time, se, pick_from_list([
            "Distributed Cloud is specifically designed for multi-cloud environments. It gives you consistent policy enforcement across AWS, Azure, and GCP without managing separate WAF instances.",
            "For Kubernetes workloads, NGINX Ingress Controller is the most deployed solution in production. It handles north-south traffic while your service mesh handles east-west.",
            "The BIG-IP Next platform is our answer to the modernization question. Full API-driven management, Terraform native, and runs anywhere - cloud, edge, or on-prem.",
            "XC App Connect creates encrypted tunnels between your cloud environments with a single control plane. No need to manage VPN gateways or transit architectures.",
            "For zero trust, our Access Policy Manager integrates with your IdP and enforces per-request authentication. Combined with XC, you get identity-aware routing.",
        ], seed + "answer")))
        current_time += 22

    # Theme 2: Fiscal/business context
    if h % 3 != 0:  # ~66% of calls include fiscal context
        current_time += 5
        fiscal_topic = pick_from_list(FISCAL_PLANNING_TOPICS, seed + "fiscal")
        lines.append((current_time, customer_name, fiscal_topic))
        current_time += 15
        themes_used.append("fiscal_planning")

        lines.append((current_time, ae, pick_from_list([
            "We can definitely work with you on that. Let me put together a total value summary showing your current investment and ROI across all F5 products.",
            "Multi-year commitments are something we actively encourage. I can get our deal desk to model out 2-year and 3-year options with the associated discounts.",
            "I understand the budget pressure. One option is to transition from capex hardware to opex SaaS models. That often fits better in today's financial planning.",
            "Let me connect you with our finance team. We have some creative options around payment terms and ramp structures that might help with the timing.",
            "We hear this a lot right now. The good news is F5 consolidates what would otherwise be 3-4 separate vendor contracts for ADC, WAF, bot, and API security.",
        ], seed + "ae_fiscal")))
        current_time += 18

    # Theme 3: Layoffs or restructuring (for some accounts)
    if health in ("At Risk", "Critical") and h % 4 == 0:
        current_time += 5
        layoff_topic = pick_from_list(LAYOFF_RESTRUCTURING_TOPICS, seed + "layoff")
        lines.append((current_time, customer_name, layoff_topic))
        current_time += 15
        themes_used.append("restructuring")

        lines.append((current_time, se, pick_from_list([
            "We can help with that transition. Our managed services offering handles the day-to-day operations so your remaining team can focus on strategic work.",
            "Automation is where we're investing heavily. BIG-IP Next and NGINX One both support full GitOps workflows. Less manual, fewer people needed.",
            "Professional Services can bridge that gap immediately. We have certified engineers who can manage your environment while you rebuild the team.",
            "A lot of customers in your situation are moving to Distributed Cloud precisely because it reduces operational overhead. No boxes to patch, no hardware to lifecycle.",
        ], seed + "se_layoff")))
        current_time += 18

    # Closing / Next steps
    current_time += 10
    lines.append((current_time, ae, "This has been really productive. Let me summarize the action items."))
    current_time += 8

    if health == "Excellent":
        lines.append((current_time, ae, pick_from_list([
            f"I'll send over the expansion proposal by end of week. {se} will schedule a technical deep-dive with your architecture team.",
            f"Let's get a POC scheduled for the AI Gateway. {se}, can you coordinate with {customer_name}'s team on environment requirements?",
            f"I'll loop in our executive sponsor for a joint roadmap session. We want to make sure {company} has early access to what's coming.",
        ], seed + "close_pos")))
    elif health in ("At Risk", "Critical"):
        lines.append((current_time, ae, pick_from_list([
            f"First priority is getting your support experience fixed. I'm escalating to our VP of Customer Success today. {se} will set up weekly technical check-ins.",
            f"I hear the frustration. Let me come back with a concrete remediation plan within 48 hours. We're not going to lose {company} over something we can fix.",
            f"Let's schedule a call with our engineering leadership next week. I want them to hear directly from you what needs to change.",
        ], seed + "close_neg")))
    else:
        lines.append((current_time, ae, pick_from_list([
            f"I'll send over the comparison document and pricing options. {se} can set up a lab environment if you want hands-on time with the platform.",
            f"Good discussion. I'll get the multi-year pricing from deal desk and {se} will put together a technical architecture for the migration path.",
            f"Let's reconvene in two weeks after you've had a chance to review the proposal. We'll bring our architect to address the integration questions.",
        ], seed + "close_neutral")))
    current_time += 15

    lines.append((current_time, customer_name, pick_from_list([
        "Sounds good. Thanks both for the time today.",
        "Appreciate it. Let's keep the momentum going.",
        "Thanks. We'll review on our end and circle back.",
        "Good. Send me the follow-up and we'll get it on the calendar.",
    ], seed + "bye")))
    current_time += 5

    lines.append((current_time, ae, f"Thank you, {customer_name}. Talk soon."))

    return lines, ae, se, customer_name, customer_title, current_time


def build_webvtt(lines):
    """Convert conversation lines to WEBVTT format."""
    output = "WEBVTT\n\n"
    for i, (seconds, speaker, text) in enumerate(lines):
        start = format_timestamp(seconds)
        # End timestamp is start of next line or +5 seconds
        if i + 1 < len(lines):
            end_sec = lines[i + 1][0]
        else:
            end_sec = seconds + 5
        end = format_timestamp(end_sec)

        output += f"{start} --> {end}\n"
        output += f"{speaker}: {text}\n\n"

    return output


def main():
    transcript_count = 0

    for account in ACCOUNTS:
        account_id, company, industry, health, city, state, region = account
        h = hash_val(account_id)

        # 1-2 transcripts per account
        num_calls = 1 + (h % 2)

        for call_num in range(1, num_calls + 1):
            lines, ae, se, customer_name, customer_title, duration = generate_conversation(account, call_num)
            webvtt = build_webvtt(lines)

            # Generate call date (within last 6 months)
            days_ago = (h + call_num * 47) % 180 + 1
            call_date = datetime.now() - timedelta(days=days_ago)

            # File naming: Customer_Name_YYYY-MM-DD.txt
            safe_name = company.replace(" ", "_").replace("&", "and").replace("'", "").replace(".", "")
            filename = f"{safe_name}_{call_date.strftime('%Y-%m-%d')}.txt"
            filepath = os.path.join(OUTPUT_DIR, filename)

            with open(filepath, "w") as f:
                f.write(webvtt)

            transcript_count += 1

    print(f"Generated {transcript_count} transcript files in {OUTPUT_DIR}")
    print(f"Accounts covered: {len(ACCOUNTS)}")


if __name__ == "__main__":
    main()
