import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestUserHRDashboard:
    #dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
    dashboard_id = "ff0170e5-e0ef-4ca1-8188-c7bb9d736898"
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    @pytest.mark.skip(reason="Panel shows error message on ubuntu cluster")
    def test_filter_computers(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Filter Computers", ".echChart",".xyChart__empty")

    @pytest.mark.skip(reason="Panel shows error message on ubuntu cluster")
    def test_filter_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Filter Users", ".echChart",".xyChart__empty")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_inperson_vs_remote_logons(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "In person vs Remote logons", ".echChart",".euiText")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_user_logoff_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "User logoff events (correlate to logon events)", ".euiDataGrid",".euiDataGrid__noResults")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_user_logon_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "User logon events (filter by LogonId)", ".euiDataGrid",".euiDataGrid__noResults")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_select_domain_and_username(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Select domain(s) and username(s)", ".icvContainer",".dummyval")
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_hr_user_activity_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "HR - User activity title", ".visualization",".dummyval")
        
    @pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_all_user_events_dayofweek_hourofday(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "All User Events by Day of Week, Hour of Day", ".echChart",".dummyval")
        #This panel is no longer available in release 2
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_events_by_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Events by Time", ".echChart",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_hr_logon_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "HR - Logon title", ".visualization",".dummyval")
        