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
from pathlib import Path

import httpx
import psycopg2
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Config from environment ──────────────────────────────────────────────────
ES_URL      = os.getenv("ELASTICSEARCH_URL",  "https://lme-elasticsearch:9200")
ES_USER     = os.getenv("ELASTICSEARCH_USER", "elastic")
ES_PASS     = os.getenv("ELASTICSEARCH_PASSWORD", "")
LITELLM_URL = os.getenv("LITELLM_URL",        "https://lme-litellm:4000")
LITELLM_KEY = os.getenv("LITELLM_API_KEY",    "sk-lme-llama-proxy")
LITELLM_MDL = os.getenv("LITELLM_MODEL",      "gemma-3-1b")

# httpx clients — both ES and LiteLLM use self-signed certs
PGVECTOR_HOST = os.getenv("PGVECTOR_HOST", "lme-pgvector")
PGVECTOR_PORT = int(os.getenv("PGVECTOR_PORT", "5432"))
PGVECTOR_DB   = os.getenv("PGVECTOR_DB",   "lme_vectors")
PGVECTOR_USER = os.getenv("PGVECTOR_USER", "lme")
PGVECTOR_PASS = os.getenv("PGVECTOR_PASS", "")
EMBED_URL     = os.getenv("EMBED_URL",     "http://lme-embeddings:8081")
RAG_TOP_K     = int(os.getenv("RAG_TOP_K", "10"))
RAG_MIN_SIM   = float(os.getenv("RAG_MIN_SIM", "0.60"))  # drop chunks below this similarity
RAG_MIN_CHARS = int(os.getenv("RAG_MIN_CHARS", "200"))   # drop stub/redirect chunks

ES_AUTH     = (ES_USER, ES_PASS)
VERIFY_SSL  = False          # internal self-signed certs

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
    size: int = Query(100, ge=1, le=500),
):
    """Return Kibana security detection rule alerts, newest first."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    severity_rank = _severity_order(min_severity)
    accepted = [s for s in ("critical", "high", "medium", "low") if _severity_order(s) <= severity_rank]

    query = {
        "size": size,
        "sort": [{"@timestamp": {"order": "desc"}}],
        "query": {
            "bool": {
                "filter": [
                    {"terms": {"kibana.alert.severity": accepted}}
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

    return {"total": total, "returned": len(alerts), "alerts": alerts}


@app.get("/api/alerts/wazuh")
async def wazuh_alerts(
    min_level: int = Query(7, ge=0, le=15, description="Minimum Wazuh rule level (0-15)"),
    size: int = Query(100, ge=1, le=500),
):
    """Return Wazuh alerts at or above min_level, newest first."""
    if not ES_PASS:
        raise HTTPException(503, "ELASTICSEARCH_PASSWORD not configured")

    query = {
        "size": size,
        "sort": [{"@timestamp": {"order": "desc"}}],
        "query": {
            "range": {"rule.level": {"gte": min_level}}
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
                return {"total": 0, "returned": 0, "alerts": [], "note": "No wazuh-alerts-* index found"}
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

    return {"total": total, "returned": len(alerts), "alerts": alerts}


# ── Chat / LLM endpoints ──────────────────────────────────────────────────────

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
        "model": LITELLM_MDL,
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
        "model": LITELLM_MDL,
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
        "model": LITELLM_MDL,
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
    async with httpx.AsyncClient(timeout=30) as c:
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

    # Fetch 3x top_k candidates so filtering still leaves enough good chunks
    fetch_k = top_k * 3

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
    if not chunks:
        return (
            "You are an LME (Logging Made Easy) security platform assistant. "
            "Answer questions helpfully using your knowledge of LME."
        )

    context_parts = []
    for i, c in enumerate(chunks, 1):
        source = f"{c['title']} — {c['section']}" if c["section"] else c["title"]
        context_parts.append(f"[{i}] Source: {source}\nURL: {c['url']}\n\n{c['content']}")

    context_block = "\n\n---\n\n".join(context_parts)

    return (
        "You are an LME (Logging Made Easy) security platform assistant.\n\n"
        "RULES — follow every rule exactly:\n"
        "1. Answer using ONLY the documentation excerpts provided below. Nothing else.\n"
        "2. NEVER invent, guess, or extrapolate commands, flags, file paths, URLs, or steps that do not appear word-for-word in the excerpts. If a command is not in the excerpts, do not write it.\n"
        "3. Be specific — reproduce exact commands, file paths, and step-by-step instructions directly from the excerpts. Do NOT paraphrase into vague overviews.\n"
        "4. If the question asks how to do something and the excerpts contain the steps, give the exact numbered steps or commands from the docs.\n"
        "5. If the answer is not clearly present in the excerpts, respond with: 'I could not find that in the LME documentation. Please refer to https://cisagov.github.io/lme-docs/ for more information.'\n"
        "6. Cite which excerpt each piece of information comes from using [1], [2], etc.\n"
        "7. If you are unsure whether a command or step is from the excerpts or your own knowledge, do NOT include it.\n"
        "8. Always end your response with a 'Read more:' line linking to the single most relevant documentation URL from the excerpts that best answers the question.\n\n"
        "=== LME Documentation Context ===\n\n"
        f"{context_block}\n\n"
        "=== End of Context ===\n\n"
        "Now answer with specific details and exact commands or steps copied from the excerpts above — no vague summaries. End your response with 'Read more: <url>' using the most relevant URL from the excerpts."
    )


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
        "model": LITELLM_MDL,
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 1800,
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
             "section": c["section"], "similarity": c["similarity"]}
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
    system_prompt = _build_rag_system_prompt(chunks)

    messages = [{"role": "system", "content": system_prompt}]
    messages += [m.model_dump() for m in req.messages]

    payload = {
        "model": LITELLM_MDL,
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 1800,
        "stream": True,
    }

    sources_event = json.dumps({
        "sources": [
            {"url": c["url"], "title": c["title"],
             "section": c["section"], "similarity": c["similarity"]}
            for c in chunks
        ]
    })

    async def event_generator():
        # First event carries the sources so the UI can render citations
        yield f"data: {sources_event}\n\n"

        async with llm_client() as c:
            try:
                async with c.stream(
                    "POST",
                    f"{LITELLM_URL}/v1/chat/completions",
                    headers={"Authorization": f"Bearer {LITELLM_KEY}",
                             "Content-Type": "application/json"},
                    json=payload,
                ) as resp:
                    async for line in resp.aiter_lines():
                        if line.startswith("data: "):
                            chunk_data = line[6:]
                            if chunk_data.strip() == "[DONE]":
                                yield "data: [DONE]\n\n"
                                return
                            try:
                                obj = json.loads(chunk_data)
                                delta = obj["choices"][0].get("delta", {})
                                if "content" in delta and delta["content"]:
                                    yield f"data: {json.dumps({'content': delta['content']})}\n\n"
                            except Exception:
                                pass
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


# ── Static files / SPA ───────────────────────────────────────────────────────

STATIC_DIR = Path(__file__).parent / "static"

@app.get("/", response_class=HTMLResponse)
async def index():
    return (STATIC_DIR / "index.html").read_text()

# Mount /static for any additional assets (favicon etc.)
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
