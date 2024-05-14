import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestSysmonSummaryDashboard:
    dashboard_id = "d2c73990-e5d4-11e9-8f1d-73a2ea4cc3ed"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_count_of_sysmon_events_by_event_code(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Count of Sysmon events by event code", ".tbvChart",".visError")
        
        
    def test_total_number_of_sysmon_events_found(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Total number of Sysmon events found", ".visualization",".dummyval")    
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior
        


    def test_percentage_of_sysmon_events_by_event_code(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Percentage of Sysmon events by event code", ".echChart",".euiText")
    
    def test_sysmon_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Sysmon events", ".echChart",".visError")    
        
    def test_top10_hosts_generating_most_sysmon_data(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Top 10 hosts generating the most Sysmon data", ".tbvChart",".visError")


    def test_sysmon_events_code_reference(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Sysmon event code reference", ".visualization",".dummyval")


