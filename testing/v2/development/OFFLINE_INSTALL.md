# Offline Install - Manual Azure Reproduction Guide

This guide reproduces the `offline.yml` GitHub Actions workflow manually on Azure using `testing/v2/installers/azure/build_azure_linux_network.py` and `testing/v2/installers/exporter.txt`. Use it to test/debug the LME offline install (`./install.sh -o`) end to end without running the full CI job.

Flow:

1. Build two Linux VMs in one resource group (u1 with internet, u2 will become the offline target).
2. On u1, clone LME and run `prepare_offline.sh` to produce the tarball.
3. Copy the tarball from u1 to u2.
4. Lock down u2's NSG (allow only intra-VNet, deny Internet) so it is truly offline. Keep SSH from your IP if you want, or only from u1.
5. SSH from u1 to u2 and run `./install.sh -o -d`.
6. When it fails, capture diagnostics on u2 **before** running `az group delete`.

## Architecture

| Role | VM name | Private IP | Public IP | Internet | Purpose |
|---|---|---|---|---|---|
| Build / bastion | `ubuntu` (u1) | `10.1.0.5` | Yes (your `$PUBLIC_IP`) | Yes | Runs `prepare_offline.sh`, scp's tarball to u2 |
| Offline target | `ubuntu-2` (u2) | `10.1.0.10` | Yes initially, locked down by NSG | **No** (after step 5) | Runs `install.sh -o`, hosts LME |

The default subnet is `10.1.0.0/24`, VNet `10.1.0.0/16`. `build_azure_linux_network.py` opens 22/443/5601/9200/9001/9300/3389 by default to your `-s` source IP list.

## Prereqs (local workstation)

```bash
sudo apt-get update
sudo apt-get install -y jq sshpass python3-venv
az login                                        # interactive Azure login
az account set --subscription <SUBSCRIPTION>    # if needed
```

Clone LME and edit `exporter.txt`:

```bash
git clone https://github.com/cisagov/LME.git
cd LME/testing/v2/installers
$EDITOR exporter.txt
```

Minimal `testing/v2/installers/exporter.txt`:

```bash
export RESOURCE_GROUP="LME-yourname-offline"
export PUBLIC_IP="YOUR_PUBLIC_IP/32"           # find with: curl -s https://api.ipify.org
export VM_SIZE="Standard_D8_v4"                # same as offline.yml
export LOCATION="westus"
export AUTO_SHUTDOWN_TIME="00:00"
export LME_USER="lme-user"
export BRANCH=cbaxley-fix-quadlet-timing
export OS_DISK_SIZE_GB=256
```

Set up the Azure Python deps once:

```bash
cd testing/v2/installers
python3 -m venv venv
source venv/bin/activate
pip install -r azure/requirements.txt
```

## Step 1: Build the two VMs

From `testing/v2/installers/`:

```bash
source exporter.txt
source venv/bin/activate

./azure/build_azure_linux_network.py \
  -g "$RESOURCE_GROUP" \
  -s "$PUBLIC_IP" \
  -vs "$VM_SIZE" \
  -l "$LOCATION" \
  -ast "$AUTO_SHUTDOWN_TIME" \
  -os "$OS_DISK_SIZE_GB" \
  -c 2 \
  -y
```

This creates:

- VNet `VNet1` (`10.1.0.0/16`), Subnet `SNet1` (`10.1.0.0/24`)
- NSG `NSG1` with inbound allow rules from `$PUBLIC_IP` on the default ports
- `ubuntu` at `10.1.0.5` (u1)
- `ubuntu-2` at `10.1.0.10` (u2)

It writes two files in the current directory:

- `${RESOURCE_GROUP}.password.txt` - same password is used for both VMs
- `${RESOURCE_GROUP}.machines.json` - public/private IPs

Pull the IPs and password into shell variables:

```bash
PASSWORD=$(cat "${RESOURCE_GROUP}.password.txt")
U1_IP=$(jq -r '.linux_vms[0].ip_address' "${RESOURCE_GROUP}.machines.json")
U2_IP=$(jq -r '.linux_vms[1].ip_address' "${RESOURCE_GROUP}.machines.json")
U1_PRIV=$(jq -r '.linux_vms[0].private_ip' "${RESOURCE_GROUP}.machines.json")  # 10.1.0.5
U2_PRIV=$(jq -r '.linux_vms[1].private_ip' "${RESOURCE_GROUP}.machines.json")  # 10.1.0.10
echo "u1: $U1_IP ($U1_PRIV)   u2: $U2_IP ($U2_PRIV)   pw: $PASSWORD"
```

Wait ~2 min for boot, then SSH-copy your key to both:

```bash
sleep 120
for IP in "$U1_IP" "$U2_IP"; do
  sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "${LME_USER}@${IP}"
done
```

## Step 2: Build the offline tarball on u1

```bash
ssh "${LME_USER}@${U1_IP}" "
  sudo apt-get update && sudo apt-get install -y git &&
  cd ~ && rm -rf LME && git clone https://github.com/cisagov/LME.git &&
  cd LME && git checkout '$BRANCH' &&
  ./scripts/prepare_offline.sh
"
```

For the LLM bundle, replace `./scripts/prepare_offline.sh` with `./scripts/prepare_offline.sh --llm`. This produces `~/lme-offline-YYYYMMDD-HHMMSS.tar.gz` on u1 (a few GB).

Find the tarball name:

```bash
TARBALL=$(ssh "${LME_USER}@${U1_IP}" "ls -t ~/lme-offline-*.tar.gz | head -1 | xargs basename")
echo "Tarball: $TARBALL"
```

## Step 3: Copy the tarball from u1 to u2

While u2 still has internet, this is also a good time to install git on u2 if you want a fallback `apt-get` later (in case you need to debug without the offline bundle's installed deps):

```bash
# Ensure u1 can SSH to u2 over the VNet without a password prompt.
# Easiest path: copy u1's public key to u2 from your workstation.
U1_PUBKEY=$(ssh "${LME_USER}@${U1_IP}" "
  [ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa -q
  cat ~/.ssh/id_rsa.pub
")
ssh "${LME_USER}@${U2_IP}" "echo '$U1_PUBKEY' >> ~/.ssh/authorized_keys"

# Now u1 can SCP the tarball to u2 over the VNet
ssh "${LME_USER}@${U1_IP}" "scp -o StrictHostKeyChecking=no ~/lme-offline-*.tar.gz ${LME_USER}@${U2_PRIV}:~/"

# Extract on u2
ssh "${LME_USER}@${U2_IP}" "
  sudo mv ~/lme-offline-*.tar.gz /var/ &&
  tar -xzf /var/lme-offline-*.tar.gz -C ~/ &&
  ls -d ~/LME
"
```

## Step 4: Lock down u2 (offline NSG)

`build_azure_linux_network.py` puts both VMs behind `NSG1`. We create a second NSG that allows only intra-VNet traffic and denies Internet outbound, and attach it to u2's NIC. This mirrors the workflow's `NSG-offline`.

```bash
# u2's NIC name (the script names VMs ubuntu, ubuntu-2, ... so NIC is <vm>VMNic)
U2_NIC=$(az vm show -g "$RESOURCE_GROUP" -n ubuntu-2 \
  --query 'networkProfile.networkInterfaces[0].id' -o tsv | awk -F/ '{print $NF}')
echo "u2 NIC: $U2_NIC"

# 1. Create the restrictive NSG
az network nsg create -g "$RESOURCE_GROUP" -n NSG-offline

# 2. Allow inbound from VNet only (lets u1 SSH to u2)
az network nsg rule create -g "$RESOURCE_GROUP" --nsg-name NSG-offline \
  --name allow-vnet-inbound --priority 1000 \
  --direction Inbound --access Allow --protocol '*' \
  --source-address-prefix VirtualNetwork \
  --destination-address-prefix VirtualNetwork \
  --source-port-range '*' --destination-port-ranges '*'

# 3. (Optional) Also allow inbound SSH from your public IP so you can still
#    log in directly for diagnostics without going through u1.
az network nsg rule create -g "$RESOURCE_GROUP" --nsg-name NSG-offline \
  --name allow-mgmt-ssh --priority 1100 \
  --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefix "$PUBLIC_IP" \
  --destination-address-prefix '*' \
  --source-port-range '*' --destination-port-ranges 22

# 4. Deny everything else inbound
az network nsg rule create -g "$RESOURCE_GROUP" --nsg-name NSG-offline \
  --name deny-public-inbound --priority 4000 \
  --direction Inbound --access Deny --protocol '*' \
  --source-address-prefix '*' --destination-address-prefix '*' \
  --source-port-range '*' --destination-port-ranges '*'

# 5. Allow VNet outbound (so u2 can reach u1 if needed)
az network nsg rule create -g "$RESOURCE_GROUP" --nsg-name NSG-offline \
  --name allow-vnet-outbound --priority 1000 \
  --direction Outbound --access Allow --protocol '*' \
  --source-address-prefix VirtualNetwork \
  --destination-address-prefix VirtualNetwork \
  --source-port-range '*' --destination-port-ranges '*'

# 6. Deny Internet outbound (this is what makes u2 "offline")
az network nsg rule create -g "$RESOURCE_GROUP" --nsg-name NSG-offline \
  --name deny-internet-outbound --priority 4000 \
  --direction Outbound --access Deny --protocol '*' \
  --source-address-prefix '*' \
  --destination-address-prefix Internet \
  --source-port-range '*' --destination-port-ranges '*'

# 7. Attach NSG-offline to u2's NIC (this replaces the inherited NSG1)
az network nic update -g "$RESOURCE_GROUP" -n "$U2_NIC" \
  --network-security-group NSG-offline
```

Verify the lockdown took effect:

```bash
# Should print "blocked" - outbound to the Internet should fail
ssh "${LME_USER}@${U1_IP}" "ssh -o StrictHostKeyChecking=no ${LME_USER}@${U2_PRIV} \
  'timeout 10 curl -s --connect-timeout 5 https://www.google.com >/dev/null && echo open || echo blocked'"
```

You should see `blocked`. If you see `open`, NSG propagation has not finished yet. Wait 30-60s and re-test.

If you skipped rule #3 above, also confirm that your local workstation **cannot** SSH to u2 directly anymore (`ssh "${LME_USER}@${U2_IP}"` should hang/refuse). You can still reach u2 by SSHing to u1 first.

## Step 5: Run the offline install on u2

From your workstation, jump through u1:

```bash
ssh "${LME_USER}@${U1_IP}" "ssh -o StrictHostKeyChecking=no ${LME_USER}@${U2_PRIV} '
  cd ~/LME && NON_INTERACTIVE=true AUTO_CREATE_ENV=true ./install.sh -o -d 2>&1 | tee /var/tmp/install.log
'"
```

This is the same command `offline.yml` runs. Add `--llm` if you used `--llm` in step 2.

To skim the result:

```bash
ssh "${LME_USER}@${U1_IP}" "ssh ${LME_USER}@${U2_PRIV} \
  'grep -E \"fatal|FAILED|PLAY RECAP\" /var/tmp/install.log'"
```

## Step 6: Capture diagnostics on u2 when it fails

**Do this before** `az group delete`. In CI, the VM gets destroyed by the cleanup step, which is exactly why we cannot see the real error today.

Run inside u2 (via u1):

```bash
ssh "${LME_USER}@${U1_IP}" "ssh -o StrictHostKeyChecking=no ${LME_USER}@${U2_PRIV} '
  echo === systemctl status ===
  sudo systemctl status lme-fleet-server.service --no-pager
  echo
  echo === journalctl -xeu lme-fleet-server ===
  sudo journalctl -xeu lme-fleet-server.service --no-pager | tail -200
  echo
  echo === podman ps ===
  sudo podman ps -a --filter name=lme-
  echo
  echo === podman logs lme-fleet-server ===
  sudo podman logs lme-fleet-server 2>&1 | tail -200
  echo
  echo === quadlet source ===
  ls -la /etc/containers/systemd/lme-fleet-server.container
  cat /etc/containers/systemd/lme-fleet-server.container
  echo
  echo === generated unit ===
  cat /run/systemd/generator/lme-fleet-server.service 2>/dev/null \
    || sudo find /run/systemd/generator* -name lme-fleet-server.service -exec cat {} \;
'" | tee ~/u2-fleet-debug.log
```

The most important pieces are:

- `journalctl -xeu lme-fleet-server.service` - the actual reason systemd refused to start the service.
- `/run/systemd/generator/lme-fleet-server.service` - the unit quadlet generated from the `.container` file. If moving `StartLimitIntervalSec`/`StartLimitBurst` from `[Service]` to `[Unit]` is mis-emitted by `podman-systemd-generator`, the diff between this and the `.container` file will show it.

To rerun just the fleet-server unit after fixing something locally on u2:

```bash
ssh "${LME_USER}@${U1_IP}" "ssh ${LME_USER}@${U2_PRIV} '
  sudo systemctl daemon-reload
  sudo systemctl reset-failed lme-fleet-server.service
  sudo systemctl restart lme-fleet-server.service
  sudo journalctl -xeu lme-fleet-server.service --no-pager | tail -50
'"
```

## Step 7: Reset the NSG (optional)

If you want to put u2 back online for further debugging without rebuilding the resource group:

```bash
az network nic update -g "$RESOURCE_GROUP" -n "$U2_NIC" \
  --network-security-group NSG1
```

## Step 8: Cleanup

When you are done:

```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```

## Optional: LLM bundle

Add `--llm` to both steps:

```bash
# On u1 in step 2
./scripts/prepare_offline.sh --llm

# On u2 in step 5
NON_INTERACTIVE=true AUTO_CREATE_ENV=true ./install.sh -o --llm -d
```

The LLM tarball is much larger (extra container images, GGUF models, pre-scraped docs). Skip unless you specifically need it.

## Optional: Windows agent VM (`w1`)

The workflow also creates a Windows VM at `10.1.0.7` and enrolls the Elastic Agent. To replicate, re-run `build_azure_linux_network.py` with `-w`, or add a Windows VM after the fact:

```bash
az vm create \
  -g "$RESOURCE_GROUP" -n w1-offline \
  --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest \
  --size Standard_D4s_v3 \
  --admin-username "$LME_USER" --admin-password "$PASSWORD" \
  --vnet-name VNet1 --subnet SNet1 \
  --nsg NSG-offline \
  --public-ip-address '' --private-ip-address 10.1.0.7 \
  --os-disk-size-gb 128
```

Then follow the `Copy offline tarball to w1`, `Extract offline tarball on w1`, `Extract Elastic Agent on w1`, and `Install Elastic Agent on w1` steps from `offline.yml`. Skip this unless you are specifically debugging Windows agent enrollment.

## Reference: `install.sh` flags used here

| Flag | Meaning |
|---|---|
| `-o`, `--offline` | Enable offline mode (skip internet-dependent tasks; skips LLM unless `--llm` is also set) |
| `-d` | Debug output |
| `--llm` | Include LLM stack (default on non-offline; explicit on offline) |
| `NON_INTERACTIVE=true` (env) | Skip prompts |
| `AUTO_CREATE_ENV=true` (env) | Auto-create `config/lme-environment.env` if missing |
| `AUTO_IP=<ip>` (env) | Use this IP for `IPVAR` when auto-creating env |

## Reference: useful `gh` CLI commands

```bash
gh run list --workflow=offline.yml --limit 5
gh run view <run-id>
gh api repos/cisagov/LME/actions/jobs/<job-id>/logs > /tmp/offline.log
grep -nE "fatal: \[|FAILED!|PLAY RECAP|##\[error\]" /tmp/offline.log
gh run rerun <run-id> --failed
gh workflow run offline.yml --ref <branch>
```

## Reference: corresponding workflow steps in `offline.yml`

| Step here | Step in `offline.yml` |
|---|---|
| Step 1 - build VMs | `Build u1 Azure instance` + `Create u2 VM` |
| Step 2 - tarball on u1 | `Prepare offline resources on u1` + `Find offline tarball on u1` |
| Step 3 - copy tarball | `Copy offline tarball from u1 to u2 (via bastion)` + `Extract offline tarball on u2 (via bastion)` |
| Step 4 - lock down u2 NSG | `Create restrictive NSG for u2 (offline VM)` + `Verify u2 outbound connectivity is blocked` |
| Step 5 - install | `Run LME installer on u2 (via bastion)` (this is where the current failure happens) |
| Step 6 - diagnostics | Not currently in `offline.yml`. Run manually before cleanup. |
| Step 8 - cleanup | `Cleanup Azure resources` |
