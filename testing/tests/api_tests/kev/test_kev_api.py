"""
Unit tests for the KEV API routes in lme-dashboard/app.py.

Uses FastAPI's TestClient (httpx-based) and mocks filesystem/subprocess
so the suite runs without any external services.
"""

import json
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Ensure the dashboard package is importable
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parents[4]
_DASHBOARD = _REPO_ROOT / "lme-dashboard"
if str(_DASHBOARD) not in sys.path:
    sys.path.insert(0, str(_DASHBOARD))

import app as dashboard_app
from fastapi.testclient import TestClient

client = TestClient(dashboard_app.app, raise_server_exceptions=False)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SAMPLE_CATALOG = {
    "generated": "2024-06-01T12:00:00Z",
    "total": 3,
    "cves": {
        "CVE-2021-44228": {"vendorProject": "Apache", "dueDate": "2021-12-24",
                           "knownRansomwareCampaignUse": "Known"},
        "CVE-2022-30190": {"vendorProject": "Microsoft", "dueDate": "2022-06-14",
                           "knownRansomwareCampaignUse": "Known"},
        "CVE-2023-23397": {"vendorProject": "Microsoft", "dueDate": "2023-04-04",
                           "knownRansomwareCampaignUse": "Unknown"},
    },
}

SAMPLE_HISTORY = [
    {"timestamp": "2024-06-01T11:00:00Z", "status": "ok", "total": 2},
    {"timestamp": "2024-06-01T12:00:00Z", "status": "ok", "total": 3},
]


@pytest.fixture(autouse=True)
def reset_kev_paths(tmp_path):
    """Point all KEV paths to tmp_path so tests never touch /opt/lme."""
    catalog = str(tmp_path / "kev_catalog.json")
    history = str(tmp_path / "kev_history.json")
    config  = str(tmp_path / "kev_config.json")

    with patch.multiple(dashboard_app,
                        KEV_CATALOG_PATH=catalog,
                        KEV_HISTORY_PATH=history,
                        KEV_CONFIG_PATH=config):
        yield {
            "catalog": catalog,
            "history": history,
            "config":  config,
            "tmp":     tmp_path,
        }


def _write_catalog(paths):
    Path(paths["catalog"]).write_text(json.dumps(SAMPLE_CATALOG))


def _write_history(paths):
    Path(paths["history"]).write_text(json.dumps(SAMPLE_HISTORY))


# ---------------------------------------------------------------------------
# GET /api/kev/status
# ---------------------------------------------------------------------------

class TestKevStatus:
    def test_returns_200(self, reset_kev_paths):
        resp = client.get("/api/kev/status")
        assert resp.status_code == 200

    def test_badge_never_when_no_catalog(self, reset_kev_paths):
        resp = client.get("/api/kev/status")
        data = resp.json()
        assert data["badge"] == "never"
        assert data["total_kev"] == 0

    def test_badge_current_for_fresh_catalog(self, reset_kev_paths):
        # Write catalog with timestamp from right now
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        catalog = {**SAMPLE_CATALOG, "generated": now}
        Path(reset_kev_paths["catalog"]).write_text(json.dumps(catalog))

        resp = client.get("/api/kev/status")
        assert resp.json()["badge"] == "current"

    def test_badge_stale_for_old_catalog(self, reset_kev_paths):
        old_catalog = {**SAMPLE_CATALOG, "generated": "2020-01-01T00:00:00Z"}
        Path(reset_kev_paths["catalog"]).write_text(json.dumps(old_catalog))

        resp = client.get("/api/kev/status")
        assert resp.json()["badge"] == "stale"

    def test_total_kev_from_catalog(self, reset_kev_paths):
        _write_catalog(reset_kev_paths)
        resp = client.get("/api/kev/status")
        assert resp.json()["total_kev"] == 3

    def test_last_pull_status_from_history(self, reset_kev_paths):
        _write_catalog(reset_kev_paths)
        _write_history(reset_kev_paths)
        resp = client.get("/api/kev/status")
        assert resp.json()["last_pull_status"] == "ok"

    def test_settings_included(self, reset_kev_paths):
        resp = client.get("/api/kev/status")
        data = resp.json()
        assert "settings" in data
        assert "auto_pull" in data["settings"]
        assert "frequency_hours" in data["settings"]

    def test_settings_reflect_persisted_config(self, reset_kev_paths):
        Path(reset_kev_paths["config"]).write_text(
            json.dumps({"auto_pull": False, "frequency_hours": 6,
                        "alert_on_match": True, "alert_on_overdue": False,
                        "ransomware_only": True})
        )
        resp = client.get("/api/kev/status")
        s = resp.json()["settings"]
        assert s["auto_pull"] is False
        assert s["frequency_hours"] == 6
        assert s["ransomware_only"] is True


# ---------------------------------------------------------------------------
# GET /api/kev/history
# ---------------------------------------------------------------------------

class TestKevHistory:
    def test_returns_200(self, reset_kev_paths):
        resp = client.get("/api/kev/history")
        assert resp.status_code == 200

    def test_empty_when_no_history_file(self, reset_kev_paths):
        resp = client.get("/api/kev/history")
        assert resp.json()["history"] == []

    def test_returns_history_entries(self, reset_kev_paths):
        _write_history(reset_kev_paths)
        resp = client.get("/api/kev/history")
        data = resp.json()["history"]
        assert len(data) == 2
        assert data[-1]["status"] == "ok"
        assert data[-1]["total"] == 3

    def test_n_parameter_limits_results(self, reset_kev_paths):
        _write_history(reset_kev_paths)
        resp = client.get("/api/kev/history?n=1")
        assert len(resp.json()["history"]) == 1

    def test_n_out_of_range_rejected(self, reset_kev_paths):
        resp = client.get("/api/kev/history?n=0")
        assert resp.status_code == 422
        resp = client.get("/api/kev/history?n=101")
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# POST /api/kev/pull
# ---------------------------------------------------------------------------

class TestKevPull:
    def _mock_script_path(self, reset_kev_paths):
        """Return a path to kev_sync.py that actually exists."""
        return str(_REPO_ROOT / "scripts" / "kev_sync.py")

    def test_returns_200_on_success(self, reset_kev_paths):
        _write_catalog(reset_kev_paths)
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "[kev_sync] OK — wrote 3 CVEs"
        mock_result.stderr = ""

        with patch("subprocess.run", return_value=mock_result), \
             patch.object(dashboard_app.Path, "exists", return_value=True):
            resp = client.post("/api/kev/pull")

        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"

    def test_returns_total_from_catalog(self, reset_kev_paths):
        _write_catalog(reset_kev_paths)
        mock_result = MagicMock(returncode=0, stdout="OK", stderr="")

        with patch("subprocess.run", return_value=mock_result), \
             patch.object(dashboard_app.Path, "exists", return_value=True):
            resp = client.post("/api/kev/pull")

        assert resp.json()["total"] == 3

    def test_script_failure_returns_500(self, reset_kev_paths):
        mock_result = MagicMock(returncode=1, stdout="", stderr="network error")

        with patch("subprocess.run", return_value=mock_result), \
             patch.object(dashboard_app.Path, "exists", return_value=True):
            resp = client.post("/api/kev/pull")

        assert resp.status_code == 500

    def test_timeout_returns_504(self, reset_kev_paths):
        with patch("subprocess.run", side_effect=__import__("subprocess").TimeoutExpired("cmd", 60)), \
             patch.object(dashboard_app.Path, "exists", return_value=True):
            resp = client.post("/api/kev/pull")
        assert resp.status_code == 504

    def test_script_not_found_returns_404(self, reset_kev_paths):
        # Patch KEV_SYNC_SCRIPT to a nonexistent path AND make Path.exists
        # return False so the fallback repo-relative path also fails.
        with patch.object(dashboard_app, "KEV_SYNC_SCRIPT", "/nonexistent/kev_sync.py"), \
             patch("app.Path.exists", return_value=False):
            resp = client.post("/api/kev/pull")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# PATCH /api/settings/kev
# ---------------------------------------------------------------------------

class TestKevSettings:
    def _valid_payload(self, **overrides):
        base = {
            "auto_pull": True,
            "frequency_hours": 24,
            "alert_on_match": True,
            "alert_on_overdue": True,
            "ransomware_only": False,
        }
        return {**base, **overrides}

    def test_returns_200_with_valid_payload(self, reset_kev_paths):
        resp = client.patch("/api/settings/kev", json=self._valid_payload())
        assert resp.status_code == 200

    def test_returns_updated_settings(self, reset_kev_paths):
        payload = self._valid_payload(auto_pull=False, frequency_hours=6, ransomware_only=True)
        resp = client.patch("/api/settings/kev", json=payload)
        s = resp.json()["settings"]
        assert s["auto_pull"] is False
        assert s["frequency_hours"] == 6
        assert s["ransomware_only"] is True

    def test_settings_persisted_to_disk(self, reset_kev_paths):
        payload = self._valid_payload(frequency_hours=12, alert_on_overdue=False)
        client.patch("/api/settings/kev", json=payload)

        with open(reset_kev_paths["config"]) as fh:
            saved = json.load(fh)
        assert saved["frequency_hours"] == 12
        assert saved["alert_on_overdue"] is False

    def test_invalid_frequency_rejected(self, reset_kev_paths):
        resp = client.patch("/api/settings/kev", json=self._valid_payload(frequency_hours=7))
        assert resp.status_code == 400

    def test_valid_frequencies_accepted(self, reset_kev_paths):
        for freq in (6, 12, 24, 168):
            resp = client.patch("/api/settings/kev", json=self._valid_payload(frequency_hours=freq))
            assert resp.status_code == 200, f"frequency {freq} was rejected"

    def test_missing_field_uses_default(self, reset_kev_paths):
        # Pydantic defaults kick in when a field is omitted
        resp = client.patch("/api/settings/kev",
                            json={"auto_pull": False, "frequency_hours": 24,
                                  "alert_on_match": True, "alert_on_overdue": True,
                                  "ransomware_only": False})
        assert resp.status_code == 200

    def test_wrong_type_rejected(self, reset_kev_paths):
        resp = client.patch("/api/settings/kev",
                            json=self._valid_payload(frequency_hours="daily"))
        assert resp.status_code == 422
