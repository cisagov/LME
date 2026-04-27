# Detection Engineering — LME Role Validation Experiment

**Type:** Ludus cyber range experiment validating 5 `ludus_*` Ansible roles
**Range ID:** mreeve | **Range Number:** 1 | **VLAN:** 10
**Ludus Server:** 192.168.1.56:8080 (v2.0.15)

## File Structure

| File | Purpose |
|------|---------|
| `MASTER_PLAN.md` | Experiment plan, decisions, phases |
| `agents.md` | This file — session context and quick reference |
| `ludus-range-config.yml` | Ludus range config (4 VMs, 5 roles) |
| `README.md` | Quickstart and verification steps |
| `CREDENTIALS.md` | Credential layout (gitignored) |
| `Readme.md` | Parent detection engineering spec |

## VM Inventory

| VM | IP | Template | Roles |
|----|----|----------|-------|
| lme-server | 10.1.10.10 | ubuntu-24.04-x64-server | ludus_lme_server |
| caldera-srv | 10.1.10.20 | ubuntu-24.04-x64-server | ludus_caldera_server, ludus_caldera_scripts |
| WIN11-EP | 10.1.10.30 | win11-22h2-x64-enterprise | ludus_lme_agents, ludus_caldera_agent |
| ubuntu-ep | 10.1.10.40 | ubuntu-24.04-x64-desktop | ludus_lme_agents |

## Ludus API Commands

```bash
export LUDUS_API_KEY="mreeve.<key>"
export LUDUS_URL="https://192.168.1.56:8080"

# Check range status
curl -sk -H "X-API-KEY: $LUDUS_API_KEY" "$LUDUS_URL/api/v2/range"

# View deployment logs
curl -sk -H "X-API-KEY: $LUDUS_API_KEY" "$LUDUS_URL/api/v2/range/logs"

# Deploy range
curl -sk -X POST -H "X-API-KEY: $LUDUS_API_KEY" -H "Content-Type: application/json" -d '{}' "$LUDUS_URL/api/v2/range/deploy"

# Deploy only roles (skip VM creation)
curl -sk -X POST -H "X-API-KEY: $LUDUS_API_KEY" -H "Content-Type: application/json" -d '{"onlyRoles":true}' "$LUDUS_URL/api/v2/range/deploy"

# Template build status
curl -sk -H "X-API-KEY: $LUDUS_API_KEY" "$LUDUS_URL/api/v2/templates"
```

## Roles Under Test

All roles live in `ansible/roles/ludus_*` in this repository. They are uploaded to Ludus via TAR and referenced by name in the range config.

## Network Topology

All VMs on VLAN 10 (`10.1.10.0/24`). Router at `10.1.10.254`. No inter-VLAN rules needed.

## Verification Checklist

1. Elasticsearch reachable at `https://10.1.10.10:9200`
2. Kibana reachable at `https://10.1.10.10:5601`
3. Fleet shows 2 enrolled agents (WIN11-EP + ubuntu-ep)
4. Wazuh manager shows 2 registered agents
5. Caldera UI at `http://10.1.10.20:8888` shows 1 agent (WIN11-EP)
6. Caldera scripts can list abilities via API
