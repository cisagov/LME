# SELinux Integration for LME with Nix and Podman

## Overview

This document describes the comprehensive SELinux integration implemented in LME to support Nix-installed Podman with systemd quadlets across different environments. **The integration automatically detects and adapts to your environment** - no manual configuration required!

## Automatic Environment Detection

The LME Ansible roles automatically detect your environment and apply the appropriate configuration:

### 🔴 **RHEL with SELinux ENABLED** 
```
✅ Full SELinux Integration Applied
```
- **Detection:** `ansible_os_family == "RedHat"` AND `ansible_selinux.status == "enabled"`
- **Configuration:** Complete SELinux policies, file contexts, booleans, and custom modules
- **Quadlet Workaround:** Manual generator execution (systemd issue on RHEL)
- **Result:** Secure, fully functional container environment

### 🟡 **RHEL with SELinux DISABLED**
```
✅ Standard Configuration (No SELinux Policies)
```
- **Detection:** `ansible_os_family == "RedHat"` AND `ansible_selinux.status != "enabled"`  
- **Configuration:** Standard file permissions, no SELinux policies
- **Quadlet Workaround:** Manual generator execution (systemd issue still exists)
- **Result:** Functional container environment with standard security

### 🟢 **Ubuntu/Debian (No SELinux)**
```
✅ Standard Configuration (Native systemd Support)
```
- **Detection:** `ansible_os_family != "RedHat"`
- **Configuration:** Standard file permissions and systemd quadlet processing
- **Quadlet Workaround:** Skipped (systemd works correctly on these platforms)
- **Result:** Functional container environment using native systemd features

## Background

When using Nix-installed container tools on SELinux-enforced systems, multiple compatibility issues arise due to:
- Incorrect SELinux contexts on Nix store binaries
- Missing domain transition permissions for containers
- Insufficient capabilities for container operations
- Complex symlink chains with wrong contexts

## Issues Addressed (SELinux-Enabled Systems Only)

### 1. Podman Generator Chain Issues ✅
**Problem:** systemd cannot execute the Podman quadlet generator
- `/usr/lib/systemd/system-generators/podman-system-generator` → `/nix/store/.../podman-system-generator` → `/nix/store/.../libexec/podman/quadlet`
- Wrong SELinux contexts prevent systemd (`init_t`) from executing

**Solution:** Set `init_exec_t` context for entire generator chain
```yaml
# File contexts
/nix/store/.*/libexec/podman/quadlet -> init_exec_t
/nix/store/.*/lib/systemd/system-generators/podman-system-generator -> init_exec_t
```

### 2. Nix Profile Symlink Issues ✅
**Problem:** systemd reads Nix profile but gets access denied
- `/nix/var/nix/profiles/default` has `default_t` instead of `bin_t`

**Solution:** Fix profile symlink context
```yaml
/nix/var/nix/profiles/default -> bin_t
```

### 3. Podman Binary Context Issues ✅  
**Problem:** Podman "binary" is actually a bash script wrapper
- Script has wrong context preventing execution

**Solution:** Set proper contexts for script and interpreter
```yaml
/nix/store/.*/bin/podman -> bin_t       # Wrapper script
/nix/store/.*/bin/bash -> shell_exec_t  # Bash interpreter  
```

### 4. Dynamic Linker Issues ✅
**Problem:** Nix binaries use custom glibc dynamic linker
- `/nix/store/.../lib/ld-linux-x86-64.so.2` has `default_t` instead of `ld_so_t`

**Solution:** Fix dynamic linker contexts
```yaml
/nix/store/.*/lib/ld-linux-x86-64.so.2 -> ld_so_t
```

### 5. Container Domain Transitions ✅
**Problem:** systemd services can't transition to container domain
- `unconfined_service_t` → `container_t` transition denied

**Solution:** Custom SELinux policy module
```selinux
allow unconfined_service_t container_t:process transition;
```

### 6. Container Filesystem Operations ✅
**Problem:** Containers need special capabilities for mounts, networking, etc.

**Solution:** Enable container SELinux booleans
```yaml
virt_sandbox_use_fusefs: on      # FUSE filesystems
virt_sandbox_use_sys_admin: on   # Mount operations  
virt_sandbox_use_mknod: on       # Device nodes
virt_sandbox_use_netlink: on     # Network operations
```

### 7. Java Application Permissions ✅
**Problem:** Java (Elasticsearch) needs executable memory
- `execmem` permission denied in containers

**Solution:** Enable executable memory permissions
```yaml
selinuxuser_execheap: on    # Executable heap
selinuxuser_execmod: on     # Memory modifications
selinuxuser_execstack: on   # Executable stack
```

**Custom policy for containers:**
```selinux
allow container_t self:process execmem;
allow container_t self:udp_socket create;
```

## Implementation

### Automated via Ansible Roles

The integration is fully automated with **environment auto-detection**:

#### `roles/nix/tasks/selinux_integration.yml`
- **Auto-detects** SELinux status and OS family
- **SELinux-enabled systems:** Full integration (contexts, booleans, policies)
- **Non-SELinux systems:** Standard configuration with informational messages
- **Smart conditionals:** All SELinux tasks use `when: ansible_os_family == "RedHat" and ansible_selinux.status == "enabled"`

#### `roles/podman/tasks/quadlet_setup.yml`  
- **RHEL:** Implements quadlet generator workaround
- **Ubuntu/Debian:** Uses standard systemd quadlet processing  
- **All systems:** Enables services and applies appropriate permissions

### Configuration Variables

Control the integration via variables (optional - defaults work for all environments):

```yaml
# In roles/nix/defaults/main.yml
verify_podman_generator: false  # Run verification tests (RHEL/SELinux only)
selinux_debug_mode: false       # Enable debug output

# In roles/podman/defaults/main.yml  
enable_quadlet_generator_workaround: true  # Manual service generation (RHEL only)
quadlet_services_auto_enable: true         # Auto-enable services (all systems)
```

## Verification

### Environment Detection
The roles display environment detection information:
```
🔍 ENVIRONMENT DETECTION:
OS Family: RedHat
SELinux Status: enabled
Quadlet Generator Workaround: ENABLED
```

### Check SELinux Status (RHEL only)
```bash
# Verify SELinux is enforcing
sudo getenforce

# Check for denials
sudo ausearch -m AVC -ts recent | grep -E "(podman|container)"
```

### Test Generator (RHEL only)
```bash
# Test quadlet generator manually
sudo /usr/lib/systemd/system-generators/podman-system-generator /tmp/test /tmp/test /tmp/test
```

### Verify Services (All Systems)
```bash
# List LME services
sudo systemctl list-units "lme*" --type=service --all

# Check specific services  
sudo systemctl status lme-elasticsearch.service
sudo systemctl status lme-kibana.service
```

### Check Custom Policies (SELinux systems only)
```bash
# List installed SELinux modules
sudo semodule -l | grep -E "(podman|java|container|nix)"

# Expected modules on SELinux systems:
# - nix_container_runtime  
# - podman_container_transition
# - java_container_permissions
```

## Troubleshooting

### Environment-Specific Issues

#### **RHEL with SELinux**
1. **Services not visible in systemctl**
   - Check `/etc/containers/systemd/` permissions (should be 755)
   - Verify SELinux policies are installed: `sudo semodule -l | grep -E "(podman|java|container)"`
   - Check for SELinux denials: `sudo ausearch -m AVC -ts recent`

2. **Container start failures**
   - Verify container booleans: `sudo getsebool -a | grep virt_sandbox`
   - Check custom SELinux policies are installed
   - Look for execmem or network denials

#### **RHEL without SELinux**
1. **Services not starting**
   - Check quadlet generator workaround ran: `ls /etc/systemd/system/lme-*.service`
   - Verify permissions: `ls -la /etc/containers/systemd/`

#### **Ubuntu/Debian**
1. **Services not appearing**
   - Check quadlet files: `ls -la /etc/containers/systemd/`
   - Verify systemd daemon reload: `sudo systemctl daemon-reload`
   - Check systemd logs: `sudo journalctl -u systemd`

### Debug Commands

#### **SELinux Systems (RHEL)**
```bash
# Check SELinux booleans
sudo getsebool -a | grep virt_sandbox

# Verify file contexts
sudo ls -laZ /nix/var/nix/profiles/default
sudo ls -laZ /usr/lib/systemd/system-generators/podman-system-generator

# Monitor SELinux in real-time
sudo ausearch -m AVC -ts recent --follow
```

#### **All Systems**
```bash
# Check systemd quadlet processing
sudo systemctl daemon-reload
sudo journalctl -u systemd --since "5 minutes ago"

# Verify LME services
sudo systemctl list-units "lme*" --all
sudo systemctl status lme.service
```

## Platform Support Matrix

| Platform | SELinux | Auto-Detection | Configuration Applied |
|----------|---------|----------------|----------------------|
| **RHEL 9** | ✅ Enabled | ✅ Automatic | Full SELinux integration + Quadlet workaround |
| **RHEL 9** | ❌ Disabled | ✅ Automatic | Standard config + Quadlet workaround |
| **Ubuntu** | N/A | ✅ Automatic | Standard config (native systemd quadlet support) |
| **Debian** | N/A | ✅ Automatic | Standard config (native systemd quadlet support) |

## Maintenance

### Updates
- **SELinux contexts:** Applied automatically on every run
- **Policies:** Persistent across reboots and system updates
- **File contexts:** Survive Nix store updates via permanent rules
- **Environment detection:** Automatic - no configuration needed

### Monitoring
- **SELinux systems:** Check logs regularly for new denials
- **All systems:** Verify services after system updates
- **Updates:** Policies adapt automatically to new container images


The roles automatically:
- 🔍 **Detect** your environment (OS + SELinux status)
- 🔧 **Configure** appropriate settings for your platform
- 🛡️ **Apply** SELinux policies only where needed
- ✅ **Enable** services using the right method for your system
- 📋 **Report** what was configured and why

## Architecture Benefits

This environment-aware integration provides:
- 🔒 **Universal Security:** Full SELinux enforcement where available, secure defaults elsewhere
- ⚡ **Performance:** No unnecessary overhead on systems that don't need SELinux policies
- 🔧 **Reliability:** Platform-specific optimizations prevent configuration errors  
- 📈 **Scalability:** Works identically across mixed infrastructure (RHEL + Ubuntu)
- 🛡️ **Compliance:** Meets security requirements automatically
- 🚀 **Simplicity:** Zero manual configuration - works everywhere out of the box

The integration ensures LME operates optimally on any supported Linux distribution while automatically applying the highest security posture available for each platform.