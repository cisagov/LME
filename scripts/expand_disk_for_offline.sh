#!/bin/bash

# LME Disk Expansion Script for Offline Preparation
# This script expands the disk with BALANCED allocation suitable for offline resources
# Unlike expand_rhel_disk.sh which gives most space to /var, this gives equal space to root and /var

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

# Show current status
show_current_status() {
    log "=== Current Disk Usage ==="
    df -h | grep -E "(Filesystem|/dev/mapper|/dev/sda)"
    echo
    
    log "=== Current LVM Layout ==="
    lvs --units g 2>/dev/null || true
    echo
    
    log "=== Physical Disk Layout ==="
    parted --script /dev/sda print free 2>/dev/null || true
    echo
}

# Backup partition table and LVM config
backup_config() {
    local backup_file="/root/disk_backup_$(date +%Y%m%d_%H%M%S).txt"
    log "Creating backup: $backup_file"
    
    {
        echo "=== Disk Backup $(date) ==="
        echo
        echo "=== Partition Table ==="
        sfdisk -d /dev/sda
        echo
        echo "=== LVM Configuration ==="
        pvs
        vgs
        lvs
        echo
        echo "=== Filesystem Mounts ==="
        df -h
    } > "$backup_file"
    
    success "Backup saved to $backup_file"
}

# Expand physical partition
expand_physical_partition() {
    local disk="/dev/sda"
    
    log "Step 1: Expanding physical LVM partition..."
    
    # Fix GPT table
    log "Fixing GPT table to use all disk space..."
    parted --script --fix "$disk" print > /dev/null 2>&1 || true
    
    # Find LVM partition
    local lvm_part_num=$(parted --script "$disk" print | grep "lvm" | tail -1 | awk '{print $1}')
    if [[ -z "$lvm_part_num" ]]; then
        error "Could not find LVM partition"
    fi
    
    local lvm_partition="/dev/sda${lvm_part_num}"
    log "Found LVM partition: ${lvm_partition}"
    
    # Expand to 100%
    log "Expanding ${lvm_partition} to use 100% of disk..."
    if ! parted --script "$disk" resizepart "$lvm_part_num" 100%; then
        error "Failed to expand partition"
    fi
    success "Partition expanded to 100% of disk"
    
    # Resize physical volume
    log "Resizing physical volume..."
    if ! pvresize "$lvm_partition"; then
        error "Failed to resize physical volume"
    fi
    success "Physical volume resized"
}

# Expand logical volumes with balanced allocation
expand_logical_volumes() {
    log "Step 2: Expanding logical volumes with balanced allocation..."
    
    # Get volume group name
    local vg_name=$(vgdisplay 2>/dev/null | grep "VG Name" | head -1 | awk '{print $3}')
    if [[ -z "$vg_name" ]]; then
        error "Could not find volume group"
    fi
    
    log "Volume group: $vg_name"
    
    # Get free space
    local vg_free_gb=$(vgs --noheadings --units g --nosuffix -o VG_FREE "$vg_name" | awk '{print int($1)}')
    log "Available free space: ${vg_free_gb}GB"
    
    if [[ $vg_free_gb -lt 10 ]]; then
        error "Not enough free space (${vg_free_gb}GB). Need at least 10GB."
    fi
    
    # Calculate allocation (split free space between /home, /var, and root)
    # /home needs ~42GB total for LME repo and offline_resources (currently 1GB, need +41GB)
    # /var needs ~100GB total for containers/logs (currently 8GB, need +92GB)
    # root/usr/tmp get remainder

    # Target: /home gets 20% of free space (~42GB final)
    #         /var gets 44% of free space (~100GB final)
    #         remainder goes to root/usr/tmp (36%)

    local home_expand_gb=$((vg_free_gb * 20 / 100))  # 20% to /home
    local var_expand_gb=$((vg_free_gb * 44 / 100))   # 44% to /var
    local root_expand_gb=$((vg_free_gb - home_expand_gb - var_expand_gb))  # remainder to root

    log "Will expand:"
    log "  - /home: +${home_expand_gb}GB (20% - for LME repo and offline_resources, target ~42GB total)"
    log "  - /var: +${var_expand_gb}GB (44% - for containers/logs, target ~100GB total)"
    log "  - Root: +${root_expand_gb}GB (36% - remainder)"

    # Find logical volumes
    local root_lv=$(findmnt -n -o SOURCE / 2>/dev/null)
    local var_lv=$(findmnt -n -o SOURCE /var 2>/dev/null)
    local home_lv=$(findmnt -n -o SOURCE /home 2>/dev/null)

    if [[ -z "$root_lv" ]]; then
        error "Could not find root logical volume"
    fi

    if [[ -z "$var_lv" ]]; then
        error "Could not find /var logical volume"
    fi

    if [[ -z "$home_lv" ]]; then
        error "Could not find /home logical volume"
    fi

    log "Root LV: $root_lv"
    log "Var LV: $var_lv"
    log "Home LV: $home_lv"
    
    # Expand /home FIRST (most important for offline_resources)
    log "Expanding /home by ${home_expand_gb}GB..."
    if ! lvextend -L "+${home_expand_gb}g" "$home_lv"; then
        error "Failed to extend /home LV"
    fi

    # Grow /home filesystem
    local home_fs=$(findmnt -n -o FSTYPE /home)
    log "Growing /home filesystem (type: $home_fs)..."
    if [[ "$home_fs" == "xfs" ]]; then
        xfs_growfs /home
    else
        resize2fs "$home_lv"
    fi
    success "/home expanded by ${home_expand_gb}GB"

    # Expand /var
    log "Expanding /var by ${var_expand_gb}GB..."
    if ! lvextend -L "+${var_expand_gb}g" "$var_lv"; then
        error "Failed to extend /var LV"
    fi

    # Grow /var filesystem
    local var_fs=$(findmnt -n -o FSTYPE /var)
    log "Growing /var filesystem (type: $var_fs)..."
    if [[ "$var_fs" == "xfs" ]]; then
        xfs_growfs /var
    else
        resize2fs "$var_lv"
    fi
    success "/var expanded by ${var_expand_gb}GB"

    # Expand root (if there's space left)
    if [[ $root_expand_gb -gt 0 ]]; then
        log "Expanding root by ${root_expand_gb}GB..."
        if ! lvextend -L "+${root_expand_gb}g" "$root_lv"; then
            error "Failed to extend root LV"
        fi

        # Grow root filesystem
        local root_fs=$(findmnt -n -o FSTYPE /)
        log "Growing root filesystem (type: $root_fs)..."
        if [[ "$root_fs" == "xfs" ]]; then
            xfs_growfs /
        else
            resize2fs "$root_lv"
        fi
        success "Root expanded by ${root_expand_gb}GB"
    else
        log "Skipping root expansion (no space remaining)"
    fi
}

# Show final status
show_final_status() {
    echo
    log "=== Final Disk Usage ==="
    df -h | grep -E "(Filesystem|/dev/mapper|/dev/sda)"
    echo
    
    log "=== Final LVM Layout ==="
    lvs --units g
    echo
    
    log "=== Volume Group Status ==="
    vgs --units g
    echo
}

# Main execution
main() {
    log "LME Disk Expansion for Offline Preparation"
    log "This script expands disk with allocation optimized for offline resources:"
    log "  - /home gets 20% (for LME repo and offline_resources, target ~42GB total)"
    log "  - /var gets 44% (for containers/logs, target ~100GB total)"
    log "  - root gets 36% (remainder)"
    echo
    
    # Show current status
    show_current_status
    
    # Confirm with user
    if [[ "${1:-}" != "--yes" ]]; then
        warning "This will expand the disk with allocation optimized for offline preparation:"
        warning "  - /home: 20% of free space (target ~42GB total for offline_resources)"
        warning "  - /var: 44% of free space (target ~100GB total for containers)"
        warning "  - root: 36% of free space (remainder)"
        echo
        read -p "Do you want to continue? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Backup
    backup_config
    
    # Expand physical partition
    expand_physical_partition
    
    # Expand logical volumes
    expand_logical_volumes
    
    # Show final status
    show_final_status
    
    success "=== DISK EXPANSION COMPLETED ==="
    success "/home, /var, and root have been expanded"
    success "/home now has space for offline_resources"
    success "You can now run prepare_offline.sh from /home/lme-user/LME"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [--yes]"
        echo "  --yes     Skip confirmation prompts"
        echo
        echo "Expands disk with balanced allocation for offline preparation"
        exit 0
        ;;
    --yes)
        main "$1"
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        ;;
esac

