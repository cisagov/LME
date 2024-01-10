"""Runs automated test cases against the kibana dashboards.

For full usage, run:
    python3 selenium_tests.py -h

NOTE:
- before running the Elastic interface password must be
saved as an environment variable, ELASTIC_PASSWORD.
- The script assumes access to the server without any
ssl errors.

Basic usage:
    python3 selenium_tests.py --timeout TIMEOUT
where TIMEOUT is in seconds. Defaults to 30.

Additionally, you can pass in arguments to the unittest
library, such as the -v flag."""

# Maybe use Write-EventLog to manually trigger events?
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/write-eventlog

import unittest
import argparse
import sys
import os

from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium import webdriver

parser = argparse.ArgumentParser()
parser.add_argument('--timeout', help='Timeout, in seconds. Defaults to 30.',
    default=30,
    type=int)
args, unittestArgs = parser.parse_known_args()

def login(password : str) -> None:
    """Login and load the home page"""

    url = "https://ls1"
    driver.get(url)

    # Wait for the login page to load
    expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, 'input[name="username"]'))
    WebDriverWait(driver, args.timeout).until(expected_cond)

    # Login
    username_input = driver.find_element(By.CSS_SELECTOR, 'input[name="username"]')
    username_input.send_keys("elastic")
    password_input = driver.find_element(By.CSS_SELECTOR, 'input[name="password"]')
    password_input.send_keys(password)
    submit_button = driver.find_element(By.CSS_SELECTOR, 'button[data-test-subj="loginSubmit"]')
    submit_button.click()

    # Wait for the home page to load
    selector = 'div[data-test-subj="homeApp"]'
    expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
    WebDriverWait(driver, args.timeout).until(expected_cond)

def load_panel(panel_title : str):
    """Waits for the given panel to load then returns it. Assumes that the appropriate dashboard
    has already been loaded by the setUp functions."""

    selector = f'div[data-title="{panel_title}"]'
    expected_cond = EC.all_of(
        EC.presence_of_element_located((By.CSS_SELECTOR, selector)),
        EC.none_of(EC.text_to_be_present_in_element_attribute((By.CSS_SELECTOR, selector),
            "innerHTML", "Loading"))
    )
    WebDriverWait(driver, args.timeout).until(expected_cond)
    return driver.find_element(By.CSS_SELECTOR, selector)

class BasicLoading(unittest.TestCase):
    "High-level tests, very basic functionality only."

    def test_title(self):
        """If for some reason we weren't able to access the webpage at
        all, this would be the first test to show it."""

        driver.get("https://ls1/app/dashboards")
        selector = 'div[data-test-subj="dashboardLandingPage"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, args.timeout).until(expected_cond)
        self.assertEqual(driver.title, "Dashboards - Elastic")

class UserSecurityTests(unittest.TestCase):
    """Test cases for the User Security Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"https://ls1/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "react-grid-layout"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_panel_count(self):
        """Do the expected number of panels load?"""
        expected_count = 32
        dashboard = driver.find_element(By.CLASS_NAME, "react-grid-layout")
        children_count = dashboard.get_attribute("childElementCount")
        self.assertEqual(children_count, str(expected_count+1)) # +1 for an invisible child element

    def test_all_network_connections(self):
        """Is there any data for the "All network connections" panel?"""
        panel = load_panel("All network connections")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_network_connections_by_protocol(self):
        """Is there any data for the "Network connection by protocol" panel?"""
        panel = load_panel("Network connection by protocol")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

options = webdriver.ChromeOptions()
# options.add_argument("--headless=new")
options.add_experimental_option("detach", True) # Make browser stay open, in reality we'd
# probably prefer headless

s = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=s, options=options)

try:
    login(os.environ['ELASTIC_PASSWORD'])
except KeyError:
    MESSAGE = "Error: Elastic password not set. Should be saved as env variable, ELASTIC_PASSWORD."
    print(MESSAGE, file=sys.stderr)
    sys.exit(1)
unit_argv = [sys.argv[0]] + unittestArgs
unittest.main(argv=unit_argv)

# driver.stop_client() # uncommented so the browser window stays open for debugging
# driver.close()
# driver.quit()
