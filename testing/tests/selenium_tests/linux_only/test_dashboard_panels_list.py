import pytest
import os
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from .lib2 import dashboard_test_function

class TestCheckDashboardPanelList:
    dashboard_id = "fff78bfe-2758-4fa1-939f-362380fc607d"
    @pytest.fixture(scope="class")
    def setup_login(self, driver, login):
        login()
        yield driver


    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_cso(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Computer Software Overview 2.0','a')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_cal(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Credential Access logs Dashboard 2.0','a')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_hdo(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'HealthCheck Dashboard - Overview 2.0','li')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_iam(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Identity Access Management 2.0','a')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_pcsa(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Policy Changes and System Activity 2.0','a')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_pald(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Privileged Activity log Dashboards 2.0','a')
            
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_pe(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Process Explorer 2.0','a')
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_sdsl(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Security Dashboard - Security Log 2.0','a')
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_ss(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'Sysmon Summary 2.0','a')
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_uhr(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'User HR 2.0','a')
        
    #@pytest.mark.skip(reason="This test is for reference to use in 2.0")
    def test_dashboard_panel_list_us(self, setup_login, kibana_url, timeout):
        driver = setup_login
        dashboard_test_function(driver, kibana_url, timeout, self.dashboard_id,'User Security 2.0','a')