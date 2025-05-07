# ElastAlert2 for Kibana Security Alerts: Quick Setup Guide

## What You'll Get

Your LME deployment comes with built-in monitoring for Kibana Detection Alerts. This integration continuously watches the `.alerts-security.alerts-*` index pattern to keep you informed of security events.

## Why This Matters

Kibana Security Solution works behind the scenes to detect suspicious or malicious activity in your infrastructure. When it finds something concerning, it creates detailed alerts containing:
- Threat detection results
- Rule violations
- Security event details
- Source and target information

With this integration, your team receives immediate notifications about potential threats without constantly checking Kibana, enabling faster incident response and reducing security risks.

## Why ElastAlert2?

While Elastic requires a paid license to send native security alerts to external services (Slack, Teams, Email), ElastAlert2 provides this functionality as a free alternative.

## Setting Up Your Notification Channels

All configuration files are located in: ```/opt/lme/config/elastalert2/rules/```

## Prerequisite steps:

Enable some rules in Kibana Security. In this example we are enabling Windows alerts:

1. **In Kibana go to Menu -> Security -> Rules**
2. **Click Detection Rules**
3. **Click Tags dropdown and type OS:Windows - then select it**
4. **Click Select all 495 rules (Or however many there are)**
5. **Click Bulk Actions - Enable**
6. **Adjust rules as necessary. From here you can turn on other OS rules, turn of rules based on severity, and tune to your liking. These are the rules that trigger ElastAlert2 notifications. Be aware of that**

## Enabling Notifications: 4 Simple Steps

1. **Edit the main configuration file**
   ```
   nano /opt/lme/config/elastalert2/rules/kibana_alerts.yml
   ```

2. **Uncomment your preferred notification method in the import section**
   ```
   import:
   # - "slack_alert_config.yaml"
   # - "email_alert_config.yaml"
   # - "teams_alert_config.yaml"
   # - "twilio_alert_config.yaml"
   ```
3. **Edit the corresponding configuration file(s) for your chosen notification methods (I.E slack_alert_config as described below).**

4. **Restart the service:**

   ```
   sudo systemctl restart lme-elastalert.service
   ```
5. **Review official ElastAlert2 documentation for other configurations.**

### Available Notification Channels

1. **Slack**
   - Configuration file: ```/opt/lme/config/elastalert2/rules/slack_alert_config```
   - Update the `slack_webhook_url` with your Slack webhook URL

2. **Email**
   - Configuration file: ```/opt/lme/config/elastalert2/rules/email_alert_config```
   - Uncomment the `- "email_alert_config.yaml"` line in the `import:` section of the main configuration
   - Update your SMTP authentication details in this file and credentials in ```/opt/lme/config/elastalert2/misc/smtp_auth.yml```

3. **Microsoft Teams**
   - Configuration file: ```/opt/lme/config/elastalert2/rules/teams_alert_config```
   - Uncomment the `- "teams_alert_config.yaml"` line in the `import:` section of the main configuration
   - Add your MS Teams webhook URL in this file

4. **SMS via Twilio**
   - Configuration file: ```/opt/lme/config/elastalert2/rules/twilio_alert_config```
   - Uncomment the `- "twilio_alert_config.yaml"` line in the `import:` section of the main configuration
   - Update your Twilio authentication details