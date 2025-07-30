#!/usr/bin/env python3
import argparse
import base64
import json
import os
import re
import requests
from pathlib import Path
from urllib3.exceptions import InsecureRequestWarning

# Suppress the InsecureRequestWarning (We are using a self-signed cert)
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

ALL = 'all'


class Api:
    def __init__(self, args):
        self.ids = None
        self.basic_auth = self.get_basic_auth(args.user, args.password)
        self.root_url = f'https://{args.host}:{args.port}'

    def export_dashboards(self):
        self.set_ids()
        self.export_selected_dashboard(self.select_dashboard())

    @staticmethod
    def get_basic_auth(username, password):
        return base64.b64encode(f"{username}:{password}".encode()).decode()

    def get_ids(self):
        url = f'{self.root_url}/api/kibana/management/saved_objects/_find?perPage=500&page=1&type=dashboard&sortField=updated_at&sortOrder=desc'

        try:
            response = requests.get(url, headers={'Authorization': f'Basic {self.basic_auth}'}, verify=False)

            if response.status_code == 200:
                data = response.json()
                #ids = {item['id']: item['meta']['title'] for item in data.get('saved_objects', [])}
                #return ids
                ids = {
                    item['id']: item['meta']['title']
                    for item in data.get('saved_objects', [])
                    if '[' not in item['meta']['title'] and ']' not in item['meta']['title']
                }
                return ids
            else:
                print(f"HTTP request failed with status code: {response.status_code}")
                print(response.text)
                return {}
        except Exception as e:
            print(f"An error occurred: {str(e)}")
            return {}

    def set_ids(self, ids=None):
        if ids is None:
            ids = self.get_ids()
        self.ids = ids

    def select_dashboard(self):
        print("Please select a dashboard ID:")
        item = 1
        choices = {}

        # Iterate through ids and display them with corresponding numbers
        for this_id, title in self.ids.items():
            print(item, this_id, title)
            choices[item] = this_id
            item += 1

        if item == 1:
            print("I could not find any dashboards")
            return

        choices[item] = ALL
        print(item, "Select all dashboards")

        # Ask the user to select a number
        while True:
            try:
                choice = int(input("Select a number: "))
                if choice in choices:
                    selected_id = choices[choice]
                    if selected_id == ALL:
                        return ALL  # Return 'all' if the user selects all dashboards
                    else:
                        return selected_id  # Return the selected dashboard ID
                else:
                    print("Invalid choice. Please select a valid number.")
            except ValueError:
                print("Invalid input. Please enter a number.")

    def export_selected_dashboard(self, selected_dashboard):
        if selected_dashboard == ALL:
            print("You selected to export all dashboards")
            self.dump_all_dashboards()
        else:
            print(f"You selected dashboard ID: {selected_dashboard}")
            self.dump_dashboard(selected_dashboard)

    def dump_dashboard(self, selected_id):
        print(f"Dumping dashboard: {selected_id}: {self.ids[selected_id]}...")
        # Dumping dashboard: e5f203f0-6182-11ee-b035-d5f231e90733: User Security

        dashboard_json = self.get_dashboard_json(selected_id)

        if dashboard_json is not None:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            export_path = Path(script_dir) / 'exported'
            os.makedirs(export_path, exist_ok=True)

            filename = re.sub(r"\W+", "_", self.ids[selected_id].lower()) + ".ndjson"

            print(f"Writing to file {filename}")
            export_path = export_path / filename

            Api.write_to_file(export_path, dashboard_json)
            return

        print("There was a problem dumping the dashboard")

    def dump_all_dashboards(self):
        for this_id in self.ids:
            self.dump_dashboard(this_id)

    def get_dashboard_json(self, selected_id):
        url = f'{self.root_url}/api/saved_objects/_export'
        data = {
            "objects": [{"id": selected_id, "type": "dashboard"}],
            "includeReferencesDeep": True
        }
        headers = {
            "kbn-xsrf": "true",
            'Authorization': f'Basic {self.basic_auth}'
        }
        try:
            response = requests.post(url, headers=headers, json=data, verify=False)

            if response.status_code == 200:
                return response.text
            else:
                print(f"HTTP request failed with status code: {response.status_code}")
                print(response.text)
                return None

        except Exception as e:
            print(f"An error occurred: {str(e)}")
            return None

    @staticmethod
    def write_to_file(filename, content):
        with open(filename, 'wb') as file:
            file.write(content.encode('utf-8'))


def main():
    # Define command-line arguments with defaults
    parser = argparse.ArgumentParser(description='Retrieve IDs from Elasticsearch')
    parser.add_argument('-u', '--user', required=True, help='Elasticsearch username')
    parser.add_argument('-p', '--password', required=True, help='Elasticsearch password')
    parser.add_argument('--host', default='localhost', help='Elasticsearch host (default: localhost)')
    parser.add_argument('--port', default='443', help='Elasticsearch port (default: 443)')
    args = parser.parse_args()

    api = Api(args)

    api.export_dashboards()


if __name__ == '__main__':
    main()
