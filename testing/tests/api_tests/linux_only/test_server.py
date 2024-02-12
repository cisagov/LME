from jsonschema import validate
import urllib3
import os

from api_tests.helpers import make_request, load_json_schema

# from api_tests.helpers import make_request, load_json_schema

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

current_script_path = os.path.abspath(__file__)
current_script_dir = os.path.dirname(current_script_path)


def test_elastic_root(es_host, es_port, username, password):
    url = f"https://{es_host}:{es_port}"
    response = make_request(url, username, password)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    body = response.json()
    assert body["name"] == "es01", f"Expected 'es01', got {body['name']}"
    schema = load_json_schema(f"{current_script_dir}/schemas/es_root.json")
    validate(instance=response.json(), schema=schema)
