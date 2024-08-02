# Chapter 4 - Post Install Actions

## Chapter Overview

* Logging in to Kibana to view logs
* Check that logs are being received
* Enable the default detection rules
* Kibana basics

## 4.1 Initial Kibana setup

Once chapters 1 to 3 are complete, you can import an existing set of Kibana dashboards, which will visualize the logs, and answer questions like 'What patch level are the clients running?'.

In a web browser, navigate to ```https://your_Linux_server``` and authenticate with the credentials provided in [Chapter 3.2](/docs/markdown/chapter3/chapter3.md#32-install-lme-the-easy-way-using-our-script).

### 4.1.1 Import Initial Dashboards

As of LME version 0.4, the install process automatically handles the initial  index creating process and importing dashboards. Upon logging into Kibana the number of dashboards should be visible under the ‘Dashboard’ tab on the left-hand side.

If the initial dashboard import has an error, you can reattempt the upload by running the dashboard update script created within the root LME directory (**NOT** the one in 'Chapter 3 Files'):

```
sudo /opt/lme/dashboard_update.sh
```

:hammer_and_wrench: If this does not resolve the issue or you wish to manually import the dashboards, see [Troubleshooting: Manual Dashboard Install](/docs/markdown/reference/troubleshooting.md#manual-dashboard-install) for the previous installation instructions.


### 4.1.2 Check that logs are being received 

While on the Elastic home page, click on the hamburger icon on the left, select "Analytics" and click "Dashboard" and select "User Security," to show a dashboard similar to Figure 2.

<p align="center">
    <img src="/docs/imgs/usersec.png" width="66%" />
</p>
<p align="center">
Figure 2 - The LME NEW - User Security - Overview
</p>

In the top right hand corner, click the calendar icon to the left of "Last 15 minutes" and select "Today" to change the date range to only include today's data. The dashboard accurately represents the machines that have been sending logs. Changing to "Last 7 days" is useful to visualize logs over time.

## 4.2 Enable Alerts

Click on the hamburger icon on the top left, then under "Security," navigate to "Alerts" (in older versions, this may be titled "Detections").

Navigate to "Manage Rules" (In older versions, this may be titled "Manage Detection Rules"):

![Enable siem](/docs/imgs/siem2.png)

Select the option to "Load Elastic prebuilt rules and timeline templates":

![Enable siem](/docs/imgs/siem3.png)

Once the prebuilt Elastic rules are installed, filter from the "Tags" option and select "Windows":

![Enable siem](/docs/imgs/siem4.png)

Ensure that the maximum number of rows is shown for all relevant rules to be selected at once (In recent versions, there is an ability to "Select All" rows):

![Enable siem](/docs/imgs/siem5.png)

Select all the displayed rules, expand "Bulk actions" and choose "Enable":

![Enable siem](/docs/imgs/alert-enable-menu.png)

In recent versions of Elastic that include Machine Learning rules (rules with the "ML" tag), you may receive errors when performing bulk actions:

![Rules_Error](/docs/imgs/rules_error.png)

Rules without the "ML" tag should still be activated through this bulk action, regardless of this error message. Use of "ML" rules require Machine Learning to be enabled, which is part of Enterprise and Platinum Elastic subscriptions.

### 4.2.1 Add rule exceptions

Depending on the environment, exceptions may be added to some of the built-in Elastic rules shown above to prevent false positives. These will be specific to your environment and should be tightly scoped to avoid excluding potentially malicious behavior but may be beneficial to filter out some of the benign behavior of LME (for example to prevent the Sysmon update script creating alerts).

An example is shown below, with further information available [here](https://www.elastic.co/guide/en/security/current/detections-ui-exceptions.html).

First, navigate to the "Manage Detection Rules" section as described above, and then search for and select the rule you wish to add an exception for:

![Select Rule](/docs/imgs/select-rule.png)

Then navigate to the "Exceptions" tab above the "Trend" section and then select "Add new exception":

![Exceptions](/docs/imgs/exceptions.png)

![Add Exceptions](/docs/imgs/add-exceptions.png)

Next, configure the necessary exception, taking care to ensure that it is tightly scoped and will not inadvertently prevent detection of actual malicious behavior:

![Example Exception](/docs/imgs/example-exception.png)

Note that in this instance the following command line value has been added as an exception, but the ```testme.local``` domain would need updating to match the location you installed the update batch script to during the LME installation, the same value used to update the scheduled task as described [here](/docs/markdown/chapter2.md#222---scheduled-task-gpo-policy).

```
C:\Windows\SYSTEM32\cmd.exe /c "\\testme.local\SYSVOL\testme.local\Sysmon\update.bat"
```

## 4.3 Learning how to use Kibana

Elasticsearch has provided a number of videos exploring the features of Kibana and how to create new dashboards and analytics. https://www.youtube.com/playlist?list=PLhLSfisesZIvA8ad1J2DSdLWnTPtzWSfI

Kibana's useful features are as following:

### 4.3.1 Dashboards
Found under "Analytics" -> "Dashboard," dashboards visualize LME data. LME comes with several dashboards. Take some time to get familiar with the different dashboards already available. If interested in creating custom dashboards, see the link above for starting points offered by Elasticsearch.

Note:  If you make changes to the dashboards that LME provides, be sure to save your changes to a dashboard with a different name.  Otherwise, your changes will be overwritten when you upgrade LME.

### 4.3.2 Discover
Found under "Analytics" -> "Discover," Discover allows the view raw events and craft custom filters to find events of interest. For example, to inspect all DNS queries made on a computer named "Example-1," you could insert the following query where it says "Filter your data using KQL syntax":
```
event.code: 22 and host.name: Example-1
```

See [Kibana Query Language](https://www.elastic.co/guide/en/kibana/current/kuery-query.html) for more information on building queries like this.

### 4.3.3 Alerts
Found under "Security" -> "Alerts," alerts are a powerful tool that helps automate detection of suspicious events. Review section [4.2 Enable Alerts](#42-enable-alerts) for help configuring alerts. See [Dections and alerts](https://www.elastic.co/guide/en/security/current/detection-engine-overview.html) to learn more.

### 4.3.4 Adding Filters
You may find you want to filter some results.  For example, the User Security dashboard displays logon attempts that quickly run in the thousands.  You can use a `regexp` filter at the top of the dashboard to get rid of these "fluff" events.

As an example, to filter out unnecessary logons in the User Security dashboard follow these steps: 
1. Click the `Add filter` '+' sign (upper left).
2. Click `Edit as Query DSL` to add a regexp filter (upper right of popup):  
```
{
  "bool": {
    "filter": [
      {
        "match_phrase": {
          "event.code": "4624"
        }
      }
    ],
    "must_not": [
      {
        "regexp": {
          "winlog.event_data.TargetUserName": ".*$.*"
        }
      }
    ]
  }
}
```
3. Click `Add Filter` (lower right of popup)

The above filters out for the [4624](https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4624) events any TargetUserName that has a `$` in the field. 
