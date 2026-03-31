import sys
import json
import argparse
from pathlib import Path
import requests
from datetime import datetime
import time

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

    def get_abilities(self):
        resp = requests.get(API_URL + "abilities", headers=self.headers)
        abilities = resp.json()
        discovery = [a['name'] for a in abilities if 'host' in a['name'].lower()
                     or 'user' in a['name'].lower() or
                     'process' in a['name'].lower() or
                     'network' in a['name'].lower()]
        for ability in discovery:
            print(ability)


if __name__ == '__main__':
    args = parse_args()
    co = CalderaOperator(args.config_file, args.api_key, args.verbose)
    co.get_abilities()

    # TODO: get operation status
