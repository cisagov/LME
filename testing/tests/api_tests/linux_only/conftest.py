# conftest.py

import os
import warnings
import pytest
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

@pytest.fixture(autouse=True)
def suppress_insecure_request_warning():
    warnings.simplefilter("ignore", urllib3.exceptions.InsecureRequestWarning)

@pytest.fixture
def es_host():
    return os.getenv("ES_HOST",os.getenv("ELASTIC_HOST",  "localhost"))

@pytest.fixture
def es_port():
    return os.getenv("ES_PORT",os.getenv("ELASTIC_PORT",  "9200"))

@pytest.fixture
def username():
    return os.getenv("ES_USERNAME",os.getenv("ELASTIC_USERNAME", "elastic"))

@pytest.fixture
def password():
    return os.getenv("elastic", os.getenv("ES_PASSWORD", os.getenv("ELASTIC_PASSWORD","default_password")))
