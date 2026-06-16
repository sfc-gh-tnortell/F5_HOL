import streamlit as st
import pandas as pd

st.set_page_config(page_title="F5 Customer Growth Hub", layout="wide", initial_sidebar_state="expanded")

conn = st.connection("snowflake")

# --- DATA LOADING ---
@st.cache_data(ttl=300)
def load_accounts():
    return conn.query("SELECT SFDCF5_ACCT_ID, ACCT_NAME, INDUSTRY_NAME, ETM_REGION_NAME, ANNUAL_REVENUE_AMT FROM F5_PROD.RAW.DIM_CUST_ACCT_SFDC ORDER BY ACCT_NAME")

@st.cache_data(ttl=300)
def load_account_team():
    return conn.query("SELECT SFDCF5_ACCT_ID, AE_NAME, SE_NAME, REGION_NAME FROM F5_PROD.RAW.SALES_ACCOUNT_TEAM")

@st.cache_data(ttl=300)
def load_recommendations():
    return conn.query("""
        SELECT r.*, p.OFFER_DESC, p.F5_PRODUCT_OFFER_FAMILY_NAME
        FROM F5_PROD.FINAL.CROSS_SELL_RECOMMENDATIONS r
        LEFT JOIN F5_PROD.RAW.DIM_PRODUCT_OFFER p ON r.RECOMMENDED_SKU = p.OFFER_SKU_ID
        ORDER BY r.ACCT_NAME, r.PRIORITY_RANK
    """)

@st.cache_data(ttl=300)
def load_support_cases():
    return conn.query("""
        SELECT d.SFDCF5_ACCT_ID, d.SUPPORT_CASE_NUM, d.SUPPORT_CASE_TITLE_TEXT, 
            d.CURRENT_PRIORITY_CODE, d.PRODUCT_NAME, d.SUPPORT_CASE_STATUS_CODE,
            d.AREA_NAME, d.SUB_AREA_NAME, d.CREATED_DATETIME,
            f.TIME_TO_RESOLUTION_MINUTES_NUM, f.TIME_OVER_UNDER_SLA_MINUTES_NUM
        FROM F5_PROD.RAW.DIM_SUPPORT_CASE d
        LEFT JOIN F5_PROD.RAW.FACT_SUPPORT_CASE f ON d.SUPPORT_CASE_ID = f.SUPPORT_CASE_ID
    """)

@st.cache_data(ttl=300)
def load_telemetry():
    return conn.query("""
        SELECT SFDCF5_ACCT_ID, OBSERVATION_DATE, 
            ACTIVE_HTTP_LOAD_BALANCER_QTY, WAF_USAGE_QTY, 
            BOT_ADVANCED_TRANSACTION_CNT, ACTIVE_ENDPOINT_QTY, DNS_ZONES_QTY
        FROM F5_PROD.RAW.COL_XC_TELEMETRY
        WHERE OBSERVATION_DATE >= CURRENT_DATE() - 90
        ORDER BY OBSERVATION_DATE
    """)

@st.cache_data(ttl=300)
def load_opportunities():
    return conn.query("""
        SELECT o.SFDCF5_ACCT_ID, o.OPPORTUNITY_NAME, o.OPPORTUNITY_TYPE_CODE,
            o.OPPORTUNITY_STAGE_NAME, o.OPPORTUNITY_CLOSE_DATE, o.OPPORTUNITY_CLOSED_IND,
            o.OPPORTUNITY_WON_IND, f.OPPORTUNITY_AMT, f.ARR_AMT
        FROM F5_PROD.RAW.DIM_SALES_OPPORTUNITY o
        JOIN F5_PROD.RAW.FACT_SALES_OPPORTUNITY f ON o.OPPORTUNITY_ID = f.OPPORTUNITY_ID
    """)

@st.cache_data(ttl=300)
def load_line_items():
    return conn.query("SELECT SFDCF5_ACCT_ID, PRODUCT_SKU_ID, TOTAL_PRICE_AMT FROM F5_PROD.RAW.COL_SALES_OPPORTUNITY_LINE_ITEM")

@st.cache_data(ttl=300)
def load_install_base():
    return conn.query("SELECT CUST_SFDCF5_ACCT_ID, SERIAL_NUM, CORE_PRODUCT_NAME, HARDWARE_PLATFORM_CODE, SOFTWARE_VERSION_NUM, SERVICE_END_DATETIME FROM F5_PROD.RAW.COL_INSTALL_BASE")

@st.cache_data(ttl=300)
def load_utilization():
    return conn.query("""
        SELECT SALES_SFDCF5_ACCT_ID, OFFER_SKU_ID, FEATURE_NAME,
            FEATURE_ENTITLED_QTY, FEATURE_USED_QTY, MONTHS_LEFT_IN_TERM_NUM, SUBSCRIPTION_END_DATE
        FROM F5_PROD.RAW.COL_TERM_SUB_MONTHLY_USAGE_V2
        WHERE BILLING_MONTH_START_DATE = (SELECT MAX(BILLING_MONTH_START_DATE) FROM F5_PROD.RAW.COL_TERM_SUB_MONTHLY_USAGE_V2)
    """)

@st.cache_data(ttl=300)
def load_health_scores():
    return conn.query("SELECT SFDCF5_ACCT_ID, SKU_UTILIZATION_PCT, CONSUMPTION_PATTERN, PRODUCT_LINE, CORE_PRODUCT FROM F5_PROD.RAW.COL_XC_PRODUCT_HEALTHSCORE")

@st.cache_data(ttl=300)
def load_transcripts():
    return conn.query("SELECT ACCOUNT_NAME, CALL_DATE, TRANSCRIPT_TEXT FROM F5_PROD.FINAL.ZOOM_TRANSCRIPT_SOURCE ORDER BY CALL_DATE DESC")

# Load data
accounts_df = load_accounts()
team_df = load_account_team()
recs_df = load_recommendations()
cases_df = load_support_cases()
telemetry_df = load_telemetry()
opps_df = load_opportunities()
line_items_df = load_line_items()
install_df = load_install_base()
util_df = load_utilization()
health_df = load_health_scores()
transcripts_df = load_transcripts()

# --- SIDEBAR ---
st.sidebar.image("https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/F5%2C_Inc._logo.svg/512px-F5%2C_Inc._logo.svg.png", width=120)
st.sidebar.markdown("## Customer Growth Hub")

selected_account = st.sidebar.selectbox("Choose an Account", accounts_df["ACCT_NAME"].tolist(), index=0)
acct_id = accounts_df[accounts_df["ACCT_NAME"] == selected_account]["SFDCF5_ACCT_ID"].values[0]

# Account team card
team_row = team_df[team_df["SFDCF5_ACCT_ID"] == acct_id]
if not team_row.empty:
    st.sidebar.markdown("---")
    st.sidebar.markdown("**Your Team**")
    st.sidebar.markdown(f"Account Exec: {team_row['AE_NAME'].values[0]}")
    st.sidebar.markdown(f"Solutions Eng: {team_row['SE_NAME'].values[0]}")
    st.sidebar.markdown(f"Region: {team_row['REGION_NAME'].values[0]}")

st.sidebar.markdown("---")
page = st.sidebar.radio("", [
    "Overview",
    "What to Sell",
    "Support Issues",
    "Pipeline & Revenue",
    "Recent Calls"
], label_visibility="collapsed")

# --- HELPER: Quick status badge ---
def status_badge(label, color="blue"):
    colors = {"green": "#28a745", "red": "#dc3545", "yellow": "#ffc107", "blue": "#29B5E8"}
    return f'<span style="background:{colors.get(color, color)};color:white;padding:2px 8px;border-radius:4px;font-size:0.8em;">{label}</span>'

# --- PRECOMPUTE ACCOUNT DATA ---
acct_items = line_items_df[line_items_df["SFDCF5_ACCT_ID"] == acct_id]
acct_cases = cases_df[cases_df["SFDCF5_ACCT_ID"] == acct_id]
acct_recs = recs_df[recs_df["SFDCF5_ACCT_ID"] == acct_id]
acct_opps = opps_df[opps_df["SFDCF5_ACCT_ID"] == acct_id]
open_cases = acct_cases[acct_cases["SUPPORT_CASE_STATUS_CODE"].isin(["Open", "In Progress"])]
open_opps = acct_opps[acct_opps["OPPORTUNITY_CLOSED_IND"] == False]

# =====================================================
# PAGE: OVERVIEW
# =====================================================
if page == "Overview":
    acct_row = accounts_df[accounts_df["SFDCF5_ACCT_ID"] == acct_id].iloc[0]
    
    st.title(selected_account)
    st.markdown(f"**{acct_row['INDUSTRY_NAME']}** | {acct_row['ETM_REGION_NAME']}")
    
    # Quick status row
    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("Revenue", f"${acct_items['TOTAL_PRICE_AMT'].sum():,.0f}")
    col2.metric("Products", f"{acct_items['PRODUCT_SKU_ID'].nunique()}")
    col3.metric("Open Cases", f"{len(open_cases)}", delta=None if len(open_cases) == 0 else f"{len(open_cases)} active")
    col4.metric("Open Pipeline", f"${open_opps['OPPORTUNITY_AMT'].sum():,.0f}")
    col5.metric("Recommendations", f"{len(acct_recs)}")
    
    st.markdown("---")
    
    # Two column layout: what they have vs what we recommend
    col_left, col_right = st.columns(2)
    
    with col_left:
        st.markdown("### What They Own Today")
        if not acct_items.empty:
            portfolio = acct_items.groupby("PRODUCT_SKU_ID")["TOTAL_PRICE_AMT"].sum().reset_index()
            portfolio.columns = ["Product", "Investment"]
            portfolio["Investment"] = portfolio["Investment"].apply(lambda x: f"${x:,.0f}")
            portfolio = portfolio.sort_values("Product")
            st.dataframe(portfolio, use_container_width=True, hide_index=True, height=300)
        else:
            st.info("No purchase history found")
    
    with col_right:
        st.markdown("### What We Should Pitch")
        if not acct_recs.empty:
            for _, rec in acct_recs.head(3).iterrows():
                type_color = "green" if rec["RECOMMENDATION_TYPE"] == "cross-sell" else "blue" if rec["RECOMMENDATION_TYPE"] == "upsell" else "yellow"
                product_name = rec.get("OFFER_DESC", rec["RECOMMENDED_SKU"])
                st.markdown(f'{status_badge(rec["RECOMMENDATION_TYPE"], type_color)} **{product_name}**', unsafe_allow_html=True)
                st.caption(f'{rec["RATIONALE"]}')
                st.markdown("")
        else:
            st.info("No expansion recommendations yet")
    
    st.markdown("---")
    
    # Health snapshot
    st.markdown("### Account Health")
    h_col1, h_col2, h_col3 = st.columns(3)
    
    acct_health = health_df[health_df["SFDCF5_ACCT_ID"] == acct_id]
    if not acct_health.empty:
        h = acct_health.iloc[0]
        h_col1.metric("Utilization", f"{h['SKU_UTILIZATION_PCT']:.0f}%")
        pattern = h["CONSUMPTION_PATTERN"]
        h_col2.metric("Usage Trend", pattern)
    
    acct_tel = telemetry_df[telemetry_df["SFDCF5_ACCT_ID"] == acct_id]
    if not acct_tel.empty:
        avgs = acct_tel[["ACTIVE_HTTP_LOAD_BALANCER_QTY", "WAF_USAGE_QTY", "BOT_ADVANCED_TRANSACTION_CNT", "ACTIVE_ENDPOINT_QTY", "DNS_ZONES_QTY"]].mean()
        if avgs["BOT_ADVANCED_TRANSACTION_CNT"] > 300000:
            signal = "Bot Defense (heavy bot traffic)"
        elif avgs["WAF_USAGE_QTY"] > 25:
            signal = "WAF (active security)"
        elif avgs["ACTIVE_ENDPOINT_QTY"] > 150:
            signal = "Capacity (many endpoints)"
        elif avgs["ACTIVE_HTTP_LOAD_BALANCER_QTY"] > 40:
            signal = "Load Balancing (high traffic)"
        elif avgs["DNS_ZONES_QTY"] > 7:
            signal = "DNS (multi-zone)"
        else:
            signal = "Load Balancing"
        h_col3.metric("Primary Use Case", signal)

# =====================================================
# PAGE: WHAT TO SELL
# =====================================================
elif page == "What to Sell":
    st.title(f"Expansion Playbook - {selected_account}")
    st.markdown("Products our model recommends based on this account's usage, purchase history, and what similar customers buy.")
    
    if acct_recs.empty:
        st.warning("No recommendations generated for this account. Run the recommendation model first.")
    else:
        # Filter
        type_filter = st.radio("Show", ["All", "Cross-Sell (New Products)", "Upsell (Upgrade)", "Capacity (More of Same)"], horizontal=True)
        type_map = {"Cross-Sell (New Products)": "cross-sell", "Upsell (Upgrade)": "upsell", "Capacity (More of Same)": "capacity"}
        
        filtered_recs = acct_recs.copy()
        if type_filter != "All":
            filtered_recs = filtered_recs[filtered_recs["RECOMMENDATION_TYPE"] == type_map[type_filter]]
        
        st.markdown("---")
        
        for _, rec in filtered_recs.iterrows():
            confidence = float(rec["CONFIDENCE_SCORE"])
            type_color = "green" if rec["RECOMMENDATION_TYPE"] == "cross-sell" else "blue" if rec["RECOMMENDATION_TYPE"] == "upsell" else "yellow"
            product_name = rec.get("OFFER_DESC", rec["RECOMMENDED_SKU"])
            family = rec.get("F5_PRODUCT_OFFER_FAMILY_NAME", "")
            
            with st.container():
                top_col1, top_col2 = st.columns([4, 1])
                with top_col1:
                    st.markdown(f'### {product_name}')
                    st.markdown(f'{status_badge(rec["RECOMMENDATION_TYPE"], type_color)} {family} | Rank #{int(rec["PRIORITY_RANK"])}', unsafe_allow_html=True)
                with top_col2:
                    st.markdown(f"**Confidence**")
                    st.progress(confidence)
                    st.caption(f"{confidence:.0%}")
                
                st.markdown(f"**Why:** {rec['RATIONALE']}")
                st.markdown("---")

# =====================================================
# PAGE: SUPPORT ISSUES
# =====================================================
elif page == "Support Issues":
    st.title(f"Support Status - {selected_account}")
    
    # Status summary
    total = len(acct_cases)
    open_count = len(open_cases)
    resolved = len(acct_cases[acct_cases["SUPPORT_CASE_STATUS_CODE"] == "Resolved"])
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Open Now", open_count)
    col2.metric("Resolved", resolved)
    col3.metric("Total (All Time)", total)
    
    st.markdown("---")
    
    # Open cases with priority coloring
    if open_count > 0:
        st.markdown("### Active Cases")
        for _, case in open_cases.sort_values("CURRENT_PRIORITY_CODE").iterrows():
            priority = case["CURRENT_PRIORITY_CODE"]
            p_color = "red" if "Critical" in str(priority) else "yellow" if "High" in str(priority) else "blue"
            st.markdown(f'{status_badge(priority, p_color)} **{case["SUPPORT_CASE_TITLE_TEXT"]}**', unsafe_allow_html=True)
            st.caption(f'{case["PRODUCT_NAME"]} | Case #{case["SUPPORT_CASE_NUM"]} | Opened: {str(case["CREATED_DATETIME"])[:10]}')
            st.markdown("")
    else:
        st.success("No open support cases. Account is in good shape.")
    
    st.markdown("---")
    
    # Utilization - highlight anything over 80%
    st.markdown("### Capacity & Utilization")
    st.caption("Features approaching or exceeding their entitlement limits")
    acct_util = util_df[util_df["SALES_SFDCF5_ACCT_ID"] == acct_id].copy()
    if not acct_util.empty:
        acct_util["Usage %"] = (acct_util["FEATURE_USED_QTY"] / acct_util["FEATURE_ENTITLED_QTY"] * 100).round(0)
        acct_util = acct_util.sort_values("Usage %", ascending=False)
        display_util = acct_util[["OFFER_SKU_ID", "FEATURE_NAME", "Usage %", "MONTHS_LEFT_IN_TERM_NUM"]].rename(columns={
            "OFFER_SKU_ID": "Product", "FEATURE_NAME": "Feature", "MONTHS_LEFT_IN_TERM_NUM": "Months to Renewal"
        })
        st.dataframe(display_util, use_container_width=True, hide_index=True)
    else:
        st.info("No subscription utilization data")
    
    st.markdown("---")
    
    # Telemetry trend (user-friendly labels)
    st.markdown("### Infrastructure Usage (Last 90 Days)")
    acct_tel = telemetry_df[telemetry_df["SFDCF5_ACCT_ID"] == acct_id].copy()
    if not acct_tel.empty:
        chart_data = acct_tel.set_index("OBSERVATION_DATE")[["ACTIVE_HTTP_LOAD_BALANCER_QTY", "WAF_USAGE_QTY", "ACTIVE_ENDPOINT_QTY", "DNS_ZONES_QTY"]]
        chart_data.columns = ["Load Balancers", "Security Rules", "Endpoints", "DNS Zones"]
        selected_metrics = st.multiselect("Show metrics", chart_data.columns.tolist(), default=chart_data.columns.tolist())
        if selected_metrics:
            st.line_chart(chart_data[selected_metrics])
    else:
        st.info("No telemetry data available")

# =====================================================
# PAGE: PIPELINE & REVENUE
# =====================================================
elif page == "Pipeline & Revenue":
    st.title(f"Sales & Revenue - {selected_account}")
    
    won_opps = acct_opps[acct_opps["OPPORTUNITY_WON_IND"] == True]
    lost_opps = acct_opps[acct_opps["OPPORTUNITY_STAGE_NAME"] == "Closed Lost"]
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Active Pipeline", f"${open_opps['OPPORTUNITY_AMT'].sum():,.0f}")
    col2.metric("Won Revenue", f"${won_opps['OPPORTUNITY_AMT'].sum():,.0f}")
    col3.metric("Lost Deals", f"{len(lost_opps)}")
    col4.metric("Win Rate", f"{len(won_opps) / max(len(won_opps) + len(lost_opps), 1) * 100:.0f}%")
    
    st.markdown("---")
    
    # Active deals
    if not open_opps.empty:
        st.markdown("### In Progress")
        for _, opp in open_opps.sort_values("OPPORTUNITY_AMT", ascending=False).iterrows():
            stage_color = "green" if "Proposal" in str(opp["OPPORTUNITY_STAGE_NAME"]) else "blue"
            st.markdown(f'{status_badge(opp["OPPORTUNITY_STAGE_NAME"], stage_color)} **{opp["OPPORTUNITY_NAME"]}** - ${opp["OPPORTUNITY_AMT"]:,.0f}', unsafe_allow_html=True)
            st.caption(f'{opp["OPPORTUNITY_TYPE_CODE"]} | Close: {str(opp["OPPORTUNITY_CLOSE_DATE"])[:10]}')
            st.markdown("")
    else:
        st.info("No active pipeline")
    
    st.markdown("---")
    
    # Install base
    st.markdown("### Deployed Products")
    st.caption("Hardware and software currently installed at this account")
    acct_install = install_df[install_df["CUST_SFDCF5_ACCT_ID"] == acct_id]
    if not acct_install.empty:
        display_install = acct_install[["CORE_PRODUCT_NAME", "HARDWARE_PLATFORM_CODE", "SOFTWARE_VERSION_NUM", "SERVICE_END_DATETIME"]].rename(columns={
            "CORE_PRODUCT_NAME": "Product", "HARDWARE_PLATFORM_CODE": "Platform",
            "SOFTWARE_VERSION_NUM": "Version", "SERVICE_END_DATETIME": "Service Expires"
        })
        st.dataframe(display_install, use_container_width=True, hide_index=True)
    else:
        st.info("No install base data")
    
    st.markdown("---")
    
    # Won/Lost history
    st.markdown("### Deal History")
    closed_opps = acct_opps[acct_opps["OPPORTUNITY_CLOSED_IND"] == True].copy()
    if not closed_opps.empty:
        closed_opps["Result"] = closed_opps["OPPORTUNITY_STAGE_NAME"].apply(lambda x: "Won" if "Won" in str(x) else "Lost")
        closed_opps["Amount"] = closed_opps["OPPORTUNITY_AMT"].apply(lambda x: f"${x:,.0f}")
        st.dataframe(closed_opps[["OPPORTUNITY_NAME", "OPPORTUNITY_TYPE_CODE", "Result", "Amount"]].rename(columns={
            "OPPORTUNITY_NAME": "Deal", "OPPORTUNITY_TYPE_CODE": "Type"
        }).sort_values("Amount", ascending=False), use_container_width=True, hide_index=True)

# =====================================================
# PAGE: RECENT CALLS
# =====================================================
elif page == "Recent Calls":
    st.title(f"Call History - {selected_account}")
    st.markdown("Review past conversations to prep for your next meeting.")
    
    acct_transcripts = transcripts_df[transcripts_df["ACCOUNT_NAME"] == selected_account]
    
    if acct_transcripts.empty:
        st.info("No recorded calls found for this account.")
    else:
        st.markdown(f"**{len(acct_transcripts)} call(s) on file**")
        st.markdown("---")
        
        for _, t in acct_transcripts.iterrows():
            with st.expander(f"Call on {t['CALL_DATE']}", expanded=len(acct_transcripts) == 1):
                text = str(t["TRANSCRIPT_TEXT"])
                # Clean WEBVTT format into readable conversation
                lines = text.split("\n")
                for line in lines:
                    line = line.strip()
                    if not line or line == "WEBVTT" or "-->" in line:
                        continue
                    if ":" in line and not line.startswith("http"):
                        speaker, _, content = line.partition(":")
                        st.markdown(f"**{speaker.strip()}:** {content.strip()}")
                    elif line:
                        st.markdown(line)
