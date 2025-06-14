import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib import dashboard_test_function

class TestUserSecurityDashboard:
    #dashboard_id = "e5f203f0-6182-11ee-b035-d5f231e90733"
    dashboard_id = "2fc36188-8461-4927-932e-0e452b7dc3ac"
    
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_search_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Search users", ".visualization",".dummyval")
        # The arguement ".dummyval" is being used though it is not a valid selector. 
        # This panel should always have a visualization so there should never be no data message displayed.
        # If there is no visualization rendered or "No Results found" message is displayed for this panel on dashboard, this test should fail which is correct behavior

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_filter_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Filter hosts", ".tbvChart",".visError")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_search_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Search hosts", ".visualization",".dummyval")
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_filter_users(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Filter users", ".euiDataGrid",".euiText")
   
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_logons_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Logons Title", ".visualization",".dummyval")
   
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_logons_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Logon attempts", ".visualization",".dummyval")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_logons_hosts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Logon hosts", ".visualization",".dummyval")
    
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_logon_attempts(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Logon attempts", ".echChart",".euiText")
   
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_logged_on_computers(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Logged on computers", ".echChart",".euiText")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_user_logon_logoff_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "User Logon & Logoff Events", ".euiDataGrid",".euiIcon")
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_network_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Network Title", ".visualization",".dummyval")  
                
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_all_network_connections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "All network connections", ".echChart",".euiIcon")        

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_network_connections_from_nonbrowser_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Unusual network connections from non-browser processes", ".tbvChart",".visError")                
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_network_connections_area(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Network connections area", ".echChart",".euiIcon")              

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_unusual_network_connections_from_non_browser_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Unusual network connections from non-browser processes", ".tbvChart",".visError")             

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_network_connection_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Network Connection Events (Sysmon ID 3)", ".euiDataGrid",".euiIcon")             

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_unusual_network_connections_events_sysmonid_3(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Network Connection Events (Sysmon ID 3)", ".euiDataGrid",".euiIcon")

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_processes_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Processes Title", ".visualization",".dummyval")  
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_spawned_processes(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Spawned Processes", ".euiDataGrid",".euiIcon")  
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_powershell_events(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Powershell Events", ".visualization",".dummyval")  

    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_powershell_events_over_time(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Powershell events over time", ".echChart",".euiIcon")  
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_powershell_events_by_computer(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Powershell events by computer", ".echChart",".euiText")  
    
    #@pytest.mark.skip(reason="Skipping this test")
    def test_potentially_suspicious_powershell(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Potentially suspicious powershell", ".euiDataGrid__focusWrap",".euiIcon")  
        
    #@pytest.mark.skip(reason="Skipping this test")
    def test_powershell_network_connections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Powershell network connections", ".euiDataGrid__focusWrap",".euiIcon")  
 
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_security_files_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Files title", ".visualization",".dummyval")  
    
    #@pytest.mark.skip(reason="Skipping this test")
    def test_references_to_temporary_files(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "References to temporary files", ".tbvChart",".visError")  
    
    #@pytest.mark.skip(reason="Skipping this test")
    def test_raw_access_read(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "RawAccessRead (Sysmon Event 9)", ".needarealvaluehere",".euiIcon")  
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_windows_defender_title(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Security - Windows Defender Title", ".visualization",".dummyval")  
        
                
    #@pytest.mark.skip(reason="Skipping this test")
    def test_av_detections(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "AV Detections (Event 1116)", ".needarealvaluehere",".euiIcon")  
    
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_defender_event_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "Defender event count", ".visualization",".dummyval")  
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_av_hits_count(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id, "AV Hits (Count)", ".visualization",".dummyval")  
                









   

    




    


 