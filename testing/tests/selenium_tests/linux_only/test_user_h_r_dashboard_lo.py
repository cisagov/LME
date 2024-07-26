import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestUserHRDashboard:
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver
    def test_dashboard_menu(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Dashboard Menu"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_domains_and_usernames(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Select domain(s) and username(s)"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_all_user_events(self, driver, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "All User Events by Day of Week, Hour of Day"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

    def test_timestamps_by_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Timestamps by Count"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")


    def test_dashboard_menu(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Dashboard Menu"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

