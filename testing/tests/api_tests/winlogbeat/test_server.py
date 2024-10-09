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


@pytest.mark.skip(reason="We no longer use winlogbeat. Keeping the test for reference")
def test_elastic_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/winlogbeat-*/_mapping"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    assert "winlog" in data ["winlogbeat-imported"]["mappings"]["properties"]
    assert "@timestamp" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "activity_id" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "api" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "channel" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "computer_name" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "event_data" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "event_id" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "host" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "keywords" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "logon" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "opcode" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "process" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "provider_guid" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "provider_name" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "record_id" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "related_activity_id" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "task" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "time_created" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "user" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "user_data" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 
    assert "version" in data ["winlogbeat-imported"]["mappings"]["properties"]["winlog"]["properties"] 


@pytest.mark.skip(reason="We no longer use winlogbeat. Keeping the test for reference")
def test_winlogbeat_settings(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}/winlogbeat-*/_settings"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()

    # Getting the value of Root Key
    for key in body:
        rootKey = key

    assert (
            body[rootKey]["settings"]["index"]["lifecycle"]["name"] == "lme_ilm_policy"
    ), f'Expected "lme_ilm_policy", got {body[rootKey]["settings"]["index"]["lifecycle"]["name"]}'
    assert (
            body[rootKey]["settings"]["index"]["lifecycle"]["rollover_alias"]
            == "winlogbeat-alias"
    ), f'Expected "winlogbeat-alias", got {body[rootKey]["settings"]["index"]["lifecycle"]["rollover_alias"]}'

    assert (
            "creation_date" in body[rootKey]["settings"]["index"]
    ), "Expected creation_date property, not found"
    assert (
            "number_of_replicas" in body[rootKey]["settings"]["index"]
    ), "Expected number_of_replicas property, not found"
    assert (
            "uuid" in body[rootKey]["settings"]["index"]
    ), "Expected uuid property, not found"
    assert (
            "created" in body[rootKey]["settings"]["index"]["version"]
    ), "Expected created property, not found"

    with open(f"{current_script_dir}/test_data/mapping_datafields.txt") as f:
        data_fields = f.read().splitlines()

    act_data_fields = body[rootKey]["settings"]["index"]["query"]["default_field"]
    assert (
            act_data_fields.sort() == data_fields.sort()
    ), "Winlogbeats data fields do not match"

@pytest.mark.skip(reason="We no longer use winlogbeat. Keeping the test for reference")
def test_winlogbeat_search(es_host, es_port, username, password):
    # This test requires DC1 instance in cluster set up otherwise it will fail
    url = f"https://{es_host}:{es_port}/winlogbeat-*/_search"
    body = {"size": 1, "query": {"term": {"host.name": "DC1.lme.local"}}}
    response = make_request(url, username, password, body=body)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    # json.dump(
    #     data,
    #     open(f"{current_script_dir}/test_data/winlog_search_data.json", "w"),
    #     indent=4,
    # )
    
    assert data["hits"]["hits"][0]["_index"] == "winlogbeat-imported"
    assert data["hits"]["hits"][0]["_source"]["agent"]["name"] == "DC1"
    assert data["hits"]["hits"][0]["_source"]["agent"]["type"] == "winlogbeat"
    assert data["hits"]["hits"][0]["_source"]["winlog"]["computer_name"] == "DC1.lme.local"
    assert data["hits"]["hits"][0]["_source"]["ecs"]["version"] == "8.0.0"
    assert data["hits"]["hits"][0]["_source"]["log"]["level"] == "information"
    assert data["hits"]["hits"][0]["_source"]["host"]["name"] == "DC1.lme.local"
    assert data["hits"]["hits"][0]["_source"]["event"]["provider"] == "PowerShell"
    assert data["hits"]["hits"][0]["_source"]["tags"][0] == "beats"

    # Validating JSON Response schema
    #schema = load_json_schema(f"{current_script_dir}/schemas/winlogbeat_search.json")
    #validate(instance=response.json(), schema=schema)
