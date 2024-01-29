import requests
from requests.auth import HTTPBasicAuth
import urllib3
import pytest
import os

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def make_request(url, username, password):
    auth = HTTPBasicAuth(username, password)
    response = requests.get(url, auth=auth, verify=False)
    return response

def test_url_status():
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    username = os.getenv('ES_USERNAME', 'elastic')
    password = os.getenv('elastic', 'default_password')
    url = f"https://{es_host}:{es_port}"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
