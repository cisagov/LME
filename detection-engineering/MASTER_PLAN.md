# MASTER_PLAN.md — LME Role Validation Experiment

**Type:** Detection engineering experiment — Ludus cyber range
**Branch:** `mreeve-det-eng`
**Created:** 2026-04-01
**Status:** Active

## Original Intent

> Validate all 5 new Ludus-compatible Ansible roles (`ludus_lme_server`, `ludus_lme_agents`,
> `ludus_caldera_server`, `ludus_caldera_agent`, `ludus_caldera_scripts`) by deploying a
> complete LME + Caldera detection engineering range and confirming end-to-end telemetry
> flow from endpoints to Elasticsearch/Kibana.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   VLAN 10 — 10.1.10.0/24                │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │  lme-server   │  │caldera-server│                     │
│  │ Ubuntu 24.04  │  │ Ubuntu 24.04 │                     │
│  │ .10           │  │ .20          │                     │
│  │               │  │              │                     │
│  │ Elasticsearch │  │ MITRE        │                     │
│  │ Kibana        │  │ Caldera      │                     │
│  │ Fleet Server  │  │ + Scripts    │                     │
│  │ Wazuh Manager │  │              │                     │
│  └──────┬───────┘  └──────┬───────┘                     │
│         │                  │                             │
│    ┌────┴──────────────────┴────┐                        │
│    │       Agent Enrollment     │                        │
│    ├────────────┬───────────────┤                        │
│    ▼            ▼               │                        │
│  ┌──────────────┐  ┌───────────┴──┐                     │
│  │ win11-endpt   │  │ ubuntu-endpt │                     │
│  │ Win11 22H2    │  │ Ubuntu 24.04 │                     │
│  │ .30           │  │ Desktop .40  │                     │
│  │               │  │              │                     │
│  │ Elastic Agent │  │ Elastic Agent│                     │
│  │ Wazuh Agent   │  │ Wazuh Agent  │                     │
│  │ Sysmon        │  │ auditd rules │                     │
│  │ Caldera Agent │  │              │                     │
│  └──────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

## Principles

1. **Test the roles as-built** — Use the roles from `ansible/roles/ludus_*` without modification
2. **End-to-end proof** — Success = logs visible in Kibana from both endpoints
3. **Document for reproducibility** — Anyone can re-deploy from this config
4. **Minimal range** — Only what's needed to validate the roles; no domain controllers or extra infra

## Decision Log

| Date | DEC-ID | Decision | Rationale |
|------|--------|----------|-----------|
| 2026-04-01 | DEC-EXP-001 | Single VLAN (10) for all VMs | Simplest topology; no inter-VLAN routing needed for role validation |
| 2026-04-01 | DEC-EXP-002 | Include Caldera server to test all 5 roles | User requested "testing all of the new roles" |
| 2026-04-01 | DEC-EXP-003 | 32GB RAM for LME server | ELK stack requires significant memory; matches production guidance |
| 2026-04-01 | DEC-EXP-004 | Ubuntu desktop for Linux endpoint | Tests ludus_lme_agents on a desktop variant (GUI + auditd), distinct from server |
| 2026-04-01 | DEC-EXP-005 | No agent-specific terminology in this repo | LME is an open-source CISA project; docs must be tool-agnostic and readable by any contributor. Session context file is `agents.md`, not tool-specific names. |

## Resources

| File | Purpose |
|------|---------|
| `ludus-range-config.yml` | Ludus range configuration — upload with API |
| `README.md` | Experiment overview, quickstart, verification steps |
| `agents.md` | Session context and quick reference |
| `CREDENTIALS.md` | Credential layout (gitignored) |
| `../Readme.md` | Parent detection engineering specification |

## Initiative: Role Validation Deployment

**Status:** active | **Started:** 2026-04-01 | **Dominant Constraint:** simplicity

### Goals
- GOAL-001: Deploy all 5 `ludus_*` roles on a Ludus range
- GOAL-002: Confirm Elastic Agent enrolled and shipping logs from Windows endpoint
- GOAL-003: Confirm Elastic Agent enrolled and shipping logs from Ubuntu endpoint
- GOAL-004: Confirm Wazuh Agent active on both endpoints
- GOAL-005: Confirm Caldera agent checking in from Windows endpoint
- GOAL-006: Confirm Caldera automation scripts functional

### Non-Goals
- NOGO-001: Attack chain emulation (future experiment)
- NOGO-002: Domain controller or AD integration
- NOGO-003: Performance tuning or production hardening

### Requirements
- **P0-001:** LME server deploys and Elasticsearch is reachable
- **P0-002:** Both endpoints enroll Elastic Agent to Fleet
- **P0-003:** Both endpoints register Wazuh Agent with manager
- **P1-001:** Caldera agent checks in from Windows endpoint
- **P1-002:** Caldera scripts deploy and can list abilities
- **P2-001:** Sysmon generating events on Windows endpoint
- **P2-002:** auditd rules active on Ubuntu endpoint

### Phases

#### Phase 1: Infrastructure Setup
**Status:** active
- Build `ubuntu-24.04-x64-desktop-template` (build started 2026-04-01)
- Upload 5 `ludus_*` roles to Ludus server
- Set range config via API

#### Phase 2: Deployment
**Status:** planned
- Deploy range via `POST /api/v2/range/deploy`
- Monitor deployment logs
- Verify all VMs come up with correct IPs

#### Phase 3: Verification
**Status:** planned
- Verify LME stack health (Elasticsearch, Kibana, Fleet)
- Check Elastic Agent enrollment for both endpoints
- Check Wazuh Agent registration for both endpoints
- Verify Caldera agent check-in
- Test Caldera automation scripts
- Screenshot Kibana dashboards showing endpoint telemetry

## Completed

_(none yet)_
