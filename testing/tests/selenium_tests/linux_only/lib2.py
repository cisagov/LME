from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException

def dashboard_test_function (driver, kibana_url, timeout, dashboard_id, dashboard_name, element_type):

        driver.get(f"{kibana_url}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.XPATH, "//span[text() = 'Logging Made Easy Dashboards:']"))
        WebDriverWait(driver, timeout).until(expected_cond)
        #driver.implicity_wait(30)
        
        panel_title = "Users seen"
        selector = f'div[data-title="{panel_title}"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, timeout).until(expected_cond)
        
        try:
            db_link = driver.find_element(By.XPATH, f"//{element_type}/span[text() = '{dashboard_name}']")
            assert (db_link.is_displayed())
        except NoSuchElementException:
            #No error message found
            assert 1==0, f"Dashboard entry {dashboard_name} not found in Dashboard Panel"