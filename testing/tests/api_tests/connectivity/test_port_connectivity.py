import socket
import ssl
import pytest
import requests
from contextlib import closing

class TestPortConnectivity:
    """Test basic port accessibility for all LME services"""
    
    def test_elasticsearch_port_open(self, es_host, es_port):
        """Test Elasticsearch port 9200 is accessible"""
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
            sock.settimeout(10)
            result = sock.connect_ex((es_host, int(es_port)))
            assert result == 0, f"Port {es_port} on {es_host} is not accessible"
    
    def test_kibana_port_open(self, es_host):
        """Test Kibana ports 5601 and 443 are accessible"""
        for port in [5601, 443]:
            with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
                sock.settimeout(10)
                result = sock.connect_ex((es_host, port))
                assert result == 0, f"Port {port} on {es_host} is not accessible"
    
    def test_fleet_server_port_open(self, es_host):
        """Test Fleet Server port 8220 is accessible"""
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
            sock.settimeout(10)
            result = sock.connect_ex((es_host, 8220))
            assert result == 0, f"Fleet Server port 8220 on {es_host} is not accessible"
    
    def test_wazuh_ports_open(self, es_host):
        """Test Wazuh Manager ports are accessible"""
        tcp_ports = [1514, 1515, 55000]
        for port in tcp_ports:
            with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
                sock.settimeout(10)
                result = sock.connect_ex((es_host, port))
                assert result == 0, f"Wazuh port {port} on {es_host} is not accessible"
        
        # Test UDP port 514
        with closing(socket.socket(socket.AF_INET, socket.SOCK_DGRAM)) as sock:
            sock.settimeout(5)
            try:
                sock.sendto(b"test", (es_host, 514))
                # UDP doesn't guarantee delivery, just test socket creation
            except Exception as e:
                pytest.fail(f"UDP port 514 test failed: {e}")
