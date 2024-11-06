import json
import warnings

import pytest
from jsonschema import validate
from jsonschema.exceptions import ValidationError
import requests
from requests.auth import HTTPBasicAuth
import urllib3
import os

from api_tests.helpers import make_request, load_json_schema

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

current_script_path = os.path.abspath(__file__)
current_script_dir = os.path.dirname(current_script_path)


def convertJsonFileToString(file_path):
    with open(file_path, "r") as file:
        return file.read()


@pytest.fixture(autouse=True)
def suppress_insecure_request_warning():
    warnings.simplefilter("ignore", urllib3.exceptions.InsecureRequestWarning)


def test_host_search(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/.ds-metrics-system.cpu-default-*/_search"
    body = load_json_schema(f"{current_script_dir}/queries/hostsearch.json")
    response = make_request(url, username, password, body=body)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    #assert "winlog" in data ["winlogbeat-imported"]["mappings"]["properties"]
    
    # Getting the value of Root Key
    for key in data:
        rootKey = key

    assert (data[rootKey]["total"]["value"] > 0)
    assert ".ds-metrics-system.cpu-default" in data[rootKey]["hits"][0]["_index"]    
    assert (data[rootKey]["hits"][0]["_source"]["agent"]["name"] == "ubuntu-vm")    
    assert (data[rootKey]["hits"][0]["_source"]["agent"]["version"] == "8.15.3") 
    assert (data[rootKey]["hits"][0]["_source"]["cloud"]["instance"]["name"] == "ubuntu")  
    assert (data[rootKey]["hits"][0]["_source"]["data_stream"]["dataset"] == "system.cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["ecs"]["version"] == "8.0.0") 
    assert (data[rootKey]["hits"][0]["_source"]["elastic_agent"]["version"] == "8.15.3") 
    assert (data[rootKey]["hits"][0]["_source"]["event"]["dataset"] == "system.cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["host"]["hostname"] == "ubuntu-vm") 
    assert (data[rootKey]["hits"][0]["_source"]["metricset"]["name"] == "cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["service"]["type"] == "system") 
    assert "system" in data[rootKey]["hits"][0]["_source"]