# Attack Testing with LME + Caldera

Adversary simulation and detection validation using MITRE Caldera on Ludus ranges.

## Ansible Roles

Three roles work together to deploy a full red team infrastructure:

### `ludus_caldera_server`

Installs MITRE Caldera C2 server on a dedicated Ubuntu VM.

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_server_version` | `5.3.0` | Caldera release tag |
| `ludus_caldera_server_port` | `8888` | HTTP API/UI port |
| `ludus_caldera_server_insecure` | `true` | HTTP mode (no TLS) |

**What it does:**
- Installs Go 1.23.3 and Node.js v22 (via NVM)
- Clones Caldera from `github.com/mitre/caldera` with plugins (stockpile, sandcat, manx, atomic, etc.)
- Creates `caldera.service` systemd unit
- Extracts API key and exports `caldera_ip` as a localhost fact for downstream roles

**Caldera UI:** `http://<caldera-ip>:8888` (default creds: `admin:admin`, `red:admin`)

### `ludus_caldera_agent`

Deploys the Sandcat implant to Windows endpoints.

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_agent_server_ip` | Auto-resolved | Caldera server IP (from localhost facts) |
| `ludus_caldera_agent_path` | `C:\Users\Public\splunkd.exe` | Implant path on target |
| `ludus_caldera_agent_group` | `red` | Caldera agent group |
| `ludus_caldera_agent_reboot` | `true` | Reboot after install |

**What it does:**
- Downloads Sandcat binary from the Caldera server
- Deploys as `splunkd.exe` (blends with process listings)
- Registers agent with the Caldera C2 using the `red` API key
- Auto-resolves `caldera_ip` from `ludus_caldera_server` localhost facts via `depends_on`

### `ludus_caldera_scripts`

Deploys Python automation scripts for scripted attack operations.

| Variable | Default | Description |
|----------|---------|-------------|
| `ludus_caldera_scripts_api_key` | Auto-extracted | Caldera API key |
| `ludus_caldera_scripts_deploy_dir` | `/opt/caldera-scripts` | Script install directory |

**What it does:**
- Copies `run_config.py`, `operation.py`, `get_abilities.py` to the Caldera server
- Ships pre-built operation configs: `demo_config.json`, `01_discovery.json`
- Exports API key via a shell source script for easy CLI usage

**Scripts:**
- `run_config.py` — Execute a Caldera operation from a JSON config file
- `operation.py` — Create/manage operations programmatically
- `get_abilities.py` — List available Caldera abilities (ATT&CK techniques)

## Range Configs

### Caldera Demo Range (`ansible/ranges/lme-caldera-demo.yml`)

Full detection engineering setup:

```
Caldera Server (8 GB, 2 CPU)  ← C2 + scripting
LME Server (32 GB, 4 CPU)     ← telemetry collection
Win11 Workstation 1            ← Sandcat agent + LME agents
Win11 Workstation 2            ← Sandcat agent + LME agents
```

No hardcoded credentials — `ludus_caldera_agent` auto-resolves from `ludus_caldera_server`,
`ludus_lme_agents` auto-resolves from `ludus_lme_server`.

Deploy:
```bash
ludus range config set -f ansible/ranges/lme-caldera-demo.yml
ludus range deploy
```

### Minimal Range (`ansible/ranges/lme-minimal.yml`)

Single LME server with self-enrolled agents. No Caldera — for install validation only.

## Executing Attacks

### Manual (Caldera UI)

1. Open `http://<caldera-ip>:8888`
2. Navigate to **Agents** — verify Sandcat agents have checked in
3. Navigate to **Operations** → **Create Operation**
4. Select adversary profile (e.g., `Discovery` or `Collection`)
5. Select agent group (`red`)
6. Start operation — watch results in real-time

### Scripted (caldera-scripts)

SSH to the Caldera server:

```bash
# Source the API key
source /opt/caldera-scripts/caldera_env.sh

# List available abilities
python3 /opt/caldera-scripts/get_abilities.py

# Run a pre-built operation
python3 /opt/caldera-scripts/run_config.py /opt/caldera-scripts/01_discovery.json

# Run custom operation
python3 /opt/caldera-scripts/operation.py --name "my-attack" --adversary "discovery" --group "red"
```

### Kubernetes Attack Chain (Advanced)

For K3s + Kubernetes Goat adversary simulation, deploy K3s on the Ubuntu endpoint
and use kubectl-based attacks:

**MITRE ATT&CK chain:**

| Step | Technique | What |
|------|-----------|------|
| 1 | T1613 | `kubectl get pods,svc,ns` — container discovery |
| 2 | T1552.001 | Read `~/.kube/config` — credential theft |
| 3 | T1610 | `kubectl exec` into pods — container execution |
| 4 | T1078.004 | `kubectl auth can-i --list` — RBAC enumeration |
| 5 | T1005 | `kubectl get configmaps` — data collection |

**Detection gaps identified:**
- K8s-specific attacks are NOT visible without audit log forwarding to LME
- `kubectl` invocations visible only via process telemetry (Wazuh/Elastic Agent)
- No FIM coverage on kubeconfig file reads
- Container-internal activity invisible without sidecar or runtime security

### Real-World Techniques (from SCARLETEEL 2.0 research)

These techniques were identified in active campaigns targeting containerized environments:

| Technique | Description | Tools |
|-----------|-------------|-------|
| T1190 | Exploit exposed JupyterLab/React apps | Direct exploitation |
| T1552.001/005 | Harvest AWS creds from IMDS, filesystem, containers | Shell builtins, curl |
| T1613/T1609 | K8s API abuse, container exec | peirates |
| T1078/T1548 | IAM privilege escalation (case-sensitive bypass) | AWS CLI, Pacu |
| T1496 | Crypto mining (XMRig as `containerd`) | XMRig, C3Pool |
| T1543.002 | Systemd persistence for miners | systemd unit files |
| T1070 | Anti-forensics: iptables flush, log deletion | Custom `notraces()` script |

**Key stat:** 282% year-over-year increase in Kubernetes token theft.

## Validating Detections in LME

After executing attacks, check LME for detection evidence:

```bash
# Check security alerts in Kibana
curl -sk -u elastic:<password> https://<lme-ip>:9200/.alerts-security.alerts-*/_count

# Check for specific MITRE technique alerts
curl -sk -u elastic:<password> https://<lme-ip>:9200/.alerts-security.alerts-*/_search \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"signal.rule.threat.technique.id":"T1613"}}}'

# Check process creation logs for kubectl/sandcat
curl -sk -u elastic:<password> https://<lme-ip>:9200/logs-*/_search \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"process.name":"kubectl"}}}'
```

The notebook's TS-04 (Sigma rules) and TS-11 (Caldera integration) validate that
detections are firing. TS-12 (RAG chat) can be used to ask the LLM about
detected attack patterns.
