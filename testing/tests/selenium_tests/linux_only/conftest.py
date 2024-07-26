import pytest
import os
from webdriver_manager.chrome import ChromeDriverManager
from selenium.common.exceptions import TimeoutException
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By


@pytest.fixture(scope="session")
def kibana_host():
    return os.getenv("KIBANA_HOST", "localhost")

@pytest.fixture(scope="session")
def kibana_port():
    return int(os.getenv("KIBANA_PORT", 443))

@pytest.fixture(scope="session")
def kibana_user():
    return os.getenv("KIBANA_USER", "elastic")

@pytest.fixture(scope="session")
def kibana_password():
    return os.getenv("elastic",os.getenv("KIBANA_PASSWORD", "changeme"))

@pytest.fixture(scope="session")
def kibana_url(kibana_host, kibana_port):
    return f"https://{kibana_host}:{kibana_port}"

@pytest.fixture(scope="session")
def timeout():
    return int(os.getenv("SELENIUM_TIMEOUT", 30))

@pytest.fixture(scope="session")
def mode():
    return os.getenv("SELENIUM_MODE", "headless")

@pytest.fixture(scope="session")
def driver(timeout, mode):
    options = webdriver.ChromeOptions()
    if mode == "detached" or mode == "debug":
        options.add_experimental_option("detach", True)
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--allow-running-insecure-content")
        options.add_argument('--force-device-scale-factor=1.5')
    else:
        options.add_argument("--headless=new")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1920,1080")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")

    s = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=s, options=options)

    yield driver

    if mode != "debug":
        driver.stop_client()
        driver.close()
        driver.quit()

@pytest.fixture(scope="session")
def login(driver, kibana_url, kibana_user, kibana_password, timeout):
    def _login():
        """Login and load the home page"""

        driver.get(kibana_url)

        # Wait for the login page to load
                    # Check if the current URL contains the login page identifier
        login_url_identifier = "/login"
        if login_url_identifier in driver.current_url:
            expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, 'input[name="username"]'))
            WebDriverWait(driver, timeout).until(expected_cond)

            # Login
            username_input = driver.find_element(By.CSS_SELECTOR, 'input[name="username"]')
            username_input.send_keys("elastic")
            password_input = driver.find_element(By.CSS_SELECTOR, 'input[name="password"]')
            password_input.send_keys(kibana_password)
            submit_button = driver.find_element(By.CSS_SELECTOR, 'button[data-test-subj="loginSubmit"]')
            submit_button.click()

            # Wait for the home page to load
            selector = 'div[data-test-subj="homeApp"]'
            expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
            WebDriverWait(driver, timeout).until(expected_cond)

    return _login