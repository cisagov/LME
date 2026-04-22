# MASTER_PLAN.md — LME Ludus Integration & Ansible Galaxy Roles

**Branch:** `mreeve-det-eng`
**Created:** 2026-03-31
**Status:** Planning

---

## Vision

Unify the fragmented ansible automation across three codebases (`connor-ludus`, `LME-VIBE/lme-ludus-integration`, and `LME/ansible`) into a single, coherent set of Ludus-compatible, Galaxy-publishable Ansible roles inside the LME repository. This enables deploying the full LME + Caldera detection engineering stack via a single Ludus range config.

## Problem Statement

Today, three separate codebases contain overlapping ansible roles for deploying LME and Caldera in Ludus:

| Codebase | Roles | Quality | Issues |
|----------|-------|---------|--------|
| `connor-ludus` | 8 functional roles (caldera_lme, install_lme, install_agent_windows, caldera_agent, extract_*_secrets, windows_setup, install_caldera_scripts) | Working but ad-hoc | No Galaxy metadata, hardcoded values, separate extract roles instead of API discovery, not idempotent, no Ludus template compliance |
| `LME-VIBE/lme-ludus-integration` | 2 roles (lme-server, agents) | Well-structured, clean conventions | Missing Caldera entirely, `ludus_` variable prefix not used, no `download_file.yml` caching, no Galaxy release workflow |
| `LME/ansible` | 10 core install roles (base, nix, podman, elasticsearch, kibana, dashboards, wazuh, fleet, backup_lme, cleanup) | Production-quality, well-tested | These are internal LME roles — NOT ludus-facing. Must not be modified. |

**Result:** No single repo can deploy the full LME + Caldera + Agents stack via Ludus out of the box.

## Constraints

1. **DO NOT MODIFY** existing LME ansible roles (`base`, `nix`, `podman`, `elasticsearch`, `kibana`, `dashboards`, `wazuh`, `fleet`, `backup_lme`, `cleanup`) or existing playbooks (`site.yml`, `backup_lme.yml`, `upgrade_lme.yml`, `rollback_lme.yml`). These are production-tested.
2. **DO NOT MODIFY** the existing `requirements.yml` collections (extend only if needed).
3. All new roles MUST comply with the [Ludus Ansible Role Template](https://github.com/badsectorlabs/ludus_ansible_role_template).
4. All new roles MUST be publishable to Ansible Galaxy.
5. New roles use the `ludus_` variable prefix convention per Ludus standards.
6. Range configs must work with `ludus range config` and `ludus ansible role add`.
7. Use `lme-ludus-integration` conventions as the reference standard (API-driven discovery, platform-conditional blocks, @decision annotations, idempotent checks).

## Sacred Boundary

The existing LME core roles are the **internal** installation mechanism. The new Ludus roles are **external** wrappers that:
- `ludus_lme_server` wraps `install.sh` (does NOT call the internal ansible roles directly)
- `ludus_lme_agents` installs agents on endpoints (uses API discovery from the running LME stack)
- Caldera roles are entirely new functionality

The two layers are independent. The internal roles are invoked by `site.yml` for standalone installs. The Ludus roles are invoked by Ludus range configs for lab deployments.

---

## Target Architecture

### New Roles (5)

```
~/LME/ansible/roles/
├── base/                      # EXISTING — DO NOT TOUCH
├── nix/                       # EXISTING — DO NOT TOUCH
├── podman/                    # EXISTING — DO NOT TOUCH
├── elasticsearch/             # EXISTING — DO NOT TOUCH
├── kibana/                    # EXISTING — DO NOT TOUCH
├── dashboards/                # EXISTING — DO NOT TOUCH
├── wazuh/                     # EXISTING — DO NOT TOUCH
├── fleet/                     # EXISTING — DO NOT TOUCH
├── backup_lme/                # EXISTING — DO NOT TOUCH
├── cleanup/                   # EXISTING — DO NOT TOUCH
│
├── ludus_lme_server/          # NEW — Ludus role: deploy LME server
│   ├── meta/main.yml          # Galaxy metadata
│   ├── defaults/main.yml      # ludus_lme_server_* variables
│   ├── tasks/
│   │   ├── main.yml           # Orchestration
│   │   └── download_file.yml  # Ludus caching downloader (from template)
│   └── README.md
│
├── ludus_lme_agents/          # NEW — Ludus role: deploy Elastic+Wazuh agents
│   ├── meta/main.yml
│   ├── defaults/main.yml      # ludus_lme_agents_* variables
│   ├── tasks/
│   │   ├── main.yml           # Installs both by default
│   │   ├── elastic.yml        # Elastic Agent (Linux + Windows)
│   │   ├── wazuh.yml          # Wazuh Agent (Linux + Windows)
│   │   └── download_file.yml
│   ├── files/                 # Sysmon configs, audit rules (optional cache)
│   └── README.md
│
├── ludus_caldera_server/      # NEW — Ludus role: deploy MITRE Caldera
│   ├── meta/main.yml
│   ├── defaults/main.yml      # ludus_caldera_server_* variables
│   ├── tasks/
│   │   ├── main.yml           # Orchestration
│   │   ├── dependencies.yml   # System packages
│   │   ├── go.yml             # Go installation
│   │   ├── node.yml           # Node/NVM installation
│   │   ├── caldera.yml        # Caldera clone, install, service
│   │   └── download_file.yml
│   ├── templates/
│   │   └── caldera.service.j2 # Systemd unit template
│   └── README.md
│
├── ludus_caldera_agent/       # NEW — Ludus role: deploy Caldera agent on endpoints
│   ├── meta/main.yml
│   ├── defaults/main.yml      # ludus_caldera_agent_* variables
│   ├── tasks/
│   │   ├── main.yml           # Orchestration (auto-discovers Caldera IP/creds)
│   │   ├── windows.yml        # Windows agent install
│   │   ├── linux.yml          # Linux agent install (future)
│   │   └── download_file.yml
│   ├── templates/
│   │   └── run_caldera.ps1.j2 # Caldera startup script
│   └── README.md
│
└── ludus_caldera_scripts/     # NEW — Ludus role: deploy Caldera automation tools
    ├── meta/main.yml
    ├── defaults/main.yml      # ludus_caldera_scripts_* variables
    ├── tasks/
    │   ├── main.yml
    │   └── download_file.yml
    ├── files/
    │   └── caldera-scripting/  # Python scripts + configs from connor-ludus
    │       ├── run_config.py
    │       ├── operation.py
    │       ├── get_abilities.py
    │       └── configs/
    │           ├── demo_config.json
    │           └── 01_discovery.json
    └── README.md
```

### Example Range Config

```
~/LME/ansible/ranges/
└── lme-caldera-demo.yml       # Reference range config for full stack
```

### Galaxy Release Workflow

```
~/LME/.github/workflows/
└── ludus-roles-release.yml    # Publishes each role to Galaxy on tag push
```

---

## Role Specifications

### Role 1: `ludus_lme_server`

**Source:** `LME-VIBE/lme-ludus-integration/ansible/roles/lme-server` (primary), `connor-ludus/roles/install_lme` (reference)

**What it does:**
1. Install prerequisites (git, python3, python3-pip)
2. Clone the LME repo at a pinned version tag
3. Run `install.sh` with `NON_INTERACTIVE=true`, `AUTO_CREATE_ENV=true`
4. Extract and expose credentials as ansible facts (elastic_password, fleet enrollment token) for downstream roles

**Key difference from connor-ludus `install_lme`:** Uses lme-ludus-integration's thin-wrapper approach (DEC-LME-SERVER-001). Does NOT hardcode `ELASTIC_PASSWORD=password1`. Adds API-based credential extraction (replacing `extract_lme_secrets` as a separate role).

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_lme_server_ip` | `""` (auto-detect) | LME server IP address |
| `ludus_lme_server_version` | `"2.2.0"` | LME version tag |
| `ludus_lme_server_offline` | `false` | Air-gapped mode |
| `ludus_lme_server_memory_limit` | `2073741824` | ES JVM heap (bytes) |
| `ludus_lme_server_repo_url` | `"https://github.com/cisagov/LME.git"` | Git repo URL |
| `ludus_lme_server_install_dir` | `"/opt/lme-install"` | Clone destination |

**Absorbs:** `connor-ludus/roles/extract_lme_secrets` — credential extraction becomes a task within this role that sets facts on localhost, eliminating the need for a separate role.

---

### Role 2: `ludus_lme_agents`

**Source:** `LME-VIBE/lme-ludus-integration/ansible/roles/agents` (primary), `connor-ludus/roles/install_agent_windows` (reference for Sysmon/Wazuh details)

**What it does:**
1. Auto-discover Elastic version and Fleet enrollment token via API (when `ludus_lme_agents_elastic_password` provided)
2. Install Elastic Agent on Linux and Windows
3. Install Sysmon on Windows (SwiftOnSecurity config)
4. Install auditd rules on Linux (Neo23x0)
5. Install Wazuh Agent on Linux and Windows
6. Poll Wazuh manager until agent reports Active

**Key improvements over connor-ludus `install_agent_windows`:**
- API-driven version/token discovery (no separate extract role needed)
- Cross-platform (Linux + Windows, not Windows-only)
- Idempotent (checks if services already running)
- `tasks_from: elastic` or `tasks_from: wazuh` for selective installation

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_lme_agents_server_ip` | `""` | LME server IP (required) |
| `ludus_lme_agents_elastic_password` | `""` | Elastic password (enables API discovery) |
| `ludus_lme_agents_enrollment_token` | `""` | Fleet enrollment token (auto-fetched if password set) |
| `ludus_lme_agents_elastic_user` | `"elastic"` | ES API user |
| `ludus_lme_agents_fleet_port` | `8220` | Fleet server port |
| `ludus_lme_agents_kibana_port` | `5601` | Kibana port |
| `ludus_lme_agents_es_port` | `9200` | Elasticsearch port |
| `ludus_lme_agents_agent_arch` | `"x86_64"` | Agent architecture |
| `ludus_lme_agents_wazuh_manager_ip` | `"{{ ludus_lme_agents_server_ip }}"` | Wazuh manager IP |
| `ludus_lme_agents_wazuh_retries` | `30` | Wazuh registration retries |
| `ludus_lme_agents_wazuh_delay` | `10` | Seconds between retries |
| `ludus_lme_agents_sysmon_url` | Sysinternals URL | Sysmon download URL |
| `ludus_lme_agents_sysmon_config_url` | SwiftOnSecurity URL | Sysmon config URL |
| `ludus_lme_agents_audit_rules_url` | Neo23x0 URL | Linux audit rules URL |

---

### Role 3: `ludus_caldera_server`

**Source:** `connor-ludus/roles/caldera_lme` (primary)

**What it does:**
1. Install system dependencies (git, curl, wget, python3, python3-venv, python3-pip, lsof, pipenv)
2. Install Go (configurable version)
3. Install Node via NVM (configurable version)
4. Clone MITRE Caldera at pinned version
5. Configure agent sleep intervals
6. Install Python dependencies via pipenv
7. Create and start systemd service
8. Extract and expose Caldera IP + API keys as ansible facts for downstream roles

**Key improvements over connor-ludus `caldera_lme`:**
- Ludus `download_file.yml` caching for Go/Node/UPX binaries
- Idempotent checks (skip if Caldera service already running)
- Templatized systemd service (not inline string)
- Variable-driven configuration (no hardcoded versions)
- Absorbs `extract_caldera_secrets` — credentials extracted as facts within this role

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_server_version` | `"5.3.0"` | Caldera git branch/tag |
| `ludus_caldera_server_go_version` | `"1.23.3"` | Go version |
| `ludus_caldera_server_node_version` | `"22"` | Node.js major version |
| `ludus_caldera_server_nvm_version` | `"0.40.1"` | NVM version |
| `ludus_caldera_server_upx_version` | `"4.2.4"` | UPX version |
| `ludus_caldera_server_install_dir` | `"/opt/caldera"` | Install directory |
| `ludus_caldera_server_port` | `8888` | Caldera HTTP port |
| `ludus_caldera_server_sleep_min` | `2` | Agent min sleep (seconds) |
| `ludus_caldera_server_sleep_max` | `5` | Agent max sleep (seconds) |
| `ludus_caldera_server_insecure` | `true` | Run in insecure mode |

**Absorbs:** `connor-ludus/roles/extract_caldera_secrets` — IP and credential extraction becomes a task within this role.

---

### Role 4: `ludus_caldera_agent`

**Source:** `connor-ludus/roles/caldera_agent` (primary)

**What it does:**
1. Auto-discover Caldera server IP from ansible facts (set by `ludus_caldera_server`)
2. Configure Defender exclusions (Windows)
3. Configure firewall rules (Windows)
4. Download Caldera sandcat agent from server
5. Create persistent startup script
6. Register via Windows Registry Run key
7. Reboot to start agent

**Key improvements over connor-ludus `caldera_agent`:**
- Variable-driven (agent path, group, server URL all configurable)
- Auto-discovers Caldera IP from facts (no separate extract role)
- Idempotent (skip if agent already exists)
- Templatized PowerShell scripts

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_agent_server_ip` | `""` | Caldera server IP (required) |
| `ludus_caldera_agent_server_port` | `8888` | Caldera HTTP port |
| `ludus_caldera_agent_path` | `"C:\\Users\\Public\\splunkd.exe"` | Agent binary path |
| `ludus_caldera_agent_group` | `"red"` | Agent group name |
| `ludus_caldera_agent_script_dir` | `"C:\\ludus"` | Startup script directory |
| `ludus_caldera_agent_reboot` | `true` | Reboot after install |

---

### Role 5: `ludus_caldera_scripts`

**Source:** `connor-ludus/roles/install_caldera_scripts` (primary)

**What it does:**
1. Extract Caldera API key from config (or receive via variable)
2. Create API key export script
3. Deploy Python automation scripts (run_config.py, operation.py, get_abilities.py)
4. Deploy operation config files (demo_config.json, 01_discovery.json)

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_scripts_server_ip` | `""` | Caldera server IP |
| `ludus_caldera_scripts_install_dir` | `"/opt/caldera"` | Caldera install dir (for API key extraction) |
| `ludus_caldera_scripts_deploy_dir` | `"/opt/caldera-scripts"` | Where scripts are deployed |
| `ludus_caldera_scripts_api_key` | `""` | API key (auto-extracted if empty) |

---

### Eliminated Roles (folded into the above)

| connor-ludus Role | Merged Into | Rationale |
|-------------------|-------------|-----------|
| `extract_lme_secrets` | `ludus_lme_server` | Credential extraction is a natural post-install step, not a separate role. API-based discovery in `ludus_lme_agents` handles the consumer side. |
| `extract_caldera_secrets` | `ludus_caldera_server` | Same pattern — extract creds at install time, expose as facts. |
| `windows_setup` | Dropped / optional task in `ludus_caldera_agent` | Writing a credentials file to the desktop is a convenience, not a deployment concern. Can be an optional task triggered by a variable. |
| `test_no_meta` | Dropped | Test scaffolding, not a real role. |
| `ludus_ansible_role_template` | N/A | Reference only, not deployed. |

---

## Example Range Config

This is the reference range config that replaces `connor-ludus/ranges/ubuntu-caldera-demo.yml`:

```yaml
# ~/LME/ansible/ranges/lme-caldera-demo.yml
# yaml-language-server: $schema=https://docs.ludus.cloud/schemas/range-config.json

ludus:
  - vm_name: "{{ range_id }}-caldera-server"
    hostname: "{{ range_id }}-caldera"
    template: ubuntu-24.04-x64-server-template
    vlan: 10
    ip_last_octet: 21
    ram_gb: 8
    cpus: 2
    linux: true
    roles:
      - ludus_caldera_server
      - name: ludus_caldera_scripts
        depends_on:
          - vm_name: "{{ range_id }}-caldera-server"
            role: ludus_caldera_server

  - vm_name: "{{ range_id }}-lme-server"
    hostname: "{{ range_id }}-lme"
    template: ubuntu-24.04-x64-server-template
    vlan: 10
    ip_last_octet: 22
    ram_gb: 32
    cpus: 4
    linux: true
    roles:
      - ludus_lme_server
    role_vars:
      ludus_lme_server_version: "2.2.0"

  - vm_name: "{{ range_id }}-win11-workstation"
    hostname: "{{ range_id }}-win11-ws"
    template: win11-22h2-x64-enterprise-template
    vlan: 10
    ip_last_octet: 23
    ram_gb: 8
    cpus: 2
    windows:
      sysprep: false
    roles:
      - name: ludus_lme_agents
        depends_on:
          - vm_name: "{{ range_id }}-lme-server"
            role: ludus_lme_server
      - name: ludus_caldera_agent
        depends_on:
          - vm_name: "{{ range_id }}-caldera-server"
            role: ludus_caldera_server
    role_vars:
      ludus_lme_agents_server_ip: "10.{{ range_second_octet }}.10.22"
      ludus_caldera_agent_server_ip: "10.{{ range_second_octet }}.10.21"

  - vm_name: "{{ range_id }}-win11-workstation-2"
    hostname: "{{ range_id }}-win11-ws2"
    template: win11-22h2-x64-enterprise-template
    vlan: 10
    ip_last_octet: 24
    ram_gb: 8
    cpus: 2
    windows:
      sysprep: false
    roles:
      - name: ludus_lme_agents
        depends_on:
          - vm_name: "{{ range_id }}-lme-server"
            role: ludus_lme_server
      - name: ludus_caldera_agent
        depends_on:
          - vm_name: "{{ range_id }}-caldera-server"
            role: ludus_caldera_server
    role_vars:
      ludus_lme_agents_server_ip: "10.{{ range_second_octet }}.10.22"
      ludus_caldera_agent_server_ip: "10.{{ range_second_octet }}.10.21"
```

**Key improvements over `connor-ludus/ranges/ubuntu-caldera-demo.yml`:**
- No separate extract_*_secrets roles — credentials flow via ansible facts automatically
- No windows_setup role — credentials available via Ludus itself
- `role_vars` pass configuration, not hardcoded in roles
- Uses `range_second_octet` Ludus template variable for VLAN addressing
- `depends_on` ensures correct deployment order without manual orchestration

---

## Ludus Template Compliance Checklist

Each new role MUST satisfy:

- [ ] `meta/main.yml` with `galaxy_info` block:
  - `role_name: ludus_<name>`
  - `namespace: cisagov`
  - `author: cisagov`
  - `license: "GPLv3"`
  - `min_ansible_version: "2.10"`
  - `platforms` list covering target OS versions
  - `galaxy_tags` for discoverability
- [ ] `defaults/main.yml` with all variables using `ludus_<role>_` prefix
- [ ] `tasks/main.yml` as entrypoint
- [ ] `tasks/download_file.yml` — Ludus caching downloader (verbatim from template)
- [ ] `README.md` with:
  - Requirements section
  - Role Variables table
  - "Example Ludus Range Config" section with `roles:` and `role_vars:` usage
  - Dependencies section
  - License and Author
- [ ] Every task named descriptively
- [ ] Idempotent: check if service/binary exists before installing
- [ ] Platform-conditional blocks (`when: ansible_system == 'Linux'` / `ansible_os_family == 'Windows'`)
- [ ] `@decision` annotations on significant design choices
- [ ] No hardcoded IPs, passwords, or versions — all in `defaults/main.yml`

---

## Implementation Phases

### Phase 1: Foundation & ludus_lme_server
**Scope:** Create role structure, implement `ludus_lme_server` with credential extraction.
**Files:** ~8 new files
**Source:** Merge `lme-ludus-integration/lme-server` + `connor-ludus/install_lme` + `connor-ludus/extract_lme_secrets`
**Acceptance:**
- Role installs LME via install.sh
- Elastic password and LME IP exposed as ansible facts
- Passes `ansible-lint`
- Galaxy metadata valid (`ansible-galaxy role info` works)

### Phase 2: ludus_lme_agents
**Scope:** Cross-platform agent deployment with API discovery.
**Files:** ~10 new files
**Source:** Merge `lme-ludus-integration/agents` + `connor-ludus/install_agent_windows`
**Acceptance:**
- Elastic Agent installs on Linux and Windows
- Wazuh Agent installs on Linux and Windows
- Sysmon installs on Windows, auditd rules on Linux
- API-based version/token discovery works
- `tasks_from: elastic` and `tasks_from: wazuh` work for selective install

### Phase 3: ludus_caldera_server
**Scope:** Caldera server deployment with credential extraction.
**Files:** ~12 new files
**Source:** Refactor `connor-ludus/caldera_lme` + `connor-ludus/extract_caldera_secrets`
**Acceptance:**
- Caldera 5.3.0 installs and starts as systemd service
- Go, Node, Python deps install cleanly
- Caldera IP and API key exposed as ansible facts
- Idempotent (re-run doesn't break)

### Phase 4: ludus_caldera_agent
**Scope:** Caldera agent deployment on Windows endpoints.
**Files:** ~8 new files
**Source:** Refactor `connor-ludus/caldera_agent`
**Acceptance:**
- Agent downloads from Caldera server
- Defender exclusions and firewall rules created
- Persistent via Registry Run key
- Connects to Caldera server in configured group

### Phase 5: ludus_caldera_scripts
**Scope:** Deploy Caldera automation tools.
**Files:** ~10 new files
**Source:** Refactor `connor-ludus/install_caldera_scripts`
**Acceptance:**
- Python scripts deployed to target directory
- API key extracted and exported
- Config files deployed

### Phase 6: Integration & Range Config
**Scope:** Create reference range config, update requirements.yml, Galaxy release workflow.
**Files:** ~3 new files
**Source:** New, based on `connor-ludus/ranges/ubuntu-caldera-demo.yml`
**Acceptance:**
- Range config validates against Ludus schema
- All role dependencies resolve correctly
- `ansible-galaxy install` works for any published role
- Full stack deploys end-to-end in a Ludus range

---

## Data Flow Architecture

```
                    ┌─────────────────────┐
                    │   Ludus Range Config │
                    │  lme-caldera-demo.yml│
                    └─────────┬───────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              v               v               v
    ┌─────────────────┐ ┌────────────┐ ┌──────────────────┐
    │ludus_caldera_   │ │ludus_lme_  │ │ Windows Endpoints │
    │server           │ │server      │ │                   │
    │                 │ │            │ │ ludus_lme_agents   │
    │ Installs Caldera│ │ Wraps      │ │ ludus_caldera_    │
    │ Extracts:       │ │ install.sh │ │ agent             │
    │  - caldera_ip   │ │ Extracts:  │ │                   │
    │  - api_key_red  │ │  - lme_ip  │ │ Reads facts from  │
    │  - passwords    │ │  - elastic │ │ localhost set by   │
    │                 │ │    _password│ │ server roles       │
    │ Sets facts on   │ │            │ │                   │
    │ localhost ──────┼─┼─> facts ───┼─┼──> consumed here  │
    └─────────────────┘ └────────────┘ └──────────────────────┘
              │
              v
    ┌─────────────────┐
    │ludus_caldera_   │
    │scripts          │
    │                 │
    │ Deploys Python  │
    │ automation tools│
    └─────────────────┘
```

**Fact delegation pattern** (replaces separate extract_* roles):
```yaml
# In ludus_lme_server/tasks/main.yml (post-install step):
- name: Extract elastic password from LME
  ansible.builtin.shell: |
    ~/lme/scripts/extract_secrets.sh -p
  register: lme_secrets_raw

- name: Set LME facts on localhost for downstream roles
  ansible.builtin.set_fact:
    lme_ip: "{{ ansible_default_ipv4.address }}"
    elastic_password: "{{ parsed_password }}"
  delegate_to: localhost
  delegate_facts: true
```

---

## Compatibility Matrix

| Role | Ubuntu 22.04 | Ubuntu 24.04 | Debian 12 | Windows 11 | Windows Server 2022 |
|------|:---:|:---:|:---:|:---:|:---:|
| ludus_lme_server | Y | Y | Y | - | - |
| ludus_lme_agents | Y | Y | Y | Y | Y |
| ludus_caldera_server | Y | Y | Y | - | - |
| ludus_caldera_agent | - | - | - | Y | Y |
| ludus_caldera_scripts | Y | Y | Y | - | - |

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| LME install.sh changes break ludus_lme_server | High | Pin to `lme_version` tag; test on LME releases |
| Caldera 5.x deprecates APIs used by scripts | Medium | Pin Caldera version; monitor upstream releases |
| Galaxy namespace conflict (cisagov) | Medium | Verify namespace availability before publishing; could use `lme` namespace |
| Fact delegation between VMs fails in Ludus | High | Test with real Ludus deployment; fallback to `role_vars` for credentials |
| Defender blocks Caldera agent on newer Windows | Medium | Document required exclusions; make exclusion paths configurable |

---

## Non-Goals (Explicitly Out of Scope)

1. Modifying existing LME core roles or playbooks
2. Linux Caldera agent support (future Phase 7 if needed)
3. Active Directory integration
4. Multi-node Elasticsearch clustering
5. Automated Caldera operation execution (scripts are deployed, not executed)
6. CI/CD pipeline for role testing (tracked separately in detection-engineering spec)

---

## Completed

(Nothing yet — plan just created.)
