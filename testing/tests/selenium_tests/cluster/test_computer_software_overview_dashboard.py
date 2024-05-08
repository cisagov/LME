import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestComputerSoftwareOverviewDashboard:
    dashboard_id = "33f0d3b0-8b8a-11ea-b1c6-a5bf39283f12"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_application_crashing_and_hanging(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")

        # Wait for the react-grid-layout element to be present
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel_title = "Application Crashing and Hanging"
        selector = f'div[data-title="{panel_title}"]'
        
        # Wait for the specific panel to be present
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)

        # Wait for either the panel content or the "No results found" message to be present
        panel_content_selector = f"{selector} .euiButtonIcon"
        no_results_selector = f"{selector} .xyChart__empty"
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, f"{panel_content_selector}, {no_results_selector}"))
        WebDriverWait(driver, timeout).until(expected_cond)
        
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        #assert "No results found" not in panel.get_attribute("innerHTML")

        # Check if the panel content is present
        try:
            # Check if the "No results found" message is present
            no_results_message = driver.find_element(By.CSS_SELECTOR, no_results_selector)
            assert no_results_message.is_displayed()
        except NoSuchElementException:
            panel_content = driver.find_element(By.CSS_SELECTOR, panel_content_selector)
            assert panel_content.is_displayed()

    def test_application_crashing_and_hanging_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")

        # Wait for the react-grid-layout element to be present
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel_title = "Application Crashing and Hanging Count"
        selector = f'div[data-title="{panel_title}"]'

        # Wait for either the panel content or the "No results found" message to be present
        panel_content_selector = f"{selector} .tbvChart"
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

        # Wait for the react-grid-layout element to be present
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel_title = "Filter Hosts"
        selector = f'div[data-title="{panel_title}"]'

        # Wait for the specific panel to be present
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)

        # Wait for either the panel content or the "No results found" message to be present
        panel_content_selector = f"{selector} .tbvChart"
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

        

    #@pytest.mark.skip(reason="Skipping this test")
    def test_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards#/view/{self.dashboard_id}")

        # Wait for the react-grid-layout element to be present
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)

        panel_title = "Processes"
        selector = f'div[data-title="{panel_title}"]'

        # Wait for the specific panel to be present
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)

        # Wait for either the panel content or the "No results found" message to be present
        panel_content_selector = f"{selector} .tbvChart"
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

