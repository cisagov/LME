import sys
import os
import requests
from datetime import datetime

api_key = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("API_KEY", "")
if not api_key:
    sys.exit("API_KEY required for operation. Either as command line argument or env variable")


def get_adversary_id() -> str:
    res = requests.get("http://localhost:8888/api/v2/adversaries",
                       headers={"KEY": api_key})
    data = res.json()

    for obj in data:
        if obj.get("name", "") == "Advanced Thief":
            return obj.get("adversary_id")

    adversary_id = data[0].get("adversary_id")
    return adversary_id


def get_agents():
    res = requests.get("http://localhost:8888/api/v2/agents", headers={"KEY": api_key})
    data = res.json()
    return data


def get_field(api_route: str, field_name: str, name_match: str):
    res = requests.get(f"http://localhost:8888/api/v2/{api_route}", headers={"KEY": api_key})
    data = res.json()

    for obj in data:
        if obj.get("name", "") == name_match:
            return obj.get(field_name)
    # fallback
    return data[0].get(field_name)


adversary_id = get_field("adversaries", "adversary_id", "Discovery")
planner_id = get_field("planners", "id", "atomic")
source_id = get_field("sources", "id", "basic")


new_operation = {
    "name": f"TEST SCRIPT OPERATION-{datetime.now().strftime('%H%M%S')}",
    "adversary": {"adversary_id": adversary_id},
    "planner": {"id": planner_id},
    "source": {"id": source_id},
    "group": "red",
    # copied from POST request on page
    "state": "running",
    "use_learning_parsers": "true",
    "visibility": 51,
    "auto_close": False,
    "autonomous": 1,
    "jitter": "2/8",
    "obfuscator": "base64",
}

print("new operation config", new_operation)
resp = requests.post("http://localhost:8888/api/v2/operations", headers={"KEY": api_key}, json=new_operation)

print(f"Send request to create operation. Got back status code {
      resp.status_code}")
