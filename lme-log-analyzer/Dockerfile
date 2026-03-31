# LME Log Analyzer - Streamlit App
FROM docker.io/library/python:3.11-slim

WORKDIR /app

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app_simple.py .

# Expose Streamlit port
EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -kf https://localhost:8501/_stcore/health || exit 1

# Run Streamlit
CMD ["streamlit", "run", "app_simple.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true"]

