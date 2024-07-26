import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestSecurityDashboardSecurityLog:
    dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_computer_filter_results(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Select a computer to filter the below results.  Leave blank for all", ".euiFlexGroup",".dummyval")
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior

    
    @pytest.mark.skip(reason="Skipping this test")
    def test_logons_with_special_privileges(self, setup_login, kibana_url, timeout):
        #This dashboard panel needs test data. Currently the panel only gives No Result found
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log -  Logons with special privileges assigned - event ID 4672", ".needarealvaluehere",".visError")
              
    def test_computer_filter(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Select a computername to filter", ".tbvChart",".visError")
        
    def test_computers_showing_failed_login_attempts_none(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Computers showing failed login attempts - 10 maximum shown", ".echChart",".visError")

    @pytest.mark.skip(reason="Skipping this test")
    def test_credential_sent_as_clear_text_type_8(self, setup_login, kibana_url, timeout):
        #This dashboard panel needs test data. Currently the panel only gives No Result found
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log - Credential sent as clear text - Logon type 8", ".needarealvaluehere",".visError")
   

    def test_failed_logon_and_reason(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Failed logon and reason (status code)", ".echChart",".euiText")
        
    def test_failed_logons(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Failed Logons", ".unifiedDataTable",".euiDataGrid__noResults")
        
    @pytest.mark.skip(reason="Skipping this test")
    def test_log_cleared_event_id_1102_or_104(self, setup_login, kibana_url, timeout):
        #This dashboard panel needs test data. Currently the panel only gives No Result found
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Log Cleared - event ID 1102 or 104", ".needarealvaluehere",".euiDataGrid__noResults")


    def test_process_started_with_different_creds(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log - Process started with different credentials- event ID 4648 [could be RUNAS, scheduled tasks]", ".euiDataGrid",".euiDataGrid__noResults")
        
    def test_security_log_events_detail(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log events - Detail", ".euiDataGrid",".euiDataGrid__noResults")
        
    def test_security_log_logon_as_a_service_type_5(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Sercurity log - logon as a service - Logon type 5",".euiDataGrid",".visError")

    def test_security_log_logon_created_logon_type_2(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log - Logon created - Logon type 2",".tbvChart",".visError")

    def test_security_log_network_logon_created_type_3(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log - network logon created - Logon type 3",".tbvChart",".visError")

    def test_security_log_process_creation_event_id_4688(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security log - Process creation - event ID 4688",".euiDataGrid",".euiDataGrid__noResults")        

    def test_security_log_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security logs events",".visualization", ".dummyval")
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior

    def test_failed_logon_type_codes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Failed logon type codes",".visualization", ".dummyval")
        
    def test_failed_logon_status_codes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Failed logon status codes",".visualization", ".dummyval")