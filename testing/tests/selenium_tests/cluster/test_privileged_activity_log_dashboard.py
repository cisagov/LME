import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestPrivilegedActivityLogDashboard:
    dashboard_id = "09d32fc8-e1d1-418a-8793-507ed5430d3d"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    @pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_privilege_service_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Privilege service attempts", ".euiText",".euiIcon")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_process_creation(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Process creation", ".echChart",".euiText")
                
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_process_termination(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Process termination", ".echChart",".euiText")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_non_sensitive_privilege(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Non-sensitive privilege attempts", ".lnsExpressionRenderer",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_sensitive_privilege_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Sensitive Privilege attempts", ".lnsExpressionRenderer",".dummyval")
        
    @pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_assigned_token(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Assigned Token", ".lnsExpressionRenderer",".euiText")
        
    @pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_privilege_access_entry(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Privilege Activity entry", ".euiFlexGroup",".euiDataGrid__noResults")
        
    @pytest.mark.skip(reason="Panel shows error message on ubuntu cluster")
    def test_process_creation_activities(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Process creation-Activities", ".lnsExpressionRenderer",".euiIcon")
        
    