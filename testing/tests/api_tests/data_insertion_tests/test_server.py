from datetime import datetime, timedelta
import json
import time
import warnings

import pytest
from jsonschema import validate
from jsonschema.exceptions import ValidationError
import requests
from requests.auth import HTTPBasicAuth
import urllib3
import os

from api_tests.helpers import make_request, load_json_schema, get_latest_winlogbeat_index, post_request, insert_winlog_data

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



def test_filter_hosts_insert(es_host, es_port, username, password):
    
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_hosts.json', 'hosts.json', 0)
     
    # Check to make sure the data was inserted
    length = len(second_response_loaded['aggregations']['2']['buckets'])

    for i in range(length):
        if second_response_loaded['aggregations']['2']['buckets'][i]['key'] == 'testing.lme.local':
            break
        
    assert(second_response_loaded['aggregations']['2']['buckets'][i]['key'] == 'testing.lme.local')

def test_user_logon_events_insert(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_logonevents.json', 'logonevents.json', 2)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'APItestuserid')
    

def test_file_downloads_insert(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_fileCreatedDownloads.json', 'fileCreatedDownloads.json', 2)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'C:\\Users\\admin.ackbar\\Downloads\\test.txt')    

    
def test_file_suspicious_powershell(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_suspiciouspowershell.json', 'suspiciouspowershell.json', 1)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'powershell.exe')    

def test_createRemoteThread(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_createRemoteThreads.json', 'createRemoteThreads.json', 1)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'testsource')    
    
def test_powershellNetworkConnections(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_powershellnetworkconnections.json', 'powershellnetworkconnections.json', 1)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'APItestuserid')  
    
    
def test_rawaccessevents(es_host, es_port, username, password):
        
    second_response_loaded=insert_winlog_data(es_host, es_port, username, password, 'filter_rawaccessevents.json', 'rawaccessevents.json', 1)
    
    # Check to make sure the data was inserted
    assert(second_response_loaded['aggregations']['2']['buckets'][0]['key'] == 'APItestuserid')
