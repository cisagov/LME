import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestProcessExplorerDashboard:
    dashboard_id = "f2cbc110-8400-11ee-a3de-f1bc0525ad6c"

    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver

    @pytest.mark.skip(reason="Skipping this test")
    def test_files_created_over_time_in_downloads(self, setup_login, kibana_url, timeout):
        #Did not find this dashboard panel on UI. This test should be removed.
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Files created (in Downloads)", ".needarealvaluehere",".euiFlexGroup")
        
    @pytest.mark.skip(reason="Skipping this test")
    def test_files_created_in_downloads(self, setup_login, kibana_url, timeout):
        #This dashboard panel is not working corectly. Shows no data even when there is data. Create issue LME#294
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Files created (in Downloads)", ".euiFlexGroup", ".euiDataGrid__noResults",)

    def test_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Hosts", ".tbvChart",".visError")
               
    def test_process_spawn_event_logs_id1(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Process spawn event logs (Sysmon ID 1)", ".euiDataGrid",".euiDataGrid__noResults")
        
    def test_process_spawns_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Process spawns over time", ".echChart",".xyChart__empty")

    def test_processes_created_by_users_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Processes created by users over time", ".echChart",".xyChart__empty")        

    def test_registry_events_sysmon_12_13_14(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Registry events (Sysmon 12, 13, 14)", ".euiDataGrid__focusWrap",".euiDataGrid__noResults")        
        
    def test_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Users", ".euiDataGrid__focusWrap",".euiText")
        

