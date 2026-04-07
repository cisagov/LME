# Converting a Single-Node LME Installation to a Cluster

## Purpose

This document describes the process and considerations for converting an existing
single-node LME installation into a multi-node Elasticsearch cluster. In the cluster
topology, the original node becomes the **master** (running Elasticsearch, Kibana,
Fleet, and Wazuh) while additional nodes join as **data-only** Elasticsearch members.

> **Status**: Working document -- not yet validated end-to-end.

---

## Prerequisites

Before starting the conversion:

| Requirement | Details |
|---|---|
| Healthy single-node install | All 5 LME containers running, ES responding on port 9200 |
| Additional servers provisioned | One or more new hosts for Elasticsearch data nodes |
| SSH access | Passwordless SSH from master to every new node |
| Network connectivity | All nodes can reach each other on ports **9200** and **9300** |
| Firewall rules | Port 9300/tcp open between all cluster nodes (ES transport) |
| Sufficient disk | New nodes should have comparable disk space to master |
| LME repo cloned on master | The same branch/version used for the original install |
| Backup completed | Full backup of the current installation (see below) |

---

## Architecture Overview

```
BEFORE (single-node)             AFTER (cluster)
========================         ==========================================
 [Master Node]                    [Master Node]
  - Elasticsearch                  - Elasticsearch  <--- cluster --->  [Data Node 2]
  - Kibana                         - Kibana                             - Elasticsearch
  - Fleet Server                   - Fleet Server
  - Wazuh Manager                  - Wazuh Manager               <-->  [Data Node 3]
========================         ==========================================   - Elasticsearch
  discovery.type=single-node      discovery.seed_hosts=[node1,node2,node3]
  replicas=0                      replicas=1
  port 9200 only                  ports 9200 + 9300

  Note: Kibana, Fleet, and Wazuh remain on the master node.
        Only Elasticsearch is distributed across all nodes.
```

---

## Key Differences: Single-Node vs Cluster

| Aspect | Single-Node | Cluster |
|---|---|---|
| Discovery | `discovery.type=single-node` | `discovery.seed_hosts=<IPs>` |
| Replicas | 0 | 1+ |
| Transport port | Not exposed | 9300 published |
| Certificates | Only localhost/127.0.0.1 SANs | All node IPs in SANs |
| Secrets | Local only | Distributed to all nodes |
| Data volume | `lme_esdata01` | Master: `lme_esdata01`, data nodes: `lme_esdata_<node_name>` |
| Node name | `lme-elasticsearch` | Per-host from inventory |
| Quadlet file | Rendered with single-node vars | Rendered with cluster vars |

---

## Step-by-Step Procedure

### Phase 1: Pre-checks and Backup

1. **Verify current installation health** (run as sudo):
   ```bash
   sudo systemctl status lme
   sudo su
   source /opt/lme/scripts/extract_secrets.sh -q
   curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
   ```
   Confirm status is `green` and all containers are running.

2. **Record current state**:
   ```bash
   curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/indices?v
   ```
   Save the index list for later verification.

3. **Create a full backup**:
   ```bash
   cd /path/to/LME
   sudo ansible-playbook ansible/backup_lme.yml
   ```
   Or use the `backup_lme` role directly. This backs up volumes, config, secrets,
   and quadlet files.

### Phase 2: Prepare Cluster Inventory

4. **Run the inventory generator**:
   ```bash
   sudo bash scripts/create_cluster_inventory.sh
   ```
   This interactively creates `ansible/inventory/cluster.yml` with all node IPs,
   SSH users, and seed host configuration.

5. **Verify SSH connectivity**:
   ```bash
   # For each cluster node (replace with actual IPs/users):
   ssh ubuntu@10.0.0.5 'echo Connected'
   ssh ubuntu@10.0.0.6 'echo Connected'
   ```

### Phase 3: Convert Master Node

6. **Run the conversion playbook**:
   ```bash
   cd /path/to/LME 
   ./scripts/convert_to_cluster.sh --skip-inventory 
   ```
   This script:
   - Stops the LME service on the master
   - Re-renders the ES quadlet with cluster settings (seed hosts, publish host,
     transport port 9300, `cluster.initial_master_nodes`)
   - Forces certificate regeneration with all cluster node IPs as SANs
   - Restarts the master Elasticsearch in cluster mode
   - Deploys Elasticsearch to all data nodes (base, nix, podman, secrets, certs)
   - Waits for cluster formation
   - Updates existing index replica counts from 0 to 1
   - Verifies cluster health

### Phase 4: Verification

7. **Check cluster health** (run as sudo):
   ```bash
   sudo su
   source /opt/lme/scripts/extract_secrets.sh -q
   curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
   ```
   Expected: `status: green` (or `yellow` while replicas are being allocated),
   `number_of_nodes: 3` (or however many nodes you added).

8. **Verify node membership**:
   ```bash
   curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?v
   ```

9. **Verify shard allocation**:
   ```bash
   curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/shards?v
   ```
   Confirm shards are distributing across all nodes.

10. **Verify Kibana, Fleet, Wazuh**:
    - Access Kibana at `https://<master-ip>:5601`
    - Check Fleet server status
    - Confirm Wazuh manager is receiving events

---

## Rollback Plan

If the conversion fails or causes issues:

1. **Stop all services on all nodes**:
   ```bash
   # On master:
   sudo systemctl stop lme
   # On each cluster node:
   ssh user@nodeN 'sudo systemctl stop lme-elasticsearch'
   ```

2. **Restore the backup** created in Phase 1. The backup contains:
   - `/opt/lme/` config and environment files
   - `/etc/lme/` vault and password files
   - `/etc/containers/systemd/` quadlet files (including the original single-node
     ES quadlet)
   - All Podman volumes (ES data, certs, etc.)

3. **Restore the original quadlet file**:
   ```bash
   sudo cp /path/to/backup/etc_containers_systemd/lme-elasticsearch.container \
           /etc/containers/systemd/lme-elasticsearch.container
   sudo systemctl daemon-reload
   ```

4. **Restart LME in single-node mode**:
   ```bash
   sudo systemctl start lme
   ```

---

## Known Risks and Gotchas

### Certificate Regeneration

The `lme-setup-certs` container generates certificates only if they do not already
exist in the `lme_certs` volume. To force regeneration with updated SANs (including
cluster node IPs), the conversion playbook **clears the existing certificate data**
from the `lme_certs` volume before re-running the cert setup unit. This is safe
because all services are stopped during conversion and the new certs are distributed
to all nodes.

### Data Volume Naming

Single-node installs use `lme_esdata01` as the data volume name. The Elasticsearch
container template now ensures the master node (identified by
`ansible_connection=local`) **always** uses `lme_esdata01`, regardless of whether
`es_node_name` is set. Only remote data nodes use the `lme_esdata_<es_node_name>`
convention. This keeps the master volume name consistent across fresh single-node
installs, fresh cluster installs, and single-node-to-cluster conversions.

### Discovery Type Transition

Elasticsearch requires a full stop before changing from `discovery.type=single-node`
to cluster mode. The conversion playbook stops the LME service, reconfigures, and
restarts. The `cluster.initial_master_nodes` setting is only needed during the
initial cluster formation.

### Existing Index Replicas

All indices created during single-node operation have `number_of_replicas: 0`. After
cluster formation, the conversion playbook updates all existing indices to
`number_of_replicas: 1`. The cluster will be `yellow` until all replicas are
allocated, then turn `green`.

### Firewall / Network

Port **9300** must be open between all nodes for Elasticsearch transport-layer
communication. This is not needed in single-node mode and may require firewall
changes.

### `cluster.initial_master_nodes` Cleanup

The `cluster.initial_master_nodes` setting is only needed for initial cluster
bootstrap. After the cluster has formed, this setting is benign but could cause
issues if the cluster is fully restarted and the named nodes are not available.
Elasticsearch documentation recommends removing it after bootstrap, but LME leaves
it in place for simplicity since it only names the master node.

---

## Code Changes Checklist

- [x] New playbook: `ansible/convert_to_cluster.yml`
- [x] New wrapper script: `scripts/convert_to_cluster.sh`
- [x] Update `ansible/templates/lme-elasticsearch.container.j2` so the master
      node (`ansible_connection=local`) always uses `lme_esdata01`
- [x] Update `ansible/roles/certs/tasks/main.yml` to support force regeneration
      via `lme_force_cert_regen` variable
- [x] Update `ansible/upgrade_lme.yml` to detect cluster mode and warn users
- [ ] Documentation on the docs site (separate task)

---

## Testing Plan

1. **Fresh single-node install** on a test environment
2. Ingest some test data so there are indices with shards
3. Run the conversion playbook with 2 additional nodes
4. Verify:
   - Cluster health is green
   - All 3 nodes appear in `_cat/nodes`
   - Existing indices have replica shards on new nodes
   - Kibana is accessible and dashboards work
   - Fleet server is functional
   - Wazuh is receiving events
5. Test rollback procedure
6. Test upgrade path on the converted cluster (using `rolling_upgrade.yml`)
