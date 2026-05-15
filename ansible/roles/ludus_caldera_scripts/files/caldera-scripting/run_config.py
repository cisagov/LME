import sys
import json
import argparse
from pathlib import Path
import requests
from datetime import datetime
import time
import base64

CALDERA_URL = "http://localhost:8888/"
API_URL = CALDERA_URL + "api/v2/"


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("config_file", help="Config file to run")
    ap.add_argument("--api_key", default="", help="API key for connecting with caldera")
    ap.add_argument("--verbose", action="store_true", default=False, help="Enable more verbose output")
    return ap.parse_args()


class CalderaOperator():
    def __init__(self, config_file: str | Path,
                 api_key: str,
                 verbose=False):
        self.config_file_path = config_file
        self.verbose = verbose
        self.config = self.load_config_file(config_file)
        self.api_key = api_key
        if self.api_key == "":
            self.api_key = self.config.get("options", {}).get("api_key", "")
            if self.api_key == "":
                sys.exit("No api key provided (in command line or in config)")

        self.headers = {'KEY': self.api_key, 'Content-Type': 'application/json'}

    def load_config_file(self, config_file: str | Path) -> dict:
        p = Path(config_file)
        if not p.exists():
            sys.exit(f"Config file {config_file} not found")

        with open(config_file, 'r') as fp:
            obj = json.load(fp)
        return obj

    def get_caldera_field(self, api_route: str, field_name: str, name_match: str):
        res = requests.get(API_URL + api_route, headers=self.headers, timeout=10)
        if not res.ok:
            sys.exit(f"GET {api_route} failed: {res.status_code} {res.text}")
        data = res.json()
        for obj in data:
            if obj.get("name", "") == name_match:
                return obj.get(field_name)
        print(data)
        sys.exit("No matching object found in data")

    def get_ability_id(self, ability_config: dict):
        if ability_config.get("ability_id", "") != "":
            return ability_config.get("ability_id")

        name = ability_config.get("name", "")
        if name != "":
            return self.get_caldera_field("abilities", "ability_id", name)

        return ""

    def create_adversary(self, ignore_empty=True, use_existing=True) -> str | None:
        adversary_config = self.config.get("adversary", {})
        if adversary_config == {} and ignore_empty:
            return
        name = adversary_config.get("name", "")

        # check if existing
        if use_existing:
            existing_adversaries = requests.get(API_URL + "adversaries", headers=self.headers)
            if existing_adversaries.status_code in (200, 201):
                existing_json = existing_adversaries.json()
                for adversary in existing_json:
                    if adversary.get("name", "") == name:
                        print("Found existing adversary with same name")
                        return adversary.get("adversary_id")

        desc = adversary_config.get("description", "")
        abilities = adversary_config.get("abilities", [])

        if name == "":
            sys.exit("Error: Provided config does not contain an adversary name")
        if len(abilities) == 0:
            sys.exit("Error: provided config does not contain any adversary abilities")

        atomic_ordering = [self.get_ability_id(conf) for conf in abilities]

        empties = [s for s in atomic_ordering if s == ""]
        if len(empties) > 0:
            print(list(zip(abilities, atomic_ordering)))
            sys.exit("Error: could not find some atomic ids")

        payload = {
            "name": name,
            "description": desc,
            "atomic_ordering": atomic_ordering,
        }

        # NOTE: post request will succeed even if there is already an adversary with
        # the same name. Worth changing this to try to GET and see if same name
        # already exists and return that id? Or just keep doing this.
        resp = requests.post(API_URL + "adversaries", headers=self.headers, json=payload, timeout=10)
        if self.verbose:
            print("Create adversary response", resp.status_code, resp.text)
        if resp.status_code in (200, 201):
            print(f"Created adversary {name}")
            return resp.json()['adversary_id']
        else:
            sys.exit(f"Create adversary failed: {resp.status_code} {resp.text}")

    def start_operation(self, adversary_id: str):
        url = API_URL + "operations"
        op_config = self.config.get("operation", {})
        if op_config == {}:
            sys.exit("No operation configuration provided")

        planner_name = op_config.get("planner", {}).get("name", "")
        planner_id = op_config.get("planner", {}).get("id", "")
        if planner_name == "" and planner_id == "":
            sys.exit("no planner name or ID given")
        elif planner_id == "":
            planner_id = self.get_caldera_field("planners", "id", planner_name)

        source_name = op_config.get("source", {}).get("name", "")
        source_id = op_config.get("source", {}).get("id", "")
        if source_name == "" and source_id == "":
            sys.exit("no source name or ID given")
        elif source_id == "":
            source_id = self.get_caldera_field("sources", "id", source_name)

        operation_name = op_config.get("name", "")
        if operation_name == "":
            sys.exit("No operation name given!")
        if self.config.get("options", {}).get("add timestamp to operation", False):
            operation_name = f"{operation_name}-{datetime.now().strftime('%H%M%S')}"

        operation = {
            "name": operation_name,
            "adversary": {"adversary_id": adversary_id},
            "planner": {"id": planner_id},
            "source": {"id": source_id},
            "group": "red",
        }

        resp = requests.post(url, headers=self.headers, json=operation, timeout=10)
        print(f"Sent request to create operation. got back status code {resp.status_code}")
        return resp.json().get("id", "")

    def poll_operation(self, operation_id, interval_s=10, poll_once=False):

        while True:
            req = requests.get(API_URL + f"operations/{operation_id}", headers=self.headers)
            operation_data = req.json()
            state = operation_data.get("state")
            print(f"[{state}] Operation: {operation_data.get('name')}")

            link_get_req = requests.get(API_URL + f"operations/{operation_id}/links", headers=self.headers)
            link_res = link_get_req.json()
            for link in link_res:
                status = link.get("status")
                ability = link.get("ability", {}).get("name", "unknown")
                output = link.get("output")
                link_id = link.get("id")
                if output == 'True':
                    result_req = requests.get(API_URL + f"operations/{operation_id}/links/{link_id}/result", headers=self.headers)
                    result = result_req.json().get("result", "")
                    result = base64.b64decode(result).decode('utf-8', errors='replace')
                    print(f"   [{status}] {ability}: {result[:100]}...")
                else:
                    print(f"   [{status}] {ability}: {output}")

            with open("test.json", 'w') as fp:
                json.dump(link_res, fp, indent=2)

            if state in ("finished", "out_of_time") or poll_once:
                break

            time.sleep(interval_s)

    def get_operation_results(self, operation_id, output_json):
        req = requests.get(API_URL + f"operations/{operation_id}", headers=self.headers)
        operation_data = req.json()
        state = operation_data.get("state")
        print(f"[{state}] Operation: {operation_data.get('name')}")

        link_get_req = requests.get(API_URL + f"operations/{operation_id}/links", headers=self.headers)
        link_res = link_get_req.json()
        for link in link_res:
            status = link.get("status")
            ability = link.get("ability", {}).get("name", "unknown")
            output = link.get("output")
            link_id = link.get("id")
            if output == 'True':
                result_req = requests.get(API_URL + f"operations/{operation_id}/links/{link_id}/result", headers=self.headers)
                result = result_req.json().get("result", "")
                result = base64.b64decode(result).decode('utf-8', errors='replace')
                print(f"   [{status}] {ability}: {result[:100]}...")
            else:
                print(f"   [{status}] {ability}: {output}")

        # TODO: save out link result too
        with open(output_json, 'w') as fp:
            json.dump(link_res, fp, indent=2)


if __name__ == '__main__':
    args = parse_args()
    co = CalderaOperator(args.config_file, args.api_key, args.verbose)
    if args.verbose:
        print(co.__dict__)
    adversary_id = co.create_adversary()
    if adversary_id is None:
        sys.exit("Error getting adversary ID")
    print("adversary id", adversary_id)
    operation_id = co.start_operation(adversary_id)
    if operation_id == "":
        sys.exit("no operation id given")
    co.poll_operation(operation_id)
