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

    assert body["name"] == "es01", f"Expected 'es01', got {body['name']}"
    assert (
        body["cluster_name"] == "loggingmadeeasy-es"
    ), f"Expected 'loggingmadeeasy-es', got {body['cluster_name']}"
    assert (
        body["version"]["number"] == "8.11.1"
    ), f"Expected '8.11.1', got {body['version']['number']}"
    assert (
        body["version"]["build_flavor"] == "default"
    ), f"Expected 'default', got {body['version']['build_flavor']}"
    assert (
        body["version"]["build_type"] == "docker"
    ), f"Expected 'docker', got {body['version']['build_type']}"
    assert (
        body["version"]["lucene_version"] == "9.8.0"
    ), f"Expected '9.8.0', got {body['version']['lucene_version']}"
    assert (
        body["version"]["minimum_wire_compatibility_version"] == "7.17.0"
    ), f"Expected '7.17.0', got {body['version']['minimum_wire_compatibility_version']}"
    assert (
        body["version"]["minimum_index_compatibility_version"] == "7.0.0"
    ), f"Expected '7.0.0', got {body['version']['minimum_index_compatibility_version']}"

    # Validating JSON Response schema
    schema = load_json_schema(f"{current_script_dir}/schemas/es_root.json")
    validate(instance=response.json(), schema=schema)


def test_elastic_indices(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}/_cat/indices/"
    response = make_request(url, username, password)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert (
        "green open .internal.alerts-observability.logs.alerts-default" in response.text
    )
    assert (
        "green open .internal.alerts-observability.uptime.alerts-default"
        in response.text
    )
    assert (
        "green open .internal.alerts-ml.anomaly-detection.alerts-default"
        in response.text
    )
    assert (
        "green open .internal.alerts-observability.slo.alerts-default" in response.text
    )
    assert (
        "green open .internal.alerts-observability.apm.alerts-default" in response.text
    )
    assert (
        "green open .internal.alerts-observability.metrics.alerts-default"
        in response.text
    )
    assert (
        "green open .kibana-observability-ai-assistant-conversations" in response.text
    )
    assert "green open winlogbeat" in response.text
    assert (
        "green open .internal.alerts-observability.threshold.alerts-default"
        in response.text
    )
    assert "green open .kibana-observability-ai-assistant-kb" in response.text
    assert "green open .internal.alerts-security.alerts-default" in response.text
    assert "green open .internal.alerts-stack.alerts-default" in response.text


def test_elastic_mapping(es_host, es_port, username, password):
    # This test currently works for full installation. For Partial installation (only Ls1), the static mappings file will need to be changed.
    url = f"https://{es_host}:{es_port}/winlogbeat-000001/_mapping"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"

    response_data = response.json()
    static_mapping = json.load(
        open(f"{current_script_dir}/test_data/mapping_response.json")
    )

    # Dumping Actual Response Json into file for comparison if test fails.
    datas = json.dump(
        response_data,
        open(f"{current_script_dir}/test_data/mapping_response_actual.json", "w"),
        indent=4,
    )

    assert static_mapping == response_data, "Mappings Json did not match Expected"


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

    data_fields = json.load(
        open(f"{current_script_dir}/test_data/mapping_datafields.json")
    )

    act_data_fields = body[rootKey]["settings"]["index"]["query"]["default_field"]
    assert (
        act_data_fields.sort() == data_fields.sort()
    ), "Winlogbeats data fields do not match"


def test_winlogbeat_search(es_host, es_port, username, password):
    # This test requires DC1 instance in cluster set up otherwise it will fail
    url = f"https://{es_host}:{es_port}/winlogbeat-*/_search"
    body = {"size": 1, "query": {"term": {"host.name": "DC1.lme.local"}}}
    response = make_request(url, username, password, body=body)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    datas = json.dump(
        data,
        open(f"{current_script_dir}/test_data/winlog_search_data.json", "w"),
        indent=4,
    )

    assert data["hits"]["hits"][0]["_source"]["host"]["name"] == "DC1.lme.local"

    # Validating JSON Response schema
    schema = load_json_schema(f"{current_script_dir}/schemas/winlogbeat_search.json")
    validate(instance=response.text, schema=schema)
