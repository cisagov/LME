#!/bin/bash

# LME Disk Expansion Script for RHEL Systems
# This script fixes the common issue where RHEL auto-partitioning doesn't use the full disk
# Doubles the root partition size and allocates remaining space to /var

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
    local root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local root_size=$(df -h / | awk 'NR==2 {print $2}')
    local var_usage=$(df /var | awk 'NR==2 {print $5}' | sed 's/%//')
    local var_size=$(df -h /var | awk 'NR==2 {print $2}')
    
    log "Current / filesystem: ${root_size} (${root_usage}% used)"
    log "Current /var filesystem: ${var_size} (${var_usage}% used)"
    
    # Check disk space usage vs total disk size
    local disk_size_bytes=$(lsblk -b -n -o SIZE /dev/sda | head -1)
    local used_space_bytes=$(df --output=used / /var | tail -n +2 | awk '{sum += $1} END {print sum * 1024}')
    local usage_percent=$((used_space_bytes * 100 / disk_size_bytes))
    
    if [[ $usage_percent -lt 80 ]]; then
        warning "Disk usage is only ${usage_percent}% - expansion recommended"
        return 0
    else
        success "Disk usage is ${usage_percent}% - expansion may not be needed"
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

# Function to check and fix GPT table non-interactively
check_and_fix_gpt() {
    local disk="/dev/sda"
    log "Checking GPT partition table..."
    
    # Use parted in script mode with --fix to handle GPT issues non-interactively
    if ! parted --script --fix "$disk" print > /dev/null 2>&1; then
        error "Failed to read or fix partition table"
    fi
    
    success "GPT table checked and fixed if needed"
}

# Function to get partition information
get_partition_info() {
    local disk="/dev/sda"
    
    # Get current partition layout
    log "Analyzing current partition layout..."
    parted --script "$disk" print free
    
    # Find the root partition (usually mounted at /)
    local root_partition=$(df / | awk 'NR==2 {print $1}' | grep -o 'sda[0-9]*')
    local root_part_num=${root_partition#sda}
    
    # Get current root partition size and end
    local root_info=$(parted --script "$disk" print | grep "^ *$root_part_num ")
    local root_start=$(echo "$root_info" | awk '{print $2}')
    local root_end=$(echo "$root_info" | awk '{print $3}')
    local root_size=$(echo "$root_info" | awk '{print $4}')
    
    log "Root partition ($root_partition): Start=$root_start, End=$root_end, Size=$root_size"
    
    # Get total disk size
    local disk_end=$(parted --script "$disk" print | grep "^Disk /dev/sda:" | awk '{print $3}')
    log "Total disk size: $disk_end"
    
    echo "$root_part_num|$root_start|$root_end|$root_size|$disk_end"
}

# Function to calculate new partition sizes
calculate_new_sizes() {
    local partition_info="$1"
    IFS='|' read -r root_part_num root_start root_end root_size disk_end <<< "$partition_info"
    
    # Convert sizes to MB for calculation
    local root_size_mb=$(echo "$root_size" | sed 's/GB/000/' | sed 's/MB//' | sed 's/\..*//')
    local disk_end_mb=$(echo "$disk_end" | sed 's/GB/000/' | sed 's/MB//' | sed 's/\..*//')
    local root_start_mb=$(echo "$root_start" | sed 's/GB/000/' | sed 's/MB//' | sed 's/\..*//')
    
    # Double the root partition size
    local new_root_size_mb=$((root_size_mb * 2))
    local new_root_end_mb=$((root_start_mb + new_root_size_mb))
    
    # Calculate /var partition start and end
    local var_start_mb=$((new_root_end_mb + 1))
    local var_end_mb=$disk_end_mb
    
    log "Calculated sizes:"
    log "  Root partition: ${root_start_mb}MB - ${new_root_end_mb}MB (${new_root_size_mb}MB)"
    log "  Var partition: ${var_start_mb}MB - ${var_end_mb}MB ($((var_end_mb - var_start_mb))MB)"
    
    echo "${root_part_num}|${new_root_end_mb}MB|${var_start_mb}MB|${var_end_mb}MB"
}

# Function to expand and repartition disk
expand_disk() {
    local disk="/dev/sda"
    
    log "Starting disk expansion process..."
    
    # Check and fix GPT table
    check_and_fix_gpt
    
    # Get partition information
    local partition_info=$(get_partition_info)
    local new_sizes=$(calculate_new_sizes "$partition_info")
    IFS='|' read -r root_part_num new_root_end var_start var_end <<< "$new_sizes"
    
    # Check if we have LVM setup
    local vg_name=""
    if command -v vgdisplay >/dev/null 2>&1; then
        vg_name=$(vgdisplay 2>/dev/null | grep "VG Name" | head -1 | awk '{print $3}' || echo "")
    fi
    
    if [[ -n "$vg_name" ]]; then
        log "LVM detected with volume group: $vg_name"
        expand_with_lvm "$disk" "$root_part_num" "$new_root_end" "$var_start" "$var_end" "$vg_name"
    else
        log "No LVM detected - using direct partition expansion"
        expand_without_lvm "$disk" "$root_part_num" "$new_root_end" "$var_start" "$var_end"
    fi
    
    return 0
}

# Function to expand with LVM
expand_with_lvm() {
    local disk="$1"
    local root_part_num="$2"
    local new_root_end="$3"
    local var_start="$4"
    local var_end="$5"
    local vg_name="$6"
    
    # Find the LVM partition (usually the last one)
    local lvm_part_num=$(parted --script "$disk" print | grep "lvm" | tail -1 | awk '{print $1}')
    local lvm_partition="/dev/sda${lvm_part_num}"
    
    log "Expanding LVM partition ${lvm_partition} to use full disk..."
    
    # Expand the LVM partition to use all available space
    parted --script "$disk" resizepart "$lvm_part_num" 100%
    success "LVM partition expanded"
    
    # Resize physical volume
    log "Resizing physical volume..."
    pvresize "$lvm_partition"
    success "Physical volume resized"
    
    # Get available free space (in MB) robustly
    local total_free_mb=$(vgs "$vg_name" --noheadings --units m --nosuffix -o vg_free | awk '{print int($1)}')
    log "Available free space in VG ${vg_name}: ${total_free_mb} MB"
    
    if [[ -z "${total_free_mb}" ]] || [[ "${total_free_mb}" -le 0 ]]; then
        warning "No free space available in volume group"
        return 1
    fi
    
    # Determine logical volumes for / and /var
    local root_lv=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    if [[ -z "$root_lv" ]]; then
        root_lv="/dev/${vg_name}/rootlv"
    fi
    local var_lv=$(findmnt -n -o SOURCE /var 2>/dev/null || true)
    if [[ -n "$var_lv" ]] && [[ "$var_lv" == "$root_lv" ]]; then
        var_lv=""
    fi
    
    # Get current root LV size (in MB)
    local current_root_mb=$(lvs --noheadings --units m --nosuffix -o LV_SIZE "$root_lv" 2>/dev/null | awk '{print int($1)}')
    if [[ -z "$current_root_mb" ]]; then
        error "Unable to determine current root LV size for $root_lv"
    fi
    
    # Target: double root size, remainder to /var
    local desired_root_mb=$((current_root_mb * 2))
    local required_increase_mb=$((desired_root_mb - current_root_mb))
    if [[ "$required_increase_mb" -le 0 ]]; then
        required_increase_mb=0
    fi
    
    local root_expand_mb=$required_increase_mb
    if [[ "$root_expand_mb" -gt "$total_free_mb" ]]; then
        root_expand_mb=$total_free_mb
    fi
    local var_expand_mb=$((total_free_mb - root_expand_mb))
    
    # Extend root logical volume
    log "Extending root logical volume ($root_lv) by ${root_expand_mb}MB..."
    if [[ $root_expand_mb -gt 0 ]]; then
        lvextend -L "+${root_expand_mb}m" "$root_lv"
    else
        log "Root LV already at or above desired size; skipping root extension"
    fi
    if [[ -e "$root_lv" ]] && [[ $root_expand_mb -gt 0 ]]; then
        # Grow root filesystem
        log "Growing root filesystem..."
        if [[ "$(findmnt -n -o FSTYPE /)" == "xfs" ]]; then
            xfs_growfs /
        else
            resize2fs "$root_lv"
        fi
        success "Root filesystem extended"
    fi
    
    # Extend /var logical volume if present
    if [[ -n "$var_lv" ]] && [[ -e "$var_lv" ]] && [[ $var_expand_mb -gt 0 ]]; then
        log "Extending /var logical volume ($var_lv) by ${var_expand_mb}MB..."
        lvextend -L "+${var_expand_mb}m" "$var_lv"
        
        # Grow /var filesystem
        log "Growing /var filesystem..."
        if [[ "$(findmnt -n -o FSTYPE /var)" == "xfs" ]]; then
            xfs_growfs /var
        else
            resize2fs "$var_lv"
        fi
        success "/var filesystem extended"
    else
        # If no separate /var LV, allocate any remaining space to root
        if [[ $var_expand_mb -gt 0 ]]; then
            log "No separate /var LV found; allocating remaining ${var_expand_mb}MB to root..."
            lvextend -L "+${var_expand_mb}m" "$root_lv"
            if [[ "$(findmnt -n -o FSTYPE /)" == "xfs" ]]; then
                xfs_growfs /
            else
                resize2fs "$root_lv"
            fi
        fi
    fi
}

# Function to expand without LVM (direct partitions)
expand_without_lvm() {
    local disk="$1"
    local root_part_num="$2"
    local new_root_end="$3"
    local var_start="$4"
    local var_end="$5"
    
    log "Expanding root partition to ${new_root_end}..."
    parted --script "$disk" resizepart "$root_part_num" "$new_root_end"
    
    # Grow root filesystem
    log "Growing root filesystem..."
    local root_partition="/dev/sda${root_part_num}"
    if mount | grep -q "xfs.*on / "; then
        xfs_growfs /
    else
        resize2fs "$root_partition"
    fi
    success "Root partition and filesystem expanded"
    
    # Create new partition for /var if there's remaining space
    local remaining_space_mb=$(($(echo "$var_end" | sed 's/MB//') - $(echo "$var_start" | sed 's/MB//')))
    if [[ $remaining_space_mb -gt 1000 ]]; then  # Only if more than 1GB
        log "Creating new partition for /var expansion..."
        local new_var_part_num=$((root_part_num + 1))
        parted --script "$disk" mkpart primary ext4 "$var_start" "$var_end"
        
        # Format the new partition
        local new_var_partition="/dev/sda${new_var_part_num}"
        log "Formatting new partition ${new_var_partition}..."
        mkfs.ext4 -F "$new_var_partition"
        
        success "New partition created for /var expansion"
        warning "Manual steps required:"
        warning "1. Mount new partition: mount ${new_var_partition} /mnt"
        warning "2. Copy /var data: cp -a /var/* /mnt/"
        warning "3. Update /etc/fstab to mount ${new_var_partition} at /var"
        warning "4. Reboot to activate new /var mount"
    fi
}

# Function to verify results
verify_expansion() {
    log "Verifying disk expansion results..."
    
    # Show new disk layout
    echo
    log "=== Final Disk Layout ==="
    lsblk | grep -E "(sda|rootvg|centos|rhel)"
    
    echo
    log "=== Root Filesystem Status ==="
    df -h /
    
    echo
    log "=== /var Filesystem Status ==="
    df -h /var
    
    # Check for LVM
    if command -v vgdisplay >/dev/null 2>&1; then
        local vg_name=$(vgdisplay 2>/dev/null | grep "VG Name" | head -1 | awk '{print $3}' || echo "")
        if [[ -n "$vg_name" ]]; then
            echo
            log "=== Volume Group Status ==="
            vgdisplay "$vg_name" | grep -E "(VG Size|Free.*Size)"
        fi
    fi
    
    # Calculate expansion success
    local root_size_gb=$(df / | awk 'NR==2 {print $2}' | awk '{print int($1/1024/1024)}')
    local var_size_gb=$(df /var | awk 'NR==2 {print $2}' | awk '{print int($1/1024/1024)}')
    
    success "Disk expansion completed!"
    success "Root (/) filesystem: ${root_size_gb}GB"
    success "/var filesystem: ${var_size_gb}GB"
}

# Main execution
main() {
    log "LME RHEL Disk Expansion Script Starting..."
    log "This script will double the root partition and allocate remaining space to /var"
    
    # Check if expansion is needed
    if ! check_disk_space; then
        if [[ "${1:-}" != "--force" ]]; then
            log "Disk expansion may not be needed - use --force to proceed anyway"
            exit 0
        fi
    fi
    
    # Confirm with user unless --yes flag is provided
    if [[ "${1:-}" != "--yes" ]] && [[ "${1:-}" != "--force" ]]; then
        echo
        warning "This script will modify your disk partitions."
        warning "It will double the root partition size and allocate remaining space to /var."
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
        success "Root partition has been doubled and /var has been allocated remaining space"
        echo
        log "You can now proceed with LME installation"
    else
        error "Disk expansion failed - check the logs above"
    fi
}

# Script usage
show_usage() {
    echo "Usage: $0 [--yes|--force]"
    echo "  --yes     Skip confirmation prompts (for automation)"
    echo "  --force   Force expansion even if not deemed necessary"
    echo
    echo "This script expands RHEL disk partitions:"
    echo "- Doubles the root (/) partition size"
    echo "- Allocates remaining space to /var"
    echo "- Works with both LVM and direct partitions"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    --yes|--force)
        main "$1"
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
