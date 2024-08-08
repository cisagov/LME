import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestUserSecurityDashboard:
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_search_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Search users"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_search_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Search hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_security_logon_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security - Logon attempts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_security_logon_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Security - Logon hosts"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")
    
    def test_av_hits(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "AV Hits (Count)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_defender_event_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Defender event count"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

