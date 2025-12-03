import streamlit as st
import requests
import os
import urllib3
import json

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

st.set_page_config(page_title="LME Security Alerts", layout="wide")

# Initialize chat history in session state
if "chat_messages" not in st.session_state:
    st.session_state.chat_messages = []

# Get credentials
ES_URL = os.getenv("ELASTICSEARCH_URL", "https://lme-elasticsearch:9200")
ES_USER = os.getenv("ELASTICSEARCH_USER", "elastic")
ES_PASS = os.getenv("ELASTICSEARCH_PASSWORD", "")
LITELLM_URL = os.getenv("LITELLM_URL", "https://lme-litellm:4000")
LITELLM_KEY = os.getenv("LITELLM_API_KEY", "sk-lme-llama-proxy")
LITELLM_MODEL = os.getenv("LITELLM_MODEL", "gemma-3-1b")

# Define LLM functions
def chat_with_llm(messages):
    """Send chat messages to LLM"""
    try:
        response = requests.post(
            f"{LITELLM_URL}/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {LITELLM_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": LITELLM_MODEL,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 500
            },
            verify=False,
            timeout=300
        )
        response.raise_for_status()
        result = response.json()
        return result["choices"][0]["message"]["content"]
    except Exception as e:
        return f"Error: {e}"

def analyze_with_llm(alert_data):
    """Send alert to LLM for analysis"""
    prompt = f"""You are a security analyst. Analyze this alert SUCCINCTLY (3-5 sentences max):

Alert Data:
{json.dumps(alert_data, indent=2)}

Provide:
1. What happened (1 sentence)
2. Risk level and why (1 sentence)
3. What to do next (1-2 sentences)

Be brief and direct."""

    return chat_with_llm([{"role": "user", "content": prompt}])

# Sidebar - Chat Interface
with st.sidebar:
    st.title("💬 AI Assistant")

    # Display chat history
    for message in st.session_state.chat_messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Chat input
    if prompt := st.chat_input("Ask me anything..."):
        # Add user message to chat history
        st.session_state.chat_messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        # Get AI response
        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                response = chat_with_llm(st.session_state.chat_messages)
                st.markdown(response)

        # Add assistant response to chat history
        st.session_state.chat_messages.append({"role": "assistant", "content": response})
        st.rerun()

# Main content
st.title("🔍 LME Security Alerts")

# Check password
if not ES_PASS:
    st.error("ELASTICSEARCH_PASSWORD not set!")
    st.stop()

st.success(f"✓ Connected to Elasticsearch as {ES_USER}")

# Query the alerts index
try:
    response = requests.post(
        f"{ES_URL}/.alerts-security.alerts-*/_search",
        auth=(ES_USER, ES_PASS),
        verify=False,
        headers={"Content-Type": "application/json"},
        json={
            "size": 50,
            "sort": [{"@timestamp": {"order": "desc"}}]
        },
        timeout=10
    )
    response.raise_for_status()
    data = response.json()

    hits = data.get("hits", {}).get("hits", [])
    total = data.get('hits', {}).get('total', {}).get('value', 0)

    st.metric("Total Alerts", total)
    st.write(f"Showing {len(hits)} most recent alerts")

    # Display each alert
    for idx, hit in enumerate(hits):
        source = hit.get("_source", {})
        alert_name = source.get('kibana.alert.rule.name', 'Unknown Alert')
        timestamp = source.get('@timestamp', 'No timestamp')
        severity = source.get('kibana.alert.severity', 'unknown')

        # Color code by severity
        severity_colors = {
            'critical': '🔴',
            'high': '🟠',
            'medium': '🟡',
            'low': '🟢',
            'unknown': '⚪'
        }
        severity_icon = severity_colors.get(severity, '⚪')

        st.divider()

        # Header row
        col1, col2 = st.columns([4, 1])
        with col1:
            st.subheader(f"{severity_icon} {alert_name}")
            st.caption(f"🕐 {timestamp} | Severity: {severity.upper()}")
        with col2:
            analyze_button = st.button("🤖 Analyze", key=f"analyze_{idx}")

        # Alert details
        if 'host.name' in source:
            st.write(f"🖥️ **Host:** `{source['host.name']}`")
        if 'user.name' in source:
            st.write(f"👤 **User:** `{source['user.name']}`")
        if 'source.ip' in source:
            st.write(f"📍 **Source IP:** `{source['source.ip']}`")
        if 'destination.ip' in source:
            st.write(f"🎯 **Destination IP:** `{source['destination.ip']}`")
        if 'process.command_line' in source:
            st.write("**Command:**")
            st.code(source['process.command_line'], language="bash")
        if 'kibana.alert.reason' in source:
            st.info(f"**Reason:** {source['kibana.alert.reason']}")

        # Show analysis if button clicked
        if analyze_button:
            with st.spinner("🤖 Analyzing alert with AI..."):
                analysis = analyze_with_llm(source)
                st.success("**AI Analysis:**")
                st.markdown(analysis)

        # JSON details in expander
        with st.expander("📄 View Full JSON"):
            st.json(source)

except Exception as e:
    st.error(f"Error querying Elasticsearch: {e}")
    st.write(f"URL: {ES_URL}")
    st.write(f"User: {ES_USER}")
    st.write(f"Password set: {bool(ES_PASS)}")
