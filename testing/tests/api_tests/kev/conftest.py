"""Fixtures shared across KEV tests."""
import json
import pytest


SAMPLE_FEED = {
    "title": "CISA Known Exploited Vulnerabilities Catalog",
    "catalogVersion": "2024.01.01",
    "dateReleased": "2024-01-01T00:00:00.0000Z",
    "count": 3,
    "vulnerabilities": [
        {
            "cveID": "CVE-2021-44228",
            "vendorProject": "Apache",
            "product": "Log4j2",
            "vulnerabilityName": "Apache Log4j2 Remote Code Execution Vulnerability",
            "dateAdded": "2021-12-10",
            "shortDescription": "Apache Log4j2 contains a RCE vulnerability.",
            "requiredAction": "Apply updates per vendor instructions.",
            "dueDate": "2021-12-24",
            "knownRansomwareCampaignUse": "Known",
            "notes": "",
        },
        {
            "cveID": "CVE-2022-30190",
            "vendorProject": "Microsoft",
            "product": "Windows",
            "vulnerabilityName": "Microsoft Windows Support Diagnostic Tool (MSDT) RCE",
            "dateAdded": "2022-05-31",
            "shortDescription": "Follina vulnerability.",
            "requiredAction": "Apply updates per vendor instructions.",
            "dueDate": "2022-06-14",
            "knownRansomwareCampaignUse": "Known",
            "notes": "",
        },
        {
            "cveID": "CVE-2023-23397",
            "vendorProject": "Microsoft",
            "product": "Outlook",
            "vulnerabilityName": "Microsoft Outlook Elevation of Privilege Vulnerability",
            "dateAdded": "2023-03-14",
            "shortDescription": "Microsoft Outlook contains an EoP vulnerability.",
            "requiredAction": "Apply updates per vendor instructions.",
            "dueDate": "2023-04-04",
            "knownRansomwareCampaignUse": "Unknown",
            "notes": "",
        },
    ],
}


@pytest.fixture
def sample_feed():
    """A minimal but realistic CISA KEV feed payload."""
    return SAMPLE_FEED


@pytest.fixture
def sample_feed_json(sample_feed):
    """sample_feed serialised to JSON bytes (as urlopen would return)."""
    return json.dumps(sample_feed).encode()
