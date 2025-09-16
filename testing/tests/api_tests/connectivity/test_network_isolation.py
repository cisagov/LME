import socket
import pytest
from contextlib import closing

class TestNetworkIsolation:
    
    def test_expected_ports_accessible(self, es_host):
        """Test that only expected LME ports are accessible"""
        expected_ports = [443, 5601, 8220, 9200, 1514, 1515, 55000]
        
        for port in expected_ports:
            with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
                sock.settimeout(10)
                result = sock.connect_ex((es_host, port))
                assert result == 0, f"Expected LME port {port} is not accessible"
    
    def test_udp_port_514_accessible(self, es_host):
        """Test that UDP port 514 (syslog) is accessible for Wazuh"""
        with closing(socket.socket(socket.AF_INET, socket.SOCK_DGRAM)) as sock:
            sock.settimeout(5)
            try:
                # Send a test syslog message
                test_message = b"<14>Jan  1 00:00:00 test-host test: connectivity test"
                sock.sendto(test_message, (es_host, 514))
                # UDP is connectionless, so we just verify we can send
            except Exception as e:
                pytest.fail(f"UDP port 514 (syslog) test failed: {e}")
