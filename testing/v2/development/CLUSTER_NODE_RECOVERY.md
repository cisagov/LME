# Cluster Node Failure Recovery (Docker Dev Environment)

This guide documents how to recover from a single Elasticsearch node failure in
the Docker-based development cluster. It covers automatic shard redistribution,
replacing the failed node, rejoining it to the cluster via Ansible, and verifying
that shards rebalance automatically.

> **Scope**: This procedure applies to **child nodes** (`node2` / `node3`) that run
> Elasticsearch only. Recovery of `node1` (the master node running Kibana, Fleet,
> and Wazuh) is a different procedure and is not covered here.

## Prerequisites

| Requirement | Details |
|---|---|
| Running Docker cluster | `docker compose -f docker-compose-cluster.yml up -d --build` |
| Completed initial install | `bash install_cluster.sh` ran to completion |
| Healthy baseline cluster | 3 nodes, status `green`, 0 unassigned shards |
| Same hostname replacement | The replacement reuses the same compose service name (`node2` or `node3`) |

Throughout this guide, **`node2`** is used as the example failed node.
Substitute `node3` / `lme_cluster_node3` / `es3` where appropriate.

## Step 1: Verify Baseline Cluster Health

Before simulating or responding to a failure, confirm the cluster is healthy:

```bash
docker exec lme_cluster_node1 bash -c '
  source /opt/lme/scripts/extract_secrets.sh -q
  echo "=== Cluster Health ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
  echo "=== Node Membership ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?v
  echo "=== Shard Distribution ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/shards?v
'
```

Expected: `status: green`, `number_of_nodes: 3`, and shards distributed across
all three nodes with no `UNASSIGNED` entries.

## Step 2: Simulate Node Failure

Stop and remove the container to simulate an unrecoverable node failure:

```bash
docker stop lme_cluster_node2
docker rm lme_cluster_node2
```

### What happens automatically

When a node leaves the cluster, Elasticsearch detects the departure and begins
**automatic shard redistribution**:

- Primary shards that were on the failed node are promoted from their replicas
  on surviving nodes.
- The cluster status changes to **`yellow`** because replica shards that were on
  the failed node no longer exist and cannot be reassigned until a new node
  joins.
- All data remains available — reads and writes continue against the surviving
  nodes.

Observe the degraded state:

```bash
docker exec lme_cluster_node1 bash -c '
  source /opt/lme/scripts/extract_secrets.sh -q
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?v
'
```

Expected: `number_of_nodes: 2`, `status: yellow`, `unassigned_shards > 0`.

## Step 3: Recreate the Container

Bring the replacement container up with the same hostname and network identity:

```bash
cd testing/v2/development
docker compose -f docker-compose-cluster.yml up -d --build --force-recreate node2
```

The new container starts with a fresh filesystem — SSH, Ansible artifacts, and
NFS mounts are all gone.

## Step 4: Reinstall SSH and Restore Trust

The replacement container needs an SSH server and the master's public key before
Ansible can reach it.

### 4a. Install and start SSH on the replacement node

```bash
docker exec lme_cluster_node2 bash -c '
  apt-get update && apt-get install -y openssh-server
  mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh
  chown lme-user:lme-user /home/lme-user/.ssh
  rm -f /run/nologin /var/run/nologin /etc/nologin
  service ssh start || /usr/sbin/sshd
'
```

### 4b. Copy the master's public key to the replacement node

```bash
PUBKEY=$(docker exec -u lme-user lme_cluster_node1 cat /home/lme-user/.ssh/id_rsa.pub)

docker exec lme_cluster_node2 bash -c "
  echo '$PUBKEY' > /home/lme-user/.ssh/authorized_keys
  chmod 600 /home/lme-user/.ssh/authorized_keys
  chown lme-user:lme-user /home/lme-user/.ssh/authorized_keys
"
```

### 4c. Update known_hosts on the master

The replacement container has new SSH host keys. Remove the stale entry and
rescan:

```bash
docker exec -u lme-user lme_cluster_node1 bash -c '
  ssh-keygen -R node2 2>/dev/null || true
  ssh-keyscan -H node2 >> ~/.ssh/known_hosts 2>/dev/null
'
```

### 4d. Verify SSH connectivity

```bash
docker exec -u lme-user lme_cluster_node1 bash -c \
  'ssh -o BatchMode=yes lme-user@node2 hostname'
```

Expected output: `node2`.

## Step 5: Run Ansible to Rejoin the Node

The `elasticsearch.yml` playbook deploys base packages, Nix, Podman, secrets,
certificates, and Elasticsearch to the target node. Use `--limit` to target
only the replacement:

```bash
docker exec -u lme-user lme_cluster_node1 bash -c '
  cd ~/LME
  ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
  ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
  ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml \
    --limit es2
'
```

This will:
- Install system prerequisites (base, nix, podman roles)
- Push vault password and encrypted secrets from the master (`secrets_distribution` role)
- Generate/distribute TLS certificates (`certs` role)
- Configure and start `lme-elasticsearch` with the correct cluster settings

### What happens automatically after rejoin

Once Elasticsearch starts on the replacement node and connects to the cluster:

1. The node announces itself using the same `es_node_name` (`es2`) and
   `es_publish_host` (`node2`) from the inventory.
2. The master node recognizes the returning node via `discovery.seed_hosts`.
3. Elasticsearch begins **automatic shard rebalancing** — replica shards that
   were unassigned are allocated to the new node, and the cluster rebalances
   primary/replica placement across all three nodes.
4. The cluster status transitions from `yellow` back to **`green`** once all
   shards are allocated.

## Step 6: Restore NFS Snapshot Mount

The NFS snapshot configuration is set up by `install_cluster.sh` outside of
Ansible, so it must be reapplied manually on the replacement node.

### 6a. Mount the NFS share

```bash
docker exec lme_cluster_node2 bash -c '
  mkdir -p /mnt/es-snapshots
  mount -t nfs nfs:/srv/es-snapshots /mnt/es-snapshots
'
```

Verify the mount:

```bash
docker exec lme_cluster_node2 bash -c 'mountpoint -q /mnt/es-snapshots && echo "NFS mounted" || echo "NFS NOT mounted"'
```

### 6b. Add the snapshot path to Elasticsearch config

```bash
docker exec lme_cluster_node2 bash -c "
  if ! grep -q '/usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml; then
    sed -i '/\/usr\/share\/elasticsearch\/backups/a\\    - /usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml
  fi
"
```

### 6c. Add the NFS volume to the ES container via Quadlet drop-in

```bash
docker exec lme_cluster_node2 bash -c "
  mkdir -p /etc/containers/systemd/lme-elasticsearch.container.d/
  cat > /etc/containers/systemd/lme-elasticsearch.container.d/nfs-mount.conf << 'EOF'
[Container]
Volume=/mnt/es-snapshots:/usr/share/elasticsearch/snapshots
EOF
  systemctl daemon-reload && systemctl restart lme-elasticsearch
"
```

## Step 7: Validate Recovery

### 7a. Cluster health and node membership

Wait a minute or two for shard rebalancing, then verify:

```bash
docker exec lme_cluster_node1 bash -c '
  source /opt/lme/scripts/extract_secrets.sh -q
  echo "=== Cluster Health ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
  echo "=== Node Membership ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?v
  echo "=== Shard Distribution ==="
  curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/shards?v
'
```

Expected:
- `status: green`
- `number_of_nodes: 3`
- `unassigned_shards: 0`
- Shards distributed across all three nodes

### 7b. Optional smoke tests

Run the existing test scripts to verify snapshot and password functionality
across all cluster nodes:

```bash
cd testing/v2/development
bash test_snapshot.sh
bash test_change_passwords.sh
```

## Caveats

### Master node recovery is different

`node1` hosts Kibana, Fleet, Wazuh, and is the Ansible control node that holds
the source certificates and vault files. Recovering `node1` requires restoring
from backup or rebuilding the full stack — it cannot be handled with the
`--limit` approach described here.

### New hostnames require additional changes

This procedure assumes the replacement reuses the same compose service name
(e.g., `node2` stays `node2`). If you need to add a node with a **different**
hostname:

1. Update `docker-compose-cluster.yml` with the new service definition
2. Update `ansible/inventory/cluster.yml` with the new host entry and
   `es_cluster_seed_hosts`
3. Force certificate regeneration so the new hostname/IP is included in the
   TLS SANs:
   ```bash
   ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml \
     -e lme_force_cert_regen=true
   ```

### NFS mounts are not persistent

The NFS mount in Step 6 does not survive a container restart. If the container
is restarted without being replaced, you will need to re-run the `mount`
command.

### Certificate and secret requirements

The `elasticsearch.yml` playbook handles certificate and secret distribution
automatically via the `certs` and `secrets_distribution` roles. The replacement
node receives:

- `/etc/lme/pass.sh` — vault password file
- `/etc/lme/vault/` — encrypted secret files
- TLS certificates from the master's `lme_certs` volume
- Podman shell driver configuration for secret access

No manual certificate or secret handling is needed when using the same hostname.

## Related Documentation

- [CLUSTER_INSTALL.md](CLUSTER_INSTALL.md) — Full cluster installation guide
- [converting_to_cluster.md](converting_to_cluster.md) — Single-node to cluster conversion
- [install_cluster.sh](install_cluster.sh) — Automated Docker cluster bootstrap script
- [Elasticsearch Cluster Formation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html) — Official cluster discovery docs
