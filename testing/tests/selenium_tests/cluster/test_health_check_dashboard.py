import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

from .lib import dashboard_test_function

class TestHealthCheckDashboard:
    dashboard_id = "51fe1470-fa59-11e9-bf25-8f92ffa3e3ec"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_number_of_admins(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Number of Admins", ".expExpressionRenderer",".dummyval")
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior
        

    def test_total_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Total Hosts", ".visualization",".dummyval")

    def test_events_by_machine(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Events by machine", ".echChart",".euiText")

    @pytest.mark.skip(reason="Skipping this test")
    def test_unexpected_shutdowns(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Unexpected shutdowns", ".echChart",".visError")

    def test_users_seen(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Users seen", ".visualization",".dummyval")


