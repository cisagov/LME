"""Runs automated test cases against the kibana dashboards.

For full usage, run:
    python3 selenium_tests.py -h
    py -u selenium_tests.py 2> log.txt #redirects everything to a text file.
NOTE:
- before running the Elastic interface password must be
saved as an environment variable, ELASTIC_PASSWORD.
- The script assumes access to the server without any
ssl errors.

Basic usage:
    python3 selenium_tests.py --mode MODE --timeout TIMEOUT
where MODE is either headless, detached, or debug. Defaults to headless
and where TIMEOUT is in seconds. Defaults to 30.

Additionally, you can pass in arguments to the unittest
library, such as the -v flag."""

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
parser.add_argument('--mode', help='Headless, no browser, detached, open browser, debug, open browser and leave it open. Default is no headless.', default='headless')
parser.add_argument('--domain', help='The ip or domain of the elasticsearch server', default='ls1')

args, unittestArgs = parser.parse_known_args()

def login(password : str) -> None:
    """Login and load the home page"""

    url = f"https://{args.domain}"
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

        driver.get(f"https://{args.domain}/app/dashboards")
        selector = 'div[data-test-subj="dashboardLandingPage"]'
        expected_cond = EC.presence_of_element_located((By.CSS_SELECTOR, selector))
        WebDriverWait(driver, args.timeout).until(expected_cond)
        self.assertEqual(driver.title, "Dashboards - Elastic")

class UserSecurityTests(unittest.TestCase):
    """Test cases for the User Security Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_dashboard_menu(self):
        """Is there any data?"""
        panel = load_panel("Dashboard Menu")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_search_users(self):
        """Is there any data?"""
        panel = load_panel("Search users")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_search_hosts(self):
        """Is there any data?"""
        panel = load_panel("Search hosts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_filter_hosts(self):
        """Is there any data?"""
        panel = load_panel("Filter hosts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_filter_users(self):
        """Is there any data?"""
        panel = load_panel("Filter users")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_logon_attempts(self):
        """Is there any data?"""
        panel = load_panel("Security - Logon attempts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_logon_hosts(self):
        """Is there any data?"""
        panel = load_panel("Security - Logon hosts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_logon_attempts(self):
        """Is there any data?"""
        panel = load_panel("Logon attempts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_logged_on_computers(self):
        """Is there any data?"""
        panel = load_panel("Logged on computers")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_user_logon_logoff_events(self):
        """Is there any data?"""
        panel = load_panel("User Logon & Logoff Events")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_all_network_connections(self):
        """Is there any data for the "All network connections" panel?"""
        panel = load_panel("All network connections")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_network_connections_from_nonbrowser_processes(self):
        """Is there any data?"""
        panel = load_panel("Network connections from non-browser processes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_network_connections_by_protocol(self):
        """Is there any data for the "Network connection by protocol" panel?"""
        panel = load_panel("Network connection by protocol")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_unusual_network_connections_from_non_browser_processes(self):
        """Is there any data?"""
        panel = load_panel("Unusual network connections from non-browser processes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_network_connection_events(self):
        """Is there any data?"""
        panel = load_panel("Network Connection Events (Sysmon ID 3)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_spawned_processes(self):
        """Is there any data?"""
        panel = load_panel("Spawned Processes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_powershell_events(self):
        """Is there any data?"""
        panel = load_panel("Powershell Events")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_powershell_events_over_time(self):
        """Is there any data?"""
        panel = load_panel("Powershell events over time")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_powershell_events_by_computer(self):
        """Is there any data?"""
        panel = load_panel("Powershell events by computer")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_potentially_suspicious_powershell(self):
        """Is there any data?"""
        panel = load_panel("Potentially suspicious powershell")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_powershell_network_connections(self):
        """Is there any data?"""
        panel = load_panel("Powershell network connections")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_references_to_temporary_files(self):
        """Is there any data?"""
        panel = load_panel("References to temporary files")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_defender_event_count(self):
        """Is there any data?"""
        panel = load_panel("Defender event count")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_av_hits(self):
        """Is there any data?"""
        panel = load_panel("AV Hits (Count)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))
    
    def test_av_detections(self):
        """Is there any data?"""
        panel = load_panel("AV Detections (Event 1116)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_raw_access_read(self):
        """Is there any data?"""
        panel = load_panel("RawAccessRead (Sysmon Event 9)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class UserHRTests(unittest.TestCase):
    """Test cases for the User HR Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "618bc5d0-84f8-11ee-9838-ff0db128d8b2"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_dashboard_menu(self):
        """Is there any data?"""
        panel = load_panel("Dashboard Menu")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_domains_and_usernames(self):
        """Is there any data?"""
        panel = load_panel("Select domain(s) and username(s)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_filter_computers(self):
        """Is there any data?"""
        panel = load_panel("Filter Computers")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_filter_users(self):
        """Is there any data?"""
        panel = load_panel("Filter Users")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_all_user_events(self):
        """Is there any data?"""
        panel = load_panel("All User Events by Day of Week, Hour of Day")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_timestamps_by_count(self):
        """Is there any data?"""
        panel = load_panel("Timestamps by Count")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_user_logon_events(self):
        """Is there any data?"""
        panel = load_panel("User logon events (filter by LogonId)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_user_logoff_events(self):
        """Is there any data?"""
        panel = load_panel("User logoff events (correlate to logon events)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_inperson_vs_remote_logons(self):
        """Is there any data?"""
        panel = load_panel("In person vs Remote logons")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class SecurityDashboardSecurityLogTests(unittest.TestCase):
    """Test cases for the Security Dashboard - Security Log Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "51186cd0-e8e9-11e9-9070-f78ae052729a"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_dashboard_menu(self):
        """Is there any data?"""
        panel = load_panel("Dashboard Menu")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_events(self):
        """Is there any data?"""
        panel = load_panel("Security logs events")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_computer_filter_results(self):
        """Is there any data?"""
        panel = load_panel("Select a computer to filter the below results. Leave blank for all")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_computer_filter(self):
        """Is there any data?"""
        panel = load_panel("Select a computername to filter")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_failed_logon_attempts(self):
        """Is there any data?"""
        panel = load_panel("Failed logon attempts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_computers_showing_failed_login_attempts(self):
        """Is there any data?"""
        panel = load_panel("Computers showing failed login attempts - 10 maximum shown")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_failed_logons_type_codes(self):
        """Is there any data?"""
        panel = load_panel("Failed logon type codes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_failed_logon_and_reason(self):
        """Is there any data?"""
        panel = load_panel("Failed logon and reason (status code)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_failed_logons(self):
        """Is there any data?"""
        panel = load_panel("Failed Logons")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_failed_logon_status_codes(self):
        """Is there any data?"""
        panel = load_panel("Failed logon status codes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_log_cleared_event_id_1102_or_104(self):
        """Is there any data?"""
        panel = load_panel("Log Cleared - event ID 1102 or 104")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_events_detail(self):
        """Is there any data?"""
        panel = load_panel("Security log events - Detail")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_process_creation_event_id_4688(self):
        """Is there any data?"""
        panel = load_panel("Security log - Process creation - event ID 4688")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_logon_created_logon_type_2(self):
        """Is there any data?"""
        panel = load_panel("Security log - Logon created - Logon type 2")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_network_logon_created_type_3(self):
        """Is there any data?"""
        panel = load_panel("Security log - network logon created - Logon type 3")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_security_log_logon_as_a_service_type_5(self):
        """Is there any data?"""
        panel = load_panel("Security log - logon as a service - Logon type 5")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_credential_sent_as_clear_text_type_8(self):
        """Is there any data?"""
        panel = load_panel("Security log - Credential sent as clear text - Logon type 8")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_logons_with_special_privileges(self):
        """Is there any data?"""
        panel = load_panel("Security log - Logons with special privileges assigned - event ID 4672")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_process_started_with_different_creds(self):
        """Is there any data?"""
        panel = load_panel("Security log - Process started with different credentials- " \
        "event ID 4648 [could be RUNAS, scheduled tasks]")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class ComputerSoftwareOverviewTests(unittest.TestCase):
    """Test cases for the Computer Software Overview Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "33f0d3b0-8b8a-11ea-b1c6-a5bf39283f12"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_dashboard_menu(self):
        """Is there any data?"""
        panel = load_panel("Dashboard Menu")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_host_count(self):
        """Is there any data?"""
        panel = load_panel("Host Count")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_filter_hosts(self):
        """Is there any data?"""
        panel = load_panel("Filter Hosts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_processes(self):
        """Is there any data?"""
        panel = load_panel("Processes")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_application_crashing_and_hanging(self):
        """Is there any data?"""
        panel = load_panel("Application Crashing and Hanging")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_application_crashing_and_hanging_count(self):
        """Is there any data?"""
        panel = load_panel("Application Crashing and Hanging Count")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_create_remote_threat_events(self):
        """Is there any data?"""
        panel = load_panel("CreateRemoteThread events")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class SysmonSummaryTests(unittest.TestCase):
    """Test cases for the Sysmon Summary Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "d2c73990-e5d4-11e9-8f1d-73a2ea4cc3ed"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_total_number_of_sysmon_events_found(self):
        """Is there any data?"""
        panel = load_panel("Total number of Sysmon events found")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_percentage_of_sysmon_events_by_event_code(self):
        """Is there any data?"""
        panel = load_panel("Percentage of Sysmon events by event code")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_count_of_sysmon_events_by_event_code(self):
        """Is there any data?"""
        panel = load_panel("Count of Sysmon events by event code")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_top10_hosts_generating_most_sysmon_data(self):
        """Is there any data?"""
        panel = load_panel("Top 10 hosts generating the most Sysmon data")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_sysmon_event_code_reference(self):
        """Is there any data?"""
        panel = load_panel("Sysmon event code reference")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_sysmon_events(self):
        """Is there any data?"""
        panel = load_panel("Sysmon events")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class ProcessExplorerTests(unittest.TestCase):
    """Test cases for the Process Explorer Dashboard"""

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "f2cbc110-8400-11ee-a3de-f1bc0525ad6c"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_process_spawns_over_time(self):
        """Is there any data?"""
        panel = load_panel("Process spawns over time")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_hosts(self):
        """Is there any data?"""
        panel = load_panel("Hosts")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_users(self):
        """Is there any data?"""
        panel = load_panel("Users")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_processes_created_by_users_over_time(self):
        """Is there any data?"""
        panel = load_panel("Processes created by users over time")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_process_spawn_event_logs_id1(self):
        """Is there any data?"""
        panel = load_panel("Process spawn event logs (Sysmon ID 1)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_files_created_in_downloads(self):
        """Is there any data?"""
        panel = load_panel("Files created (in Downloads)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_files_created_over_time_in_downloads(self):
        """Is there any data?"""
        panel = load_panel("Files created over time (in Downloads)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_registry_events_sysmon_12_13_14(self):
        """Is there any data?"""
        panel = load_panel("Registry events (Sysmon 12, 13, 14)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

# class AlertingTests(unittest.TestCase):
#     """Test cases for the Alerting Dashboard"""

#     def setUp(self):
#         # The dashboard ID is hard-coded in the ndjson file
#         dashboard_id = "ac1078e0-8a32-11ea-8939-89f508ff7909"
#         driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
#         expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
#         WebDriverWait(driver, args.timeout).until(expected_cond)

#     def test_signals_overview(self):
#         """Is there any data?"""
#         panel = load_panel("Signals Overview")
#         self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

#     def test_mitre_attack_technique(self):
#         """Is there any data?"""
#         panel = load_panel("MITRE ATT&CK Technique")
#         self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

#     def test_signals_details(self):
#         """Is there any data?"""
#         panel = load_panel("Signals Details")
#         self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

#     def test_full_event_logs(self):
#         """Is there any data?"""
#         panel = load_panel("Full Event Logs")
#         self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

class HealthCheckTests(unittest.TestCase):
    """Test cases for the HealthCheck Dashboard"""
    #2/6/2024, main branch on lme. The health check dashboard has an odd dashboard menu. This will likely need updating.

    def setUp(self):
        # The dashboard ID is hard-coded in the ndjson file
        dashboard_id = "51fe1470-fa59-11e9-bf25-8f92ffa3e3ec"
        driver.get(f"https://{args.domain}/app/dashboards#/view/{dashboard_id}")
        expected_cond = EC.presence_of_element_located((By.CLASS_NAME, "kbnAppWrapper"))
        WebDriverWait(driver, args.timeout).until(expected_cond)

    def test_total_hosts(self):
        """Is there any data?"""
        panel = load_panel("Alpha - Health Check - Total Hosts - Metric")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_users_seen(self):
        """Is there any data?"""
        panel = load_panel("Users seen")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_number_of_admins(self):
        """Is there any data?"""
        panel = load_panel("Alpha - Health Check - Number of Admins - Metric (converted)")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_events_by_machine(self):
        """Is there any data?"""
        panel = load_panel("Events by machine")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

    def test_unexpected_shutdowns(self):
        """Is there any data?"""
        panel = load_panel("Unexpected shutdowns")
        self.assertFalse("No results found" in panel.get_attribute("innerHTML"))

options = webdriver.ChromeOptions()
if args.mode == "detached" or args.mode =="debug": #browser opens
    print("# " + args.mode + " mode #")
    options.add_experimental_option("detach", True)

else: #Browser does not open. Default mode is headless
    print("# headless mode #")
    options.add_argument("--headless=new")
    # options.add_argument("--proxy-server='direct://'")
    # options.add_argument("--proxy-bypass-list=*")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--ignore-certificate-errors")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

s = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=s, options=options)

try:
    login(os.environ['ELASTIC_PASSWORD'])
except KeyError:
    MESSAGE = "Error: Elastic password not set. Should be saved as env variable, ELASTIC_PASSWORD."
    print(MESSAGE, file=sys.stderr)
    sys.exit(1)

unit_argv = [sys.argv[0]] + unittestArgs
unittest.main(argv=unit_argv, exit=False)

if args.mode == "debug":
    print("# Debug Mode - Browser will remain open.") # Browser will stay open   
else: 
    driver.stop_client() 
    driver.close()
    driver.quit()
