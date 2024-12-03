import json
import warnings

import pytest
from jsonschema import validate
#from jsonschema.exceptions import ValidationError
#import requests
#from requests.auth import HTTPBasicAuth
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
    assert (data[rootKey]["hits"][0]["_source"]["data_stream"]["dataset"] == "system.cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["ecs"]["version"] == "8.0.0") 
    assert (data[rootKey]["hits"][0]["_source"]["elastic_agent"]["version"] == "8.15.3") 
    assert (data[rootKey]["hits"][0]["_source"]["event"]["dataset"] == "system.cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["host"]["hostname"] == "ubuntu-vm") 
    assert (data[rootKey]["hits"][0]["_source"]["metricset"]["name"] == "cpu") 
    assert (data[rootKey]["hits"][0]["_source"]["service"]["type"] == "system") 
    assert "system" in data[rootKey]["hits"][0]["_source"]
    

def test_logs_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/logs-*/_mapping"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-logs-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-logs-elastic_agent-default-" in response.text
    assert ".ds-logs-elastic_agent.filebeat-default-" in response.text
    assert ".ds-logs-system.auth-default-" in response.text
    assert ".ds-logs-endpoint.events.network-default-" in response.text
    assert ".ds-logs-system.syslog-default-" in response.text
    assert ".ds-logs-elastic_agent.fleet_server-default-" in response.text
    assert ".ds-logs-endpoint.events.file-default-" in response.text
    assert ".ds-logs-endpoint.events.process-default-" in response.text
    assert ".ds-logs-elastic_agent.metricbeat-default-" in response.text
    
def test_logs_settings(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/logs-*/_settings"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-logs-endpoint.events.process-default-" in response.text
    assert ".ds-logs-elastic_agent.metricbeat-default-" in response.text
    assert ".ds-logs-elastic_agent.fleet_server-default-" in response.text
    assert ".ds-logs-endpoint.events.file-default-" in response.text
    assert ".ds-logs-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-logs-elastic_agent-default-" in response.text
    assert ".ds-logs-system.syslog-default-" in response.text
    assert ".ds-logs-elastic_agent.filebeat-default-" in response.text
    assert ".ds-logs-system.auth-default-" in response.text
    assert ".ds-logs-endpoint.events.network-default-" in response.text
 
@pytest.mark.skip(reason="Test is currently failing on develop branch")   
def test_logs_search(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/.ds-logs-elastic_agent-default-*/_search"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    
    # Getting the value of Root Key
    for key in data:
        rootKey = key

    assert (data[rootKey]["total"]["value"] > 0)
    
    with open(f"{current_script_dir}/test_data/wazuh_manager_vulnerabilities.txt") as f:
        data_fields = f.read().splitlines()
    act_data_fields=""
    
    
    
    for x in range(len(data[rootKey]["hits"])):
        if "inputs" in data[rootKey]["hits"][x]["_source"]:
            act_data_fields=data[rootKey]["hits"][x]["_source"]["inputs"]
            if (act_data_fields.sort() == data_fields.sort()):
                break
    
    assert (
            act_data_fields.sort() == data_fields.sort()
    ), "Logs inputs do not match"
    
def test_metrics_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/metrics-*/_mapping"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-metrics-system.process.summary-default" in response.text
    assert ".ds-metrics-system.memory-default-" in response.text
    assert ".ds-metrics-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-metrics-system.cpu-default-" in response.text
    assert ".ds-metrics-endpoint.metadata-default-" in response.text
    assert ".ds-metrics-system.process-default-" in response.text
    assert ".ds-metrics-elastic_agent.filebeat-default-" in response.text
    assert ".ds-metrics-system.diskio-default-" in response.text
    assert ".ds-metrics-endpoint.policy-default-" in response.text
    assert ".ds-metrics-system.socket_summary-default-" in response.text  
    assert ".ds-metrics-system.load-default-" in response.text
    assert ".ds-metrics-fleet_server.agent_status-default-" in response.text
    assert "metrics-endpoint.metadata_current_default" in response.text
    assert ".ds-metrics-elastic_agent.elastic_agent-default-" in response.text
    assert ".ds-metrics-system.fsstat-default-" in response.text
    assert ".ds-metrics-elastic_agent.fleet_server-default-" in response.text
    assert ".ds-metrics-fleet_server.agent_versions-default-" in response.text
    assert ".ds-metrics-system.network-default-" in response.text
    assert ".ds-metrics-endpoint.metrics-default-" in response.text
    assert ".ds-metrics-elastic_agent.metricbeat-default-" in response.text
    assert ".ds-metrics-elastic_agent.filebeat_input-default-" in response.text
    assert ".ds-metrics-system.uptime-default-" in response.text
    assert ".ds-metrics-system.filesystem-default-" in response.text
    
    
def test_metrics_settings(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/metrics-*/_settings"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-metrics-system.process.summary-default-" in response.text
    assert ".ds-metrics-system.fsstat-default-" in response.text
    assert ".ds-metrics-elastic_agent.fleet_server-default-" in response.text
    assert ".ds-metrics-system.load-default-" in response.text
    assert ".ds-metrics-endpoint.metrics-default-" in response.text
    assert ".ds-metrics-endpoint.policy-default-" in response.text
    assert ".ds-metrics-elastic_agent.filebeat-default-" in response.text
    assert ".ds-metrics-system.diskio-default-" in response.text
    assert ".ds-metrics-endpoint.metadata-default-" in response.text
    assert ".ds-metrics-system.uptime-default-" in response.text  
    assert ".ds-metrics-system.socket_summary-default-" in response.text
    assert ".ds-metrics-elastic_agent.filebeat_input-default-" in response.text
    assert "metrics-endpoint.metadata_current_default" in response.text
    assert ".ds-metrics-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-metrics-fleet_server.agent_versions-default-" in response.text
    assert ".ds-metrics-system.process-default-" in response.text
    assert ".ds-metrics-system.cpu-default-" in response.text
    assert ".ds-metrics-system.memory-default-" in response.text
    assert ".ds-metrics-elastic_agent.metricbeat-default-" in response.text
    assert ".ds-metrics-system.network-default-" in response.text
    assert ".ds-metrics-system.filesystem-default-" in response.text
    assert ".ds-metrics-fleet_server.agent_status-default-" in response.text
    assert ".ds-metrics-elastic_agent.elastic_agent-default-" in response.text
    
def test_metrics_search(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/.ds-metrics-elastic_agent.elastic_agent-default*/_search"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    
    # Getting the value of Root Key
    for key in data:
        rootKey = key

    assert (data[rootKey]["total"]["value"] > 0)
    assert data[rootKey]["hits"][0]["_source"]["agent"]["name"]=="lme-fleet-server"
    assert data[rootKey]["hits"][0]["_source"]["agent"]["type"]=="metricbeat"
    assert data[rootKey]["hits"][0]["_source"]["component"]["binary"]=="metricbeat"
    assert data[rootKey]["hits"][0]["_source"]["component"]["id"]=="http/metrics-monitoring"
    assert data[rootKey]["hits"][0]["_source"]["data_stream"]["dataset"]=="elastic_agent.elastic_agent"
    
def test_wazuh_alert_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/wazuh-alerts-4.x-*/_mapping"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    for key in data:
        rootKey = key


    assert "@timestamp" in data[rootKey]["mappings"]["properties"]
    assert "@version" in data[rootKey]["mappings"]["properties"]
    assert "GeoLocation" in data[rootKey]["mappings"]["properties"]
    assert "agent" in data[rootKey]["mappings"]["properties"]
    assert "cluster" in data[rootKey]["mappings"]["properties"]
    assert "command" in data[rootKey]["mappings"]["properties"]
    assert "data" in data[rootKey]["mappings"]["properties"]
    assert "decoder" in data[rootKey]["mappings"]["properties"]
    assert "full_log" in data[rootKey]["mappings"]["properties"]
    assert "host" in data[rootKey]["mappings"]["properties"]
    assert "id" in data[rootKey]["mappings"]["properties"]
    assert "input" in data[rootKey]["mappings"]["properties"]
    assert "location" in data[rootKey]["mappings"]["properties"]
    assert "manager" in data[rootKey]["mappings"]["properties"]
    assert "message" in data[rootKey]["mappings"]["properties"]
    assert "offset" in data[rootKey]["mappings"]["properties"]
    assert "predecoder" in data[rootKey]["mappings"]["properties"]
    assert "previous_log" in data[rootKey]["mappings"]["properties"]
    assert "previous_output" in data[rootKey]["mappings"]["properties"]
    assert "program_name" in data[rootKey]["mappings"]["properties"]
    assert "rule" in data[rootKey]["mappings"]["properties"]
    assert "syscheck" in data[rootKey]["mappings"]["properties"]
    assert "timestamp" in data[rootKey]["mappings"]["properties"]
    assert "title" in data[rootKey]["mappings"]["properties"]
    assert "type" in data[rootKey]["mappings"]["properties"]
    
def test_wazuh_alert_settings(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/wazuh-alerts-4.x-*/_settings"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    for key in data:
        rootKey = key


    with open(f"{current_script_dir}/test_data/wazuh_datafields.txt") as f:
        data_fields = f.read().splitlines()

    act_data_fields = data[rootKey]["settings"]["index"]["query"]["default_field"]
    assert (
            act_data_fields.sort() == data_fields.sort()
    ), "Wazuh data fields do not match"
    
def test_wazuh_manager_vulnerabilities(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/wazuh-states-vulnerabilities-wazuh-manager/_settings"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    for key in data:
        rootKey = key


    with open(f"{current_script_dir}/test_data/wazuh_manager_vulnerabilities.txt") as f:
        data_fields = f.read().splitlines()

    act_data_fields = data[rootKey]["settings"]["index"]["query"]["default_field"]
    assert (
            act_data_fields.sort() == data_fields.sort()
    ), "Wazuh data fields do not match"