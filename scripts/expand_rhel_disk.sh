#!/bin/bash

# LME Disk Expansion Script for RHEL Systems
# This script fixes the common issue where RHEL auto-partitioning doesn't use the full disk
# Expands the main LVM partition and /var filesystem to use all available space

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Function to check if disk expansion is needed
check_disk_space() {
    local disk="/dev/sda"
    local var_usage=$(df /var | awk 'NR==2 {print $5}' | sed 's/%//')
    local var_size=$(df -h /var | awk 'NR==2 {print $2}')
    
    log "Current /var filesystem: ${var_size} (${var_usage}% used)"
    
    # Check if /var is less than 50GB (indicating it needs expansion)
    local var_size_gb=$(df /var | awk 'NR==2 {print $2}' | awk '{print int($1/1024/1024)}')
    if [[ $var_size_gb -lt 50 ]]; then
        warning "/var is only ${var_size_gb}GB - expansion recommended for LME deployment"
        return 0
    else
        success "/var is ${var_size_gb}GB - sufficient space available"
        return 1
    fi
}

# Function to backup partition table
backup_partition_table() {
    local backup_file="/root/partition_backup_$(date +%Y%m%d_%H%M%S).dump"
    log "Creating partition table backup: $backup_file"
    sfdisk -d /dev/sda > "$backup_file"
    success "Partition table backed up to $backup_file"
}

# Function to fix GPT and expand partition
expand_disk() {
    local disk="/dev/sda"
    local lvm_partition="/dev/sda4"
    
    log "Starting disk expansion process..."
    
    # Fix GPT table and get partition info
    log "Fixing GPT partition table..."
    parted $disk print 2>&1 | grep -q "fix the GPT" && {
        echo "Fix" | parted $disk print > /dev/null 2>&1
        success "GPT table fixed"
    } || {
        log "GPT table already correct"
    }
    
    # Get current disk size
    local disk_size=$(parted $disk print | grep "Disk.*:" | awk '{print $3}')
    log "Total disk size: $disk_size"
    
    # Expand partition 4 to use full disk
    log "Expanding LVM partition to use full disk..."
    parted $disk resizepart 4 100% 2>/dev/null || {
        # Alternative approach if 100% doesn't work
        parted $disk resizepart 4 $disk_size
    }
    success "LVM partition expanded"
    
    # Resize physical volume
    log "Resizing physical volume..."
    pvresize $lvm_partition
    success "Physical volume resized"
    
    # Get volume group name (usually rootvg for RHEL)
    local vg_name=$(pvdisplay $lvm_partition | grep "VG Name" | awk '{print $3}')
    log "Volume group: $vg_name"
    
    # Show available space
    local free_space=$(vgdisplay $vg_name | grep "Free.*Size" | awk '{print $6 $7}')
    log "Available free space: $free_space"
    
    if [[ "$free_space" == "0" ]]; then
        warning "No free space available in volume group"
        return 1
    fi
    
    # Extend /var logical volume
    log "Extending /var logical volume..."
    lvextend -l +100%FREE /dev/$vg_name/varlv
    success "/var logical volume extended"
    
    # Grow XFS filesystem
    log "Growing XFS filesystem..."
    xfs_growfs /var
    success "XFS filesystem grown"
    
    return 0
}

# Function to verify results
verify_expansion() {
    log "Verifying disk expansion results..."
    
    # Show new disk layout
    echo
    log "=== Final Disk Layout ==="
    lsblk | grep -E "(sda|rootvg)"
    
    echo
    log "=== /var Filesystem Status ==="
    df -h /var
    
    echo
    log "=== Volume Group Status ==="
    vgdisplay rootvg | grep -E "(VG Size|Free.*Size)"
    
    # Check if /var is now larger than 50GB
    local var_size_gb=$(df /var | awk 'NR==2 {print $2}' | awk '{print int($1/1024/1024)}')
    if [[ $var_size_gb -gt 50 ]]; then
        success "Disk expansion successful! /var is now ${var_size_gb}GB"
    else
        error "Disk expansion may have failed - /var is still only ${var_size_gb}GB"
    fi
}

# Main execution
main() {
    log "LME RHEL Disk Expansion Script Starting..."
    log "This script will expand your disk partitions to use full available space"
    
    # Check if expansion is needed
    if ! check_disk_space; then
        log "Disk expansion not needed - exiting"
        exit 0
    fi
    
    # Confirm with user unless --yes flag is provided
    if [[ "${1:-}" != "--yes" ]]; then
        echo
        warning "This script will modify your disk partitions."
        warning "While these operations are generally safe, always ensure you have backups."
        echo
        read -p "Do you want to continue? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Create backup
    backup_partition_table
    
    # Perform expansion
    if expand_disk; then
        verify_expansion
        echo
        success "=== DISK EXPANSION COMPLETED SUCCESSFULLY ==="
        success "Your system now has significantly more space for LME containers and data"
        echo
        log "You can now proceed with LME installation"
    else
        error "Disk expansion failed - check the logs above"
    fi
}

# Script usage
show_usage() {
    echo "Usage: $0 [--yes]"
    echo "  --yes    Skip confirmation prompts (for automation)"
    echo
    echo "This script expands RHEL disk partitions to use all available space."
    echo "Specifically designed for Azure VMs where auto-partitioning is conservative."
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    --yes)
        main --yes
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
