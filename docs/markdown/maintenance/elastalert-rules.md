# Elast Alert Rule Example

Below is the complete rule for detecting when Windows Event Logs are cleared:

```yaml
name: Windows Event Logs Cleared

# Type of rule
type: any

# Index pattern to search
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

## Rule Name and Type

```yaml
name: Windows Event Logs Cleared
type: any
```

- **Name**: Identifies the rule as detecting Windows Event Logs being cleared.
- **Type**: Set to "any", meaning the rule will trigger for any matching event, regardless of frequency.

## Index Pattern

```yaml
index: logs-*
```

This specifies which Elasticsearch indices to search. The pattern `logs-*` typically includes all log data indexed by Elastic. Could also be wazuh-*

## Filter Conditions

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

## Alert Configuration

This configuration may be email, slack, or anything else. See official elastalert documentation: https://elastalert2.readthedocs.io/en/latest/alerts.html

```yaml
alert:
  - "slack"

slack_webhook_url: "https://hooks.slack.com/services/EXAMPLE" # This is an example webhook to slack
```

## Alert Message Format

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

## Alert Frequency

```yaml
realert:
  minutes: 5
```

This setting suppresses duplicate alerts for 5 minutes after an alert is sent, preventing alert fatigue. After 5 minutes it will trigger again, and only detect NEW events.

## Timestamp Field

```yaml
timestamp_field: "@timestamp"
```

This specifies that the rule should use the "@timestamp" field to determine the time of events.

Again see elast alert 2 documentation to tailor more specific alerts to your needs:

https://elastalert2.readthedocs.io/en/latest/index.html