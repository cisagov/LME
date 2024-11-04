import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

from .lib import dashboard_test_function

class TestCredentialsAccessLogsDashboard:
    dashboard_id = "e4d7b207-99aa-4410-8a2e-03487222bda1"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_audit_logons(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Audit logons", ".echChart",".euiText")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_kerberos_ticket_failed_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Kerberos ticket - Failed attempts", ".expExpressionRenderer",".xyChart__empty")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_special_logon_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Special logon-attempts", ".echChart",".dummyval")    
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_account_lockout_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Account lockout -attempts", ".euiDataGrid",".euiSpacer")    
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_other_logon_logoff_disconnection_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Other logon /logoff-Disconnection attempts", ".expExpressionRenderer",".euiSpacer")  
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_kerberos_auth_request(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Kerberos auth request", ".echChart",".euiText")        
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_logon_attempts_by_host(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Logon attempts by hosts", ".echChart",".euiText")  
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_credential_validation_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Credential validation- attempts", ".echChart",".euiText")   
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_logon_using_explicit_credential_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Logon-using explicit credential attempts", ".echChart",".euiText")                     