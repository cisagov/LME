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
    
def find_json_key_paths(data, target_key, current_path=""):
    """
    Recursively finds the full path(s) to a target key within a JSON-like structure.

    Args:
        data: The JSON data (Python dict or list).
        target_key: The key to search for.
        current_path: The path accumulated so far (for internal use in recursion).

    Returns:
        A list of full paths (strings) to the target key.
    """
    paths = []

    if isinstance(data, dict):
        for key, value in data.items():
            new_path = f"{current_path}.{key}" if current_path else key
            if key == target_key:
                paths.append(new_path)
            paths.extend(find_json_key_paths(value, target_key, new_path))
    elif isinstance(data, list):
        for index, item in enumerate(data):
            new_path = f"{current_path}[{index}]"
            paths.extend(find_json_key_paths(item, target_key, new_path))
    return paths

def get_value_from_json_path(data_dict, json_path):
    """
    Retrieves a value from a nested dictionary (representing JSON) using a JSON path string.

    Args:
        data_dict (dict): The dictionary to traverse.
        json_path (str): The JSON path string (e.g., "level1.level2.key", "array[0].key").

    Returns:
        Any: The value found at the specified path, or None if the path is invalid.
    """
    keys = json_path.split('.')
    current_data = data_dict

    for key in keys:
        if '[' in key and ']' in key:  # Handle array indexing
            array_key, index_str = key.split('[')
            index = int(index_str[:-1])  # Remove ']' and convert to int
            if array_key:  # If there's a key before the array index
                if not isinstance(current_data, dict) or array_key not in current_data:
                    return None
                current_data = current_data[array_key]
            
            if not isinstance(current_data, list) or index >= len(current_data):
                return None
            current_data = current_data[index]
        else:  # Handle regular dictionary keys
            if not isinstance(current_data, dict) or key not in current_data:
                return None
            current_data = current_data[key]
    
    return current_data

    
def test_cluster_node(es_host, es_port, username, password):
    
    #API Request & Response
    url = f"https://{es_host}:{es_port}/_nodes"
    response = make_request(url, username, password)
    

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    for key in data:
        rootKey = key
        
    name_paths = find_json_key_paths(data, "name")
    name_path = name_paths[0]
    version_paths = find_json_key_paths(data, "version")
    version_path = version_paths[0]
    
    cluster_name = get_value_from_json_path(data, name_path)
    assert cluster_name == "lme-elasticsearch"
    cluster_version = get_value_from_json_path(data, version_path)
    assert cluster_version == "8.18.8"
    
def test_logging_policy(es_host, es_port, username, password):
    
    #API Request & Response
    url = f"https://{es_host}:{es_port}/_ilm/policy?pretty"
    response = make_request(url, username, password)
    

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    # Get the top-level keys
    top_level_keys = data.keys()

    # Convert the keys to a list if needed
    list_of_top_level_keys = list(top_level_keys)
    
    #file_name=f"{current_script_dir}/test_data/logging_policies.txt"
    #with open(file_name, 'w') as file:
    #    for item in list_of_top_level_keys:
    #        file.write(f"{item}\n")
    
    with open(f"{current_script_dir}/test_data/logging_policies.txt") as f:
        data_fields = f.read().splitlines()

    assert (
            list_of_top_level_keys.sort() == data_fields.sort()
    ), "Log Management policies do not match"

    

def test_logs_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/logs-*/_mapping"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-logs-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-logs-elastic_agent-default-" in response.text
    assert ".ds-logs-elastic_agent.filebeat-default-" in response.text
    #assert ".ds-logs-system.auth-default-" in response.text

    #assert ".ds-logs-endpoint.events.network-default-" in response.text

    #assert ".ds-logs-system.syslog-default-" in response.text
    assert ".ds-logs-elastic_agent.fleet_server-default-" in response.text
    assert ".ds-logs-endpoint.events.file-default-" in response.text
    assert ".ds-logs-endpoint.events.process-default-" in response.text
    assert ".ds-logs-elastic_agent.metricbeat-default-" in response.text
    
    assert ".ds-logs-endpoint.events.network-default-" in response.text

    #assert ".ds-logs-endpoint.events.library-default-" in response.text
    assert ".ds-logs-system.application-default-" in response.text
    assert ".ds-logs-system.system-default-" in response.text
    #assert ".ds-logs-endpoint.events.api-default-" in response.text
    assert ".ds-logs-system.security-default-" in response.text
    #assert ".ds-logs-endpoint.events.security-default-" in response.text
    assert ".ds-logs-endpoint.events.registry-default-" in response.text

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
    #assert ".ds-logs-system.syslog-default-" in response.text
    assert ".ds-logs-elastic_agent.filebeat-default-" in response.text
    #assert ".ds-logs-system.auth-default-" in response.text
    assert ".ds-logs-endpoint.events.network-default-" in response.text

    assert ".ds-logs-endpoint.events.library-default-" in response.text
    assert ".ds-logs-system.system-default-" in response.text
    assert ".ds-logs-system.application-default-" in response.text
    assert ".ds-logs-endpoint.events.registry-default-" in response.text
    #assert ".ds-logs-endpoint.events.api-default-" in response.text
    assert ".ds-logs-system.security-default-" in response.text
    #assert ".ds-logs-endpoint.events.security-default-" in response.text

#@pytest.mark.skip(reason="Test is currently failing on develop branch")   
def test_elastic_agent_logs_search(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/.ds-logs-elastic_agent-default-*/_search"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    
    # Getting the value of Root Key
    for key in data:
        rootKey = key

    assert (data[rootKey]["total"]["value"] > 0)
     
    for x in range(len(data[rootKey]["hits"])):
        assert "ds-logs-elastic_agent-default" in data[rootKey]["hits"][x]["_index"]
        assert "agent" in data[rootKey]["hits"][x]["_source"]
        assert "name" in data[rootKey]["hits"][x]["_source"]["agent"]
        assert "id" in data[rootKey]["hits"][x]["_source"]["agent"]
        assert "type" in data[rootKey]["hits"][x]["_source"]["agent"]
        assert "ephemeral_id" in data[rootKey]["hits"][x]["_source"]["agent"]
        assert "version" in data[rootKey]["hits"][x]["_source"]["agent"]
        #assert data[rootKey]["hits"][x]["_source"]["agent"]["version"]=="8.18.8"
        assert "log" in data[rootKey]["hits"][x]["_source"]
        assert "offset" in data[rootKey]["hits"][x]["_source"]["log"]
        assert "id" in data[rootKey]["hits"][x]["_source"]["elastic_agent"]
        assert "version" in data[rootKey]["hits"][x]["_source"]["elastic_agent"]
        #assert data[rootKey]["hits"][x]["_source"]["elastic_agent"]["version"]=="8.18.8"
        assert "snapshot" in data[rootKey]["hits"][x]["_source"]["elastic_agent"]
        assert "message" in data[rootKey]["hits"][x]["_source"]
        assert "file.line" in data[rootKey]["hits"][x]["_source"]["log.origin"]
        assert "function" in data[rootKey]["hits"][x]["_source"]["log.origin"]
        assert "file.name" in data[rootKey]["hits"][x]["_source"]["log.origin"]
        assert "type" in data[rootKey]["hits"][x]["_source"]["input"]
        assert data[rootKey]["hits"][x]["_source"]["ecs"]["version"]=="8.0.0"
        assert data[rootKey]["hits"][x]["_source"]["data_stream"]["type"]=="logs"
        assert data[rootKey]["hits"][x]["_source"]["data_stream"]["dataset"]=="elastic_agent"
        assert "os" in data[rootKey]["hits"][x]["_source"]["host"]
        assert "ip" in data[rootKey]["hits"][x]["_source"]["host"]
        assert "mac" in data[rootKey]["hits"][x]["_source"]["host"]
        #assert data[rootKey]["hits"][x]["_source"]["log.level"]=="info"
        assert data[rootKey]["hits"][x]["_source"]["event"]["agent_id_status"]=="verified"
        assert data[rootKey]["hits"][x]["_source"]["event"]["dataset"]=="elastic_agent"
        
def test_metrics_mapping(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/metrics-*/_mapping"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    #assert ".ds-metrics-system.process.summary-default" in response.text
    assert ".ds-metrics-system.memory-default-" in response.text
    assert ".ds-metrics-elastic_agent.endpoint_security-default-" in response.text
    assert ".ds-metrics-system.cpu-default-" in response.text
    assert ".ds-metrics-endpoint.metadata-default-" in response.text
    assert ".ds-metrics-system.process-default-" in response.text
    assert ".ds-metrics-elastic_agent.filebeat-default-" in response.text
    assert ".ds-metrics-system.diskio-default-" in response.text
    assert ".ds-metrics-endpoint.policy-default-" in response.text
    assert ".ds-metrics-system.socket_summary-default-" in response.text  
    #assert ".ds-metrics-system.load-default-" in response.text
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
    
    assert ".ds-metrics-system.process.summary-default-" in response.text

def test_metrics_settings(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/metrics-*/_settings"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    assert ".ds-metrics-system.process.summary-default-" in response.text
    assert ".ds-metrics-system.fsstat-default-" in response.text
    assert ".ds-metrics-elastic_agent.fleet_server-default-" in response.text
    #assert ".ds-metrics-system.load-default-" in response.text
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

#@pytest.mark.skip(reason="Test is currently failing on develop branch")       
def test_metrics_search(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/.ds-metrics-elastic_agent.elastic_agent-default*/_search"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)

    
    # Getting the value of Root Key
    for key in data:
        rootKey = key

    assert (data[rootKey]["total"]["value"] > 0)
    #assert data[rootKey]["hits"][0]["_source"]["agent"]["name"]=="lme-fleet-server"
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
    
def test_elastic_indices(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}/_cat/indices/"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert ("open .ds-logs-system.system-default" in response.text)                   
    assert ("open .ds-metrics-system.process-default" in response.text)                  
    assert ("open elastalert_status" in response.text)                                                      
    #assert ("open .ds-logs-endpoint.events.api-default" in response.text)              
    assert ("open .ds-metrics-endpoint.policy-default" in response.text)                       
    assert ("open .ds-metrics-elastic_agent.metricbeat-default" in response.text)                         
    assert ("open elastalert_status_error" in response.text)                                                
    assert ("open .ds-logs-system.security-default" in response.text)              
    assert ("open .ds-metrics-fleet_server.agent_versions-default" in response.text)    
    assert ("open .ds-logs-endpoint.events.library-default" in response.text)             
    assert ("open wazuh-states-vulnerabilities-wazuh-manager" in response.text)                             
    assert ("open .ds-logs-endpoint.events.process-default" in response.text)            
    assert ("open .ds-logs-endpoint.events.registry-default" in response.text)           
    assert ("open .ds-metrics-elastic_agent.fleet_server-default" in response.text)      
    assert ("open .ds-logs-elastic_agent.filebeat-default" in response.text)             
    assert ("open .ds-metrics-elastic_agent.endpoint_security-default" in response.text) 
    assert ("open .ds-logs-elastic_agent.fleet_server-default" in response.text)         
    assert ("open .ds-metrics-fleet_server.agent_status-default" in response.text)      
    assert ("open .ds-logs-elastic_agent-default" in response.text)                                       
    assert ("open elastalert_status_silence" in response.text)                                              
    assert ("open .ds-metrics-elastic_agent.filebeat_input-default" in response.text)    
    assert ("open .ds-metrics-elastic_agent.filebeat-default" in response.text)           
    assert ("open .ds-logs-elastic_agent.metricbeat-default" in response.text)                         
    assert ("open .ds-logs-system.application-default" in response.text)                 
    assert ("open .ds-logs-elastic_agent.endpoint_security-default" in response.text)    
    assert ("open elastalert_status_status" in response.text)                                               
    assert ("open elastalert_status_past" in response.text)                                                 
    #assert ("open .ds-logs-system.auth-default" in response.text)
    #assert ("open .ds-logs-system.syslog-default" in response.text)
    assert ("open .ds-logs-endpoint.events.network-default" in response.text)          
    assert ("open .ds-logs-endpoint.events.file-default" in response.text)              
    assert ("open wazuh-alerts-4.x" in response.text)                                            
    assert ("open .ds-metrics-elastic_agent.elastic_agent" in response.text)
    
def test_fleet_server(es_host, es_port, username, password):
    
    url = f"https://{es_host}:{es_port}/logs-elastic_agent.fleet_server-default/_search"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"    
    data = json.loads(response.text)
    
    for key in data:
        rootKey = key


    assert rootKey=="hits"
    assert (data[rootKey]["hits"][0]["_source"]["agent"]["name"] == "lme-fleet-server") 
    assert (data[rootKey]["hits"][0]["_source"]["agent"]["version"] == "8.18.8") 
    assert (data[rootKey]["hits"][0]["_source"]["ecs"]["version"] == "8.0.0") 
    assert (data[rootKey]["hits"][0]["_source"]["state"] == "HEALTHY") 
