import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestIdentityAccessManagementDashboard:
    dashboard_id = "32ed7a33-b22e-4c4b-b4bd-a55c2cf4c0d0"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_registry_object_access(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Registry Object Access", ".echChart",".dummyval")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_updated_scheduler_jobs(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Updated Scheduler Jobs", ".visualization",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_new_scheduler_jobs(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "New Scheduler Jobs", ".visualization",".dummyval")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_password_resets_changes_logs(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Password Resets and Changes Logs", ".euiDataGrid__content",".euiDataGrid__noResults")    
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_password_resets_changes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Password Resets and Changes", ".echChart",".euiDataGrid__noResults")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_user_lockouts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "User Lockouts Lens", ".echChart",".euiDataGrid__noResults")  
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_password_hash_access(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Password Hash Access", ".echChart",".euiDataGrid__noResults")  
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_changes_to_default_domain_policy(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Changes to Default Domain Policy", ".euiFlexGroup",".euiIcon")                                                  