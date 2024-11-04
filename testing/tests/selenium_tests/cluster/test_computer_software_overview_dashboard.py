import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

from .lib import dashboard_test_function

class TestComputerSoftwareOverviewDashboard:
    #dashboard_id = "33f0d3b0-8b8a-11ea-b1c6-a5bf39283f12"
    #dashboard_id = "new dashboard"
    dashboard_id = "ce98c19b-587f-4d76-9c49-2e9acee257d5"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_application_crashing_and_hanging(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Application Crashing and Hanging", ".echChart",".xyChart__empty")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_application_crashing_and_hanging_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Application Crashing and Hanging Count", ".tbvChart",".visError")

    #@pytest.mark.skip(reason="Skipping this test")
    def test_create_remote_threat_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "CreateRemoteThread events", ".euiFlexGroup",".visError")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_filter_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Filter Hosts", ".tbvChart",".visError")

    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Processes", ".euiDataGrid__focusWrap",".euiText")
        

