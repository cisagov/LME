# LME Log Analyzer

A simple Streamlit web interface for browsing Elasticsearch logs and analyzing them with AI.

## Features

- 🔍 **Search Logs** - Query any Elasticsearch index
- 🤖 **AI Analysis** - Four analysis modes:
  - 📝 Summarize - Get a quick overview
  - 🛡️ Security Analysis - Identify threats
  - 💡 Explain - Understand what's happening
  - 🔧 Remediate - Get fix suggestions
- 📊 **Multiple Views** - Table and JSON views
- ⚡ **Simple** - Just one Python file!

## Quick Start

### Local Development

```bash
cd lme-log-analyzer

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export ELASTICSEARCH_PASSWORD="your-password"

# Run the app
streamlit run app.py
```

Access at: http://localhost:8501

### Docker

```bash
# Build
docker build -t lme-log-analyzer .

# Run
docker run -p 8501:8501 \
  -e ELASTICSEARCH_PASSWORD="your-password" \
  lme-log-analyzer
```

### LME Integration

The app is deployed as a container in the LME stack when enabled in `instances.yml`:

```yaml
enable_log_analyzer: true
```

Access at: https://localhost:8501

## Configuration

Set via environment variables or `.streamlit/secrets.toml`:

- `ELASTICSEARCH_URL` - Default: `https://lme-elasticsearch:9200`
- `ELASTICSEARCH_USER` - Default: `elastic`
- `ELASTICSEARCH_PASSWORD` - **Required**
- `LITELLM_URL` - Default: `https://lme-litellm:4000`
- `LITELLM_API_KEY` - Default: `sk-lme-llama-proxy`
- `LITELLM_MODEL` - Default: `gemma-3-1b`

## Usage

1. **Select an index** from the sidebar
2. **Enter a query** (use `*` for all logs)
3. **Click "Search Logs"**
4. **Use AI buttons** to analyze the results:
   - Click any analysis button to get AI insights
5. **Browse logs** in table or JSON view

## Architecture

```
Streamlit App (Port 8501)
    ↓
    ├─→ Elasticsearch (read logs)
    └─→ LiteLLM → llama.cpp (AI analysis)
```

## File Structure

```
lme-log-analyzer/
├── app.py                    # Main Streamlit app (225 lines)
├── requirements.txt          # Python dependencies
├── Dockerfile               # Container build
├── .streamlit/
│   └── secrets.toml         # Configuration
└── README.md
```

## License

Same as LME project

