# Elast Alert Rule writing:

This page discusses how to add and implement alert notifications for detections and alerts that trigger in elastic and wazuh.
The basic premise is that all data (logs and detections) will reach specific indices in elasticsearch, but you may want a way to get a notification in your communications systems on this activity. 

Elastalert enables this by providing hooks into email, slack, ms_teams, etc... (see a list of all alert types [HERE](https://elastalert2.readthedocs.io/en/latest/alerts.html#alert-types))

## TOC:

## Alert Rule overview:
See a complete rule below. We discuss the components of it below. 

This is the complete rule for detecting when Windows Event Logs are cleared, one of LME's default rules.
We will continue to add more with later editions of LME, and we welcome detection/alerts from the community as well. 

```yaml
name: Windows Event Logs Cleared

# Type of rule
type: any

# Index pattern to search another example could be wazuh-*
index: logs-*

# Elasticsearch query in DSL format
filter:
  - query:
      bool:
        must:
          - terms:
              event.action: ["audit-log-cleared", "Log clear"]
          - term:
              winlog.api: "wineventlog"
        must_not:
          - term:
              winlog.provider_name: "AD FS Auditing"

# Alert when conditions are met
alert:
  - "slack"

# Slack alert details
slack_webhook_url: "https://hooks.slack.com/services/EXAMPLE" # This is an example webhook to slack

# Alert message format
alert_text: |
  Windows Event Logs Cleared Detected!
  Host: {0}
  Event Action: {1}
  Winlog Provider Name: {2}
  Timestamp: {3}
alert_text_args:
  - host.name
  - event.action
  - winlog.provider_name
  - "@timestamp"

# Alert text only, without additional metadata
alert_text_type: alert_text_only

# Frequency for querying Elasticsearch
realert:
  minutes: 5

# Optional timestamp field to use for events
timestamp_field: "@timestamp"
```

Now, let's break down each section of the rule:

### Rule Name and Type

```yaml
name: Windows Event Logs Cleared
type: any
```

- **Name**: Identifies the rule as detecting Windows Event Logs being cleared.
- **Type**: Set to "any", meaning the rule will trigger for any matching event, regardless of frequency.

### Index Pattern

```yaml
index: logs-*
```

This specifies which Elasticsearch indices to search. The pattern `logs-*` typically includes all log data indexed by Elastic. Could also be wazuh-*

### Filter Conditions

```yaml
filter:
  - query:
      bool:
        must:
          - terms:
              event.action: ["audit-log-cleared", "Log clear"]
          - term:
              winlog.api: "wineventlog"
        must_not:
          - term:
              winlog.provider_name: "AD FS Auditing"
```

This section defines the criteria for triggering the alert:
- The `event.action` must be either "audit-log-cleared" or "Log clear"
- The `winlog.api` must be "wineventlog"
- The `winlog.provider_name` must not be "AD FS Auditing" (to exclude legitimate log clearing events from AD FS)

Some helpful hints for building this filter can be found in elastic's query DSL [docs](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).
In addition, we suggest working with a gpt model and the documentation for how to construct the query above. 
We've found the AI models to produce good boilerplate that can be edited to suit your needs.

### Alert Configuration

This configuration may be email, slack, or anything else. See official elastalert documentation: https://elastalert2.readthedocs.io/en/latest/alerts.html

```yaml
alert:
  - "slack"

slack_webhook_url: "https://hooks.slack.com/services/EXAMPLE" # This is an example webhook to slack
```

### Alert Message Format

```yaml
alert_text: |
  Windows Event Logs Cleared Detected!
  Host: {0}
  Event Action: {1}
  Winlog Provider Name: {2}
  Timestamp: {3}
alert_text_args:
  - host.name
  - event.action
  - winlog.provider_name
  - "@timestamp"

alert_text_type: alert_text_only
```

This defines the content and format of the alert message:
- A warning message
- The name of the host where the event occurred
- The specific event action
- The Windows log provider name
- The timestamp of the event

The `alert_text_type` is set to `alert_text_only`, meaning the alert will only include the specified text without additional metadata.

The alert_test_args are used in the alert text. The arg's are fields in the json event. I.E. hostname will be 0. So, when the alert shows up in email or slack it will start with Host: {The Host Name Pulled from the JSON}. Review the json in Kibana to pull any fields you wanted added to your alert messages.

### Alert Frequency

```yaml
realert:
  minutes: 5
```

This setting suppresses duplicate alerts for 5 minutes after an alert is sent, preventing alert fatigue. After 5 minutes it will trigger again, and only detect NEW events.

### Timestamp Field

```yaml
timestamp_field: "@timestamp"
```

This specifies that the rule should use the "@timestamp" field to determine the time of events.


## Rule storage:
First we need to put the rule at the appropriate directory where elastalert expects all the rules.
Elastalert is setup to use the following directories: 
```bash
root@ubuntu:~# tree /opt/lme/config/elastalert2/
/opt/lme/config/elastalert2/
├── config.yaml
├── misc
│   └── smtp_auth.yml
└── rules
    ├── example-email-rule.yml
        └── windows_event_logs_cleared.yaml
```

- `/opt/lme/config/elastalert2/misc/`: is where you can store various files your alert type might require. For example, smtp alerts require a smtp_auth.yml file like we've included as an example.
- `/opt/lme/config/elastalert2/rules/`: is where you store your elastalert rules.
- `/opt/lme/config/elastalert2/config.yaml`: is the configuration for elastalert. More options are available in their [documentation](https://elastalert2.readthedocs.io/en/latest/configuration.html).

Any changes to the above files, will require a container restart for them to apply to the elastalert service. 

\**WAIT*\* to restart elastalert until you've verified your rule in the next section.

## Test and Deploy the rule:

Once you've written your rule you can test it using the below command: 
```bash
podman run -it --rm --net lme --env-file=/opt/lme/lme-environment.env -e ES_HOST=lme-elasticsearch -e ES_PORT=9200 -e ES_USERNAME=elastic --secret elastic,type=env,target=ES_PASSWORD\
-v /opt/lme/config/elastalert2/config.yaml:/opt/elastalert/config.yaml -v /opt/lme/config/elastalert2/rules:/opt/elastalert/rules -v /opt/lme/config/elastalert2/misc:/opt/elastalert/misc\
--entrypoint elastalert-test-rule localhost/elastalert2:LME_LATEST /opt/elastalert/rules/example-email-rule.yml
```

We've wrapped the above command into a bash script: 
```bash
cd ~/LME/
./scripts/elastalert-test.sh example-email-rule.yml
```
The input value is the filename of your rules saved to the rules directory at:  `/opt/lme/config/elastalert2/rules/`

#####*****IMPORTANT*****
You should make sure the rule evaluates and runs successfully before adding it into elastalert, as elastalert will crash if the rule cannot be successfully parsed.

## Elastalert error and  status logs:
You can find the logs for elastalert at:

1. in the logs volume
```bash
sudo -i 
podman volume mount lme_elastalert2_logs
cd /var/lib/containers/storage/volumes/lme_elastalert2_logs/_data
```

2. you can also see errors and status from elastalert's running at: 
```bash
sudo -i podman logs lme-elastalert
```

3. There are indexes inside elasticsearch where elastalert will write its data `elastalert_*`. 
To view these logs in discover create a new dataview:
1. click the blue drop down to manage dataviews
2. select `create a data view`:

![dataview1](/docs/imgs/dashboard/dataview-create.png)

3. Edit the data view with the anme you'd like to call it, we suggest `elastalert`.
4. add the index pattern you want to match on: `elastalert*`
5. click `save` at the bottom.

![dataview2](/docs/imgs/dashboard/elastalert-dataview.png)


## Using Email and SMTP
We've also provided an example smtp rule you can tune to your needs. 

Because elastalert doesn't support more modern authentication methods, you'll need to setup a username/password combination for your email user that will send the email. 

Gmail has a feature called an `app password` to setup a regular password for a user. Outlook and other email providers have a similar option.
We suggest that you use an unprivileged account you make ONLY to send notifications to your regular email.

You can follow google's instructions [here](https://support.google.com/accounts/answer/185833?hl=en), once done you should have a screen like this: 
![email](/docs/imgs/dashboard/app_password.png)

Other providers should be similar.

Finally you can setup the rule and smtp_auth.yml files like below, and put them at the directories shown in this tree command:
```bash
root@ubuntu:/opt/lme/config/elastalert2# tree
.
├── misc
│   └── smtp_auth.yml
└── rules
    ├── example-email-rule.yml
```

### SMTP_AUTH.yml: 
```yaml
---
user: "loggingmadeeasy@gmail.com"
password: "giyq caym zqiw chje"
```

### SMTP_AUTH.yml: 
```yaml
name: EMAIL
type: frequency
index: wazuh-*
num_events: 1
timeframe:
  minutes: 1
filter:
- query:
    match_phrase:
      agent.ip: "10.1.0.4"
alert: email
alert_text: "ASDFASDF"
alert_text_type: alert_text_only
email:
  - "loggingmadeeasy@gmail.com"
smtp_ssl: true
smtp_port: 465
smtp_host: "smtp.gmail.com"
from_addr: "elastalert@elastalert.com"
smtp_auth_file: /opt/elastalert/misc/smtp_auth.yml
```

# Other options:
Again see elast alert 2 documentation to tailor more specific alerts to your needs:

https://elastalert2.readthedocs.io/en/latest/index.html
