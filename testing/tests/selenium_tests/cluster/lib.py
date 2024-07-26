import pytest
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException


def dashboard_test_function (driver, kibana_url, timeout, dashboard_id, panel_title, result_panel_class, noresult_panel_class):

    driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")

    # Wait for the react-grid-layout element to be present
    expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
    WebDriverWait(driver, timeout).until(expected_cond)

    selector = f'div[data-title="{panel_title}"]'
    
    # Wait for the specific panel to be present
    expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
    WebDriverWait(driver, timeout).until(expected_cond)

    # Wait for either the panel content or the "No results found" message to be present
 

    panel_content_selector = f"{selector} {result_panel_class}"
    no_results_selector = f"{selector} {noresult_panel_class}"

    expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, f"{panel_content_selector}, {no_results_selector}"))
    WebDriverWait(driver, timeout).until(expected_cond)
    

    # Check if the panel content is present
    try:
        # Check if the "No results found" message is present
        no_results_message = driver.find_element(By.CSS_SELECTOR, no_results_selector)
        assert no_results_message.is_displayed()
    except NoSuchElementException:
        panel_content = driver.find_element(By.CSS_SELECTOR, panel_content_selector)
        assert panel_content.is_displayed()

    