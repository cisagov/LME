#!/usr/bin/env python3
"""
LME CISA Known Exploited Vulnerabilities (KEV) Sync
=====================================================
Inspired by community research documented at:
  https://medium.com/@chinazaObidike/bridging-wazuh-and-cisa-kev-...
KEV data sourced from CISA (public domain):
  https://www.cisa.gov/known-exploited-vulnerabilities-catalog

Flow:
  1. Download the CISA KEV JSON feed from KEV_FEED_URL
  2. Parse into a CVE-keyed lookup dict
  3. Write kev_catalog.json atomically to KEV_CATALOG_PATH
  4. Append a timestamped entry to KEV_HISTORY_PATH (capped at MAX_HISTORY)
  5. Exit 0 on success, 1 on failure

All paths are configurable via environment variables so the script works
both on the host and inside containers.  Stdlib only — no external deps.
"""

import json
import os
import sys
import tempfile
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration (all overridable via environment)
# ---------------------------------------------------------------------------

KEV_FEED_URL = os.getenv(
    "KEV_FEED_URL",
    "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json",
)
KEV_CATALOG_PATH = os.getenv(
    "KEV_CATALOG_PATH",
    "/opt/lme/config/wazuh_cluster/kev_catalog.json",
)
KEV_HISTORY_PATH = os.getenv(
    "KEV_HISTORY_PATH",
    "/opt/lme/config/kev_history.json",
)
MAX_HISTORY = int(os.getenv("KEV_MAX_HISTORY", "100"))
HTTP_TIMEOUT = int(os.getenv("KEV_HTTP_TIMEOUT", "30"))


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------


def fetch_kev_feed(url: str, timeout: int = HTTP_TIMEOUT) -> dict:
    """Download the CISA KEV JSON feed and return the parsed dict.

    Raises:
        urllib.error.URLError: on network failure
        ValueError: if the response is not valid JSON
    """
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "LME-KEV-Sync/1.0 (https://github.com/cisagov/LME)"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
    except urllib.error.URLError as exc:
        raise urllib.error.URLError(f"Failed to fetch KEV feed from {url}: {exc.reason}") from exc

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"KEV feed is not valid JSON: {exc}") from exc


def parse_feed(raw: dict) -> dict:
    """Transform the raw CISA feed into the LME catalog format.

    The catalog is a dict keyed by CVE ID for O(1) lookups from custom-kev.

    Args:
        raw: Parsed CISA JSON feed

    Returns:
        catalog dict with keys: generated, total, cves

    Raises:
        ValueError: if the feed is missing expected fields
    """
    vulnerabilities = raw.get("vulnerabilities")
    if vulnerabilities is None:
        raise ValueError("KEV feed missing 'vulnerabilities' key")
    if not isinstance(vulnerabilities, list):
        raise ValueError("'vulnerabilities' must be a list")

    cves: dict[str, dict] = {}
    for entry in vulnerabilities:
        cve_id = entry.get("cveID", "").strip()
        if not cve_id:
            continue
        cves[cve_id] = {
            "vendorProject": entry.get("vendorProject", ""),
            "product": entry.get("product", ""),
            "vulnerabilityName": entry.get("vulnerabilityName", ""),
            "dateAdded": entry.get("dateAdded", ""),
            "shortDescription": entry.get("shortDescription", ""),
            "requiredAction": entry.get("requiredAction", ""),
            "dueDate": entry.get("dueDate", ""),
            "knownRansomwareCampaignUse": entry.get("knownRansomwareCampaignUse", "Unknown"),
            "notes": entry.get("notes", ""),
        }

    return {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "total": len(cves),
        "cves": cves,
    }


def write_catalog(catalog: dict, path: str) -> None:
    """Atomically write the catalog JSON to disk.

    Uses a temp file + rename so readers never see a partial write.

    Args:
        catalog: The catalog dict from parse_feed()
        path: Destination file path (created with parents if needed)

    Raises:
        OSError: on filesystem errors
    """
    dest = Path(path)
    dest.parent.mkdir(parents=True, exist_ok=True)

    # Write to a sibling temp file then rename (atomic on Linux)
    fd, tmp_path = tempfile.mkstemp(dir=dest.parent, prefix=".kev_catalog_tmp_")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(catalog, fh, indent=2)
        os.replace(tmp_path, dest)
    except Exception:
        # Clean up temp file on failure
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def append_history(entry: dict, path: str, max_entries: int = MAX_HISTORY) -> None:
    """Append a sync log entry to the history file.

    The history file is a JSON array capped at max_entries (FIFO).

    Args:
        entry: Dict with keys: timestamp, status, total, error (optional)
        path: Path to the history JSON file
        max_entries: Maximum number of entries to keep
    """
    hist_path = Path(path)
    hist_path.parent.mkdir(parents=True, exist_ok=True)

    history: list = []
    if hist_path.exists():
        try:
            with open(hist_path) as fh:
                history = json.load(fh)
            if not isinstance(history, list):
                history = []
        except (json.JSONDecodeError, OSError):
            history = []

    history.append(entry)
    # Keep only the most recent max_entries
    history = history[-max_entries:]

    fd, tmp_path = tempfile.mkstemp(dir=hist_path.parent, prefix=".kev_history_tmp_")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(history, fh, indent=2)
        os.replace(tmp_path, hist_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def lookup_cve(cve_id: str, catalog_path: str = KEV_CATALOG_PATH) -> dict | None:
    """Return the catalog entry for a CVE ID, or None if not found / catalog missing.

    Used by custom-kev integration and tests.
    """
    try:
        with open(catalog_path) as fh:
            catalog = json.load(fh)
        return catalog.get("cves", {}).get(cve_id)
    except (OSError, json.JSONDecodeError):
        return None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> int:
    """Run a single KEV sync.  Returns exit code (0=ok, 1=error)."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    print(f"[kev_sync] {timestamp} — fetching KEV feed from {KEV_FEED_URL}")

    try:
        raw = fetch_kev_feed(KEV_FEED_URL)
    except Exception as exc:
        msg = str(exc)
        print(f"[kev_sync] ERROR fetching feed: {msg}", file=sys.stderr)
        append_history({"timestamp": timestamp, "status": "error", "total": 0, "error": msg},
                       KEV_HISTORY_PATH)
        return 1

    try:
        catalog = parse_feed(raw)
    except Exception as exc:
        msg = str(exc)
        print(f"[kev_sync] ERROR parsing feed: {msg}", file=sys.stderr)
        append_history({"timestamp": timestamp, "status": "error", "total": 0, "error": msg},
                       KEV_HISTORY_PATH)
        return 1

    try:
        write_catalog(catalog, KEV_CATALOG_PATH)
    except Exception as exc:
        msg = str(exc)
        print(f"[kev_sync] ERROR writing catalog: {msg}", file=sys.stderr)
        append_history({"timestamp": timestamp, "status": "error", "total": 0, "error": msg},
                       KEV_HISTORY_PATH)
        return 1

    total = catalog["total"]
    print(f"[kev_sync] OK — wrote {total} CVEs to {KEV_CATALOG_PATH}")
    append_history({"timestamp": timestamp, "status": "ok", "total": total},
                   KEV_HISTORY_PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
