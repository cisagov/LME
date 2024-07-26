import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

class TestBasicLoading:
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    # @pytest.fixture(scope="class", autouse=True)
    # def setup_teardown(self, driver):
    #     yield
    #     driver.quit()  # Clean up the browser (driver) here


    def test_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        driver.get(f"{kibana_url}/app/dashboards")
        selector = 'div[data-test-subj="dashboardLandingPage"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        assert driver.title == "Dashboards - Elastic"

    def test_dashboard_menu(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel_title = "Dashboard Menu"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        panel = driver.find_element(By.CSS_SELECTOR, selector)
        assert "No results found" not in panel.get_attribute("innerHTML")

