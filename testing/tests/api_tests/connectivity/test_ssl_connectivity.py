import socket
import ssl
import pytest

class TestSSLConnectivity:
    """Test SSL certificate validation and connectivity"""
    
    def test_elasticsearch_ssl_connectivity(self, es_host, es_port):
        """Test Elasticsearch SSL certificate chain"""
        try:
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE  # For self-signed certs
            
            with socket.create_connection((es_host, int(es_port)), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=es_host) as ssock:
                    assert ssock.version() is not None, "SSL handshake failed"
        except ssl.SSLError as e:
            pytest.fail(f"SSL connection to Elasticsearch failed: {e}")
    
    def test_kibana_ssl_connectivity(self, es_host):
        """Test Kibana SSL connectivity on both ports"""
        for port in [5601, 443]:
            try:
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                
                with socket.create_connection((es_host, port), timeout=10) as sock:
                    with context.wrap_socket(sock, server_hostname=es_host) as ssock:
                        assert ssock.version() is not None, f"SSL handshake failed on port {port}"
            except ssl.SSLError as e:
                pytest.fail(f"SSL connection to Kibana port {port} failed: {e}")
    
    def test_fleet_server_ssl_connectivity(self, es_host):
        """Test Fleet Server SSL connectivity"""
        try:
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            with socket.create_connection((es_host, 8220), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=es_host) as ssock:
                    assert ssock.version() is not None, "Fleet Server SSL handshake failed"
        except ssl.SSLError as e:
            pytest.fail(f"SSL connection to Fleet Server failed: {e}")
    
    def test_wazuh_ssl_connectivity(self, es_host):
        """Test Wazuh Manager SSL connectivity"""
        try:
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            with socket.create_connection((es_host, 55000), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=es_host) as ssock:
                    assert ssock.version() is not None, "Wazuh Manager SSL handshake failed"
        except ssl.SSLError as e:
            pytest.fail(f"SSL connection to Wazuh Manager failed: {e}")
