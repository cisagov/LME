import json
import warnings

import pytest
from jsonschema import validate
from jsonschema.exceptions import ValidationError
import requests
from requests.auth import HTTPBasicAuth
import urllib3
import os

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

current_script_path = os.path.abspath(__file__)
current_script_dir = os.path.dirname(current_script_path)

def make_request(url, username, password, body=None):
    auth = HTTPBasicAuth(username, password)
    headers = {'Content-Type': 'application/json'}

    if body:
        response = requests.post(url, auth=auth, verify=False, data=json.dumps(body), headers=headers)
    else:
        response = requests.get(url, auth=auth, verify=False)

    return response


def load_json_schema(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

@pytest.fixture(autouse=True)
def suppress_insecure_request_warning():
    warnings.simplefilter("ignore", urllib3.exceptions.InsecureRequestWarning)

def test_elastic_root():
    # Get the password from environment variable
    es_host = os.getenv('ES_HOST', 'localhost')
    es_port = os.getenv('ES_PORT', '9200')
    username = os.getenv('ES_USERNAME', 'elastic')
    password = os.getenv('elastic', 'default_password')
    url = f"https://{es_host}:{es_port}"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()
    assert body['name'] == 'es01', f"Expected 'es01', got {body['name']}"
    schema = load_json_schema(f"{current_script_dir}/schemas/es_root.json")
    try:
        validate(instance=response.text, schema=schema)
        print("JSON data is valid.")
    except ValidationError as ve:
        print("JSON data is invalid.")
        print(ve)