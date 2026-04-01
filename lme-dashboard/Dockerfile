FROM python:3.11-slim

WORKDIR /app

# Install deps first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY static/ static/
COPY scripts/ scripts/

EXPOSE 8502

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8502"]
