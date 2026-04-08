# LME Cluster Backup And Recovery

This guide describes the supported backup and recovery model for clustered LME
deployments.

## Recovery Model

Cluster recovery is split into two layers:

1. **Elasticsearch data protection** uses the Elasticsearch snapshot API.
2. **Master/control-plane recovery** uses a host-level backup of the LME master.

This distinction matters because Elasticsearch data is sharded across nodes.
Filesystem-level copies of a single host do **not** produce a valid cluster data
backup.

## Supported Playbooks

### `ansible/cluster_backup_lme.yml`

Creates a cluster recovery bundle by combining:
- An Elasticsearch snapshot across the cluster
- A master/control-plane backup on the first `elasticsearch` inventory host
- An exported copy of the master recovery bundle on shared storage when `/mnt/es-snapshots` is mounted

Run from the master with the cluster inventory:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml
```

Optional examples:

```bash
# Use the shared NFS-backed snapshot path
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
  -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots \
  -e es_snapshot_repo=lme_nfs_backups

# Use a specific snapshot name
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
  -e snapshot_name=before-maintenance
```

Artifacts:
- Elasticsearch snapshot in the configured repository
- Master backup under the local backup root
- Exported master backup on shared storage (when `/mnt/es-snapshots` is mounted) as **`/mnt/es-snapshots/lme-master-backups/<timestamp>.tar.gz`** — a gzip tarball of the same directory tree (avoids NFS metadata issues with directory-tree copies). Older installs may still have a **directory** export at `/mnt/es-snapshots/lme-master-backups/<timestamp>/`; `restore_lme_master.yml` accepts either form.
- `cluster_recovery_manifest.yml` inside the backup tree (and inside the tarball)

### `ansible/restore_elasticsearch_snapshot.yml`

Restores Elasticsearch data from a previously created snapshot.

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e confirm_full_cluster_restore=true
```

Restore modes:
- `fresh_cluster`: full-cluster restore flow, intended for rebuild/recovery targets
- `live_cluster`: targeted restore only; requires `include_global_state=false` and a specific `restore_indices` value

With `restore_mode=fresh_cluster` and the default `restore_indices='*'` and `include_global_state=true`, you must pass `-e confirm_full_cluster_restore=true` or the playbook will stop with a confirmation error.

Common options:

```bash
# Restore only a specific index
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e restore_mode=live_cluster \
  -e restore_indices=lme-recovery-test

# Restore into renamed indices
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e restore_mode=live_cluster \
  -e restore_indices=lme-recovery-test \
  -e rename_pattern='(.+)' \
  -e rename_replacement='restored-$1'
```

### `ansible/restore_lme_master.yml`

Restores master/control-plane state from a host-level backup.

This playbook restores:
- `/opt/lme`
- `/etc/lme`
- `/etc/containers/systemd`
- Podman secrets
- Non-Elasticsearch LME volumes by default

It **does not** restore Elasticsearch data volumes unless you explicitly opt in
with `-e restore_es_volumes=true`.

```bash
ansible-playbook ansible/restore_lme_master.yml
```

Or point directly at a backup:

```bash
ansible-playbook ansible/restore_lme_master.yml \
  -e restore_backup_dir=/mnt/es-snapshots/lme-master-backups/2026-03-30_10-15
```

If `restore_backup_dir` is omitted, the playbook searches both:
- local Podman backup storage
- `/mnt/es-snapshots/lme-master-backups`

## Recommended Recovery Scenarios

### Child node failure

Use the existing node rebuild and rejoin flow:
- `testing/v2/development/CLUSTER_NODE_RECOVERY.md`

### Master node failure with surviving cluster

1. Recover or rebuild the replacement master host.
2. Restore master state:
   ```bash
   ansible-playbook ansible/restore_lme_master.yml
   ```
3. Verify the master rejoins the cluster and that Kibana, Fleet, and Wazuh come
   back up.

### Major failure or failed upgrade

1. Deploy a compatible cluster.
2. Restore master state:
   ```bash
   ansible-playbook ansible/restore_lme_master.yml
   ```
3. Restore Elasticsearch data:
   ```bash
   ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
     -e snapshot_name=<snapshot> \
     -e confirm_full_cluster_restore=true
   ```

## Backup Container Lifecycle

The `backup_lme` role stops all LME services before copying volumes, then
restarts them afterward. Because Podman tracks container-level dependencies
(e.g. `lme-kibana --requires lme-elasticsearch`, `lme-setup-accts` uses
`UserNS=container:lme-elasticsearch`), a clean teardown requires removing
containers in dependency order so that Podman's internal graph does not block
recreation on restart.

### Teardown order enforced by the backup role

1. `systemctl stop lme` — signals all PartOf units to stop.
2. Wait for running `lme-*` containers to exit (up to 90 seconds).
3. If any remain running, force stop in reverse dependency order:
   `lme-fleet-server` → `lme-fleet-distribution` → `lme-elastalert2` →
   `lme-wazuh-manager` → `lme-kibana` → `lme-setup-accts` →
   `lme-setup-certs` → `lme-elasticsearch`.
4. Remove all stopped `lme-*` containers (`podman rm -f`) in the same order
   to clear Podman's dependency graph.
5. Verify `podman ps -a` shows zero `lme-*` entries. If any remain, the
   backup fails immediately rather than proceeding with a broken state.

### Restart after backup

Before `systemctl start lme`, the role runs one more cleanup pass to remove
any containers that may have reappeared (e.g. from a systemd timer restart
race). Quadlet then recreates each container from its `.container` unit file.

The role waits specifically for `lme-elasticsearch` to reach running state
(up to 4 minutes). If it does not start, the role collects `systemctl status`
and `journalctl` output for `lme-elasticsearch.service` and prints actionable
remediation guidance.

## Important Limitations

- `ansible/rollback_lme.yml` is **single-node only**.
- Elasticsearch version downgrade is **not supported**.
- For multi-node `fs` repositories, all nodes must share the same underlying
  snapshot storage path.
- Snapshot restore may conflict with a running Kibana instance if restoring
  `.kibana*` indices or global state. Prefer restoring into a fresh cluster or
  stopping Kibana first when appropriate.

## Validation Scripts

- Docker dev cluster:
  `testing/v2/development/test_cluster_backup_restore.sh`
- Azure installer cluster:
  `testing/v2/installers/cluster_installer/test_cluster_backup_restore.sh`
- QA checklist:
  `testing/v2/development/CLUSTER_RECOVERY_QA_CHECKLIST.md`

## Related Docs

- [BACKUP_README.md](BACKUP_README.md)
- [SNAPSHOT_README.md](SNAPSHOT_README.md)
- [ROLLBACK_README.md](ROLLBACK_README.md)
