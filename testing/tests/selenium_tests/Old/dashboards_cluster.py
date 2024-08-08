import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException


class TestHealthCheckDashboard:
    dashboard_id = "51fe1470-fa59-11e9-bf25-8f92ffa3e3ec"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_number_of_admins(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Number of Admins"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_total_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Total Hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_events_by_machine(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Events by machine"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_unexpected_shutdowns(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Unexpected shutdowns"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")


class TestProcessExplorerDashboard:
    dashboard_id = "f2cbc110-8400-11ee-a3de-f1bc0525ad6c"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_files_created_over_time_in_downloads(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Files created (in Downloads)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_files_created_in_downloads(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Files created (in Downloads)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_process_spawn_event_logs_id1(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Process spawn event logs (Sysmon ID 1)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_process_spawns_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Process spawns over time"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_processes_created_by_users_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Processes created by users over time"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_registry_events_sysmon_12_13_14(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Registry events (Sysmon 12, 13, 14)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Users"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")


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



class TestComputerSoftwareOverviewDashboard:
    dashboard_id = "33f0d3b0-8b8a-11ea-b1c6-a5bf39283f12"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_application_crashing_and_hanging(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Application Crashing and Hanging"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_application_crashing_and_hanging_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Application Crashing and Hanging Count"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_create_remote_threat_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "CreateRemoteThread events"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_filter_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Filter Hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Processes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

class TestSysmonSummaryDashboard:
    dashboard_id = "d2c73990-e5d4-11e9-8f1d-73a2ea4cc3ed"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_count_of_sysmon_events_by_event_code(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Count of Sysmon events by event code"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_percentage_of_sysmon_events_by_event_code(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Percentage of Sysmon events by event code"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_sysmon_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Sysmon events"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_top10_hosts_generating_most_sysmon_data(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Top 10 hosts generating the most Sysmon data"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")


class TestUserHRDashboard:
    dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_filter_computers(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Filter Computers"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_filter_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Filter Users"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_inperson_vs_remote_logons(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "In person vs Remote logons"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_user_logoff_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "User logoff events (correlate to logon events)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_user_logon_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "User logon events (filter by LogonId)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

class TestUserSecurityDashboard:
    dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_all_network_connections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "All network connections"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_av_detections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "AV Detections (Event 1116)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_filter_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Filter hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_filter_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Filter users"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_logged_on_computers(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Logged on computers"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_logon_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Logon attempts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_network_connection_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Network Connection Events (Sysmon ID 3)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_network_connections_by_protocol(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Network connection by protocol"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_network_connections_from_nonbrowser_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Network connections from non-browser processes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_potentially_suspicious_powershell(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Potentially suspicious powershell"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_powershell_events_by_computer(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Powershell events by computer"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_powershell_events_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Powershell events over time"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_powershell_network_connections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Powershell network connections"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_raw_access_read(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "RawAccessRead (Sysmon Event 9)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_references_to_temporary_files(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "References to temporary files"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_spawned_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Spawned Processes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_unusual_network_connections_from_non_browser_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Unusual network connections from non-browser processes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_user_logon_logoff_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "User Logon & Logoff Events"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")