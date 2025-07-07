
[![BANNER](https://mreeve-snl.github.io/docs-test/docs/imgs/lme-image.png)]()

[![Downloads](https://img.shields.io/github/downloads/cisagov/lme/total.svg)]()



# Logging Made Easy 

CISA's Logging Made Easy (LME) is a no cost, open source platform that centralizes log collection, enhances threat detection, and enables real-time alerting, helping small to medium-sized organizations secure their infrastructure. Whether you're upgrading from a previous version or deploying for the first time, LME offers a scalable, efficient solution for logging and endpoint security. 

Check out the LME introduction video [here](https://www.youtube.com/watch?v=AZFV6ZOLg7s).

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

![Architecture](https://cisagov.github.io/lme-docs/docs/imgs/lme-architecture-v2.png)

## Documentation:
  - For installation instructions, see the [install documentation](https://cisagov.github.io/lme-docs/docs/markdown/install/).
  - For offline installation (air-gapped environments), see [OFFLINE_INSTALLATION.md](OFFLINE_INSTALLATION.md).
  - For a detailed overview and additional content, see the [overall documentation](https://cisagov.github.io/lme-docs/docs/).
