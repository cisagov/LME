# Cluster Recovery QA Checklist

Use this checklist to validate the cluster backup and recovery implementation.

## Core Scenarios

- Cluster backup bundle creates an Elasticsearch snapshot successfully.
Environment: Docker dev cluster or Azure cluster with NFS/shared snapshot storage.
Method: Run `ansible/cluster_backup_lme.yml`.
Expected: Snapshot state is `SUCCESS`.
- Cluster backup bundle creates a local master recovery bundle.
Environment: Docker dev cluster or Azure cluster.
Method: Run `ansible/cluster_backup_lme.yml`.
Expected: Backup directory contains `cluster_recovery_manifest.yml`.
- Cluster backup bundle exports the master recovery bundle to shared storage.
Environment: Docker dev cluster or Azure cluster with `/mnt/es-snapshots` mounted.
Method: Run `ansible/cluster_backup_lme.yml`.
Expected: Exported bundle exists under `/mnt/es-snapshots/lme-master-backups/<timestamp>`.
- Cluster backup manifest records both snapshot and exported backup paths.
Environment: Any clustered environment with shared storage.
Method: Inspect `cluster_recovery_manifest.yml`.
Expected: Manifest includes snapshot name, repository details, local backup path, and exported backup path.
- `backup_lme.yml` on a cluster excludes Elasticsearch data volumes.
Environment: Docker dev cluster or Azure cluster.
Method: Run `ansible/backup_lme.yml` on the master.
Expected: Backup notes/manifest show `lme_esdata*` excluded.
- `rollback_lme.yml` fails fast on a cluster.
Environment: Clustered master host.
Method: Run `ansible/rollback_lme.yml`.
Expected: Playbook aborts with guidance to use snapshot restore plus master restore.

## Snapshot Restore Scenarios

- Live-cluster targeted restore works for a deleted test index.
Environment: Running Docker dev cluster or Azure cluster.
Method: Create a temporary index, snapshot it, delete it, then run `ansible/restore_elasticsearch_snapshot.yml` with:
  `-e restore_mode=live_cluster -e restore_indices=<test-index> -e include_global_state=false`
Expected: Index is restored and document count matches pre-delete state.
- Live-cluster restore rejects unsafe defaults.
Environment: Running cluster.
Method: Run `ansible/restore_elasticsearch_snapshot.yml` with `restore_mode=live_cluster` and default `restore_indices='*'` or `include_global_state=true`.
Expected: Playbook fails with a safety message.
- Full-cluster restore requires explicit confirmation.
Environment: Fresh or rebuild target cluster.
Method: Run `ansible/restore_elasticsearch_snapshot.yml` with default full restore settings but without `confirm_full_cluster_restore=true`.
Expected: Playbook fails with a confirmation requirement.
- Fresh-cluster full restore succeeds when explicitly confirmed.
Environment: Fresh or rebuild target cluster.
Method: Run `ansible/restore_elasticsearch_snapshot.yml -e confirm_full_cluster_restore=true`.
Expected: Snapshot restore completes and cluster health becomes `green` or `yellow`.
- Kibana global-state restore path does not leave Kibana down.
Environment: Fresh or rebuild target cluster with Kibana on master.
Method: Run full restore including global state.
Expected: `lme-kibana` restarts successfully after restore.

## Master Restore Scenarios

- Master restore works from local backup storage.
Environment: Master host with local backup bundle still present.
Method: Run `ansible/restore_lme_master.yml` and select a local backup.
Expected: `/opt/lme`, `/etc/lme`, `/etc/containers/systemd`, secrets, and non-ES volumes are restored.
- Master restore works from exported shared-storage backup.
Environment: Master host or replacement host with `/mnt/es-snapshots` mounted.
Method: Run `ansible/restore_lme_master.yml -e restore_backup_dir=/mnt/es-snapshots/lme-master-backups/<timestamp>`.
Expected: Restore succeeds without relying on local Podman backup storage.
- Master restore auto-discovers backups in both local and shared paths.
Environment: Host with both search roots available.
Method: Run `ansible/restore_lme_master.yml` without `restore_backup_dir`.
Expected: Backup selection list includes candidates from both locations.
- Master restore leaves Elasticsearch volumes untouched by default.
Environment: Clustered master host.
Method: Run `ansible/restore_lme_master.yml` with default settings.
Expected: `lme_esdata*` volumes are not selected for restoration.
- Master restore brings the control plane back.
Environment: Clustered master host.
Method: Run `ansible/restore_lme_master.yml`.
Expected: At least the expected master services return and cluster health remains acceptable.

## Recovery Flow Scenarios

- Child-node recovery still works after these changes.
Environment: Docker dev cluster or Azure cluster.
Method: Follow the existing child-node recovery guide.
Expected: Node rejoins and cluster returns to `green`.
- Cluster backup/restore test script passes in Docker dev.
Environment: `testing/v2/development`.
Method: Run `bash test_cluster_backup_restore.sh`.
Expected: Script ends with `All tests passed.`
- Cluster backup/restore test script passes in Azure installer flow.
Environment: `testing/v2/installers/cluster_installer`.
Method: Run `./test_cluster_backup_restore.sh -r <resource-group>`.
Expected: Script ends with `All tests passed.`
- Existing snapshot tests still pass.
Environment: Docker dev and Azure cluster.
Method: Run existing `test_snapshot.sh`.
Expected: Existing snapshot workflow remains intact.
- Existing password-change tests still pass.
Environment: Docker dev and Azure cluster.
Method: Run existing `test_change_passwords.sh`.
Expected: Existing password workflow remains intact.

## Documentation / Operator Scenarios

- Operator can follow `ansible/CLUSTER_RECOVERY_README.md` to understand supported recovery paths.
Expected: Doc clearly separates child-node recovery, master restore, and full snapshot restore.
- Operator docs clearly state rollback is single-node only.
Expected: `ROLLBACK_README.md` and `rollback_lme.yml` behavior match.
- Operator docs clearly distinguish `fresh_cluster` vs `live_cluster` restore.
Expected: Snapshot restore instructions match actual playbook safety checks.

## Not In Scope / Known Limits

- Confirm docs do not promise automatic child-to-master promotion.
Expected: Documentation describes that as manual or unsupported, not as a validated workflow.
- Confirm docs do not promise Elasticsearch version downgrade rollback.
Expected: Documentation states restore must target a compatible Elasticsearch version.

