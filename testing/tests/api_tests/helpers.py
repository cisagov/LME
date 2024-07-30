import json

import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime, timedelta
import os
import time
import urllib3


def make_request(url, username, password, body=None):
    auth = HTTPBasicAuth(username, password)
    headers = {"Content-Type": "application/json"}

    if body:
        response = requests.post(
            url, auth=auth, verify=False, data=json.dumps(body), headers=headers
        )
    else:
        response = requests.get(url, auth=auth, verify=False)

    return response


def post_request(url, username, password, body):
    auth = HTTPBasicAuth(username, password)
    headers = {"Content-Type": "application/json"}

    response = requests.post(
        url,
        auth=auth,
        verify=False,
        data=json.dumps(body),
        headers=headers
    )

    return response


def load_json_schema(file_path):
    with open(file_path, "r") as file:
        return json.load(file)

def get_latest_winlogbeat_index(hostname, port, username, password):
    url = f"https://{hostname}:{port}/_cat/indices/winlogbeat-*?h=index&s=index:desc&format=json"
    response = make_request(url, username, password)

    if response.status_code == 200:
        indices = json.loads(response.text)
        if indices:
            latest_index = indices[0]["index"]
            return latest_index
        else:
            print("No winlogbeat indices found.")
    else:
        print(f"Error retrieving winlogbeat indices. Status code: {response.status_code}")

    return None

def insert_winlog_data(es_host, es_port, username, password, filter_query_filename, fixture_filename, filter_num):
    # Get the current date
    today = datetime.now()

    # Generate timestamp one day before
    one_day_before = (today - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    # Generate timestamp one day after
    one_day_after = (today + timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    # Computer software overview-> Filter Hosts
    url = f"https://{es_host}:{es_port}"

    current_script_path = os.path.abspath(__file__)
    current_script_dir = os.path.dirname(current_script_path)

    # This is the query from the dashboard in Kibana
    filter_query = load_json_schema(f"{current_script_dir}/data_insertion_tests/queries/{filter_query_filename}")
    filter_query['query']['bool']['filter'][filter_num]['range']['@timestamp']['gte'] = one_day_before
    filter_query['query']['bool']['filter'][filter_num]['range']['@timestamp']['lte'] = one_day_after

    # You can use this to compare to the update later
    first_response = make_request(f"{url}/winlogbeat-*/_search", username, password, filter_query)
    first_response_loaded = first_response.json()

    # Get the latest winlogbeat index
    latest_index = get_latest_winlogbeat_index(es_host, es_port, username, password)

    # This fixture is a pared down version of the data that will match the query
    fixture = load_json_schema(f"{current_script_dir}/data_insertion_tests/fixtures/{fixture_filename}")
    fixture['@timestamp'] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    # Insert the fixture into the latest index
    ans =  post_request(f"{url}/{latest_index}/_doc", username, password, fixture)

    # Make sure to sleep for a few seconds to allow the data to be indexed
    time.sleep(2)

    # Make the same query again
    second_response = make_request(f"{url}/winlogbeat-*/_search", username, password, filter_query)

    second_response_loaded = second_response.json()

    return second_response_loaded