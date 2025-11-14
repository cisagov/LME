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


def test_elastic_root(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()

    assert body["name"] == "lme-elasticsearch", f"Expected 'lme-elasticsearch', got {body['name']}"
    assert (
            body["cluster_name"] == "LME"
    ), f"Expected 'LME', got {body['cluster_name']}"
    assert (
            body["version"]["number"] == "8.18.8"
    ), f"Expected '8.18.8', got {body['version']['number']}"
    assert (
            body["version"]["build_flavor"] == "default"
    ), f"Expected 'default', got {body['version']['build_flavor']}"
    assert (
            body["version"]["build_type"] == "docker"
    ), f"Expected 'docker', got {body['version']['build_type']}"
    assert (
            body["version"]["lucene_version"] == "9.12.1"
    ), f"Expected '9.11.1', got {body['version']['lucene_version']}"

    assert (
            body["version"]["minimum_wire_compatibility_version"] == "7.17.0"
    ), f"Expected '7.17.0', got {body['version']['minimum_wire_compatibility_version']}"
    assert (
            body["version"]["minimum_index_compatibility_version"] == "7.0.0"
    ), f"Expected '7.0.0', got {body['version']['minimum_index_compatibility_version']}"

    # Validating JSON Response schema
    schema = load_json_schema(f"{current_script_dir}/schemas/es_root.json")
    validate(instance=response.json(), schema=schema)

#@pytest.mark.skip(reason="These indices were changed in the new LME version")
def test_elastic_indices(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}/_cat/indices/"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
             
    assert ("open elastalert_status" in response.text)                                                 
    assert ("open .ds-metrics-fleet_server.agent_status-default" in response.text)
    assert ("open .ds-metrics-elastic_agent.metricbeat-default" in response.text)   
    assert ("open .ds-metrics-elastic_agent.fleet_server-default" in response.text) 
    assert ("open elastalert_status_silence" in response.text)                                         
    assert ("open .ds-metrics-elastic_agent.filebeat-default" in response.text)     
    assert ("open .ds-metrics-elastic_agent.filebeat_input-default" in response.text)
    assert ("open .internal.alerts-security.alerts-default" in response.text)                  
    assert ("open elastalert_status_error" in response.text)                                           
    assert ("open .ds-metrics-fleet_server.agent_versions-default" in response.text)
    assert ("open elastalert_status_status" in response.text)                                          
    assert ("open elastalert_status_past" in response.text)                                            
    assert ("open wazuh-states-vulnerabilities-wazuh-manager" in response.text)                        
    assert ("open metrics-endpoint.metadata_current_default" in response.text)  # Endpoint metrics may not exist yet                                
    assert ("open .ds-logs-elastic_agent-default" in response.text)                 
    assert ("open wazuh-alerts-4.x" in response.text)                                     
    assert ("open .ds-metrics-elastic_agent.elastic_agent-default" in response.text)
    assert ("open .ds-logs-elastic_agent.fleet_server-default" in response.text) 
