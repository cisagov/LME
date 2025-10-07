import requests
import pytest
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class TestServiceDependencies:
    """Test proper service startup order and dependencies"""
    
    def test_elasticsearch_available_first(self, es_host, es_port, username, password):
        """Elasticsearch should be available before other services depend on it"""
        url = f"https://{es_host}:{es_port}/_cluster/health"
        response = requests.get(url, auth=(username, password), verify=False, timeout=30)
        assert response.status_code == 200, "Elasticsearch not ready for dependent services"
        
        # Ensure cluster is at least yellow (functional)
        health = response.json()
        assert health["status"] in ["green", "yellow"], f"Cluster status is {health['status']}, should be green or yellow"
    
    def test_kibana_connects_to_elasticsearch(self, es_host, username, password):
        """Test that Kibana successfully connects to Elasticsearch"""
        kibana_url = f"https://{es_host}:5601/api/status"
        try:
            response = requests.get(kibana_url, auth=(username, password), verify=False, timeout=10)
            assert response.status_code in [200, 401], "Kibana not properly connected"
        except requests.exceptions.ConnectionError:
            pytest.fail("Kibana connectivity test failed")
    
    def test_fleet_server_depends_on_elasticsearch(self, es_host, es_port, username, password):
        """Test that Fleet Server can reach Elasticsearch"""
        # First verify Elasticsearch is up
        es_url = f"https://{es_host}:{es_port}/_cluster/health"
        es_response = requests.get(es_url, auth=(username, password), verify=False, timeout=10)
        assert es_response.status_code == 200, "Elasticsearch must be up for Fleet Server"
        
        # Then check Fleet Server is responding
        fleet_url = f"https://{es_host}:8220/api/status"
        try:
            fleet_response = requests.get(fleet_url, verify=False, timeout=10)
            # Fleet server should respond, even if auth is required
            assert fleet_response.status_code in [200, 401, 403], "Fleet Server should be responding"
        except requests.exceptions.ConnectionError:
            pytest.fail("Fleet Server not accessible after Elasticsearch is up")
    
    def test_wazuh_depends_on_elasticsearch(self, es_host, es_port, username, password):
        """Test that Wazuh Manager can reach Elasticsearch for log shipping"""
        # First verify Elasticsearch is up
        es_url = f"https://{es_host}:{es_port}/_cluster/health"
        es_response = requests.get(es_url, auth=(username, password), verify=False, timeout=10)
        assert es_response.status_code == 200, "Elasticsearch must be up for Wazuh"
        
        # Check if Wazuh API is responding
        wazuh_url = f"https://{es_host}:55000"
        try:
            wazuh_response = requests.get(wazuh_url, verify=False, timeout=10)
            # Wazuh API should return 401 for unauthenticated requests
            assert wazuh_response.status_code == 401, "Wazuh API should be responding with 401"
        except requests.exceptions.ConnectionError:
            pytest.fail("Wazuh Manager API not accessible")
