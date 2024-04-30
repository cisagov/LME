import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestSecurityDashboardSecurityLog:
    dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_computer_filter_results(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Select a computer to filter the below results.  Leave blank for all"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_logons_with_special_privileges(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log -  Logons with special privileges assigned - event ID 4672"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_computer_filter(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Select a computername to filter"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_computers_showing_failed_login_attempts_none(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")

        # Wait for the react-grid-layout element to be present
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel_title = "Computers showing failed login attempts - 10 maximum shown"
        selector = f'div[data-title="{panel_title}"]'

        # Wait for the specific panel to be present
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)

        # Wait for either the panel content or the "No results found" message to be present
        panel_content_selector = f"{selector} .echChart"
        no_results_selector = f"{selector} .visError"
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, f"{panel_content_selector}, {no_results_selector}"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel = driver.find_element(By.CSS_SELECTOR, selector)
        
        # Check if the panel content is present
        try:
            # Check if the "No results found" message is present
            no_results_message = driver.find_element(By.CSS_SELECTOR, no_results_selector)
            assert no_results_message.is_displayed()
        except NoSuchElementException:
            panel_content = driver.find_element(By.CSS_SELECTOR, panel_content_selector)
            assert panel_content.is_displayed()

    @pytest.mark.skip(reason="Skipping this test")
    def test_credential_sent_as_clear_text_type_8(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log - Credential sent as clear text - Logon type 8"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_failed_logon_and_reason(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Failed logon and reason (status code)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_failed_logons(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Failed Logons"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_log_cleared_event_id_1102_or_104(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Log Cleared - event ID 1102 or 104"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_process_started_with_different_creds(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log - Process started with different credentials- event ID 4648 [could be RUNAS, scheduled tasks]"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_security_log_events_detail(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log events - Detail"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_security_log_logon_as_a_service_type_5(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Sercurity log - logon as a service - Logon type 5"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_security_log_logon_created_logon_type_2(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log - Logon created - Logon type 2"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_security_log_network_logon_created_type_3(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log - network logon created - Logon type 3"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    @pytest.mark.skip(reason="Skipping this test")
    def test_security_log_process_creation_event_id_4688(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security log - Process creation - event ID 4688"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")



