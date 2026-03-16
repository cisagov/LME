#!/usr/bin/env python3
"""
LME Documentation Ingestion Pipeline
Crawls https://cisagov.github.io/lme-docs/, converts pages to markdown,
chunks them intelligently, embeds with nomic-embed-text via lme-embeddings,
and stores in pgvector for RAG retrieval.

Usage (run inside the lme podman network):
    podman run --rm --network lme \\
      -e PGVECTOR_PASS=<secret> \\
      -v $(pwd)/scripts:/scripts:z \\
      python:3.11-slim bash -c "pip install -q requests beautifulsoup4 markdownify psycopg2-binary pgvector lxml && python /scripts/ingest_docs.py [--reset]"

    --reset : drop and recreate the docs_chunks table before ingesting
"""

import os
import re
import sys
import time
import argparse
import requests
import psycopg2
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
from markdownify import markdownify as md

# ── Config ────────────────────────────────────────────────────────────────────
BASE_URL      = "https://cisagov.github.io/lme-docs/"
EMBED_URL     = os.getenv("EMBED_URL",     "http://lme-embeddings:8081")
EMBED_DIMS    = 768

PG_HOST       = os.getenv("PGVECTOR_HOST", "lme-pgvector")
PG_PORT       = int(os.getenv("PGVECTOR_PORT", "5432"))
PG_DB         = os.getenv("PGVECTOR_DB",   "lme_vectors")
PG_USER       = os.getenv("PGVECTOR_USER", "lme")
PG_PASS       = os.getenv("PGVECTOR_PASS", "")

# Chunking config
CHUNK_SIZE     = 800   # target characters per chunk
CHUNK_OVERLAP  = 150   # overlap between consecutive chunks
MIN_CHUNK_SIZE = 100   # discard chunks shorter than this

REQUEST_DELAY  = 0.3   # seconds between HTTP requests (be polite)

# ── DB helpers ────────────────────────────────────────────────────────────────

def get_conn():
    return psycopg2.connect(
        host=PG_HOST, port=PG_PORT, dbname=PG_DB,
        user=PG_USER, password=PG_PASS
    )


def setup_db(conn, reset: bool = False):
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        if reset:
            cur.execute("DROP TABLE IF EXISTS docs_chunks;")
            print("  Dropped existing docs_chunks table.")
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS docs_chunks (
                id          SERIAL PRIMARY KEY,
                url         TEXT NOT NULL,
                title       TEXT,
                section     TEXT,
                chunk_index INTEGER,
                content     TEXT NOT NULL,
                embedding   vector({EMBED_DIMS}),
                created_at  TIMESTAMPTZ DEFAULT NOW()
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS docs_chunks_embedding_idx
            ON docs_chunks
            USING ivfflat (embedding vector_cosine_ops)
            WITH (lists = 50);
        """)
    conn.commit()
    print("  DB schema ready.")


# ── Scraping ──────────────────────────────────────────────────────────────────

def is_docs_url(url: str) -> bool:
    """Only follow URLs that are part of the lme-docs site."""
    parsed = urlparse(url)
    return (
        parsed.netloc == "cisagov.github.io"
        and parsed.path.startswith("/lme-docs/")
        and not any(parsed.path.endswith(ext) for ext in
                    (".png", ".jpg", ".gif", ".svg", ".pdf", ".zip",
                     ".ico", ".css", ".js", ".xml", ".txt"))
    )


def crawl(base_url: str) -> dict[str, str]:
    """
    BFS crawl of the docs site.
    Returns {url: html_content} for all discovered pages.
    """
    visited: set[str] = set()
    queue:   list[str] = [base_url]
    pages:   dict[str, str] = {}

    session = requests.Session()
    session.headers["User-Agent"] = "LME-DocBot/1.0 (RAG ingestion)"

    while queue:
        url = queue.pop(0)
        # Normalise — strip fragment and trailing slash variations
        url = url.split("#")[0].rstrip("/") + "/"
        if url in visited:
            continue
        visited.add(url)

        try:
            resp = session.get(url, timeout=15)
            resp.raise_for_status()
        except Exception as e:
            print(f"  SKIP {url}: {e}")
            continue

        html = resp.text
        pages[url] = html

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = urljoin(url, a["href"]).split("#")[0]
            if is_docs_url(href):
                norm = href.rstrip("/") + "/"
                if norm not in visited:
                    queue.append(norm)

        time.sleep(REQUEST_DELAY)

    return pages


# ── HTML → Markdown ──────────────────────────────────────────────────────────

# Tags that are pure navigation noise
_NAV_ROLES = {"navigation", "banner", "contentinfo", "search", "complementary"}


def extract_main_content(soup: BeautifulSoup) -> BeautifulSoup | None:
    """
    Return the BeautifulSoup node that contains the primary page content,
    stripping nav/header/footer/sidebar noise.
    """
    # MkDocs / Jekyll common content containers
    for selector in (
        "article.md-content__inner",
        "div.md-content",
        "main",
        "article",
        '[role="main"]',
        "div#content",
        "div.content",
    ):
        node = soup.select_one(selector)
        if node:
            return node
    return soup.body or soup


def html_to_markdown(url: str, html: str) -> tuple[str, str]:
    """
    Convert a page's HTML to clean markdown.
    Returns (title, markdown_text).
    """
    soup = BeautifulSoup(html, "lxml")

    # Extract title
    title = ""
    if soup.title:
        title = soup.title.string or ""
        # Strip " - LME Docs" suffixes etc.
        title = re.sub(r"\s*[|\-–]\s*.*$", "", title).strip()

    # Remove nav/header/footer/sidebar clutter
    for tag in soup.find_all(
        ["nav", "header", "footer", "aside", "script", "style"]
    ):
        tag.decompose()
    for tag in soup.find_all(attrs={"role": True}):
        if tag.get("role") in _NAV_ROLES:
            tag.decompose()
    for tag in soup.find_all(attrs={"class": True}):
        classes = " ".join(tag.get("class", []))
        if any(k in classes for k in ("nav", "sidebar", "toc", "breadcrumb",
                                       "footer", "header", "menu", "search")):
            tag.decompose()

    content_node = extract_main_content(soup)

    markdown = md(
        str(content_node),
        heading_style="ATX",
        bullets="-",
        strip=["img", "script", "style", "svg"],
    )

    # Collapse excessive blank lines
    markdown = re.sub(r"\n{3,}", "\n\n", markdown).strip()
    return title, markdown


# ── Chunking ──────────────────────────────────────────────────────────────────

def split_by_headings(markdown: str) -> list[tuple[str, str]]:
    """
    Split markdown into (section_heading, section_text) pairs.
    Each ## or ### heading starts a new section.
    """
    heading_re = re.compile(r"^(#{1,3} .+)$", re.MULTILINE)
    sections: list[tuple[str, str]] = []
    parts = heading_re.split(markdown)

    # parts alternates: [pre-heading-text, heading, body, heading, body, ...]
    current_heading = ""
    current_body = parts[0].strip() if parts else ""

    for i in range(1, len(parts)):
        if heading_re.match(parts[i]):
            if current_body or current_heading:
                sections.append((current_heading, current_body))
            current_heading = parts[i].strip("# ").strip()
            current_body = ""
        else:
            current_body += parts[i]

    if current_body or current_heading:
        sections.append((current_heading, current_body.strip()))

    return sections


def chunk_text(text: str) -> list[str]:
    """
    Split text into overlapping chunks of ~CHUNK_SIZE characters,
    breaking on paragraph boundaries where possible.
    """
    paragraphs = [p.strip() for p in re.split(r"\n\n+", text) if p.strip()]
    chunks: list[str] = []
    current = ""

    for para in paragraphs:
        if len(current) + len(para) + 2 <= CHUNK_SIZE:
            current = (current + "\n\n" + para).strip()
        else:
            if current:
                chunks.append(current)
            # If single paragraph exceeds CHUNK_SIZE, hard-split it
            if len(para) > CHUNK_SIZE:
                for start in range(0, len(para), CHUNK_SIZE - CHUNK_OVERLAP):
                    piece = para[start : start + CHUNK_SIZE]
                    if len(piece) >= MIN_CHUNK_SIZE:
                        chunks.append(piece)
                current = ""
            else:
                current = para

    if current and len(current) >= MIN_CHUNK_SIZE:
        chunks.append(current)

    return chunks


def page_to_chunks(url: str, html: str) -> list[dict]:
    """Convert a page to a list of chunk dicts ready for embedding."""
    title, markdown = html_to_markdown(url, html)
    sections = split_by_headings(markdown)
    chunks: list[dict] = []

    for section_heading, section_body in sections:
        if not section_body.strip():
            continue
        section_body = section_body.strip()
        for idx, chunk_text_val in enumerate(chunk_text(section_body)):
            # Prepend title + section as context prefix for better embedding quality
            prefix = f"# {title}\n## {section_heading}\n\n" if section_heading else f"# {title}\n\n"
            full_text = prefix + chunk_text_val
            chunks.append({
                "url":         url,
                "title":       title,
                "section":     section_heading,
                "chunk_index": idx,
                "content":     full_text,
            })

    return chunks


# ── Embedding ─────────────────────────────────────────────────────────────────

def embed_texts(texts: list[str]) -> list[list[float]]:
    """Batch embed texts via the lme-embeddings llama.cpp /v1/embeddings endpoint."""
    resp = requests.post(
        f"{EMBED_URL}/v1/embeddings",
        json={"model": "nomic-embed-text", "input": texts},
        timeout=120,
    )
    resp.raise_for_status()
    data = resp.json()["data"]
    data.sort(key=lambda x: x["index"])
    return [d["embedding"] for d in data]


# ── Main pipeline ─────────────────────────────────────────────────────────────

def ingest(reset: bool = False):
    print(f"\n{'='*60}")
    print("LME Documentation RAG Ingestion Pipeline")
    print(f"{'='*60}\n")

    # 1. DB setup
    print("[1/4] Connecting to pgvector...")
    conn = get_conn()
    setup_db(conn, reset=reset)

    # 2. Crawl
    print(f"\n[2/4] Crawling {BASE_URL} ...")
    pages = crawl(BASE_URL)
    print(f"  Found {len(pages)} pages.")

    # 3. Convert & chunk
    print("\n[3/4] Converting HTML → Markdown and chunking...")
    all_chunks: list[dict] = []
    for url, html in pages.items():
        chunks = page_to_chunks(url, html)
        all_chunks.extend(chunks)
        print(f"  {len(chunks):3d} chunks  ← {url}")

    print(f"\n  Total chunks: {len(all_chunks)}")

    # 4. Embed & store in batches
    print("\n[4/4] Embedding and storing chunks...")
    BATCH = 16
    stored = 0

    with conn.cursor() as cur:
        for i in range(0, len(all_chunks), BATCH):
            batch = all_chunks[i : i + BATCH]
            texts = [c["content"] for c in batch]

            try:
                embeddings = embed_texts(texts)
            except Exception as e:
                print(f"  ERROR embedding batch {i//BATCH}: {e}")
                continue

            for chunk, emb in zip(batch, embeddings):
                cur.execute(
                    """
                    INSERT INTO docs_chunks
                        (url, title, section, chunk_index, content, embedding)
                    VALUES (%s, %s, %s, %s, %s, %s::vector)
                    """,
                    (
                        chunk["url"],
                        chunk["title"],
                        chunk["section"],
                        chunk["chunk_index"],
                        chunk["content"],
                        f"[{','.join(str(x) for x in emb)}]",
                    ),
                )
                stored += 1

            conn.commit()
            pct = min(100, int((i + BATCH) / len(all_chunks) * 100))
            print(f"  [{pct:3d}%] Stored {stored}/{len(all_chunks)} chunks", end="\r")

    print(f"\n\n  Done! Stored {stored} chunks in pgvector.")
    conn.close()
    print("\nIngestion complete. The LME docs are ready for RAG queries.\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest LME docs into pgvector")
    parser.add_argument("--reset", action="store_true",
                        help="Drop and recreate the docs_chunks table first")
    args = parser.parse_args()
    ingest(reset=args.reset)
