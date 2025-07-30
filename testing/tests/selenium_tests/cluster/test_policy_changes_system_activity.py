import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestPolicyChangesSystemActivityDashboard:
    
    dashboard_id = "614a8392-17b5-49c4-9397-bc3cac526c61"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_rpc_connection_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "RPC Connection Attempts", ".lnsExpressionRenderer",".dummyval")
      
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_exception_firewall_rules(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Added or Updated Exception Firewall Rules Lens", ".lnsExpressionRenderer",".dummyval")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_rpc_connections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "RPC Connections", ".echChart",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_firewall_setting_changes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Firewall Setting Changes", ".euiFlexGroup",".euiIcon")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_firewall_policy_changes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Firewall Policy Changes", ".euiDataGrid",".euiIcon")
      
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_firewall_turned_on(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Firewall Turned On", ".euiDataGrid",".euiIcon")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_firewall_turned_off(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Firewall Turned Off", ".euiDataGrid",".euiIcon")
             
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_audit_policy_changes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Audit Policy Changes", ".euiDataGrid",".euiIcon")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_kerberos_policy_changes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Kerberos Policy Changes", ".euiDataGrid",".euiIcon")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_pc_start_up(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "PC Start Up", ".echChart",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_pc_shut_down(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "PC Shut Down", ".echChart",".dummyval")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_pc_startups(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "PC Startups", ".lnsExpressionRenderer",".euiText")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_pc_shutdowns(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "PC Shutdowns", ".lnsExpressionRenderer",".euiText")                                  