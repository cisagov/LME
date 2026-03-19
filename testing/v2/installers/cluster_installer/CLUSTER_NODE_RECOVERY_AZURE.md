# Cluster Node Failure Recovery (Azure)

This guide walks through recovering from a single Elasticsearch node failure in
an Azure-based LME cluster by replacing the failed node with a brand-new server.

The scenario:

1. Build a **3-node cluster** plus one spare VM that is not part of the cluster.
2. **Fail node 3** (es3 / `ubuntu-3`) by deallocating it.
3. **Replace it with node 4** (`ubuntu-4`) — a fresh VM that has never been in
   the cluster. This requires updating the Ansible inventory and Elasticsearch
   discovery configuration on all surviving nodes, then running Ansible on the
   new node to join it to the cluster.

> **Scope**: This procedure applies to **child nodes** (es2, es3) that run
> Elasticsearch only. Recovery of the master node (es1, running Kibana, Fleet,
> and Wazuh) requires restoring from backup or rebuilding the full stack and is
> not covered here.

## Prerequisites

| Requirement | Details |
|---|---|
| Azure CLI | Authenticated (`az login`) |
| Local tools | `jq`, `sshpass` installed (`sudo apt-get install -y jq sshpass`) |
| exporter.txt | Configured in `testing/v2/installers/exporter.txt` (see README.md) |

---

## Step 1: Set Up Environment Variables

All commands in this guide are run from your local machine:

```bash
cd testing/v2/installers
source exporter.txt
```

## Step 2: Build a 3-Node Cluster

Make sure `CLUSTER_SIZE=3` in `exporter.txt`:

```bash
grep -q '^export CLUSTER_SIZE=' exporter.txt && \
  sed -i 's/^export CLUSTER_SIZE=.*/export CLUSTER_SIZE=3/' exporter.txt || \
  echo 'export CLUSTER_SIZE=3' >> exporter.txt

source exporter.txt
```

Run the cluster setup:

```bash
cd cluster_installer
./setup_cluster.sh
```

All remaining commands in this guide are run from the `cluster_installer/`
directory.

`setup_cluster.sh` also copies `${RESOURCE_GROUP}.password.txt` and
`${RESOURCE_GROUP}.machines.json` into `output/`. Read and edit those copies
here so they stay the single source of truth (the originals under
`testing/v2/installers/` are not updated when you change the files locally).

Set variables for subsequent steps:

```bash
export PASSWORD=$(cat "output/${RESOURCE_GROUP}.password.txt")
export MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "output/${RESOURCE_GROUP}.machines.json")
export MASTER_PRIVATE_IP=$(jq -r '.linux_vms[0].private_ip' "output/${RESOURCE_GROUP}.machines.json")
echo "Master: $MASTER_IP (private: $MASTER_PRIVATE_IP)"
```

## Step 3: Create a 4th VM (Spare Node)

Create a 4th VM in the same resource group and virtual network. This VM will
not be part of the cluster yet — it is the spare that will replace the failed
node later.

```bash
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ubuntu-4" \
  --image "Canonical:ubuntu-24_04-lts:server:latest" \
  --size "${VM_SIZE:-Standard_E2d_v4}" \
  --admin-username "$LME_USER" \
  --admin-password "$PASSWORD" \
  --vnet-name "VNet1" \
  --subnet "SNet1" \
  --private-ip-address "10.1.0.12" \
  --nsg "NSG1" \
  --public-ip-sku Standard \
  --os-disk-size-gb 128 \
  --output json
```

Get the public IP of the new VM and save it:

```bash
NODE4_PUBLIC_IP=$(az vm list-ip-addresses \
  --resource-group "$RESOURCE_GROUP" \
  --name "ubuntu-4" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
NODE4_PRIVATE_IP="10.1.0.12"
echo "Node 4: $NODE4_PUBLIC_IP (private: $NODE4_PRIVATE_IP)"
```

Add the new VM to `output/${RESOURCE_GROUP}.machines.json`:

```bash
jq --arg pub "$NODE4_PUBLIC_IP" --arg priv "$NODE4_PRIVATE_IP" \
  --arg user "$LME_USER" --arg pw "$PASSWORD" \
  '.linux_vms += [{"vm_name":"ubuntu-4","ip_address":$pub,"private_ip":$priv,"username":$user,"password":$pw}]' \
  "output/${RESOURCE_GROUP}.machines.json" > /tmp/machines_updated.json

mv /tmp/machines_updated.json "output/${RESOURCE_GROUP}.machines.json"
```

Copy your local SSH key to the new VM so you can access it:

```bash
sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "${LME_USER}@${NODE4_PUBLIC_IP}"
```

## Step 4: Verify Baseline Cluster Health

Confirm the 3-node cluster is healthy before simulating a failure:

```bash
ssh "${LME_USER}@${MASTER_IP}" 'sudo bash -c "
  source /opt/lme/scripts/extract_secrets.sh -q
  echo \"=== Cluster Health ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty
  echo \"=== Node Membership ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/nodes?v
  echo \"=== Shard Distribution ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/shards?v
"'
```

Expected:
- `status`: `green`
- `number_of_nodes`: `3`
- Shards distributed across all three nodes with no `UNASSIGNED` entries

If this check does not pass, stop and re-run `./setup_cluster.sh` before
continuing.

## Step 5: Simulate Node Failure (Deallocate Node 3)

Deallocate `ubuntu-3` to simulate an unrecoverable node failure:

```bash
az vm deallocate --resource-group "$RESOURCE_GROUP" --name "ubuntu-3" --no-wait
```

Wait for deallocation to complete:

```bash
while true; do
  STATE=$(az vm show --resource-group "$RESOURCE_GROUP" --name "ubuntu-3" \
    -d --query "powerState" -o tsv 2>/dev/null)
  echo "Power state: $STATE"
  [[ "$STATE" == *"deallocated"* ]] && break
  sleep 10
done
echo "ubuntu-3 is deallocated"
```

### Observe the degraded state

When a node leaves the cluster, Elasticsearch promotes replica shards from
surviving nodes. The cluster goes `yellow` because replica shards that were on
the failed node are now unassigned.

```bash
ssh "${LME_USER}@${MASTER_IP}" 'sudo bash -c "
  source /opt/lme/scripts/extract_secrets.sh -q
  echo \"=== Cluster Health ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty
  echo \"=== Node Membership ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/nodes?v
"'
```

Expected: `number_of_nodes: 2`, `status: yellow`, `unassigned_shards > 0`.

## Step 6: Set Up SSH Access to the Replacement Node

The master needs SSH access to `ubuntu-4` so Ansible can run against it.

Copy the master's SSH key to the new node using its **private IP**:

```bash
ssh "${LME_USER}@${MASTER_IP}" "sshpass -p '$PASSWORD' ssh-copy-id -o StrictHostKeyChecking=no ${LME_USER}@${NODE4_PRIVATE_IP}"
```

Verify connectivity from the master:

```bash
ssh "${LME_USER}@${MASTER_IP}" "ssh -o StrictHostKeyChecking=no ${LME_USER}@${NODE4_PRIVATE_IP} hostname"
```

Expected output: `ubuntu-4`.

## Step 7: Update Inventory and Discovery Configuration

The Ansible inventory and Elasticsearch `discovery.seed_hosts` must be updated
to replace `ubuntu-3` (10.1.0.11) with `ubuntu-4` (10.1.0.12).

Generate the new inventory and push it to the master:

```bash
INVENTORY_FILE=$(mktemp)

cat > "$INVENTORY_FILE" << EOF
all:
  vars:
    es_master_host: ${MASTER_PRIVATE_IP}
    es_cluster_seed_hosts:
      - ${MASTER_PRIVATE_IP}
      - 10.1.0.10
      - ${NODE4_PRIVATE_IP}

  children:
    elasticsearch:
      hosts:
        es1:
          ansible_host: ${MASTER_PRIVATE_IP}
          ansible_connection: local
          es_node_name: lme-elasticsearch
          es_is_initial_master: true
          es_publish_host: ${MASTER_PRIVATE_IP}
        es2:
          ansible_host: 10.1.0.10
          ansible_user: ${LME_USER}
          es_node_name: es2
          es_publish_host: 10.1.0.10
        es4:
          ansible_host: ${NODE4_PRIVATE_IP}
          ansible_user: ${LME_USER}
          es_node_name: es4
          es_publish_host: ${NODE4_PRIVATE_IP}
EOF

echo "=== New inventory ==="
cat "$INVENTORY_FILE"
echo "====================="

scp "$INVENTORY_FILE" "${LME_USER}@${MASTER_IP}:~/LME/ansible/inventory/cluster.yml"
rm "$INVENTORY_FILE"
echo "Inventory updated on master"
```

Verify the inventory was written correctly:

```bash
ssh "${LME_USER}@${MASTER_IP}" "cat ~/LME/ansible/inventory/cluster.yml"
```

## Step 8: Run Ansible to Update Discovery and Join the New Node

Run `elasticsearch.yml` against **all nodes**. This will:

- Update `discovery.seed_hosts` on the master (es1) and es2 to include
  `ubuntu-4`'s IP instead of `ubuntu-3`'s
- Install all prerequisites on `ubuntu-4` from scratch (base, nix, podman,
  secrets, certs, elasticsearch)
- Start Elasticsearch on `ubuntu-4` and join it to the cluster

```bash
ssh "${LME_USER}@${MASTER_IP}" "cd ~/LME && ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml"
```

This will take several minutes since it is installing everything on `ubuntu-4`
from scratch.

After Ansible completes, restart Elasticsearch on the master and es2 so they
pick up the updated `discovery.seed_hosts`:

```bash
ssh "${LME_USER}@${MASTER_IP}" "sudo systemctl restart lme-elasticsearch"
sleep 10

ES2_PUBLIC_IP=$(jq -r '.linux_vms[1].ip_address' "output/${RESOURCE_GROUP}.machines.json")
ssh "${LME_USER}@${ES2_PUBLIC_IP}" "sudo systemctl restart lme-elasticsearch"
sleep 10
```

Verify Elasticsearch is running on the new node:

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "sudo systemctl is-active lme-elasticsearch"
```

Expected: `active`.

## Step 9: Set Up NFS on the Replacement Node

If the cluster was set up with NFS snapshots, the replacement node needs the
NFS client, mount, and Elasticsearch snapshot configuration.

### 9a. Update NFS exports on the master to allow the new node

```bash
ssh "${LME_USER}@${MASTER_IP}" "
  sudo sed -i '/^\/srv\/es-snapshots/d' /etc/exports
  echo '/srv/es-snapshots ${MASTER_PRIVATE_IP}(rw,sync,no_subtree_check,no_root_squash) 10.1.0.10(rw,sync,no_subtree_check,no_root_squash) ${NODE4_PRIVATE_IP}(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
  sudo exportfs -ra
"
```

### 9b. Install NFS client and mount on the replacement node

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "
  sudo apt-get install -y nfs-common
  sudo mkdir -p /mnt/es-snapshots
  sudo mount -t nfs ${MASTER_PRIVATE_IP}:/srv/es-snapshots /mnt/es-snapshots
  grep -q '/mnt/es-snapshots' /etc/fstab || \
    echo '${MASTER_PRIVATE_IP}:/srv/es-snapshots /mnt/es-snapshots nfs defaults 0 0' | sudo tee -a /etc/fstab
"
```

Verify the mount:

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "mountpoint -q /mnt/es-snapshots && echo 'NFS mounted' || echo 'NFS NOT mounted'"
```

### 9c. Add the snapshot path to Elasticsearch config

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "
  sudo grep -q '/usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml || \
    sudo sed -i '/\/usr\/share\/elasticsearch\/backups/a\\    - /usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml
"
```

### 9d. Add the NFS volume to the ES container via Quadlet drop-in

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "
  sudo mkdir -p /etc/containers/systemd/lme-elasticsearch.container.d/
  echo '[Container]
Volume=/mnt/es-snapshots:/usr/share/elasticsearch/snapshots' | sudo tee /etc/containers/systemd/lme-elasticsearch.container.d/nfs-mount.conf
  sudo systemctl daemon-reload && sudo systemctl restart lme-elasticsearch
"
```

Verify Elasticsearch restarted:

```bash
ssh "${LME_USER}@${NODE4_PUBLIC_IP}" "sudo systemctl is-active lme-elasticsearch"
```

Expected: `active`.

## Step 10: Validate Recovery

Wait 1–2 minutes for shard rebalancing, then verify the cluster is healthy:

```bash
ssh "${LME_USER}@${MASTER_IP}" 'sudo bash -c "
  source /opt/lme/scripts/extract_secrets.sh -q
  echo \"=== Cluster Health ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty
  echo \"=== Node Membership ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/nodes?v
  echo \"=== Shard Distribution ===\"
  curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/shards?v
"'
```

Expected:
- `status`: `green`
- `number_of_nodes`: `3` (es1, es2, es4 — ubuntu-3 is gone)
- `unassigned_shards`: `0`
- Shards distributed across all three active nodes

Run the snapshot and password-change smoke tests:

```bash
./test_snapshot.sh
./test_change_passwords.sh
```

Both scripts should end with `All tests passed.`

## Handling `red` Status After Rejoin

If the cluster shows `red` after the new node joins, a primary shard may have
existed only on the failed node with no replica (e.g., Wazuh indices with 0
replicas). Check which shards are unassigned:

```bash
ssh "${LME_USER}@${MASTER_IP}" 'sudo bash -c "
  source /opt/lme/scripts/extract_secrets.sh -q
  curl -sk -u \"elastic:\$elastic\" \"https://localhost:9200/_cat/shards?v&s=state\" | grep UNASSIGNED
"'
```

If the unassigned shard is a non-critical index (e.g.,
`wazuh-states-vulnerabilities-*`) and the data loss is acceptable, allocate an
empty primary to restore `green` status. Replace `<INDEX_NAME>` with the actual
index name from the output above:

```bash
ssh "${LME_USER}@${MASTER_IP}" 'sudo bash -c "
  source /opt/lme/scripts/extract_secrets.sh -q
  curl -sk -u \"elastic:\$elastic\" -X POST \
    \"https://localhost:9200/_cluster/reroute?pretty\" \
    -H \"Content-Type: application/json\" \
    -d \"{\\\"commands\\\": [{\\\"allocate_empty_primary\\\": {
      \\\"index\\\": \\\"<INDEX_NAME>\\\",
      \\\"shard\\\": 0,
      \\\"node\\\": \\\"es4\\\",
      \\\"accept_data_loss\\\": true
    }}]}\"
"'
```

## Caveats

### Master node recovery is different

The master (es1) hosts Kibana, Fleet, Wazuh, and is the Ansible control node
that holds source certificates and vault files. Recovering es1 requires
restoring from backup or rebuilding the full stack — it cannot be handled with
the approach described here.

### Azure VM and inventory naming

| VM name | Inventory name | Default private IP | Role |
|---|---|---|---|
| `ubuntu` | `es1` (master) | `10.1.0.5` | Master + Kibana + Fleet + Wazuh |
| `ubuntu-2` | `es2` | `10.1.0.10` | Elasticsearch data node |
| `ubuntu-3` | `es3` | `10.1.0.11` | Elasticsearch data node (failed) |
| `ubuntu-4` | `es4` | `10.1.0.12` | Elasticsearch data node (replacement) |

### VNet and subnet defaults

The build script creates VNet `VNet1` and subnet `SNet1` with prefix
`10.1.0.0/24`. The `az vm create` command in Step 3 uses these defaults. If
you customized VNet/subnet names in your build, adjust accordingly.

### Cleanup

Delete all Azure resources when done:

```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```

## Related Documentation

- [CLUSTER_NODE_RECOVERY.md](../../development/CLUSTER_NODE_RECOVERY.md) — Docker-based development cluster recovery
- [README.md](README.md) — Cluster installer overview
- [README_DOCKER.md](README_DOCKER.md) — Docker-based cluster testing
- [Elasticsearch Cluster Formation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html) — Official cluster discovery docs
