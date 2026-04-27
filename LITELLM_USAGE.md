# LiteLLM Proxy Usage Guide

LiteLLM provides an OpenAI-compatible API proxy for LME's local LLM (llama.cpp) and optional cloud models.

## Quick Start

**Endpoint:** `https://localhost:4000`  
**API Key:** `sk-lme-llama-proxy`  
**Default Model:** `gemma-3-1b` (local)

## Basic Usage Examples

### 1. Simple Chat Completion

```bash
curl -k https://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-lme-llama-proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-3-1b",
    "messages": [
      {"role": "user", "content": "Explain what a SIEM is in one sentence."}
    ],
    "max_tokens": 100
  }'
```

### 2. Security Alert Analysis

```bash
curl -k https://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-lme-llama-proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-3-1b",
    "messages": [
      {
        "role": "system",
        "content": "You are a cybersecurity analyst. Provide concise security analysis."
      },
      {
        "role": "user",
        "content": "Analyze this alert: Failed SSH login attempt from 192.168.1.100"
      }
    ],
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

### 3. List Available Models

```bash
curl -k https://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-lme-llama-proxy"
```

### 4. Health Check

```bash
curl -k https://localhost:4000/health
```

## Using from Python

```python
import requests
import json

url = "https://localhost:4000/v1/chat/completions"
headers = {
    "Authorization": "Bearer sk-lme-llama-proxy",
    "Content-Type": "application/json"
}
payload = {
    "model": "gemma-3-1b",
    "messages": [
        {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 50
}

response = requests.post(url, headers=headers, json=payload, verify=False)
result = response.json()
print(result["choices"][0]["message"]["content"])
```

## Internal Container-to-Container Communication

From inside the `lme` network (e.g., from lme-elasticsearch, lme-kibana, or any container on the `lme` network):

**Endpoint:** `https://lme-litellm:4000` (same port, just use internal DNS name)

```bash
# Example: Running from inside lme-elasticsearch container
curl -k https://lme-litellm:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-lme-llama-proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-3-1b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 20
  }'
```

**Key differences for internal usage:**
- Use `https://lme-litellm:4000` instead of `https://localhost:4000`
- Same port (4000), same API, same authentication
- All communication stays within the private `lme` network
- Still uses HTTPS (self-signed certs)

## Adding Cloud Models

Edit `config/litellm_config.yaml` to add cloud providers (OpenAI, Anthropic, Azure, etc.).  
See the commented examples in that file.

Once configured, just change the `"model"` parameter:

```bash
# Use OpenAI GPT-4 instead of local model
curl -k https://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-lme-llama-proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

## Common Parameters

- `model` - Model name (e.g., "gemma-3-1b", "gpt-4")
- `messages` - Array of message objects with `role` and `content`
- `max_tokens` - Maximum tokens to generate
- `temperature` - Randomness (0.0 = deterministic, 1.0 = creative)
- `stream` - Set to `true` for streaming responses

## Notes

- The `-k` flag in curl bypasses SSL certificate verification (self-signed certs)
- For production, consider using proper SSL certificates
- API key can be changed in `config/litellm_config.yaml` (master_key)
- All requests require the `Authorization: Bearer` header

## Troubleshooting

**Check if LiteLLM is running:**
```bash
sudo podman ps | grep litellm
```

**View LiteLLM logs:**
```bash
sudo journalctl -u lme-litellm.service -f
```

**Check if llama.cpp backend is accessible:**
```bash
sudo podman exec lme-litellm curl -s http://lme-llama-cpp:8080/health
```

