# CA Certificate Path Compatibility Issue

## Overview

Red Hat Enterprise Linux (RHEL) and Fedora-based systems use a different file system layout for CA certificates compared to Debian/Ubuntu systems. This creates a compatibility issue when running containers that expect Debian-style certificate paths.

## The Problem

### Certificate Path Differences

**Red Hat/Fedora Systems:**
```
/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem    # Main CA certificate bundle
/etc/pki/ca-trust/extracted/pem/ca-bundle.crt        # Alternative format
/etc/ssl/certs/ca-bundle.crt                         # Symlink to PKI location
```

**Debian/Ubuntu Systems:**
```
/etc/ssl/certs/ca-certificates.crt                   # Main CA certificate bundle
/usr/share/ca-certificates/                          # Individual certificates
```

### Container Impact

LME containers, particularly Kibana, are configured to mount the system's CA certificate bundle for validating external SSL connections:

```yaml
# From quadlet/lme-kibana.container
Volume=/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
```

**The Issue:** When running on RHEL/Fedora hosts, this file path doesn't exist by default, causing container startup failures with:
```
Error: statfs /etc/ssl/certs/ca-certificates.crt: no such file or directory
```

## The Solution

### Automatic Workaround (Ansible)

The LME Ansible installation automatically creates the required compatibility symlink on Red Hat family systems:

```yaml
# From ansible/roles/base/tasks/redhat.yml
- name: Create CA certificates symlink for compatibility (Red Hat systems)
  file:
    src: /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
    dest: /etc/ssl/certs/ca-certificates.crt
    state: link
    force: yes
  become: yes
  when: ansible_os_family == 'RedHat'
```

### Manual Workaround

If running containers manually or troubleshooting, create the symlink on the host system:

```bash
# Create the target directory if it doesn't exist
sudo mkdir -p /etc/ssl/certs

# Create the compatibility symlink
sudo ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/certs/ca-certificates.crt

# Verify the symlink
ls -la /etc/ssl/certs/ca-certificates.crt
```

## Technical Details

### Certificate Content

Both files contain the same content - hundreds of trusted root CA certificates in PEM format:
```
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIEkjCCA3qgAwIBAgIQCgFBQgAAAVOFc2oLheynCDANBgkqhkiG9w0BAQsFADA/...
-----END CERTIFICATE-----
[hundreds more certificates...]
```

### LME Certificate Architecture

LME uses a two-tier certificate system:

1. **System CA Certificates** (this fix addresses):
   - Purpose: Validate external SSL connections
   - Location: `/etc/ssl/certs/ca-certificates.crt` (symlinked)
   - Used by: Package downloads, external API calls, health checks

2. **Internal LME Certificates**:
   - Purpose: Secure inter-service communication
   - Location: `lme_certs` volume
   - Contains: Internal CA, service certificates for Elasticsearch, Kibana, etc.

### Why This Matters

Without the system CA bundle available at the expected path:
- Containers fail to start due to mount point errors
- SSL certificate validation fails for external connections
- Health checks and API calls cannot verify certificate authenticity
- Package downloads and updates may fail

## Verification

After applying the fix, verify the setup:

```bash
# Check that the symlink exists
ls -la /etc/ssl/certs/ca-certificates.crt

# Verify it points to the correct file
readlink /etc/ssl/certs/ca-certificates.crt

# Test that containers can access it
docker run --rm -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \
  registry.access.redhat.com/ubi9/ubi:latest \
  cat /etc/ssl/certs/ca-certificates.crt | head -5
```

## Container Development Notes

When developing containers for cross-platform compatibility:

1. **Use flexible CA paths**: Check for both Debian and Red Hat certificate locations
2. **Document certificate requirements**: Clearly specify which certificate files containers need
3. **Test on multiple base images**: Verify compatibility with both UBI and Ubuntu base images
4. **Consider init containers**: Use setup containers to create necessary symlinks if needed

## Related Files

- `ansible/roles/base/tasks/redhat.yml` - Automatic symlink creation
- `quadlet/lme-kibana.container` - Container configuration requiring the certificate
- `quadlet/lme-elasticsearch.container` - Related certificate configuration