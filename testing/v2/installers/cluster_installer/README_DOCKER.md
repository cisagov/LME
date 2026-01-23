# Running Cluster Installer in Docker

This directory contains Docker configuration to run the cluster installer script in a containerized environment with all required tools pre-installed.

## Quick Start

### Option 1: Using the Helper Script (Easiest)

1. **Create your `exporter.txt` file** in this directory:
   ```bash
   export RESOURCE_GROUP="my-cluster-rg"
   export PUBLIC_IP="YOUR_IP/32"
   export VM_SIZE="Standard_E2d_v4"
   export LOCATION="westus"
   export AUTO_SHUTDOWN_TIME="00:00"
   export LME_USER="lme-user"
   export BRANCH="your-branch-name"
   ```

2. **Set up Azure credentials** (one of these methods):
   - Set environment variables:
     ```bash
     export AZURE_CLIENT_ID="your-client-id"
     export AZURE_CLIENT_SECRET="your-client-secret"
     export AZURE_TENANT_ID="your-tenant-id"
     export AZURE_SUBSCRIPTION_ID="your-subscription-id"
     ```
   - Or use `az login` on your host (the script will mount `~/.azure`)

3. **Run the helper script**:
   ```bash
   ./run-docker.sh
   ```

   Or with debug mode:
   ```bash
   ./run-docker.sh --debug
   ```

### Option 2: Using Docker Commands Directly

1. **Build the image**:
   ```bash
   cd /path/to/LME
   docker build -f testing/v2/installers/cluster_installer/Dockerfile -t lme-cluster-installer .
   ```

2. **Create output directory**:
   ```bash
   mkdir -p testing/v2/installers/cluster_installer/output
   ```

3. **Run the container**:
   ```bash
   docker run -it --rm \
     --network host \
     -v $(pwd):/workspace/LME:ro \
     -v $(pwd)/testing/v2/installers/cluster_installer/output:/workspace/testing/v2/installers/output \
     -v $(pwd)/testing/v2/installers/cluster_installer/exporter.txt:/workspace/testing/v2/installers/exporter.txt:ro \
     -v ~/.azure:/root/.azure:ro \
     -e AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}" \
     -e AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}" \
     -e AZURE_TENANT_ID="${AZURE_TENANT_ID:-}" \
     -e AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}" \
     lme-cluster-installer \
     bash -c "cd /workspace/testing/v2/installers/cluster_installer && ./setup_cluster.sh"
   ```

   Or for interactive shell:
   ```bash
   docker run -it --rm \
     --network host \
     -v $(pwd):/workspace/LME:ro \
     -v $(pwd)/testing/v2/installers/cluster_installer/output:/workspace/testing/v2/installers/output \
     -v $(pwd)/testing/v2/installers/cluster_installer/exporter.txt:/workspace/testing/v2/installers/exporter.txt:ro \
     -v ~/.azure:/root/.azure:ro \
     -e AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}" \
     -e AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}" \
     -e AZURE_TENANT_ID="${AZURE_TENANT_ID:-}" \
     -e AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}" \
     lme-cluster-installer \
     bash
   # Then inside container:
   cd /workspace/testing/v2/installers/cluster_installer
   ./setup_cluster.sh
   ```

## Directory Structure

The Docker setup expects:
- `/workspace/LME` - The entire LME repository (mounted read-only)
- `/workspace/testing/v2/installers/output` - Directory for generated files (passwords, machine info)
- `/workspace/testing/v2/installers/exporter.txt` - Your configuration file

## Output Files

Generated files (like `${RESOURCE_GROUP}.password.txt` and `${RESOURCE_GROUP}.machines.json`) will be saved to the `output/` directory, which is mounted as a volume so they persist on your host.

## SSH Keys

The container generates its own SSH keys automatically when needed. The `setup_cluster.sh` script will:
1. Generate an SSH key pair in `/root/.ssh/id_rsa` if one doesn't exist
2. Copy the public key to all cluster VMs using password authentication
3. Set up SSH key-based authentication for subsequent connections

No SSH keys need to be mounted from the host - everything is handled inside the container.

## Azure Authentication

The container supports multiple authentication methods:

1. **Environment Variables**: Set `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`
2. **Azure CLI Login**: If you've run `az login` on your host, mount `~/.azure` (already included in the commands above)
3. **Managed Identity**: If running in Azure, the container will automatically use managed identity

## Network Mode

The container uses `--network host` to allow direct SSH connections to Azure VMs. If you're running Docker on a system where host networking isn't available, you may need to adjust firewall rules or use port forwarding.

## Troubleshooting

### Azure Authentication Issues

If you get authentication errors:
1. Verify your Azure credentials are set correctly
2. Check that the service principal has the necessary permissions
3. Try logging in with `az login` on your host and ensure `~/.azure` is mounted
4. Check that environment variables are being passed correctly

### SSH Connection Issues

If SSH connections fail:
1. Ensure `--network host` is set (or configure port forwarding)
2. Verify firewall rules allow outbound SSH connections
3. The script generates SSH keys automatically - check the output for key generation messages
4. If you need to debug SSH issues, you can inspect the container:
   ```bash
   docker run -it --rm --network host lme-cluster-installer bash
   # Inside container:
   ls -la /root/.ssh
   ssh-keygen -l -f /root/.ssh/id_rsa.pub  # Verify key exists
   ```

### File Permission Issues

If you get permission errors:
1. Check that the output directory is writable: `chmod 755 output/`
2. Ensure mounted volumes have correct permissions
3. You may need to adjust file ownership inside the container

### Build Issues

If the Docker build fails:
1. Make sure you're running from the LME repository root
2. Check that the Dockerfile path is correct relative to the repo root
3. Verify you have sufficient disk space

## Examples

### Running with Debug Mode

```bash
docker run -it --rm \
  --network host \
  -v $(pwd):/workspace/LME:ro \
  -v $(pwd)/testing/v2/installers/cluster_installer/output:/workspace/testing/v2/installers/output \
  -v $(pwd)/testing/v2/installers/cluster_installer/exporter.txt:/workspace/testing/v2/installers/exporter.txt:ro \
  -v ~/.azure:/root/.azure:ro \
  lme-cluster-installer \
  bash -c "cd /workspace/testing/v2/installers/cluster_installer && ./setup_cluster.sh --debug"
```

### Running with Custom Environment Variables

```bash
export AZURE_CLIENT_ID="your-id"
export AZURE_CLIENT_SECRET="your-secret"
export AZURE_TENANT_ID="your-tenant"
export AZURE_SUBSCRIPTION_ID="your-subscription"

docker run -it --rm \
  --network host \
  -v $(pwd):/workspace/LME:ro \
  -v $(pwd)/testing/v2/installers/cluster_installer/output:/workspace/testing/v2/installers/output \
  -v $(pwd)/testing/v2/installers/cluster_installer/exporter.txt:/workspace/testing/v2/installers/exporter.txt:ro \
  -v ~/.azure:/root/.azure:ro \
  -e AZURE_CLIENT_ID="${AZURE_CLIENT_ID}" \
  -e AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}" \
  -e AZURE_TENANT_ID="${AZURE_TENANT_ID}" \
  -e AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
  lme-cluster-installer \
  bash -c "cd /workspace/testing/v2/installers/cluster_installer && ./setup_cluster.sh"
```

### Interactive Debugging Session

```bash
docker run -it --rm \
  --network host \
  -v $(pwd):/workspace/LME:ro \
  -v $(pwd)/testing/v2/installers/cluster_installer/output:/workspace/testing/v2/installers/output \
  -v $(pwd)/testing/v2/installers/cluster_installer/exporter.txt:/workspace/testing/v2/installers/exporter.txt:ro \
  -v ~/.azure:/root/.azure:ro \
  lme-cluster-installer \
  bash

# Inside container:
cd /workspace/testing/v2/installers/cluster_installer
./setup_cluster.sh -d
```
