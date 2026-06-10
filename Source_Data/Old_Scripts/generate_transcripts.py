"""
Generate Gong Call Transcripts
==============================
Creates text transcript files for Fortune 500 customers with varied sentiment
based on account health scores.

Usage:
    python generate_transcripts.py
"""

import os
import hashlib
from datetime import datetime, timedelta
import random

output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "gong_transcripts")
os.makedirs(output_dir, exist_ok=True)

# 80% coverage - 134 Fortune 500 accounts
accounts = [
    ("ACC000096", "3M", "Industrial", "At Risk", "St. Paul", "MN", 92000),
    ("ACC000029", "AT&T", "Telecommunications", "Good", "Dallas", "TX", 160700),
    ("ACC000063", "AbbVie", "Healthcare", "Healthy", "North Chicago", "IL", 50000),
    ("ACC000053", "Accenture", "Professional Services", "Good", "New York", "NY", 738000),
    ("ACC000125", "Adobe", "Technology", "Good", "San Jose", "CA", 30000),
    ("ACC000149", "Airbnb", "Technology", "Healthy", "San Francisco", "CA", 6900),
    ("ACC000065", "Allstate", "Financial Services", "Excellent", "Northbrook", "IL", 54500),
    ("ACC000009", "Alphabet", "Technology", "At Risk", "Mountain View", "CA", 190000),
    ("ACC000002", "Amazon", "Technology", "At Risk", "Seattle", "WA", 1540000),
    ("ACC000072", "American Airlines", "Transportation", "Good", "Fort Worth", "TX", 128900),
    ("ACC000061", "American Express", "Financial Services", "Good", "New York", "NY", 77300),
    ("ACC000010", "AmerisourceBergen", "Healthcare", "Healthy", "Conshohocken", "PA", 44000),
    ("ACC000144", "Aon", "Financial Services", "Healthy", "Dublin", "OH", 50000),
    ("ACC000089", "Arrow Electronics", "Distribution", "Critical", "Centennial", "CO", 22500),
    ("ACC000153", "Autodesk", "Technology", "Excellent", "San Francisco", "CA", 14100),
    ("ACC000080", "Best Buy", "Retail", "Excellent", "Richfield", "MN", 90000),
    ("ACC000126", "BlackRock", "Financial Services", "Healthy", "New York", "NY", 21000),
    ("ACC000121", "Block", "Technology", "Critical", "San Francisco", "CA", 14000),
    ("ACC000046", "Boeing", "Industrial", "Excellent", "Arlington", "VA", 156000),
    ("ACC000086", "Broadcom", "Technology", "Excellent", "San Jose", "CA", 20000),
    ("ACC000114", "CDW", "Distribution", "Critical", "Vernon Hills", "IL", 15200),
    ("ACC000142", "CSX", "Transportation", "At Risk", "Jacksonville", "FL", 22000),
    ("ACC000007", "CVS Health", "Healthcare", "Healthy", "Woonsocket", "RI", 300000),
    ("ACC000085", "Capital One", "Financial Services", "Good", "McLean", "VA", 52500),
    ("ACC000014", "Cardinal Health", "Healthcare", "Critical", "Dublin", "OH", 48000),
    ("ACC000052", "Caterpillar", "Industrial", "Good", "Irving", "TX", 109100),
    ("ACC000025", "Centene", "Healthcare", "Good", "St. Louis", "MO", 74300),
    ("ACC000123", "Charles Schwab", "Financial Services", "Good", "Westlake", "TX", 36000),
    ("ACC000068", "Charter Communications", "Telecommunications", "At Risk", "Stamford", "CT", 101000),
    ("ACC000012", "Chevron", "Energy", "Good", "San Ramon", "CA", 43846),
    ("ACC000067", "Cisco Systems", "Technology", "Excellent", "San Jose", "CA", 90400),
    ("ACC000034", "Citigroup", "Financial Services", "Good", "New York", "NY", 240000),
    ("ACC000161", "Cloudflare", "Technology", "Healthy", "San Francisco", "CA", 4000),
    ("ACC000077", "Coca-Cola", "Consumer Goods", "Healthy", "Atlanta", "GA", 82500),
    ("ACC000128", "Cognizant", "Professional Services", "Good", "Teaneck", "NJ", 351500),
    ("ACC000129", "Colgate-Palmolive", "Consumer Goods", "At Risk", "New York", "NY", 33800),
    ("ACC000030", "Comcast", "Telecommunications", "Good", "Philadelphia", "PA", 186000),
    ("ACC000045", "ConocoPhillips", "Energy", "Excellent", "Houston", "TX", 10500),
    ("ACC000159", "CrowdStrike", "Technology", "Healthy", "Austin", "TX", 8500),
    ("ACC000160", "Datadog", "Technology", "At Risk", "New York", "NY", 5500),
    ("ACC000033", "Dell Technologies", "Technology", "Healthy", "Round Rock", "TX", 133000),
    ("ACC000066", "Delta Air Lines", "Transportation", "At Risk", "Atlanta", "GA", 100000),
    ("ACC000136", "Discover Financial", "Financial Services", "Excellent", "Riverwoods", "IL", 21400),
    ("ACC000132", "Dominion Energy", "Energy", "Critical", "Richmond", "VA", 17200),
    ("ACC000102", "Duke Energy", "Energy", "Healthy", "Charlotte", "NC", 27600),
    ("ACC000022", "Elevance Health", "Healthcare", "Good", "Indianapolis", "IN", 100000),
    ("ACC000154", "Equifax", "Financial Services", "Critical", "Atlanta", "GA", 15000),
    ("ACC000134", "Estee Lauder", "Consumer Goods", "Critical", "New York", "NY", 62000),
    ("ACC000003", "ExxonMobil", "Energy", "Good", "Irving", "TX", 62000),
    ("ACC000038", "FedEx", "Transportation", "Critical", "Memphis", "TN", 518000),
    ("ACC000105", "Fidelity", "Financial Services", "At Risk", "Boston", "MA", 74000),
    ("ACC000130", "Fiserv", "Financial Services", "Excellent", "Milwaukee", "WI", 40000),
    ("ACC000020", "Ford Motor", "Automotive", "Critical", "Dearborn", "MI", 177000),
    ("ACC000155", "Fortinet", "Technology", "Excellent", "Sunnyvale", "CA", 14200),
    ("ACC000139", "Gap", "Retail", "Excellent", "San Francisco", "CA", 95000),
    ("ACC000081", "General Dynamics", "Industrial", "Healthy", "Reston", "VA", 112000),
    ("ACC000047", "General Electric", "Industrial", "At Risk", "Boston", "MA", 125000),
    ("ACC000124", "General Mills", "Consumer Goods", "At Risk", "Minneapolis", "MN", 35000),
    ("ACC000023", "General Motors", "Automotive", "Healthy", "Detroit", "MI", 167000),
    ("ACC000075", "Goldman Sachs", "Financial Services", "Critical", "New York", "NY", 49100),
    ("ACC000054", "HCA Healthcare", "Healthcare", "Critical", "Nashville", "TN", 293000),
    ("ACC000069", "HP Inc", "Technology", "Healthy", "Palo Alto", "CA", 58000),
    ("ACC000147", "Hilton", "Hospitality", "Good", "McLean", "VA", 159000),
    ("ACC000024", "Home Depot", "Retail", "At Risk", "Atlanta", "GA", 475000),
    ("ACC000092", "Honeywell", "Industrial", "Excellent", "Charlotte", "NC", 110000),
    ("ACC000031", "Humana", "Healthcare", "Excellent", "Louisville", "KY", 67000),
    ("ACC000060", "IBM", "Technology", "Good", "Armonk", "NY", 288300),
    ("ACC000055", "Intel", "Technology", "At Risk", "Santa Clara", "CA", 131900),
    ("ACC000137", "Intuit", "Technology", "Critical", "Mountain View", "CA", 18200),
    ("ACC000018", "JPMorgan Chase", "Financial Services", "Excellent", "New York", "NY", 310000),
    ("ACC000041", "Johnson & Johnson", "Healthcare", "At Risk", "New Brunswick", "NJ", 152700),
    ("ACC000133", "Kellogg", "Consumer Goods", "Critical", "Battle Creek", "MI", 30000),
    ("ACC000127", "Kimberly-Clark", "Consumer Goods", "Good", "Irving", "TX", 43000),
    ("ACC000135", "Leidos", "Government Services", "At Risk", "Reston", "VA", 47000),
    ("ACC000049", "Lockheed Martin", "Industrial", "Critical", "Bethesda", "MD", 116000),
    ("ACC000040", "Lowes", "Retail", "At Risk", "Mooresville", "NC", 300000),
    ("ACC000116", "Marriott International", "Hospitality", "Good", "Bethesda", "MD", 141000),
    ("ACC000109", "Mastercard", "Financial Services", "Excellent", "Purchase", "NY", 33400),
    ("ACC000062", "Merck", "Healthcare", "Excellent", "Rahway", "NJ", 70000),
    ("ACC000051", "MetLife", "Financial Services", "Healthy", "New York", "NY", 43000),
    ("ACC000027", "Meta Platforms", "Technology", "Healthy", "Menlo Park", "CA", 86000),
    ("ACC000097", "Micron Technology", "Technology", "Critical", "Boise", "ID", 48000),
    ("ACC000013", "Microsoft", "Technology", "Good", "Redmond", "WA", 228000),
    ("ACC000090", "Mondelez", "Consumer Goods", "At Risk", "Chicago", "IL", 91000),
    ("ACC000059", "Morgan Stanley", "Financial Services", "Excellent", "New York", "NY", 82000),
    ("ACC000095", "Netflix", "Media", "Excellent", "Los Gatos", "CA", 13000),
    ("ACC000104", "NextEra Energy", "Energy", "At Risk", "Juno Beach", "FL", 15000),
    ("ACC000074", "Nike", "Consumer Goods", "Critical", "Beaverton", "OR", 83700),
    ("ACC000140", "Nordstrom", "Retail", "At Risk", "Seattle", "WA", 60000),
    ("ACC000146", "Norfolk Southern", "Transportation", "Excellent", "Atlanta", "GA", 19300),
    ("ACC000084", "Northrop Grumman", "Industrial", "Healthy", "Falls Church", "VA", 100500),
    ("ACC000057", "Nvidia", "Technology", "At Risk", "Santa Clara", "CA", 29600),
    ("ACC000120", "PNC Financial", "Financial Services", "At Risk", "Pittsburgh", "PA", 60000),
    ("ACC000151", "Palo Alto Networks", "Technology", "Critical", "Santa Clara", "CA", 15000),
    ("ACC000099", "Paramount Global", "Media", "At Risk", "New York", "NY", 22000),
    ("ACC000098", "PayPal", "Technology", "Healthy", "San Jose", "CA", 29900),
    ("ACC000037", "PepsiCo", "Consumer Goods", "Critical", "Purchase", "NY", 318000),
    ("ACC000064", "Pfizer", "Healthcare", "Critical", "New York", "NY", 83000),
    ("ACC000021", "Phillips 66", "Energy", "Critical", "Houston", "TX", 14000),
    ("ACC000042", "Procter & Gamble", "Consumer Goods", "Excellent", "Cincinnati", "OH", 107000),
    ("ACC000056", "Progressive", "Financial Services", "At Risk", "Mayfield Village", "OH", 60000),
    ("ACC000073", "Prudential Financial", "Financial Services", "Good", "Newark", "NJ", 40000),
    ("ACC000079", "Qualcomm", "Technology", "Excellent", "San Diego", "CA", 51000),
    ("ACC000117", "Quanta Services", "Construction", "Critical", "Houston", "TX", 54800),
    ("ACC000050", "Raytheon Technologies", "Industrial", "Critical", "Arlington", "VA", 182000),
    ("ACC000141", "Republic Services", "Waste Management", "Healthy", "Phoenix", "AZ", 41000),
    ("ACC000094", "Salesforce", "Technology", "Excellent", "San Francisco", "CA", 79000),
    ("ACC000158", "Snowflake", "Technology", "Excellent", "Bozeman", "MT", 7000),
    ("ACC000101", "Southern Company", "Energy", "Critical", "Atlanta", "GA", 27000),
    ("ACC000110", "Southwest Airlines", "Transportation", "Good", "Dallas", "TX", 74000),
    ("ACC000157", "Splunk", "Technology", "Excellent", "San Francisco", "CA", 8500),
    ("ACC000145", "State Street", "Financial Services", "Good", "Boston", "MA", 53000),
    ("ACC000016", "Stellantis", "Automotive", "At Risk", "Auburn Hills", "MI", 281000),
    ("ACC000048", "Sysco", "Food Distribution", "Good", "Houston", "TX", 72000),
    ("ACC000044", "T-Mobile", "Telecommunications", "Excellent", "Bellevue", "WA", 71000),
    ("ACC000032", "Target", "Retail", "At Risk", "Minneapolis", "MN", 440000),
    ("ACC000036", "Tesla", "Automotive", "Good", "Austin", "TX", 140000),
    ("ACC000131", "Texas Instruments", "Technology", "Healthy", "Dallas", "TX", 34000),
    ("ACC000156", "TransUnion", "Financial Services", "Critical", "Chicago", "IL", 13000),
    ("ACC000083", "Travelers", "Financial Services", "Excellent", "New York", "NY", 30800),
    ("ACC000119", "Truist Financial", "Financial Services", "At Risk", "Charlotte", "NC", 52000),
    ("ACC000035", "UPS", "Transportation", "Excellent", "Atlanta", "GA", 500000),
    ("ACC000103", "US Bancorp", "Financial Services", "At Risk", "Minneapolis", "MN", 77000),
    ("ACC000088", "Uber Technologies", "Technology", "Good", "San Francisco", "CA", 32800),
    ("ACC000111", "Union Pacific", "Transportation", "Good", "Omaha", "NE", 30000),
    ("ACC000071", "United Airlines", "Transportation", "Critical", "Chicago", "IL", 99000),
    ("ACC000005", "UnitedHealth Group", "Healthcare", "At Risk", "Minnetonka", "MN", 440000),
    ("ACC000019", "Valero Energy", "Energy", "At Risk", "San Antonio", "TX", 10015),
    ("ACC000026", "Verizon", "Telecommunications", "Healthy", "New York", "NY", 117100),
    ("ACC000001", "Walmart", "Retail", "Healthy", "Bentonville", "AR", 2100000),
    ("ACC000039", "Walt Disney", "Media", "Critical", "Burbank", "CA", 220000),
    ("ACC000082", "Warner Bros Discovery", "Media", "Excellent", "New York", "NY", 35000),
    ("ACC000122", "Waste Management", "Waste Management", "Excellent", "Houston", "TX", 48000),
    ("ACC000152", "Workday", "Technology", "Good", "Pleasanton", "CA", 18800),
]

ae_names = ["Sarah Johnson", "Michael Chen", "Emily Rodriguez", "James Williams", "Amanda Thompson"]
se_names = ["David Park", "Lisa Anderson", "Kevin Martinez", "Rachel Green", "Chris Taylor"]
customer_titles = ["VP of IT", "CISO", "Director of Security", "Head of Infrastructure", "IT Director"]

positive_conversations = [
    """[00:00:00] {ae}: Thanks for joining today! How are things going at {company}?

[00:00:15] Customer: Fantastic! We're really excited about the progress we've made. The platform has been incredible.

[00:01:00] {ae}: That's wonderful to hear! What's been working best for your team?

[00:01:30] Customer: The automation has saved us countless hours. Our team loves it. We've reduced onboarding time from 2 weeks to just 2 days!

[00:02:15] {se}: That's amazing ROI. How has adoption been across the organization?

[00:02:45] Customer: We're at 98% adoption now, up from 75% last quarter. The user experience is so intuitive that people actually want to use it.

[00:03:30] {ae}: Excellent! Any areas where we can help drive even more value?

[00:04:00] Customer: Actually yes - we're so happy with the results that we want to expand! We're looking at adding Lifecycle Management and API Access Management.

[00:05:00] {se}: That's great news! Both products integrate seamlessly with what you already have.

[00:05:45] Customer: Perfect. Our CFO actually reached out asking why we're not using more of your platform given how well SSO has worked.

[00:06:30] {ae}: Music to our ears! When can we schedule a call to discuss the expansion?

[00:07:00] Customer: How about next week? I want to move quickly on this. Budget is already approved.

[00:07:30] {se}: We can do a technical deep dive on Tuesday if that works?

[00:08:00] Customer: Tuesday is perfect. I'll bring our infrastructure team - they're eager to learn more.

[00:08:30] {ae}: This is really exciting. Thank you for being such a great partner!

[00:09:00] Customer: Thank you! Your team has been incredibly responsive and helpful. We're happy customers.""",

    """[00:00:00] {ae}: Great to see you! How has everything been since our last call?

[00:00:20] Customer: Honestly? Better than expected. We just passed our SOC 2 audit with flying colors, and the auditors specifically called out our identity controls.

[00:01:00] {se}: Congratulations! That's a huge accomplishment.

[00:01:30] Customer: Thanks! Your platform made it so much easier. The access certification reports were exactly what the auditors needed.

[00:02:15] {ae}: That's exactly the outcome we aim for. What's next on your roadmap?

[00:02:45] Customer: We're planning a major expansion. The board approved a 40% increase in our security budget, and identity is the top priority.

[00:03:30] Customer: We want to roll out MFA to all contractors and implement privileged access management.

[00:04:15] {se}: Both excellent choices. PAM especially will strengthen your security posture significantly.

[00:05:00] Customer: Our CISO is a big advocate. She's been presenting our success metrics to the board quarterly.

[00:05:45] {ae}: That's wonderful to hear. Executive sponsorship makes such a difference.

[00:06:30] Customer: Absolutely. She wants to do a case study with you actually - would that be possible?

[00:07:00] {ae}: We'd be honored! Our marketing team would love to connect.

[00:07:30] Customer: Great! Also, do you have any customer advisory board opportunities? We'd love to provide input on your roadmap.

[00:08:15] {se}: We absolutely do. I'll send you the details after this call.

[00:08:45] Customer: Perfect. This has been a great partnership. Looking forward to growing it further!""",

    """[00:00:00] {ae}: Thanks for making time today. I know you're busy!

[00:00:15] Customer: Always happy to chat with you. We've got some exciting news to share!

[00:00:45] {ae}: I love exciting news! What's happening?

[00:01:15] Customer: We just acquired TechCorp - 3,000 new employees! And we want to bring them onto your platform immediately.

[00:02:00] {se}: Congratulations on the acquisition! That's a significant growth opportunity for us too.

[00:02:30] Customer: Exactly. We've seen how well your platform scales. Our team is confident we can onboard them within 60 days.

[00:03:15] {ae}: That's an aggressive timeline, but definitely achievable with proper planning.

[00:03:45] Customer: Your customer success team has been phenomenal. They've already offered to help with the migration planning.

[00:04:30] {se}: We can dedicate additional resources to ensure a smooth transition.

[00:05:00] Customer: That would be great. The CEO is watching this integration closely - it needs to go smoothly.

[00:05:45] {ae}: We won't let you down. What's the timeline for contract expansion?

[00:06:15] Customer: Let's get the paperwork started this week. We want to move fast.

[00:06:45] {se}: I'll prepare the technical requirements document today.

[00:07:15] Customer: Excellent. This partnership continues to exceed our expectations. Thank you!"""
]

negative_conversations = [
    """[00:00:00] {ae}: Thanks for taking this call. I understand there have been some concerns?

[00:00:20] Customer: Concerns is an understatement. We've been having serious issues with the platform.

[00:00:45] {ae}: I'm sorry to hear that. Can you walk me through what's been happening?

[00:01:15] Customer: Where do I start? The login failures have increased 300% this quarter. Our help desk is overwhelmed.

[00:02:00] {se}: That's definitely not acceptable. What error messages are users seeing?

[00:02:30] Customer: Various errors. Timeouts, authentication failures, MFA not working. It's a mess.

[00:03:15] Customer: Frankly, our leadership is questioning whether we made the right choice with your platform.

[00:04:00] {ae}: I completely understand the frustration. We need to get this resolved immediately.

[00:04:30] Customer: We've opened multiple support tickets but responses have been slow. This is affecting our business.

[00:05:15] {se}: I'll personally escalate this to our engineering team today.

[00:05:45] Customer: We've heard that before. I need to see actual results, not promises.

[00:06:30] Customer: Our CFO is already asking me to evaluate alternatives. This is that serious.

[00:07:15] {ae}: I hear you. What would it take to regain your confidence?

[00:07:45] Customer: Fix the issues, provide a detailed root cause analysis, and show me it won't happen again.

[00:08:30] Customer: And honestly? We may need to discuss pricing. We're not getting the value we're paying for.

[00:09:00] {ae}: Those are fair requests. Let me set up an emergency call with our VP of Engineering.

[00:09:30] Customer: Fine. But this is our last attempt. If things don't improve, we're moving to a competitor.""",

    """[00:00:00] {ae}: I appreciate you meeting with me. I know things have been challenging.

[00:00:20] Customer: Challenging doesn't begin to describe it. We've lost confidence in your platform.

[00:01:00] Customer: Last week we had an outage during our busiest period. Employees couldn't log in for 4 hours.

[00:01:45] {se}: I saw the incident report. We've identified the root cause and implemented fixes.

[00:02:15] Customer: That's what you said after the last outage. And the one before that.

[00:02:45] Customer: Our CEO had to apologize to the board because employees couldn't access critical systems.

[00:03:30] {ae}: I understand the severity. We take full responsibility.

[00:04:00] Customer: Responsibility doesn't help me when I'm explaining to leadership why we're still using your product.

[00:04:45] Customer: Microsoft has been calling us weekly. Their pricing is significantly lower.

[00:05:30] {se}: We can discuss technical differentiators that justify the investment.

[00:06:00] Customer: At this point, I'm not sure any differentiator is worth this level of disruption.

[00:06:45] Customer: We need a 90-day remediation plan with SLA guarantees, or we're issuing an RFP.

[00:07:30] {ae}: Let's schedule a meeting with our executive team to discuss a concrete action plan.

[00:08:00] Customer: Fine, but I'm being transparent - my recommendation to leadership will be to switch vendors.

[00:08:30] Customer: You have one chance to change my mind. Don't waste it.""",

    """[00:00:00] {ae}: Thanks for your time today. I wanted to check in on how things are going.

[00:00:20] Customer: Since you asked, not well. I'm frustrated and disappointed.

[00:00:50] Customer: We signed up expecting a premium experience. What we've gotten is anything but.

[00:01:30] {ae}: I'm sorry to hear that. What specific issues are you facing?

[00:02:00] Customer: Support response times are terrible. Our last critical ticket took 3 days to get a response.

[00:02:45] Customer: Three days! Meanwhile our users were locked out of essential applications.

[00:03:30] {se}: That's unacceptable. Our SLA guarantees 4-hour response for critical issues.

[00:04:00] Customer: Well, your SLA isn't worth the paper it's written on apparently.

[00:04:45] Customer: I've escalated this internally. Our procurement team is reviewing the contract for termination clauses.

[00:05:30] {ae}: I don't want it to come to that. What can we do to make this right?

[00:06:00] Customer: Honestly? I'm not sure there's anything you can do at this point.

[00:06:45] Customer: The trust is broken. My team has lost confidence in the platform.

[00:07:30] Customer: We've already started a POC with a competitor. It's going well.

[00:08:00] {ae}: Is there anything that would pause that evaluation?

[00:08:30] Customer: Maybe if your CEO called me personally to apologize. But even then, I'm skeptical.

[00:09:00] Customer: This relationship has been a disappointment from start to finish."""
]

neutral_conversations = [
    """[00:00:00] {ae}: Thanks for meeting today. How's everything going at {company}?

[00:00:15] Customer: Things are steady. No major changes since we last spoke.

[00:00:45] {ae}: Good to hear. Any feedback on the platform?

[00:01:15] Customer: It's working fine. Nothing to report really. Users seem satisfied.

[00:01:45] {se}: Are you utilizing all the features available to you?

[00:02:15] Customer: We're using what we need. Haven't explored much beyond the basics.

[00:02:45] {ae}: There might be some capabilities that could add value. Want me to walk through them?

[00:03:15] Customer: Sure, I have a few minutes. But we're not looking to expand right now.

[00:03:45] Customer: Budget is tight and we need to justify any additional spend carefully.

[00:04:30] {se}: Understood. Even within your current license, there are features you might not be using.

[00:05:00] Customer: Like what?

[00:05:30] {se}: For example, automated access reviews could save your team several hours each month.

[00:06:00] Customer: Interesting. We've been doing those manually. I'll take a look.

[00:06:30] {ae}: When is your renewal coming up?

[00:07:00] Customer: Six months out. We'll evaluate options when the time comes.

[00:07:30] {ae}: Fair enough. Anything else we can help with today?

[00:08:00] Customer: Not really. Just keep the platform running smoothly and we're good.

[00:08:30] {ae}: Will do. Thanks for your time today.""",

    """[00:00:00] {ae}: Good to connect. How has Q3 been treating you?

[00:00:20] Customer: Busy as always. Lots of projects competing for attention.

[00:00:50] {ae}: I can imagine. Where does identity fit in your priorities?

[00:01:20] Customer: It's maintenance mode honestly. We set it up and it works. Not much else to do.

[00:01:50] {se}: That's actually a good sign - means the platform is running smoothly.

[00:02:20] Customer: I suppose so. We have other fires to fight right now.

[00:02:50] Customer: Cloud migration is consuming most of our bandwidth.

[00:03:30] {ae}: Identity can actually help with cloud migrations. Access Gateway supports hybrid environments.

[00:04:00] Customer: We might look at that eventually. Not a priority right now though.

[00:04:30] Customer: Our current solution handles what we need for the migration.

[00:05:00] {se}: Makes sense. When you're ready to discuss, let us know.

[00:05:30] Customer: Will do. What else is on your agenda today?

[00:06:00] {ae}: Just wanted to check in and make sure everything is running smoothly.

[00:06:30] Customer: It is. Nothing else really to discuss.

[00:07:00] {ae}: Understood. We're here if you need anything.

[00:07:30] Customer: Appreciate it. Talk soon."""
]

def hash_str(s):
    return int(hashlib.md5(s.encode()).hexdigest(), 16)

def get_sentiment_for_health(healthscore, call_num, hash_val):
    """Determine sentiment based on health score with some randomness"""
    roll = hash_val % 100
    
    if healthscore == "Excellent":
        if roll < 80: return "positive"
        elif roll < 95: return "neutral"
        else: return "negative"
    elif healthscore == "Healthy":
        if roll < 60: return "positive"
        elif roll < 90: return "neutral"
        else: return "negative"
    elif healthscore == "Good":
        if roll < 40: return "positive"
        elif roll < 80: return "neutral"
        else: return "negative"
    elif healthscore == "At Risk":
        if roll < 15: return "positive"
        elif roll < 50: return "neutral"
        else: return "negative"
    else:  # Critical
        if roll < 5: return "positive"
        elif roll < 25: return "neutral"
        else: return "negative"

def generate_transcript(account_id, account_name, industry, healthscore, city, state, employees, call_num):
    h = hash_str(account_id + str(call_num))
    
    ae = ae_names[h % len(ae_names)]
    se = se_names[(h + 1) % len(se_names)]
    customer_title = customer_titles[(h + 2) % len(customer_titles)]
    
    sentiment = get_sentiment_for_health(healthscore, call_num, h)
    
    if sentiment == "positive":
        conversation = positive_conversations[h % len(positive_conversations)]
        call_type = "Expansion Discussion" if h % 2 == 0 else "Quarterly Business Review"
        summary = "Excellent call with engaged customer. Strong platform adoption and high satisfaction. Customer interested in expanding usage and adding new products."
        insights = "GROWTH: Customer is a strong advocate. Multiple expansion opportunities identified. Executive sponsorship confirmed."
    elif sentiment == "negative":
        conversation = negative_conversations[h % len(negative_conversations)]
        call_type = "Escalation Call" if h % 2 == 0 else "Issue Resolution"
        summary = "Difficult call addressing customer concerns. Platform issues causing frustration. Customer evaluating alternatives and considering churn."
        insights = "CHURN RISK: Customer is frustrated and evaluating competitors. Immediate action required to retain account."
    else:
        conversation = neutral_conversations[h % len(neutral_conversations)]
        call_type = "Check-in Call" if h % 2 == 0 else "Renewal Discussion"
        summary = "Routine check-in with stable customer. Platform working as expected. No immediate concerns but limited engagement."
        insights = "STABLE: Customer is satisfied but not engaged. Potential to increase adoption with targeted outreach."
    
    conversation = conversation.format(ae=ae, se=se, company=account_name)
    
    duration = 30 + (h % 60)
    call_date = datetime.now() - timedelta(days=(h % 180))
    
    transcript = f"""================================================================================
GONG CALL TRANSCRIPT
================================================================================

CALL METADATA
-------------
Call ID: GONG{hash_str(account_id)%10000000:07d}
Date: {call_date.strftime('%Y-%m-%d')}
Duration: {duration} minutes
Call Type: {call_type}

ACCOUNT INFORMATION
-------------------
Account: {account_name}
Account ID: {account_id}
Industry: {industry}
Location: {city}, {state}
Employees: {employees:,}
Health Score: {healthscore}

PARTICIPANTS
------------
- {ae} (Account Executive)
- {se} (Sales Engineer)
- {customer_title}, {account_name} (Customer)

CALL SUMMARY
------------
{summary}

KEY INSIGHTS
------------
{insights}

================================================================================
FULL TRANSCRIPT
================================================================================

{conversation}

[END OF TRANSCRIPT]
================================================================================
"""
    return transcript, call_date

print(f"Generating transcripts for {len(accounts)} accounts...")

transcript_count = 0
for account in accounts:
    account_id, account_name, industry, healthscore, city, state, employees = account
    
    num_calls = 1 + (hash_str(account_id) % 3)
    
    for call_num in range(1, num_calls + 1):
        transcript, call_date = generate_transcript(
            account_id, account_name, industry, healthscore, city, state, employees, call_num
        )
        
        safe_name = account_name.replace(" ", "_").replace("&", "and").replace(".", "")
        filename = f"{safe_name}_{call_date.strftime('%Y-%m-%d')}_call_{call_num}.txt"
        filepath = os.path.join(output_dir, filename)
        
        with open(filepath, 'w') as f:
            f.write(transcript)
        
        transcript_count += 1

print(f"\nGenerated {transcript_count} transcript files in {output_dir}")
