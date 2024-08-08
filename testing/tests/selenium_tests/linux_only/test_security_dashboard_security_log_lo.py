import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestSecurityDashboardSecurityLog:
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_security_log_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security logs events"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_failed_logon_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Failed logon attempts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_failed_logons_type_codes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Failed logon type codes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_failed_logon_status_codes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Failed logon status codes"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

