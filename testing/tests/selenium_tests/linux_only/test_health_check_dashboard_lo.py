import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestHealthCheckDashboard:
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    def test_users_seen(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "51fe1470-fa59-11e9-bf25-8f92ffa3e3ec"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Users seen"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
