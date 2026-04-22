# LME Detection Engineering - Technical Specification

## Overview

This document lays out Deteciton engineering tasks

## Goals
1. Implement Detection Engineering Environment for Repeatable experiments
2. Build a Map of threats for LME users based on MITRE framework
3. Integrate threats into MITRE CALDERA replayable scripts
4. Ensure overlapping detections and applicable mitigations for threat attack scripts
5. Integrate attack and detection into regression tests for integration into CI/CD pipeline

### Stretch Goals:
6. Increase complexity of attacks to stage 2 and support AD/router virtual machine templates
7. Increase attack complexity to stage 3, and support internet style attack simulations

---

## Design

### What is detection engineering?

Detection engineering is about creating a culture, as well as a process, for
developing, evolving, and tuning detections to defend against current threats.

It loosely involves the following steps:

1. Identify threats
1. Collect logs/visibility
1. Build mitigations
1. Validate they work
1. Repeat as needed

### How Detection Engineering supports the needs of LME users:

1. Active Defense:

a. Create documentation to answer “what do I do with LME for X defense need?”

b. Develop detections AND response capabilities for applicable threats

c. Define the threats that users need mitigations for today

2. Actionable Visibility:

a. Expand documentation for logging types

b. Expand coverage for types of ingestion to pcaps/syslog/cloud/etc.

c. Confirm that users can see activity

### Components:

![Flow](/detection-engineering/DetEngFlow.drawio.png)

1. We begin with a simulation that emulates an actor and its behavior in a virtual network environment.
2. This produces:
  - repeatable cyber range configuration
  - Logs of activity
  - Detection to notify on attack activity
  - Attacker profile to understand what the attack emulates
  - Attack script to re-run the attack
3. Those pieces feed into github CI/CD for validation
4. The detections and actor profile feed into data LME users can use for:
   1. Dashboard understanding
   2. Forensic reports to understand how to use LME
   3. Alerts to notify on similar malicious activity
   4. Wazuh mitigations to stop attacks


---

## Implementation Plan:

### Stage 0:

Lay the foundations described above

### Stage 1:

All of these are draw.io diagrams, and can be edited: https://app.diagrams.net/

![diagram1](/detection-engineering/DetEng-Simple.drawio.png)

### Stage 2:

![diagram2](/detection-engineering/stage-2-diagram.drawio.png)

### Stage 3:

![diagram3](/detection-engineering/stage3-volt-typhoon.drawio.png)
