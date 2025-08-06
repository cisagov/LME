# SELinux Policies for Nix-Installed Container Runtime Tools

## Overview
This directory contains SELinux policy files (`.te` and `.fc`) that enable Nix-installed container runtime tools to work properly on SELinux-enforced systems like RHEL, CentOS, Rocky Linux, AlmaLinux, and Fedora.

## Policy Categories

### Base Nix Container Runtime
- **`nix_container_runtime.te/.fc`** - Core policy for Nix-installed container tools

### Core Container Policies (Originally Inline)
- **`podman-container-transition.te`** - Allow systemd services to transition to container domain
- **`java-container-permissions.te`** - Basic Java container permissions (execmem, UDP sockets, sysfs access)

### Java Runtime Policies (Post-Restart Fixes)
These policies address runtime issues that only appear when Elasticsearch fully initializes:

- **`java-cgroup-access.te`** - Allow containers to access cgroup files (`/sys/fs/cgroup/cpu.max`, `memory.max`)
- **`java-fusefs-socket.te`** - Create socket files in FUSE filesystem 
- **`java-fusefs-unlink.te`** - Delete socket files in FUSE filesystem
- **`java-fusefs-setattr.te`** - Set attributes on socket files in FUSE filesystem
- **`java-fusefs-rename.te`** - Rename socket files in FUSE filesystem
- **`java-udp-ioctl.te`** - Allow ioctl operations on UDP sockets
- **`java-random-access.te`** - Access `/dev/random` for entropy

### Elasticsearch-Specific Policies
- **`elasticsearch-ml-controller.te`** - Allow Elasticsearch ML controller to create FIFO files

### Podman Wrapper Policies
- **`podman-wrapper-exec.te`** - Execute podman wrapper files
- **`podman-wrapper-read.te`** - Read podman wrapper files  
- **`podman-wrapper-execute-no-trans.te`** - Execute wrapper without domain transition

## Installation
These policies are automatically compiled and installed by the `selinux_integration.yml` task when:
- `ansible_os_family == "RedHat"`
- `ansible_selinux.status == "enabled"`

## Total Modules: 15
- **File-based policies:** 14 (this directory) 
- **Original Nix policy:** 1 (uses both .te and .fc files)

All policies are now consistently file-based and managed through the same copy/compile/install process.

## Discovery Process
The additional 11 policies in this directory were discovered through systematic troubleshooting of SELinux denials during LME startup after system restarts. They address runtime issues that only manifest when:

- Elasticsearch fully initializes its JVM
- ML controllers start up  
- Java attach listeners create socket files
- System resource access occurs (cgroups, entropy)
- Network operations begin with ioctl calls

## Verification
After installation, verify all modules are loaded:
```bash
sudo semodule -l | grep -E "(java|elasticsearch|podman|nix)" | sort
```

Expected output should show all 15 modules.

## Environment Support
- ✅ **RHEL/CentOS + SELinux:** Full policy integration
- ✅ **RHEL/CentOS No SELinux:** Policies skipped automatically  
- ✅ **Ubuntu/Debian:** Policies skipped automatically (no SELinux)

The integration automatically detects the environment and applies appropriate configuration.