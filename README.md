
[![BANNER](https://mreeve-snl.github.io/docs-test/docs/imgs/lme-image.png)]()

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()



# Logging Made Easy 

CISA's Logging Made Easy (LME) is a no cost, open source platform that centralizes log collection, enhances threat detection, and enables real-time alerting, helping small to medium-sized organizations secure their infrastructure. Whether you're upgrading from a previous version or deploying for the first time, LME offers a scalable, efficient solution for logging and endpoint security. 

> [!WARNING]
> **Important Service Notice: Logging Made Easy (LME) Retirement**
> 
> After reviewing our cybersecurity services to ensure alignment with our strategic priorities and statutory mission, the Cybersecurity and Infrastructure Security Agency (CISA) made the difficult decision to retire support for the Logging Made Easy (LME) service, effective May 22, 2026. Users may continue to use LME; however, the service will no longer be maintained or supported by CISA.

## Who is Logging Made Easy for?

From single IT administrators with a handful of devices in their network to small and medium-sized agencies. Really, for anyone! 
LME is intended for organizations that:
- Need a log management and threat detection system.
- Do not have an existing Security Operations Center (SOC), Security Information and Event Management (SIEM) solution or log management and monitoring capabilities.
- Work within limited budgets, time or expertise to set up and manage a logging and threat detection system.

## Features: 

- **Enhanced Threat Detection and Response**: Integrated Wazuh’s and Elastic's open-source tools, along with ElastAlert, for improved detection accuracy and real-time alerting. 
- **Security by Design**: Introduced Podman containerization and encryption to meet the highest security standards.
- **Simplified Installation**: Added Ansible scripts to automate deployment for faster setup and easier maintenance.
- **Custom Data Visualization**: Design and customize dashboards with Kibana to meet specific monitoring needs.
- **Comprehensive Testing**: Expanded unit testing and threat emulation ensure system stability and reliability.

![Architecture](https://github.com/cisagov/lme-docs/blob/main/static/img/lme-architecture-v2-3.png)

## Documentation: 
  - For installation instructions, see the [install documentation](https://cisagov.github.io/lme-docs/docs/markdown/install/).
  - For a detailed overview and additional content, see the [overall documentation](https://cisagov.github.io/lme-docs/docs/).
