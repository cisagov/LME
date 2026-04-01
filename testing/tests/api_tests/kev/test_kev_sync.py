"""
Unit tests for scripts/kev_sync.py.

All tests are offline — network calls are mocked with unittest.mock so the
suite runs without any external connectivity.
"""

import importlib
import io
import json
import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Import the script as a module regardless of how pytest is invoked.
# We locate it relative to this file to avoid sys.path assumptions.
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parents[4]  # LME/
_SCRIPT = _REPO_ROOT / "scripts" / "kev_sync.py"

spec = importlib.util.spec_from_file_location("kev_sync", _SCRIPT)
kev_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kev_sync)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_urlopen_mock(payload: bytes, status: int = 200):
    """Return a context-manager mock that yields a file-like object."""
    cm = MagicMock()
    cm.__enter__ = MagicMock(return_value=io.BytesIO(payload))
    cm.__exit__ = MagicMock(return_value=False)
    return cm


# ---------------------------------------------------------------------------
# parse_feed
# ---------------------------------------------------------------------------

class TestParseFeed:
    def test_returns_expected_keys(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        assert set(catalog.keys()) == {"generated", "total", "cves"}

    def test_total_matches_vuln_count(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        assert catalog["total"] == 3
        assert len(catalog["cves"]) == 3

    def test_cve_keyed_by_id(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        assert "CVE-2021-44228" in catalog["cves"]
        assert "CVE-2022-30190" in catalog["cves"]
        assert "CVE-2023-23397" in catalog["cves"]

    def test_entry_fields_present(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        entry = catalog["cves"]["CVE-2021-44228"]
        required = {
            "vendorProject", "product", "vulnerabilityName",
            "dateAdded", "shortDescription", "requiredAction",
            "dueDate", "knownRansomwareCampaignUse", "notes",
        }
        assert required.issubset(entry.keys())

    def test_entry_values_correct(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        entry = catalog["cves"]["CVE-2021-44228"]
        assert entry["vendorProject"] == "Apache"
        assert entry["product"] == "Log4j2"
        assert entry["dueDate"] == "2021-12-24"
        assert entry["knownRansomwareCampaignUse"] == "Known"

    def test_ransomware_unknown_preserved(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        assert catalog["cves"]["CVE-2023-23397"]["knownRansomwareCampaignUse"] == "Unknown"

    def test_generated_is_iso_timestamp(self, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        # Should be parseable as an ISO-8601 UTC timestamp
        from datetime import datetime
        dt = datetime.strptime(catalog["generated"], "%Y-%m-%dT%H:%M:%SZ")
        assert dt.year >= 2024

    def test_missing_vulnerabilities_key_raises(self):
        with pytest.raises(ValueError, match="'vulnerabilities'"):
            kev_sync.parse_feed({"title": "CISA KEV"})

    def test_vulnerabilities_not_list_raises(self):
        with pytest.raises(ValueError, match="must be a list"):
            kev_sync.parse_feed({"vulnerabilities": "not a list"})

    def test_entry_missing_cve_id_skipped(self):
        feed = {
            "vulnerabilities": [
                {"vendorProject": "Acme"},          # no cveID
                {"cveID": "CVE-2021-44228", "vendorProject": "Apache"},
            ]
        }
        catalog = kev_sync.parse_feed(feed)
        assert catalog["total"] == 1
        assert "CVE-2021-44228" in catalog["cves"]

    def test_empty_vulnerabilities_list(self):
        catalog = kev_sync.parse_feed({"vulnerabilities": []})
        assert catalog["total"] == 0
        assert catalog["cves"] == {}

    def test_optional_fields_default_to_empty_string(self):
        feed = {"vulnerabilities": [{"cveID": "CVE-2099-0001"}]}
        catalog = kev_sync.parse_feed(feed)
        entry = catalog["cves"]["CVE-2099-0001"]
        assert entry["vendorProject"] == ""
        assert entry["shortDescription"] == ""
        assert entry["knownRansomwareCampaignUse"] == "Unknown"


# ---------------------------------------------------------------------------
# fetch_kev_feed
# ---------------------------------------------------------------------------

class TestFetchKevFeed:
    def test_returns_parsed_dict(self, sample_feed, sample_feed_json):
        mock_cm = _make_urlopen_mock(sample_feed_json)
        with patch("urllib.request.urlopen", return_value=mock_cm):
            result = kev_sync.fetch_kev_feed("https://example.com/kev.json")
        assert result["count"] == sample_feed["count"]
        assert len(result["vulnerabilities"]) == 3

    def test_network_error_raises_url_error(self):
        import urllib.error
        with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("timeout")):
            with pytest.raises(urllib.error.URLError, match="Failed to fetch"):
                kev_sync.fetch_kev_feed("https://example.com/kev.json")

    def test_invalid_json_raises_value_error(self):
        mock_cm = _make_urlopen_mock(b"this is not json")
        with patch("urllib.request.urlopen", return_value=mock_cm):
            with pytest.raises(ValueError, match="not valid JSON"):
                kev_sync.fetch_kev_feed("https://example.com/kev.json")

    def test_user_agent_header_set(self, sample_feed_json):
        mock_cm = _make_urlopen_mock(sample_feed_json)
        captured = {}

        def fake_urlopen(req, timeout=None):
            captured["headers"] = req.headers
            return mock_cm

        with patch("urllib.request.urlopen", side_effect=fake_urlopen):
            kev_sync.fetch_kev_feed("https://example.com/kev.json")

        assert "User-agent" in captured["headers"]
        assert "LME" in captured["headers"]["User-agent"]


# ---------------------------------------------------------------------------
# write_catalog
# ---------------------------------------------------------------------------

class TestWriteCatalog:
    def test_file_created(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "kev_catalog.json"
        kev_sync.write_catalog(catalog, str(dest))
        assert dest.exists()

    def test_content_is_valid_json(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "kev_catalog.json"
        kev_sync.write_catalog(catalog, str(dest))
        with open(dest) as fh:
            loaded = json.load(fh)
        assert loaded["total"] == 3
        assert "CVE-2021-44228" in loaded["cves"]

    def test_creates_parent_dirs(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "deep" / "nested" / "kev_catalog.json"
        kev_sync.write_catalog(catalog, str(dest))
        assert dest.exists()

    def test_overwrites_existing_file(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "kev_catalog.json"
        dest.write_text("old content")
        kev_sync.write_catalog(catalog, str(dest))
        with open(dest) as fh:
            loaded = json.load(fh)
        assert loaded["total"] == 3

    def test_no_tmp_files_left_on_success(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        kev_sync.write_catalog(catalog, str(tmp_path / "kev_catalog.json"))
        tmp_files = list(tmp_path.glob(".kev_catalog_tmp_*"))
        assert tmp_files == []


# ---------------------------------------------------------------------------
# append_history
# ---------------------------------------------------------------------------

class TestAppendHistory:
    def _entry(self, status="ok", total=100):
        return {"timestamp": "2024-01-01T00:00:00Z", "status": status, "total": total}

    def test_creates_history_file(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        kev_sync.append_history(self._entry(), str(hist))
        assert hist.exists()

    def test_first_entry_stored(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        kev_sync.append_history(self._entry(total=42), str(hist))
        with open(hist) as fh:
            data = json.load(fh)
        assert len(data) == 1
        assert data[0]["total"] == 42

    def test_multiple_entries_appended(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        for i in range(5):
            kev_sync.append_history(self._entry(total=i), str(hist))
        with open(hist) as fh:
            data = json.load(fh)
        assert len(data) == 5
        assert [e["total"] for e in data] == list(range(5))

    def test_capped_at_max_entries(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        for i in range(10):
            kev_sync.append_history(self._entry(total=i), str(hist), max_entries=5)
        with open(hist) as fh:
            data = json.load(fh)
        assert len(data) == 5
        # Should keep the 5 most recent (totals 5..9)
        assert [e["total"] for e in data] == list(range(5, 10))

    def test_corrupted_history_file_reset(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        hist.write_text("not valid json {{{{")
        kev_sync.append_history(self._entry(), str(hist))
        with open(hist) as fh:
            data = json.load(fh)
        assert len(data) == 1

    def test_non_list_history_reset(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        hist.write_text('{"not": "a list"}')
        kev_sync.append_history(self._entry(), str(hist))
        with open(hist) as fh:
            data = json.load(fh)
        assert isinstance(data, list)
        assert len(data) == 1

    def test_error_entry_stored(self, tmp_path):
        hist = tmp_path / "kev_history.json"
        entry = {"timestamp": "2024-01-01T00:00:00Z", "status": "error",
                 "total": 0, "error": "network timeout"}
        kev_sync.append_history(entry, str(hist))
        with open(hist) as fh:
            data = json.load(fh)
        assert data[0]["status"] == "error"
        assert data[0]["error"] == "network timeout"


# ---------------------------------------------------------------------------
# lookup_cve
# ---------------------------------------------------------------------------

class TestLookupCve:
    def test_found(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "kev_catalog.json"
        kev_sync.write_catalog(catalog, str(dest))
        result = kev_sync.lookup_cve("CVE-2021-44228", str(dest))
        assert result is not None
        assert result["vendorProject"] == "Apache"

    def test_not_found_returns_none(self, tmp_path, sample_feed):
        catalog = kev_sync.parse_feed(sample_feed)
        dest = tmp_path / "kev_catalog.json"
        kev_sync.write_catalog(catalog, str(dest))
        assert kev_sync.lookup_cve("CVE-9999-9999", str(dest)) is None

    def test_missing_catalog_returns_none(self, tmp_path):
        assert kev_sync.lookup_cve("CVE-2021-44228", str(tmp_path / "missing.json")) is None

    def test_corrupted_catalog_returns_none(self, tmp_path):
        dest = tmp_path / "bad.json"
        dest.write_text("{{corrupted")
        assert kev_sync.lookup_cve("CVE-2021-44228", str(dest)) is None


# ---------------------------------------------------------------------------
# main() integration
# ---------------------------------------------------------------------------

class TestMain:
    def test_successful_run_returns_0(self, tmp_path, sample_feed_json):
        mock_cm = _make_urlopen_mock(sample_feed_json)
        catalog_path = str(tmp_path / "kev_catalog.json")
        history_path = str(tmp_path / "kev_history.json")

        with patch("urllib.request.urlopen", return_value=mock_cm), \
             patch.object(kev_sync, "KEV_CATALOG_PATH", catalog_path), \
             patch.object(kev_sync, "KEV_HISTORY_PATH", history_path):
            rc = kev_sync.main()

        assert rc == 0
        assert Path(catalog_path).exists()
        assert Path(history_path).exists()

    def test_successful_run_writes_ok_history(self, tmp_path, sample_feed_json):
        mock_cm = _make_urlopen_mock(sample_feed_json)
        catalog_path = str(tmp_path / "kev_catalog.json")
        history_path = str(tmp_path / "kev_history.json")

        with patch("urllib.request.urlopen", return_value=mock_cm), \
             patch.object(kev_sync, "KEV_CATALOG_PATH", catalog_path), \
             patch.object(kev_sync, "KEV_HISTORY_PATH", history_path):
            kev_sync.main()

        with open(history_path) as fh:
            history = json.load(fh)
        assert history[-1]["status"] == "ok"
        assert history[-1]["total"] == 3

    def test_network_failure_returns_1(self, tmp_path):
        import urllib.error
        history_path = str(tmp_path / "kev_history.json")

        with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("refused")), \
             patch.object(kev_sync, "KEV_HISTORY_PATH", history_path):
            rc = kev_sync.main()

        assert rc == 1
        with open(history_path) as fh:
            history = json.load(fh)
        assert history[-1]["status"] == "error"

    def test_parse_failure_returns_1(self, tmp_path):
        bad_json = json.dumps({"no_vulnerabilities": True}).encode()
        mock_cm = _make_urlopen_mock(bad_json)
        history_path = str(tmp_path / "kev_history.json")

        with patch("urllib.request.urlopen", return_value=mock_cm), \
             patch.object(kev_sync, "KEV_HISTORY_PATH", history_path):
            rc = kev_sync.main()

        assert rc == 1
        with open(history_path) as fh:
            history = json.load(fh)
        assert history[-1]["status"] == "error"

    def test_write_failure_returns_1(self, tmp_path, sample_feed_json):
        mock_cm = _make_urlopen_mock(sample_feed_json)
        history_path = str(tmp_path / "kev_history.json")
        # Point catalog at a path we can't write (a directory)
        bad_path = str(tmp_path / "is_a_dir" / "kev_catalog.json")
        (tmp_path / "is_a_dir").mkdir()
        (tmp_path / "is_a_dir" / "kev_catalog.json").mkdir()  # make it a dir, not a file

        with patch("urllib.request.urlopen", return_value=mock_cm), \
             patch.object(kev_sync, "KEV_CATALOG_PATH", bad_path), \
             patch.object(kev_sync, "KEV_HISTORY_PATH", history_path):
            rc = kev_sync.main()

        assert rc == 1
