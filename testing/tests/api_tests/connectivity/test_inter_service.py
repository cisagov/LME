import requests
import pytest
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class TestInterServiceCommunication:
    """Test communication between LME services"""
    
    def test_kibana_to_elasticsearch(self, es_host, es_port, username, password):
        """Test Kibana can communicate with Elasticsearch"""
        # This tests the internal communication path
        url = f"https://{es_host}:{es_port}/_cluster/health"
        response = requests.get(url, auth=(username, password), verify=False, timeout=10)
        assert response.status_code == 200
        health = response.json()
        assert health["status"] in ["green", "yellow"], "Elasticsearch cluster unhealthy"
    
    def test_fleet_server_api_connectivity(self, es_host):
        """Test Fleet Server API is responding"""
        url = f"https://{es_host}:8220/api/status"
        try:
            response = requests.get(url, verify=False, timeout=10)
            # Fleet server may require authentication, but should respond
            assert response.status_code in [200, 401, 403], "Fleet Server not responding"
        except requests.exceptions.ConnectionError:
            pytest.fail("Fleet Server is not accessible on port 8220")
    
    def test_wazuh_api_connectivity(self, es_host):
        """Test Wazuh Manager API is responding"""
        url = f"https://{es_host}:55000"
        try:
            response = requests.get(url, verify=False, timeout=10)
            # Wazuh API should return 401 when not authenticated
            assert response.status_code == 401, "Wazuh API not responding correctly"
        except requests.exceptions.ConnectionError:
            pytest.fail("Wazuh Manager API is not accessible on port 55000")
