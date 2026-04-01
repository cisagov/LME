"""
LME Security Dashboard - FastAPI backend
Serves the SPA and provides API endpoints for:
  - Kibana security alerts
  - Wazuh alerts (level-filtered)
  - AI chat via LiteLLM proxy
"""

import os
import json
import logging
import socket
import base64
import hashlib
import subprocess
import sys
import re
from datetime import datetime, timezone
from pathlib import Path

import httpx
import psycopg2
import yaml
from cryptography.fernet import Fernet
from fastapi import FastAPI, HTTPException, Query, UploadFile, File
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Config from environment ──────────────────────────────────────────────────
ES_URL = os.getenv("ELASTICSEARCH_URL", "https://lme-elasticsearch:9200")
ES_USER = os.getenv("ELASTICSEARCH_USER", "elastic")
ES_PASS = os.getenv("ELASTICSEARCH_PASSWORD", "")
LITELLM_URL = os.getenv("LITELLM_URL", "https://lme-litellm:4000")
LITELLM_KEY = os.getenv("LITELLM_API_KEY", "sk-lme-llama-proxy")
LITELLM_MDL = os.getenv("LITELLM_MODEL", "lfm2.5-1.2b-instruct")

# Path to LiteLLM config YAML — writable so the UI can manage models
LITELLM_CONFIG_PATH = os.getenv("LITELLM_CONFIG_PATH", "/opt/lme/config/litellm_config.yaml")

# Encrypted key storage paths
LLM_KEYS_PATH = os.getenv("LLM_KEYS_PATH", "/opt/lme/config/llm_keys.enc")
VAULT_PASS_FILE = os.getenv("VAULT_PASS_FILE", "/etc/lme/pass.sh")
LLM_KEYS_TRIGGER = os.getenv("LLM_KEYS_TRIGGER", "/opt/lme/config/.llm-keys-updated")

# ── Local model config paths ────────────────────────────────────────────────
LLAMA_MODELS_DIR = os.getenv("LLAMA_MODELS_DIR", "/opt/lme/llama-models")
LLAMA_MODEL_CONFIG = os.getenv("LLAMA_MODEL_CONFIG", "/opt/lme/config/llama-cpp-model.json")
LLAMA_MODEL_TRIGGER = os.getenv("LLAMA_MODEL_TRIGGER", "/opt/lme/config/.llama-model-updated")
LLAMA_MODEL_STATUS = os.getenv("LLAMA_MODEL_STATUS", "/opt/lme/config/llama-cpp-status.json")

# ── ElastAlert2 rules path ───────────────────────────────────────────────────
ELASTALERT_RULES_PATH = Path(
    os.getenv("ELASTALERT_RULES_PATH", "/opt/lme/config/elastalert2/rules")
)

# ── KEV config paths ─────────────────────────────────────────────────────────
KEV_CATALOG_PATH = os.getenv("KEV_CATALOG_PATH", "/opt/lme/config/wazuh_cluster/kev_catalog.json")
KEV_HISTORY_PATH = os.getenv("KEV_HISTORY_PATH", "/opt/lme/config/kev_history.json")
KEV_CONFIG_PATH = os.getenv("KEV_CONFIG_PATH", "/opt/lme/config/kev_config.json")
KEV_SYNC_SCRIPT = os.getenv("KEV_SYNC_SCRIPT", "/opt/lme/scripts/kev_sync.py")

# Mutable active-model state (updated via UI)
_active_model = {"name": LITELLM_MDL}


def _sync_active_model_from_litellm():
    """On startup, sync _active_model with what LiteLLM actually has registered."""
    import httpx as _httpx
    try:
        r = _httpx.get(
            f"{LITELLM_URL}/v1/models",
            headers={"Authorization": f"Bearer {LITELLM_KEY}"},
            verify=False,
            timeout=5,
        )
        if r.status_code == 200:
            models = [m["id"] for m in r.json().get("data", [])]
            if models and _active_model["name"] not in models:
                _active_model["name"] = models[0]
                logger.info("Synced active model to '%s' (from LiteLLM)", models[0])
    except Exception as e:
        logger.warning("Could not sync active model from LiteLLM: %s", e)


_sync_active_model_from_litellm()


# ── Encrypted key storage ────────────────────────────────────────────────────

def _get_fernet() -> Fernet:
    """Derive a Fernet key from the ansible vault password."""
    try:
        with open(VAULT_PASS_FILE, "r") as f:
            content = f.read().strip()
        # pass.sh is a script that echoes the password; extract it
        # Look for the echo/printf line
        vault_pass = ""
        for line in content.splitlines():
            line = line.strip()
            if line.startswith("echo") or line.startswith("printf"):
                # Extract quoted string
                for q in ('"', "'"):
                    if q in line:
                        parts = line.split(q)
                        if len(parts) >= 2:
                            vault_pass = parts[1]
                            break
                if vault_pass:
                    break
            elif not line.startswith("#") and not line.startswith("!") and line:
                vault_pass = line
        if not vault_pass:
            vault_pass = content
    except FileNotFoundError:
        # Fallback key for development — not for production
        vault_pass = "lme-dev-key-not-for-production"
        logger.warning("Vault password file not found, using development fallback")

    # Derive a 32-byte Fernet key from the vault password using PBKDF2
    key = hashlib.pbkdf2_hmac("sha256", vault_pass.encode(), b"lme-llm-keys", 100000)
    return Fernet(base64.urlsafe_b64encode(key))


def _read_llm_keys() -> dict:
    """Read and decrypt the LLM API keys store."""
    try:
        with open(LLM_KEYS_PATH, "rb") as f:
            encrypted = f.read()
        if not encrypted:
            return {}
        fernet = _get_fernet()
        decrypted = fernet.decrypt(encrypted)
        return json.loads(decrypted)
    except FileNotFoundError:
        return {}
    except Exception as e:
        logger.error(f"Failed to decrypt LLM keys: {e}")
        return {}


def _write_llm_keys(keys: dict):
    """Encrypt and write the LLM API keys store, then signal for sync."""
    fernet = _get_fernet()
    encrypted = fernet.encrypt(json.dumps(keys).encode())
    with open(LLM_KEYS_PATH, "wb") as f:
        f.write(encrypted)
    # Touch the trigger file so the host-side systemd unit picks up the change
    Path(LLM_KEYS_TRIGGER).touch()


def _env_var_name(provider: str) -> str:
    """Convert a provider name to an env var name for LiteLLM."""
    return f"LME_LLM_KEY_{provider.upper()}"


# httpx clients — both ES and LiteLLM use self-signed certs
PGVECTOR_HOST = os.getenv("PGVECTOR_HOST", "lme-pgvector")
PGVECTOR_PORT = int(os.getenv("PGVECTOR_PORT", "5432"))
PGVECTOR_DB = os.getenv("PGVECTOR_DB", "lme_vectors")
PGVECTOR_USER = os.getenv("PGVECTOR_USER", "lme")
PGVECTOR_PASS = os.getenv("PGVECTOR_PASS", "")
EMBED_URL = os.getenv("EMBED_URL", "http://lme-embeddings:8081")
RAG_TOP_K = int(os.getenv("RAG_TOP_K", "10"))
RAG_MIN_SIM = float(os.getenv("RAG_MIN_SIM", "0.55"))  # drop chunks below this similarity
RAG_MIN_CHARS = int(os.getenv("RAG_MIN_CHARS", "200"))   # drop stub/redirect chunks

ES_AUTH = (ES_USER, ES_PASS)
VERIFY_SSL = False          # internal self-signed certs

app = FastAPI(title="LME Dashboard", docs_url=None, redoc_url=None)

# ── Helpers ──────────────────────────────────────────────────────────────────


def es_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(verify=VERIFY_SSL, timeout=15)


def llm_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(verify=VERIFY_SSL, timeout=300)


def _severity_order(s: str) -> int:
    return {"critical": 0, "high": 1, "medium": 2, "low": 3}.get(s.lower(), 4)

# ── API routes ────────────────────────────────────────────────────────────────


@app.get("/api/health")
async def health():
    """Quick connectivity check for both ES and LiteLLM."""
    status = {"elasticsearch": "unknown", "litellm": "unknown", "es_password_set": bool(ES_PASS)}
    async with es_client() as c:
        try:
            r = await c.get(f"{ES_URL}/_cluster/health", auth=ES_AUTH)
            status["elasticsearch"] = r.json().get("status", "error")
        except Exception as e:
            status["elasticsearch"] = f"error: {e}"
    async with llm_client() as c:
        try:
            r = await c.get(f"{LITELLM_URL}/health",
                            headers={"Authorization": f"Bearer {LITELLM_KEY}"})
            status["litellm"] = "ok" if r.status_code < 400 else f"http {r.status_code}"
        except Exception as e:
            status["litellm"] = f"error: {e}"
    # pgvector — TCP reachability check (no extra deps needed)
    try:
        sock = socket.create_connection((PGVECTOR_HOST, PGVECTOR_PORT), timeout=3)
        sock.close()
        status["pgvector"] = "ok"
    except Exception as e:
        status["pgvector"] = f"error: {e}"
    return status


@app.get("/api/alerts/kibana")
async def kibana_alerts(
    min_severity: str = Query("medium", description="Minimum severity: low|medium|high|critical"),
    size: int = Query(50, ge=1, le=500),
    time_from: str = Query("now-24h", description="Start of time range (ES date math, e.g. now-24h)"),
    time_to: str = Query("now", description="End of time range (ES date math, e.g. now)"),
    search_after: str = Query("", description="Cursor for pagination (timestamp,doc_id from previous page)"),
):
    """Return Kibana security detection rule alerts, newest first."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    severity_rank = _severity_order(min_severity)
    accepted = [s for s in ("critical", "high", "medium", "low") if _severity_order(s) <= severity_rank]

    query = {
        "size": size,
        "sort": [{"@timestamp": {"order": "desc"}}, {"_doc": {"order": "desc"}}],
        "query": {
            "bool": {
                "filter": [
                    {"terms": {"kibana.alert.severity": accepted}},
                    {"range": {"@timestamp": {"gte": time_from, "lte": time_to}}},
                ]
            }
        },
        "_source": [
            "@timestamp",
            "kibana.alert.rule.name",
            "kibana.alert.severity",
            "kibana.alert.reason",
            "kibana.alert.status",
            "host.name",
            "user.name",
            "source.ip",
            "destination.ip",
            "process.command_line",
            "event.action",
            "rule.name",
        ],
    }

    if search_after:
        parts = search_after.split(",", 1)
        if len(parts) == 2:
            query["search_after"] = [parts[0], parts[1]]

    async with es_client() as c:
        try:
            r = await c.post(
                f"{ES_URL}/.alerts-security.alerts-*/_search",
                auth=ES_AUTH,
                json=query,
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(e.response.status_code, f"Elasticsearch error: {e.response.text[:200]}")
        except Exception as e:
            raise HTTPException(502, f"Elasticsearch unreachable: {e}")

    data = r.json()
    hits = data.get("hits", {}).get("hits", [])
    total = data.get("hits", {}).get("total", {}).get("value", 0)

    def _get(s, *keys, default=""):
        """Resolve a field that may be dot-notation flat or nested object."""
        for key in keys:
            # Try dot-notation flat key first (kibana.alert.xxx style)
            if key in s:
                val = s[key]
                if isinstance(val, list):
                    val = val[0] if val else default
                return val if val is not None else default
            # Try nested object traversal (host.name → s["host"]["name"])
            parts = key.split(".")
            val = s
            for p in parts:
                if isinstance(val, dict):
                    val = val.get(p)
                else:
                    val = None
                    break
            if val is not None:
                if isinstance(val, list):
                    val = val[0] if val else default
                return val
        return default

    alerts = []
    for h in hits:
        s = h["_source"]
        alerts.append({
            "id": h["_id"],
            "timestamp": s.get("@timestamp", ""),
            "rule_name": _get(s, "kibana.alert.rule.name", "rule.name") or "Unknown",
            "severity": _get(s, "kibana.alert.severity", default="unknown"),
            "reason": _get(s, "kibana.alert.reason"),
            "status": _get(s, "kibana.alert.status"),
            "host": _get(s, "host.name"),
            "user": _get(s, "user.name"),
            "src_ip": _get(s, "source.ip"),
            "dst_ip": _get(s, "destination.ip"),
            "command": _get(s, "process.command_line"),
            "action": _get(s, "event.action"),
            "_raw": s,
        })

    next_cursor = ""
    if hits:
        last_sort = hits[-1].get("sort", [])
        if len(last_sort) >= 2:
            next_cursor = f"{last_sort[0]},{last_sort[1]}"

    return {"total": total, "returned": len(alerts), "alerts": alerts, "next_cursor": next_cursor}


@app.get("/api/alerts/wazuh")
async def wazuh_alerts(
    min_level: int = Query(7, ge=0, le=15, description="Minimum Wazuh rule level (0-15)"),
    size: int = Query(50, ge=1, le=500),
    time_from: str = Query("now-24h", description="Start of time range (ES date math, e.g. now-24h)"),
    time_to: str = Query("now", description="End of time range (ES date math, e.g. now)"),
    search_after: str = Query("", description="Cursor for pagination (timestamp,doc_id from previous page)"),
):
    """Return Wazuh alerts at or above min_level, newest first."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    query = {
        "size": size,
        "sort": [{"@timestamp": {"order": "desc"}}, {"_doc": {"order": "desc"}}],
        "query": {
            "bool": {
                "filter": [
                    {"range": {"rule.level": {"gte": min_level}}},
                    {"range": {"@timestamp": {"gte": time_from, "lte": time_to}}},
                ]
            }
        },
        "_source": [
            "@timestamp",
            "rule.level",
            "rule.description",
            "rule.id",
            "rule.groups",
            "agent.name",
            "agent.ip",
            "data.srcip",
            "data.dstip",
            "data.win.system.computer",
            "data.win.eventdata.commandLine",
            "full_log",
            "location",
        ],
    }

    if search_after:
        parts = search_after.split(",", 1)
        if len(parts) == 2:
            query["search_after"] = [parts[0], parts[1]]

    async with es_client() as c:
        try:
            r = await c.post(
                f"{ES_URL}/wazuh-alerts-*/_search",
                auth=ES_AUTH,
                json=query,
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"total": 0, "returned": 0, "alerts": [], "next_cursor": "", "note": "No wazuh-alerts-* index found"}
            raise HTTPException(e.response.status_code, f"Elasticsearch error: {e.response.text[:200]}")
        except Exception as e:
            raise HTTPException(502, f"Elasticsearch unreachable: {e}")

    data = r.json()
    hits = data.get("hits", {}).get("hits", [])
    total = data.get("hits", {}).get("total", {}).get("value", 0)

    alerts = []
    for h in hits:
        s = h["_source"]
        rule = s.get("rule", {})
        agent = s.get("agent", {})
        data_block = s.get("data", {})

        level = rule.get("level", 0)
        # Map numeric level to a display severity
        if level >= 12:
            sev = "critical"
        elif level >= 9:
            sev = "high"
        elif level >= 6:
            sev = "medium"
        else:
            sev = "low"

        alerts.append({
            "id": h["_id"],
            "timestamp": s.get("@timestamp", ""),
            "rule_id": rule.get("id", ""),
            "rule_name": rule.get("description", "Unknown"),
            "level": level,
            "severity": sev,
            "groups": rule.get("groups", []),
            "agent_name": agent.get("name", ""),
            "agent_ip": agent.get("ip", ""),
            "src_ip": data_block.get("srcip", ""),
            "dst_ip": data_block.get("dstip", ""),
            "full_log": s.get("full_log", "")[:500],
            "location": s.get("location", ""),
            "_raw": s,
        })

    next_cursor = ""
    if hits:
        last_sort = hits[-1].get("sort", [])
        if len(last_sort) >= 2:
            next_cursor = f"{last_sort[0]},{last_sort[1]}"

    return {"total": total, "returned": len(alerts), "alerts": alerts, "next_cursor": next_cursor}


# ── Vulnerability endpoints ───────────────────────────────────────────────────

VULN_INDEX = "wazuh-states-vulnerabilities-*"


@app.get("/api/vulnerabilities")
async def vulnerabilities_overview():
    """Return per-agent vulnerability summary, sorted most-to-least vulnerable."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    query = {
        "size": 0,
        "aggs": {
            "by_agent": {
                "terms": {"field": "agent.name", "size": 500},
                "aggs": {
                    "agent_id": {"terms": {"field": "agent.id", "size": 1}},
                    "os": {"terms": {"field": "host.os.full", "size": 1}},
                    "by_severity": {"terms": {"field": "vulnerability.severity", "size": 10}},
                    "max_score": {"max": {"field": "vulnerability.score.base"}},
                    "risk_score": {
                        "weighted_avg": {
                            "value": {"field": "vulnerability.score.base"},
                            "weight": {"script": {
                                "source": """
                                    String s = doc['vulnerability.severity'].size() > 0 ? doc['vulnerability.severity'].value : '';
                                    if (s == 'Critical') return 10;
                                    if (s == 'High') return 5;
                                    if (s == 'Medium') return 2;
                                    if (s == 'Low') return 1;
                                    return 0.5;
                                """
                            }}
                        }
                    },
                }
            }
        }
    }

    async with es_client() as c:
        try:
            r = await c.post(f"{ES_URL}/{VULN_INDEX}/_search", auth=ES_AUTH, json=query)
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"agents": [], "total_vulnerabilities": 0}
            raise HTTPException(e.response.status_code, f"Elasticsearch error: {e.response.text[:200]}")
        except Exception as e:
            raise HTTPException(502, f"Elasticsearch unreachable: {e}")

    data = r.json()
    buckets = data.get("aggregations", {}).get("by_agent", {}).get("buckets", [])

    agents = []
    total_vulns = 0
    for b in buckets:
        sev_map = {s["key"]: s["doc_count"] for s in b["by_severity"]["buckets"]}
        count = b["doc_count"]
        total_vulns += count
        agent_id_buckets = b["agent_id"]["buckets"]
        os_buckets = b["os"]["buckets"]
        agents.append({
            "agent_name": b["key"],
            "agent_id": agent_id_buckets[0]["key"] if agent_id_buckets else "",
            "os": os_buckets[0]["key"] if os_buckets else "",
            "total": count,
            "critical": sev_map.get("Critical", 0),
            "high": sev_map.get("High", 0),
            "medium": sev_map.get("Medium", 0),
            "low": sev_map.get("Low", 0),
            "unrated": sev_map.get("", 0),
            "max_cvss": b["max_score"]["value"] or 0,
            "risk_score": round(b["risk_score"]["value"] or 0, 1),
        })

    # Sort: most vulnerable first (by weighted risk score desc, then total desc)
    agents.sort(key=lambda a: (a["critical"], a["risk_score"], a["total"]), reverse=True)

    return {"agents": agents, "total_vulnerabilities": total_vulns}


@app.get("/api/vulnerabilities/{agent_id}")
async def vulnerabilities_detail(
    agent_id: str,
    severity: str = Query("", description="Filter by severity: Critical|High|Medium|Low"),
    size: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0, description="Number of results to skip for pagination"),
):
    """Return individual CVEs for a specific agent, paginated."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    filters = [{"term": {"agent.id": agent_id}}]
    if severity:
        filters.append({"term": {"vulnerability.severity": severity}})

    query = {
        "from": offset,
        "size": size,
        "sort": [{"vulnerability.score.base": {"order": "desc", "missing": "_last"}}],
        "query": {"bool": {"filter": filters}},
        "_source": [
            "vulnerability.id", "vulnerability.severity", "vulnerability.score.base",
            "vulnerability.description", "vulnerability.detected_at", "vulnerability.published_at",
            "vulnerability.reference", "package.name", "package.version",
            "agent.name", "host.os.full",
        ],
    }

    async with es_client() as c:
        try:
            r = await c.post(f"{ES_URL}/{VULN_INDEX}/_search", auth=ES_AUTH, json=query)
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"total": 0, "vulnerabilities": []}
            raise HTTPException(e.response.status_code, f"Elasticsearch error: {e.response.text[:200]}")
        except Exception as e:
            raise HTTPException(502, f"Elasticsearch unreachable: {e}")

    data = r.json()
    hits = data.get("hits", {}).get("hits", [])
    total = data.get("hits", {}).get("total", {}).get("value", 0)

    # Load KEV catalog for cross-reference
    kev_cves = _read_kev_catalog().get("cves", {})

    vulns = []
    for h in hits:
        s = h["_source"]
        v = s.get("vulnerability", {})
        p = s.get("package", {})
        cve_id = v.get("id", "")
        kev_info = kev_cves.get(cve_id)
        entry = {
            "cve_id": cve_id,
            "severity": v.get("severity", ""),
            "cvss": v.get("score", {}).get("base"),
            "description": v.get("description", ""),
            "detected_at": v.get("detected_at", ""),
            "published_at": v.get("published_at", ""),
            "reference": v.get("reference", ""),
            "package": p.get("name", ""),
            "package_version": p.get("version", ""),
            "is_kev": kev_info is not None,
        }
        if kev_info:
            entry["kev_due_date"] = kev_info.get("dueDate", "")
            entry["kev_ransomware"] = kev_info.get("knownRansomwareCampaignUse", "Unknown")
            entry["kev_name"] = kev_info.get("vulnerabilityName", "")
        vulns.append(entry)

    return {"total": total, "returned": len(vulns), "vulnerabilities": vulns}


# ── Chat / LLM endpoints ──────────────────────────────────────────────────────

class KevSettingsRequest(BaseModel):
    auto_pull: bool = True
    frequency_hours: int = 24          # 6 | 12 | 24 | 168 (weekly)
    alert_on_match: bool = True
    alert_on_overdue: bool = True
    ransomware_only: bool = False


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    stream: bool = False


class AnalyzeRequest(BaseModel):
    alert: dict
    source: str = "kibana"   # "kibana" or "wazuh"


@app.post("/api/chat")
async def chat(req: ChatRequest):
    """Forward a chat conversation to LiteLLM. Returns full response."""
    payload = {
        "model": _active_model["name"],
        "messages": [m.model_dump() for m in req.messages],
        "temperature": 0.7,
        "max_tokens": 800,
    }
    async with llm_client() as c:
        try:
            r = await c.post(
                f"{LITELLM_URL}/v1/chat/completions",
                headers={"Authorization": f"Bearer {LITELLM_KEY}",
                         "Content-Type": "application/json"},
                json=payload,
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(e.response.status_code, f"LLM error: {e.response.text[:300]}")
        except Exception as e:
            raise HTTPException(502, f"LLM unreachable: {e}")

    result = r.json()
    return {"content": result["choices"][0]["message"]["content"]}


@app.post("/api/chat/stream")
async def chat_stream(req: ChatRequest):
    """SSE streaming chat via LiteLLM."""
    payload = {
        "model": _active_model["name"],
        "messages": [m.model_dump() for m in req.messages],
        "temperature": 0.7,
        "max_tokens": 800,
        "stream": True,
    }

    async def event_generator():
        async with llm_client() as c:
            try:
                async with c.stream(
                    "POST",
                    f"{LITELLM_URL}/v1/chat/completions",
                    headers={"Authorization": f"Bearer {LITELLM_KEY}",
                             "Content-Type": "application/json"},
                    json=payload,
                ) as resp:
                    if resp.status_code != 200:
                        body = await resp.aread()
                        try:
                            detail = json.loads(body).get("error", {})
                            if isinstance(detail, dict):
                                detail = detail.get("message", str(detail))
                        except Exception:
                            detail = body.decode(errors="replace")
                        yield f"data: {json.dumps({'error': f'LLM error ({resp.status_code}): {detail}'})}\n\n"
                        return
                    async for line in resp.aiter_lines():
                        if line.startswith("data: "):
                            chunk = line[6:]
                            if chunk.strip() == "[DONE]":
                                yield "data: [DONE]\n\n"
                                return
                            try:
                                obj = json.loads(chunk)
                                delta = obj["choices"][0].get("delta", {})
                                if "content" in delta and delta["content"]:
                                    yield f"data: {json.dumps({'content': delta['content']})}\n\n"
                            except Exception:
                                pass
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@app.post("/api/analyze")
async def analyze_alert(req: AnalyzeRequest):
    """Ask the LLM to analyze a specific alert."""
    alert_json = json.dumps(req.alert, indent=2)[:2000]   # cap context size
    source_label = "Kibana security detection rule" if req.source == "kibana" else "Wazuh threat detection"

    prompt = f"""You are a security analyst. Analyze this {source_label} alert concisely.

Alert:
{alert_json}

Reply with exactly three sections (be brief, 1-2 sentences each):
**What happened:** [describe the event]
**Risk:** [severity and why it matters]
**Action:** [recommended immediate response]"""

    payload = {
        "model": _active_model["name"],
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 400,
    }
    async with llm_client() as c:
        try:
            r = await c.post(
                f"{LITELLM_URL}/v1/chat/completions",
                headers={"Authorization": f"Bearer {LITELLM_KEY}",
                         "Content-Type": "application/json"},
                json=payload,
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(e.response.status_code, f"LLM error: {e.response.text[:300]}")
        except Exception as e:
            raise HTTPException(502, f"LLM unreachable: {e}")

    result = r.json()
    return {"analysis": result["choices"][0]["message"]["content"]}


# ── RAG helpers ──────────────────────────────────────────────────────────────

def _pg_conn():
    return psycopg2.connect(
        host=PGVECTOR_HOST, port=PGVECTOR_PORT, dbname=PGVECTOR_DB,
        user=PGVECTOR_USER, password=PGVECTOR_PASS,
        connect_timeout=5,
    )


async def _embed_query(query: str) -> list[float]:
    """Embed a single query string via the lme-embeddings llama.cpp server."""
    async with httpx.AsyncClient(verify=VERIFY_SSL, timeout=30) as c:
        r = await c.post(
            f"{EMBED_URL}/v1/embeddings",
            json={"model": "nomic-embed-text", "input": query},
        )
        r.raise_for_status()
    return r.json()["data"][0]["embedding"]


async def _retrieve_context(query: str, top_k: int = RAG_TOP_K) -> list[dict]:
    """
    Embed query, fetch candidate chunks from pgvector, then filter:
    - drop chunks below RAG_MIN_SIM (off-topic noise)
    - drop stub chunks shorter than RAG_MIN_CHARS (FAQ redirects, empty sections)
    - deduplicate by (url, section) keeping the highest-similarity chunk
    Returns at most top_k chunks after filtering.
    """
    emb = await _embed_query(query)
    vec_str = f"[{','.join(str(x) for x in emb)}]"

    # Fetch 5x top_k candidates so filtering still leaves enough good chunks
    fetch_k = top_k * 5

    try:
        conn = _pg_conn()
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT url, title, section, content,
                       1 - (embedding <=> %s::vector) AS similarity
                FROM docs_chunks
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (vec_str, vec_str, fetch_k),
            )
            rows = cur.fetchall()
        conn.close()
    except Exception as e:
        logger.warning(f"RAG retrieval failed: {e}")
        return []

    seen = {}
    filtered = []
    for url, title, section, content, sim in rows:
        sim = float(sim)
        # Drop low-similarity and stub chunks
        if sim < RAG_MIN_SIM:
            continue
        if len(content.strip()) < RAG_MIN_CHARS:
            continue
        # Deduplicate: keep highest-sim chunk per (url, section)
        key = (url, section)
        if key in seen:
            continue
        seen[key] = True
        filtered.append({"url": url, "title": title, "section": section,
                         "content": content, "similarity": sim})
        if len(filtered) >= top_k:
            break

    return filtered


def _build_rag_system_prompt(chunks: list[dict]) -> str:
    """Build a system prompt that injects retrieved doc context."""
    context_parts = []
    for i, c in enumerate(chunks, 1):
        source = f"{c['title']} — {c['section']}" if c["section"] else c["title"]
        context_parts.append(f"[{i}] {source}\n{c['content'][:500]}")

    context_block = "\n\n".join(context_parts)

    return (
        "You are an LME documentation assistant. "
        "Answer in 1-2 sentences using only the text below. "
        "Do not invent commands or steps.\n\n"
        f"{context_block}"
    )


_NOT_FOUND_PHRASES = [
    "i could not find that in the lme documentation",
    "i could not find that information",
    "i could not find the answer",
    "read more:",
]


def _clean_rag_response(text: str, best_url: str) -> str:
    """Strip hallucinated 'not found' phrases and append the correct URL."""
    lines = []
    for line in text.splitlines():
        lower = line.strip().lower()
        if any(lower.startswith(p) for p in _NOT_FOUND_PHRASES):
            continue
        lines.append(line)
    cleaned = "\n".join(lines).strip()
    return f"{cleaned}\n\nRead more: {best_url}"


class RagChatRequest(BaseModel):
    messages: list[ChatMessage]
    stream: bool = False
    top_k: int = RAG_TOP_K


@app.post("/api/chat/rag")
async def chat_rag(req: RagChatRequest):
    """RAG-augmented chat: retrieves relevant LME doc chunks, then calls LLM."""
    # Use the last user message as the retrieval query
    user_query = next(
        (m.content for m in reversed(req.messages) if m.role == "user"), ""
    )

    chunks = await _retrieve_context(user_query, top_k=req.top_k)
    system_prompt = _build_rag_system_prompt(chunks)

    messages = [{"role": "system", "content": system_prompt}]
    messages += [m.model_dump() for m in req.messages]

    payload = {
        "model": _active_model["name"],
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 250,
    }

    async with llm_client() as c:
        try:
            r = await c.post(
                f"{LITELLM_URL}/v1/chat/completions",
                headers={"Authorization": f"Bearer {LITELLM_KEY}",
                         "Content-Type": "application/json"},
                json=payload,
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(e.response.status_code, f"LLM error: {e.response.text[:300]}")
        except Exception as e:
            raise HTTPException(502, f"LLM unreachable: {e}")

    result = r.json()
    return {
        "content": result["choices"][0]["message"]["content"],
        "sources": [
            {"url": c["url"], "title": c["title"],
             "section": c["section"], "similarity": c["similarity"],
             "excerpt": c["content"][:200].strip()}
            for c in chunks
        ],
    }


@app.post("/api/chat/rag/stream")
async def chat_rag_stream(req: RagChatRequest):
    """SSE streaming RAG chat."""
    user_query = next(
        (m.content for m in reversed(req.messages) if m.role == "user"), ""
    )

    chunks = await _retrieve_context(user_query, top_k=req.top_k)

    # If no relevant chunks found, skip the LLM entirely
    if not chunks:
        async def not_found():
            yield f"data: {json.dumps({'sources': []})}\n\n"
            yield f"data: {json.dumps({'content': 'I could not find that in the LME documentation. '})}\n\n"
            yield f"data: {json.dumps({'content': 'Read more: https://cisagov.github.io/lme-docs/'})}\n\n"
            yield "data: [DONE]\n\n"
        return StreamingResponse(not_found(), media_type="text/event-stream")

    system_prompt = _build_rag_system_prompt(chunks)

    messages = [{"role": "system", "content": system_prompt}]
    messages += [m.model_dump() for m in req.messages]

    payload = {
        "model": _active_model["name"],
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 250,
        "stream": True,
    }

    sources_event = json.dumps({
        "sources": [
            {"url": c["url"], "title": c["title"],
             "section": c["section"], "similarity": c["similarity"],
             "excerpt": c["content"][:200].strip()}
            for c in chunks
        ]
    })

    best_url = chunks[0]["url"]

    async def event_generator():
        # First event carries the sources so the UI can render citations
        yield f"data: {sources_event}\n\n"

        # Buffer full response, then clean and emit
        full_text = ""
        async with llm_client() as c:
            try:
                async with c.stream(
                    "POST",
                    f"{LITELLM_URL}/v1/chat/completions",
                    headers={"Authorization": f"Bearer {LITELLM_KEY}",
                             "Content-Type": "application/json"},
                    json=payload,
                ) as resp:
                    if resp.status_code != 200:
                        body = await resp.aread()
                        try:
                            detail = json.loads(body).get("error", {})
                            if isinstance(detail, dict):
                                detail = detail.get("message", str(detail))
                        except Exception:
                            detail = body.decode(errors="replace")
                        yield f"data: {json.dumps({'error': f'LLM error ({resp.status_code}): {detail}'})}\n\n"
                        return
                    async for line in resp.aiter_lines():
                        if line.startswith("data: "):
                            chunk_data = line[6:]
                            if chunk_data.strip() == "[DONE]":
                                break
                            try:
                                obj = json.loads(chunk_data)
                                delta = obj["choices"][0].get("delta", {})
                                if "content" in delta and delta["content"]:
                                    full_text += delta["content"]
                            except Exception:
                                pass
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"
                return

        cleaned = _clean_rag_response(full_text, best_url)
        yield f"data: {json.dumps({'content': cleaned})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


# ── Model management endpoints ───────────────────────────────────────────────

PROVIDER_TEMPLATES = {
    "local": {
        "label": "Local (llama.cpp)",
        "prefix": "openai/",
        "api_base": "http://lme-llama-cpp:8080/v1",
        "api_key": "dummy",
        "needs_api_key": False,
    },
    "openai": {
        "label": "OpenAI",
        "prefix": "",
        "models": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
        "needs_api_key": True,
    },
    "anthropic": {
        "label": "Anthropic Claude",
        "prefix": "",
        "models": ["claude-sonnet-4-20250514", "claude-3-5-sonnet-20241022", "claude-3-haiku-20240307"],
        "needs_api_key": True,
    },
    "openrouter": {
        "label": "OpenRouter",
        "prefix": "openrouter/",
        "api_base": "https://openrouter.ai/api/v1",
        "models": ["openai/gpt-4o", "anthropic/claude-sonnet-4", "google/gemini-2.0-flash-exp:free", "meta-llama/llama-3-70b-instruct"],
        "needs_api_key": True,
    },
}


def _read_litellm_config() -> dict:
    """Read the litellm_config.yaml file."""
    try:
        with open(LITELLM_CONFIG_PATH, "r") as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {"model_list": [], "general_settings": {"master_key": LITELLM_KEY},
                "litellm_settings": {"drop_params": True, "success_callback": [], "failure_callback": []}}


def _write_litellm_config(config: dict):
    """Write the litellm_config.yaml file."""
    with open(LITELLM_CONFIG_PATH, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


@app.get("/api/models")
async def get_models():
    """Return configured models and the currently active model."""
    config = _read_litellm_config()
    keys = _read_llm_keys()
    models = []
    for entry in config.get("model_list", []):
        params = entry.get("litellm_params", {})
        model_name = entry.get("model_name", "")
        # Determine if key is set: check encrypted store for the provider
        api_key_ref = params.get("api_key", "")
        has_key = False
        provider = ""
        if isinstance(api_key_ref, str) and api_key_ref.startswith("os.environ/"):
            env_name = api_key_ref.split("/", 1)[1]
            # Reverse-lookup provider from env var name
            for p in PROVIDER_TEMPLATES:
                if _env_var_name(p) == env_name:
                    provider = p
                    break
            has_key = env_name in keys or bool(os.getenv(env_name))
        elif api_key_ref and api_key_ref != "dummy":
            has_key = True
        models.append({
            "model_name": model_name,
            "litellm_model": params.get("model", ""),
            "api_base": params.get("api_base", ""),
            "has_api_key": has_key,
            "provider": provider,
        })
    return {
        "active_model": _active_model["name"],
        "models": models,
        "providers": PROVIDER_TEMPLATES,
    }


class AddModelRequest(BaseModel):
    model_name: str
    provider: str
    litellm_model: str = ""
    api_key: str = ""
    api_base: str = ""


@app.post("/api/models")
async def add_model(req: AddModelRequest):
    """Add or update a model in litellm_config.yaml.
    API keys are stored encrypted — the YAML only contains os.environ/ references.
    """
    config = _read_litellm_config()
    if "model_list" not in config:
        config["model_list"] = []

    template = PROVIDER_TEMPLATES.get(req.provider, {})

    # Build litellm_params
    params = {}
    prefix = template.get("prefix", "")
    if req.litellm_model:
        params["model"] = f"{prefix}{req.litellm_model}" if prefix and not req.litellm_model.startswith(prefix) else req.litellm_model
    else:
        params["model"] = req.model_name

    if req.api_base:
        params["api_base"] = req.api_base
    elif "api_base" in template:
        params["api_base"] = template["api_base"]

    # Handle API key: store encrypted, put env var reference in YAML
    needs_restart = False
    if req.api_key:
        env_name = _env_var_name(req.provider)
        # Store the key encrypted
        keys = _read_llm_keys()
        keys[env_name] = req.api_key
        _write_llm_keys(keys)
        # YAML gets the env var reference — never the raw key
        params["api_key"] = f"os.environ/{env_name}"
        needs_restart = True
    elif template.get("api_key"):
        params["api_key"] = template["api_key"]

    # Remove existing model with same name (update)
    config["model_list"] = [
        m for m in config["model_list"] if m.get("model_name") != req.model_name
    ]

    config["model_list"].append({
        "model_name": req.model_name,
        "litellm_params": params,
    })

    _write_litellm_config(config)

    msg = f"Model '{req.model_name}' added."
    if needs_restart:
        msg += " LiteLLM will restart to pick up the new key."
    else:
        msg += " Restart LiteLLM to apply."
    return {"status": "ok", "message": msg, "needs_restart": needs_restart}


@app.delete("/api/models/{model_name}")
async def delete_model(model_name: str):
    """Remove a model from litellm_config.yaml."""
    config = _read_litellm_config()
    original_len = len(config.get("model_list", []))

    # Find the model to get its provider key reference before removing
    removed_entry = None
    for m in config.get("model_list", []):
        if m.get("model_name") == model_name:
            removed_entry = m
            break

    config["model_list"] = [
        m for m in config.get("model_list", []) if m.get("model_name") != model_name
    ]
    if len(config["model_list"]) == original_len:
        raise HTTPException(404, f"Model '{model_name}' not found")

    # Check if any remaining models use the same provider key; if not, clean it up
    if removed_entry:
        removed_key_ref = removed_entry.get("litellm_params", {}).get("api_key", "")
        if isinstance(removed_key_ref, str) and removed_key_ref.startswith("os.environ/"):
            env_name = removed_key_ref.split("/", 1)[1]
            still_used = any(
                m.get("litellm_params", {}).get("api_key") == removed_key_ref
                for m in config["model_list"]
            )
            if not still_used:
                keys = _read_llm_keys()
                keys.pop(env_name, None)
                _write_llm_keys(keys)

    _write_litellm_config(config)

    # If deleted model was active, fall back to first available or default
    if _active_model["name"] == model_name:
        if config["model_list"]:
            _active_model["name"] = config["model_list"][0]["model_name"]
        else:
            _active_model["name"] = LITELLM_MDL

    return {"status": "ok", "message": f"Model '{model_name}' removed. LiteLLM will restart to apply."}


class SetActiveModelRequest(BaseModel):
    model_name: str


@app.post("/api/models/active")
async def set_active_model(req: SetActiveModelRequest):
    """Set which model the dashboard uses for chat/analysis."""
    _active_model["name"] = req.model_name
    return {"status": "ok", "active_model": req.model_name}


# ── Local model management ──────────────────────────────────────────────────

def _get_active_local_model() -> str:
    """Read the currently configured local model from the config file."""
    try:
        with open(LLAMA_MODEL_CONFIG, "r") as f:
            return json.load(f).get("model", "")
    except (FileNotFoundError, json.JSONDecodeError):
        # Fall back: parse the quadlet file for the current --model value
        return ""


def _get_local_model_status() -> dict:
    """Read the status file written by the host-side switch script."""
    try:
        with open(LLAMA_MODEL_STATUS, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"status": "unknown"}


@app.get("/api/local-models")
async def list_local_models():
    """List available .gguf model files and the currently active local model."""
    models = []
    try:
        for entry in sorted(os.listdir(LLAMA_MODELS_DIR)):
            if entry.lower().endswith(".gguf"):
                filepath = os.path.join(LLAMA_MODELS_DIR, entry)
                stat = os.stat(filepath)
                size_mb = round(stat.st_size / (1024 * 1024), 1)
                models.append({
                    "filename": entry,
                    "size_mb": size_mb,
                })
    except FileNotFoundError:
        pass

    active_model = _get_active_local_model()
    status = _get_local_model_status()

    return {
        "models": models,
        "active_model": active_model,
        "status": status,
    }


class SwitchLocalModelRequest(BaseModel):
    model: str  # just the filename, e.g. "LFM2.5-1.2B-Instruct-Q4_K_M.gguf"


@app.post("/api/local-models/switch")
async def switch_local_model(req: SwitchLocalModelRequest):
    """Request a local model switch. Writes config, updates LiteLLM config, and triggers host-side restart."""
    filename = req.model

    # Validate: simple filename only, no path traversal
    if "/" in filename or ".." in filename or not filename.lower().endswith(".gguf"):
        raise HTTPException(400, "Invalid model filename")

    # Verify the file exists
    model_path = os.path.join(LLAMA_MODELS_DIR, filename)
    if not os.path.isfile(model_path):
        raise HTTPException(404, f"Model file not found: {filename}")

    # Derive a friendly display name from the filename
    # e.g. "gemma-3-1b-it.Q4_K_M.gguf" → "gemma-3-1b-it"
    # e.g. "LFM2.5-1.2B-Instruct-Q4_K_M.gguf" → "lfm2.5-1.2b-instruct"
    import re as _re
    stem = filename.rsplit(".gguf", 1)[0]  # strip .gguf
    # Strip quantization suffixes like Q4_K_M, Q8_0, F16, BF16 (may use . - or _ as separator)
    stem = _re.sub(r'[.\-_](?:Q\d[._]?\w*|[FB]F?\d+)$', '', stem, flags=_re.IGNORECASE)
    display_name = stem.lower()

    # Update the local model entry in litellm_config.yaml
    model_id_for_litellm = f"openai/{filename.rsplit('.gguf', 1)[0]}"
    config = _read_litellm_config()
    if "model_list" not in config:
        config["model_list"] = []

    # Find and update the local model entry (api_base pointing at llama-cpp)
    found = False
    for entry in config["model_list"]:
        params = entry.get("litellm_params", {})
        api_base = params.get("api_base", "")
        if "lme-llama-cpp" in api_base:
            entry["model_name"] = display_name
            params["model"] = model_id_for_litellm
            found = True
            break

    if not found:
        # Create a new local entry
        config["model_list"].insert(0, {
            "model_name": display_name,
            "litellm_params": {
                "model": model_id_for_litellm,
                "api_base": "https://lme-llama-cpp:8080/v1",
                "api_key": "dummy",
                "ssl_verify": False,
            },
        })

    _write_litellm_config(config)

    # Update the dashboard's active model to the new name
    _active_model["name"] = display_name

    # Write "switching" status BEFORE triggering, so the UI poll sees it immediately
    with open(LLAMA_MODEL_STATUS, "w") as f:
        json.dump({"status": "switching", "model": filename, "error": ""}, f)

    # Write the config file for the host-side switch script
    with open(LLAMA_MODEL_CONFIG, "w") as f:
        json.dump({"model": filename}, f)

    # Touch the trigger file so the host-side systemd path unit picks it up
    Path(LLAMA_MODEL_TRIGGER).touch()

    return {
        "status": "ok",
        "message": f"Switching to {filename} — llama.cpp will restart momentarily.",
        "model": filename,
        "display_name": display_name,
    }


class SearchModelRequest(BaseModel):
    query: str  # e.g. "google/gemma-3-1b-it" or "mistral-7b"


@app.post("/api/local-models/search")
async def search_gguf_models(req: SearchModelRequest):
    """Search HuggingFace for GGUF versions of a model.

    Strategy:
      1. If query looks like owner/model, search for owner/model-GGUF and check siblings
      2. Search HuggingFace API with the query + GGUF filter
      3. For each matching repo, list .gguf files with sizes
    """
    query = req.query.strip()
    if not query:
        raise HTTPException(400, "Search query is required")

    results = []

    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as c:
        # Strategy 1: direct repo with -GGUF suffix variations
        if "/" in query:
            base = query.rstrip("/")
            # Check the repo itself and common GGUF repo patterns
            candidates = [base, f"{base}-GGUF", f"{base}-gguf"]
            # Also check popular quantizers
            model_name = base.split("/", 1)[1] if "/" in base else base
            for quantizer in ["bartowski", "mradermacher", "QuantFactory"]:
                candidates.append(f"{quantizer}/{model_name}-GGUF")

            for repo_id in candidates:
                files = await _list_hf_gguf_files(c, repo_id)
                if files:
                    results.append({"repo_id": repo_id, "files": files})
                if len(results) >= 3:
                    break

        # Strategy 2: HuggingFace search API
        if len(results) < 3:
            search_term = query.split("/")[-1] if "/" in query else query
            try:
                r = await c.get(
                    "https://huggingface.co/api/models",
                    params={
                        "search": f"{search_term} GGUF",
                        "filter": "gguf",
                        "limit": 5,
                        "sort": "downloads",
                        "direction": -1,
                    },
                )
                if r.status_code == 200:
                    for model in r.json():
                        repo_id = model.get("modelId", "")
                        # Skip repos we already found
                        if any(res["repo_id"] == repo_id for res in results):
                            continue
                        files = await _list_hf_gguf_files(c, repo_id)
                        if files:
                            results.append({"repo_id": repo_id, "files": files})
                        if len(results) >= 5:
                            break
            except Exception as e:
                logger.warning(f"HuggingFace search failed: {e}")

    return {"query": query, "results": results}


async def _list_hf_gguf_files(client: httpx.AsyncClient, repo_id: str) -> list[dict]:
    """List .gguf files in a HuggingFace repo with their sizes."""
    try:
        r = await client.get(f"https://huggingface.co/api/models/{repo_id}")
        if r.status_code != 200:
            return []
        model_info = r.json()
        siblings = model_info.get("siblings", [])
        files = []
        for s in siblings:
            fname = s.get("rfilename", "")
            if fname.lower().endswith(".gguf") and not fname.startswith("."):
                size_bytes = s.get("size", 0)
                size_mb = round(size_bytes / (1024 * 1024), 1) if size_bytes else None
                # Extract quantization tag from filename (e.g. Q4_K_M, Q8_0)
                quant = ""
                for part in fname.replace(".gguf", "").split("-"):
                    if part.startswith("Q") or part.startswith("q") or part in ("f16", "f32", "bf16"):
                        quant = part
                        break
                # Also try underscore-separated
                if not quant:
                    for part in fname.replace(".gguf", "").split("_"):
                        if part.startswith("Q") or part in ("f16", "f32", "bf16"):
                            quant = part
                            break
                files.append({
                    "filename": fname,
                    "size_mb": size_mb,
                    "quant": quant,
                    "download_url": f"https://huggingface.co/{repo_id}/resolve/main/{fname}",
                })
        # Sort by size ascending so smaller quants appear first
        files.sort(key=lambda f: f["size_mb"] or 9999999)
        return files
    except Exception:
        return []


class DownloadModelRequest(BaseModel):
    repo_id: str    # e.g. "bartowski/gemma-3-1b-it-GGUF"
    filename: str   # e.g. "gemma-3-1b-it-Q4_K_M.gguf"


@app.post("/api/local-models/download")
async def download_local_model(req: DownloadModelRequest):
    """Download a specific GGUF file from a HuggingFace repo."""
    filename = req.filename
    repo_id = req.repo_id

    # Validate filename
    if "/" in filename or ".." in filename or not filename.lower().endswith(".gguf"):
        raise HTTPException(400, "Invalid model filename")

    # Validate repo_id format (owner/model)
    if "/" not in repo_id or ".." in repo_id:
        raise HTTPException(400, "Invalid repo ID")

    url = f"https://huggingface.co/{repo_id}/resolve/main/{filename}"
    dest_path = os.path.join(LLAMA_MODELS_DIR, filename)

    if os.path.exists(dest_path):
        raise HTTPException(409, f"Model file already exists: {filename}")

    partial_path = dest_path + ".downloading"
    if os.path.exists(partial_path):
        raise HTTPException(409, f"Download already in progress for: {filename}")

    import asyncio

    async def _download():
        try:
            async with httpx.AsyncClient(timeout=3600, follow_redirects=True) as c:
                async with c.stream("GET", url) as resp:
                    resp.raise_for_status()
                    with open(partial_path, "wb") as f:
                        async for chunk in resp.aiter_bytes(chunk_size=1024 * 1024):
                            f.write(chunk)
            os.rename(partial_path, dest_path)
            logger.info(f"Model download complete: {filename} from {repo_id}")
        except Exception as e:
            logger.error(f"Model download failed for {filename}: {e}")
            try:
                os.unlink(partial_path)
            except FileNotFoundError:
                pass

    asyncio.create_task(_download())

    return {
        "status": "ok",
        "message": f"Downloading {filename} — this may take a while for large models.",
        "filename": filename,
    }


@app.get("/api/local-models/downloads")
async def check_downloads():
    """Check for in-progress downloads (.downloading files)."""
    downloads = []
    try:
        for entry in os.listdir(LLAMA_MODELS_DIR):
            if entry.endswith(".downloading"):
                filepath = os.path.join(LLAMA_MODELS_DIR, entry)
                stat = os.stat(filepath)
                downloads.append({
                    "filename": entry.replace(".downloading", ""),
                    "downloaded_mb": round(stat.st_size / (1024 * 1024), 1),
                    "in_progress": True,
                })
    except FileNotFoundError:
        pass
    return {"downloads": downloads}


# ── Static files / SPA ───────────────────────────────────────────────────────

STATIC_DIR = Path(__file__).parent / "static"

# ── KEV helpers ─────────────────────────────────────────────────────────────

_KEV_SETTINGS_DEFAULTS: dict = {
    "auto_pull": True,
    "frequency_hours": 24,
    "alert_on_match": True,
    "alert_on_overdue": True,
    "ransomware_only": False,
}


def _read_kev_config() -> dict:
    """Return persisted KEV settings, falling back to defaults."""
    try:
        with open(KEV_CONFIG_PATH) as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            return dict(_KEV_SETTINGS_DEFAULTS)
        return {**_KEV_SETTINGS_DEFAULTS, **data}
    except (FileNotFoundError, json.JSONDecodeError):
        return dict(_KEV_SETTINGS_DEFAULTS)


def _write_kev_config(settings: dict) -> None:
    """Atomically persist KEV settings to disk."""
    import tempfile
    dest = Path(KEV_CONFIG_PATH)
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".kev_config_tmp_")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(settings, fh, indent=2)
        os.replace(tmp, dest)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read_kev_catalog() -> dict:
    """Return the KEV catalog dict, or empty structure if not present."""
    try:
        with open(KEV_CATALOG_PATH) as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"generated": None, "total": 0, "cves": {}}


def _read_kev_history(n: int = 20) -> list:
    """Return the last n history entries."""
    try:
        with open(KEV_HISTORY_PATH) as fh:
            history = json.load(fh)
        if not isinstance(history, list):
            return []
        return history[-n:]
    except (FileNotFoundError, json.JSONDecodeError):
        return []


# ── KEV routes ───────────────────────────────────────────────────────────────

@app.post("/api/kev/pull")
async def kev_pull():
    """Trigger kev_sync.py as a subprocess and return status."""
    script = KEV_SYNC_SCRIPT
    if not Path(script).exists():
        # Fall back to path inside the container image
        script = str(Path(__file__).parent / "scripts" / "kev_sync.py")
    if not Path(script).exists():
        raise HTTPException(404, f"kev_sync.py not found at {KEV_SYNC_SCRIPT}")

    try:
        result = subprocess.run(
            [sys.executable, script],
            capture_output=True,
            text=True,
            timeout=60,
            env={**os.environ,
                 "KEV_CATALOG_PATH": KEV_CATALOG_PATH,
                 "KEV_HISTORY_PATH": KEV_HISTORY_PATH},
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(504, "kev_sync.py timed out after 60 seconds")
    except Exception as exc:
        raise HTTPException(500, f"Failed to run kev_sync.py: {exc}")

    if result.returncode != 0:
        logger.error("kev_sync stderr: %s", result.stderr)
        raise HTTPException(500, result.stderr.strip() or "kev_sync.py exited with error")

    catalog = _read_kev_catalog()
    return {
        "status": "ok",
        "total": catalog.get("total", 0),
        "generated": catalog.get("generated"),
        "stdout": result.stdout.strip(),
    }


@app.get("/api/kev/status")
async def kev_status():
    """Return catalog stats: last pull time, total CVEs, matched/overdue counts."""
    catalog = _read_kev_catalog()
    history = _read_kev_history(1)

    # Determine status badge: Current (<24h), Syncing (pull in progress),
    # Stale (>24h or never pulled), or Never.
    generated = catalog.get("generated")
    badge = "never"
    if generated:
        try:
            pulled_at = datetime.strptime(generated, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            age_hours = (datetime.now(timezone.utc) - pulled_at).total_seconds() / 3600
            badge = "current" if age_hours < 24 else "stale"
        except ValueError:
            badge = "stale"

    last_pull = history[-1] if history else None

    # Cross-reference KEV catalog against Wazuh vulnerability index
    matched_cves = 0
    overdue_count = 0
    kev_cves = catalog.get("cves", {})
    if kev_cves and ES_PASS:
        try:
            kev_ids = list(kev_cves.keys())
            query = {
                "size": 0,
                "query": {"terms": {"vulnerability.id": kev_ids}},
                "aggs": {"matched": {"cardinality": {"field": "vulnerability.id"}}},
            }
            async with es_client() as c:
                r = await c.post(
                    f"{ES_URL}/{VULN_INDEX}/_search", auth=ES_AUTH, json=query,
                )
                if r.status_code == 200:
                    data = r.json()
                    matched_cves = data.get("aggregations", {}).get("matched", {}).get("value", 0)
                    # Count overdue: KEVs matched AND past their due date
                    if matched_cves > 0:
                        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                        overdue_ids = [
                            cve_id for cve_id, info in kev_cves.items()
                            if info.get("dueDate") and info["dueDate"] < now_str[:10]
                        ]
                        if overdue_ids:
                            oq = {
                                "size": 0,
                                "query": {"terms": {"vulnerability.id": overdue_ids}},
                                "aggs": {"overdue": {"cardinality": {"field": "vulnerability.id"}}},
                            }
                            r2 = await c.post(
                                f"{ES_URL}/{VULN_INDEX}/_search", auth=ES_AUTH, json=oq,
                            )
                            if r2.status_code == 200:
                                overdue_count = r2.json().get("aggregations", {}).get("overdue", {}).get("value", 0)
        except Exception as e:
            logger.warning(f"KEV cross-reference failed: {e}")

    return {
        "last_pull_timestamp": generated,
        "badge": badge,
        "total_kev": catalog.get("total", 0),
        "matched_cves": matched_cves,
        "overdue_count": overdue_count,
        "last_pull_status": last_pull.get("status") if last_pull else None,
        "settings": _read_kev_config(),
    }


@app.get("/api/kev/history")
async def kev_history(n: int = Query(20, ge=1, le=100)):
    """Return the last n KEV sync log entries."""
    return {"history": _read_kev_history(n)}


@app.patch("/api/settings/kev")
async def update_kev_settings(req: KevSettingsRequest):
    """Persist KEV settings and (on a real host) reschedule the systemd timer."""
    valid_frequencies = {6, 12, 24, 168}
    if req.frequency_hours not in valid_frequencies:
        raise HTTPException(400, f"frequency_hours must be one of {sorted(valid_frequencies)}")

    settings = {
        "auto_pull": req.auto_pull,
        "frequency_hours": req.frequency_hours,
        "alert_on_match": req.alert_on_match,
        "alert_on_overdue": req.alert_on_overdue,
        "ransomware_only": req.ransomware_only,
    }

    try:
        _write_kev_config(settings)
    except Exception as exc:
        raise HTTPException(500, f"Failed to save KEV settings: {exc}")

    logger.info("KEV settings updated: %s", settings)
    return {"status": "ok", "settings": settings}


# ── ElastAlert2 rules routes ─────────────────────────────────────────────────

def _parse_ea_rule_meta(path: Path) -> dict:
    """Return lightweight metadata for a single rule file without raising."""
    meta = {"filename": path.name, "name": path.stem, "type": "unknown", "index": ""}
    try:
        with open(path) as fh:
            data = yaml.safe_load(fh) or {}
        meta["name"] = data.get("name", path.stem)
        meta["type"] = data.get("type", "unknown")
        meta["index"] = data.get("index", "")
    except Exception:
        pass
    return meta


@app.get("/api/rules/elastalert")
async def list_ea_rules():
    """List all ElastAlert2 rule files with basic metadata."""
    if not ELASTALERT_RULES_PATH.exists():
        return {"rules": []}
    rules = []
    for p in sorted(ELASTALERT_RULES_PATH.glob("*.yml")):
        if p.is_file():
            rules.append(_parse_ea_rule_meta(p))
    for p in sorted(ELASTALERT_RULES_PATH.glob("*.yaml")):
        if p.is_file():
            rules.append(_parse_ea_rule_meta(p))
    return {"rules": rules}


class PasteRuleRequest(BaseModel):
    yaml_content: str
    filename: str = ""


@app.post("/api/rules/elastalert/paste")
async def paste_ea_rule(req: PasteRuleRequest):
    """Save a pasted YAML string as an ElastAlert2 rule file."""
    import tempfile
    try:
        data = yaml.safe_load(req.yaml_content)
    except yaml.YAMLError as exc:
        raise HTTPException(400, f"Invalid YAML: {exc}")
    if not isinstance(data, dict):
        raise HTTPException(400, "Rule must be a YAML mapping")

    # Derive filename from rule name field or caller-supplied name
    if req.filename:
        fname = req.filename.strip()
    elif "name" in data:
        fname = data["name"].lower().replace(" ", "_").replace("/", "_") + ".yml"
    else:
        raise HTTPException(400, "Rule must contain a 'name' field or a filename must be provided")

    if not fname.endswith((".yml", ".yaml")):
        fname += ".yml"

    # Reject path traversal
    dest = ELASTALERT_RULES_PATH / fname
    if dest.resolve().parent != ELASTALERT_RULES_PATH.resolve():
        raise HTTPException(400, "Invalid filename")

    ELASTALERT_RULES_PATH.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=ELASTALERT_RULES_PATH, prefix=".tmp_rule_")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(req.yaml_content)
        os.chmod(tmp, 0o644)
        os.replace(tmp, dest)
    except Exception as exc:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise HTTPException(500, f"Failed to write rule: {exc}")

    logger.info("ElastAlert2 rule saved: %s", fname)
    return {"status": "ok", "filename": fname, **_parse_ea_rule_meta(dest)}


@app.post("/api/rules/elastalert/upload")
async def upload_ea_rules(files: list[UploadFile] = File(...)):
    """Upload one or more ElastAlert2 rule YAML files."""
    import tempfile
    ELASTALERT_RULES_PATH.mkdir(parents=True, exist_ok=True)
    saved = []
    errors = []
    for upload in files:
        fname = Path(upload.filename).name  # strip any directory component
        if not fname.endswith((".yml", ".yaml")):
            errors.append({"filename": fname, "error": "Only .yml / .yaml files accepted"})
            continue
        dest = ELASTALERT_RULES_PATH / fname
        if dest.resolve().parent != ELASTALERT_RULES_PATH.resolve():
            errors.append({"filename": fname, "error": "Invalid filename"})
            continue
        content = await upload.read()
        try:
            data = yaml.safe_load(content)
            if not isinstance(data, dict):
                raise ValueError("Not a YAML mapping")
        except Exception as exc:
            errors.append({"filename": fname, "error": f"Invalid YAML: {exc}"})
            continue
        fd, tmp = tempfile.mkstemp(dir=ELASTALERT_RULES_PATH, prefix=".tmp_rule_")
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(content)
            os.chmod(tmp, 0o644)
            os.replace(tmp, dest)
        except Exception as exc:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            errors.append({"filename": fname, "error": f"Write failed: {exc}"})
            continue
        saved.append(_parse_ea_rule_meta(dest))
        logger.info("ElastAlert2 rule uploaded: %s", fname)

    if errors and not saved:
        raise HTTPException(400, {"saved": [], "errors": errors})
    return {"saved": saved, "errors": errors}


@app.get("/api/rules/elastalert/{filename}")
async def get_ea_rule(filename: str):
    """Return the raw YAML content of a single ElastAlert2 rule file."""
    dest = ELASTALERT_RULES_PATH / filename
    if dest.resolve().parent != ELASTALERT_RULES_PATH.resolve():
        raise HTTPException(400, "Invalid filename")
    if not dest.exists():
        raise HTTPException(404, f"Rule '{filename}' not found")
    return {"filename": filename, "content": dest.read_text()}


@app.delete("/api/rules/elastalert/{filename}")
async def delete_ea_rule(filename: str):
    """Delete a single ElastAlert2 rule file."""
    dest = ELASTALERT_RULES_PATH / filename
    if dest.resolve().parent != ELASTALERT_RULES_PATH.resolve():
        raise HTTPException(400, "Invalid filename")
    if not dest.exists():
        raise HTTPException(404, f"Rule '{filename}' not found")
    dest.unlink()
    logger.info("ElastAlert2 rule deleted: %s", filename)
    return {"status": "ok", "filename": filename}


class SubmitReportRequest(BaseModel):
    text: str


class GenerateDetectionRequest(BaseModel):
    cve_id: str
    host: str
    package: str
    excluded_fields: list[str] = []


class DetectionField(BaseModel):
    name: str
    seen: bool
    event_count: int = 0


class DetectionWarning(BaseModel):
    field: str
    message: str


class GenerateDetectionResponse(BaseModel):
    summary: str
    elastalert_yaml: str
    sigma_yaml: str
    fields: list[DetectionField]
    warnings: list[DetectionWarning]
    reasoning: str


class DeployElastAlertRequest(BaseModel):
    rule_yaml: str
    rule_name: str


@app.post("/api/submit_report")
async def submit_report(req: SubmitReportRequest):
    """
    Endpoint to receive pasted text and respond with 'received'.
    """
    try:
        # Log the received text (optional)
        print(f"Received report: {req.text[:100]}")  # Log first 100 characters

        # Respond with a simple message
        return {"status": "success", "message": "received"}
    except Exception as e:
        raise HTTPException(500, f"Failed to process report: {str(e)}")


# ── Detection builder endpoints ────────────────────────────────────────────────

def _flatten_fields(obj, prefix="", depth=0, max_depth=5):
    """Recursively flatten nested dict/list to extract all field paths."""
    if depth > max_depth:
        return set()
    fields = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            path = f"{prefix}.{k}" if prefix else k
            fields.add(path)
            fields.update(_flatten_fields(v, path, depth + 1, max_depth))
    elif isinstance(obj, list) and obj:
        fields.update(_flatten_fields(obj[0], prefix, depth + 1, max_depth))
    return fields


def _parse_llm_response(text: str) -> dict:
    """Parse LLM response into structured sections."""
    # Extract SUMMARY section
    summary_match = re.search(r'SUMMARY:\s*\n(.*?)(?:\n\n|$)', text, re.DOTALL)
    summary = summary_match.group(1).strip() if summary_match else ""

    # Extract ELASTALERT2 YAML block
    elastalert_match = re.search(r'ELASTALERT2:\s*\n```yaml\s*\n(.*?)\n```', text, re.DOTALL)
    elastalert_yaml = elastalert_match.group(1).strip() if elastalert_match else ""

    # Extract SIGMA YAML block
    sigma_match = re.search(r'SIGMA:\s*\n```yaml\s*\n(.*?)\n```', text, re.DOTALL)
    sigma_yaml = sigma_match.group(1).strip() if sigma_match else ""

    # Extract REASONING section
    reasoning_match = re.search(r'REASONING:\s*\n(.*?)(?:\n|$)', text, re.DOTALL)
    reasoning = reasoning_match.group(1).strip() if reasoning_match else ""

    return {
        "summary": summary,
        "elastalert_yaml": elastalert_yaml,
        "sigma_yaml": sigma_yaml,
        "reasoning": reasoning,
    }


@app.post("/api/detections/generate", response_model=GenerateDetectionResponse)
async def generate_detection(req: GenerateDetectionRequest):
    """Generate a detection rule for a CVE based on available logs."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    # 1. Read KEV catalog and get CVE entry
    kev_catalog = _read_kev_catalog()
    cve_entry = kev_catalog.get("cves", {}).get(req.cve_id, {})
    if not cve_entry:
        raise HTTPException(404, f"CVE {req.cve_id} not found in KEV catalog")

    # 2. Confirm CVE+host pairing in Wazuh vulnerability index
    async with es_client() as c:
        query = {
            "size": 1,
            "query": {
                "bool": {
                    "filter": [
                        {"term": {"vulnerability.id": req.cve_id}},
                        {"term": {"agent.name": req.host}},
                    ]
                }
            },
        }
        try:
            r = await c.post(
                f"{ES_URL}/wazuh-states-vulnerabilities-*/_search",
                auth=ES_AUTH,
                json=query,
            )
            r.raise_for_status()
            hits = r.json().get("hits", {}).get("hits", [])
            if not hits:
                raise HTTPException(400, f"CVE {req.cve_id} not found on host {req.host}")
        except httpx.HTTPStatusError as e:
            if e.response.status_code != 404:
                raise HTTPException(502, f"Elasticsearch error: {e.response.text[:200]}")

    # 3. Get log sources for the host (last 7 days)
    log_sources = []
    async with es_client() as c:
        query = {
            "size": 0,
            "query": {
                "bool": {
                    "filter": [
                        {"term": {"agent.name": req.host}},
                        {"range": {"@timestamp": {"gte": "now-7d"}}},
                    ]
                }
            },
            "aggs": {"log_sources": {"terms": {"field": "event.dataset", "size": 20}}},
        }
        try:
            r = await c.post(
                f"{ES_URL}/logs-*/_search",
                auth=ES_AUTH,
                json=query,
            )
            if r.status_code == 200:
                buckets = r.json().get("aggregations", {}).get("log_sources", {}).get("buckets", [])
                log_sources = [b["key"] for b in buckets if b["key"]]
        except:
            pass

    # 4. Extract available field names from recent events (last 7 days, max 50)
    available_fields = set()
    async with es_client() as c:
        query = {
            "size": 50,
            "sort": [{"@timestamp": {"order": "desc"}}],
            "query": {
                "bool": {
                    "filter": [
                        {"term": {"agent.name": req.host}},
                        {"range": {"@timestamp": {"gte": "now-7d"}}},
                    ]
                }
            },
        }
        try:
            r = await c.post(
                f"{ES_URL}/logs-*/_search",
                auth=ES_AUTH,
                json=query,
            )
            if r.status_code == 200:
                hits = r.json().get("hits", {}).get("hits", [])
                for h in hits:
                    fields = _flatten_fields(h.get("_source", {}))
                    available_fields.update(fields)
        except:
            pass

    # 5. Scan existing rules for this CVE
    existing_rules = ""
    if ELASTALERT_RULES_PATH.exists():
        for rule_file in ELASTALERT_RULES_PATH.glob("*.yml"):
            try:
                content = rule_file.read_text()
                if req.cve_id in content:
                    existing_rules += f"\n# {rule_file.name}\n{content[:500]}"
            except:
                pass

    # 6. Build LLM prompt
    excluded_str = ", ".join(req.excluded_fields) if req.excluded_fields else "none"
    prompt = f"""You are a detection engineer writing rules for a small organization running LME (Logging Made Easy).

CVE: {req.cve_id}
Vulnerable software: {cve_entry.get('vulnerabilityName', 'Unknown')}
What the exploit does: {cve_entry.get('description', 'See CISA KEV catalog')}
Affected host: {req.host}

Log sources available on this host:
{', '.join(log_sources) if log_sources else 'Unknown'}

Fields present in recent logs on this host:
{', '.join(sorted(available_fields)[:50]) if available_fields else 'Unknown'}

Do NOT use these fields (not present in logs):
{excluded_str}

Existing rules for this CVE: {existing_rules if existing_rules else 'None'}

Generate:
1. A plain-English description (2 sentences max) of what exploitation looks like in logs. Written for a non-technical IT admin. No ATT&CK IDs or jargon.
2. An ElastAlert2 YAML rule using only fields from the available list above
3. A Sigma rule (product: windows, category: process_creation) for the same behavior
4. A plain-English explanation of why you chose these specific fields

Format your response exactly as:

SUMMARY:
<2 sentence description>

ELASTALERT2:
```yaml
<rule>
```

SIGMA:
```yaml
<rule>
```

REASONING:
<explanation>"""

    # 7. Call LiteLLM
    parsed_response = None
    try:
        async with llm_client() as c:
            r = await c.post(
                f"{LITELLM_URL}/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {LITELLM_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _active_model["name"],
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.2,
                    "max_tokens": 1500,
                },
            )
            r.raise_for_status()
            data = r.json()
            llm_text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            parsed_response = _parse_llm_response(llm_text)
    except Exception as e:
        raise HTTPException(502, f"LLM call failed: {str(e)}")

    # 8. Validate fields in generated rules
    warnings = []
    field_list = []

    # Extract all field references from YAML (simplified: look for quoted strings and unquoted identifiers)
    yaml_text = (parsed_response.get("elastalert_yaml", "") + " " + parsed_response.get("sigma_yaml", "")).lower()
    field_pattern = r'[\w.]+'
    mentioned_fields = set(re.findall(field_pattern, yaml_text))

    for field in mentioned_fields:
        if field in available_fields:
            field_list.append({"name": field, "seen": True})
        else:
            # Check if it's a partial match or common field that might not be in recent data
            if any(av_field.endswith('.' + field) or av_field.endswith(field) for av_field in available_fields):
                field_list.append({"name": field, "seen": True})
            else:
                # Only warn if it's not a common static field
                if not field.startswith('_') and field not in ['and', 'or', 'not', 'query', 'filter', 'name', 'type', 'index', 'alert', 'query_string', 'timeframe', 'days', 'hours', 'minutes', 'seconds']:
                    warnings.append({"field": field, "message": "Not found in last 7 days of logs"})

    return GenerateDetectionResponse(
        summary=parsed_response.get("summary", ""),
        elastalert_yaml=parsed_response.get("elastalert_yaml", ""),
        sigma_yaml=parsed_response.get("sigma_yaml", ""),
        fields=field_list[:20],  # Limit to first 20 for display
        warnings=warnings[:10],  # Limit to first 10
        reasoning=parsed_response.get("reasoning", ""),
    )


@app.post("/api/detections/deploy/elastalert")
async def deploy_elastalert(req: DeployElastAlertRequest):
    """Deploy an ElastAlert2 rule and restart the service."""
    # 1. Validate YAML
    try:
        yaml.safe_load(req.rule_yaml)
    except Exception as e:
        raise HTTPException(400, f"Invalid YAML: {str(e)}")

    # 2. Sanitize rule name
    import re
    safe_name = re.sub(r'[^a-z0-9_]', '_', req.rule_name.lower())

    # 3. Write rule with atomic pattern
    dest = ELASTALERT_RULES_PATH / f"{safe_name}.yml"
    try:
        import tempfile
        fd, tmp = tempfile.mkstemp(dir=str(ELASTALERT_RULES_PATH), prefix=".tmp_rule_", suffix=".yml")
        with os.fdopen(fd, "w") as fh:
            fh.write("# Generated by LME detection builder — review before use\n")
            fh.write(req.rule_yaml)
        os.chmod(tmp, 0o644)
        os.replace(tmp, str(dest))
    except Exception as e:
        raise HTTPException(500, f"Failed to write rule: {str(e)}")

    # 4. Restart service
    try:
        result = subprocess.run(
            ["systemctl", "restart", "lme-elastalert.service"],
            capture_output=True,
            timeout=30,
            text=True,
        )
        if result.returncode != 0:
            return {"success": False, "message": f"Service restart failed: {result.stderr}"}
    except subprocess.TimeoutExpired:
        return {"success": False, "message": "Service restart timed out"}
    except Exception as e:
        return {"success": False, "message": f"Service restart error: {str(e)}"}

    return {"success": True, "message": "Rule deployed — service restarting"}


@app.get("/", response_class=HTMLResponse)
async def index():
    return (STATIC_DIR / "index.html").read_text()

# Mount /static for any additional assets (favicon etc.)
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
