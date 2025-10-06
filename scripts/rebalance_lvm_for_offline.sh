#!/bin/bash

# LME LVM Rebalancing Script for Offline Preparation
# This script rebalances LVM logical volumes to provide sufficient space on root (/) 
# for offline resource preparation while reducing oversized /var allocation
#
# Target allocation:
# - Root (/): Expand to 30GB (sufficient for offline resources + OS)
# - /var: Reduce from 110GB to 80GB (still plenty for containers/logs)
# - /usr: Keep at 10GB
# - /tmp: Keep at 2GB  
# - /home: Keep at 2GB

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

# Function to display current disk usage
show_current_status() {
    log "=== Current Disk Usage ==="
    df -h | grep -E "(Filesystem|/dev/mapper|/dev/sda)"
    echo
    
    log "=== Current LVM Layout ==="
    lvs --units g 2>/dev/null || true
    echo
    
    log "=== Volume Group Status ==="
    vgs --units g 2>/dev/null || true
    echo
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for LVM tools
    if ! command -v lvs >/dev/null 2>&1; then
        error "LVM tools not found. This script requires LVM."
    fi
    
    # Check for XFS filesystem tools (RHEL default)
    if ! command -v xfs_growfs >/dev/null 2>&1; then
        warning "xfs_growfs not found - assuming ext4 filesystems"
    fi
    
    # Verify we have a volume group
    local vg_name=$(vgdisplay 2>/dev/null | grep "VG Name" | head -1 | awk '{print $3}' || echo "")
    if [[ -z "$vg_name" ]]; then
        error "No LVM volume group found. This script requires LVM setup."
    fi
    
    log "Found volume group: $vg_name"
    echo "$vg_name"
}

# Function to get logical volume info
get_lv_info() {
    local mount_point="$1"
    local lv_path=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null || echo "")
    
    if [[ -z "$lv_path" ]]; then
        echo ""
        return 1
    fi
    
    echo "$lv_path"
    return 0
}

# Function to get filesystem type
get_fs_type() {
    local mount_point="$1"
    local fs_type=$(findmnt -n -o FSTYPE "$mount_point" 2>/dev/null || echo "")
    echo "$fs_type"
}

# Function to get current LV size in GB
get_lv_size_gb() {
    local lv_path="$1"
    local size_gb=$(lvs --noheadings --units g --nosuffix -o LV_SIZE "$lv_path" 2>/dev/null | awk '{print int($1)}')
    echo "$size_gb"
}

# Function to get available space in VG
get_vg_free_space_gb() {
    local vg_name="$1"
    local free_gb=$(vgs --noheadings --units g --nosuffix -o VG_FREE "$vg_name" 2>/dev/null | awk '{print int($1)}')
    echo "$free_gb"
}

# Function to backup LVM configuration
backup_lvm_config() {
    local backup_file="/root/lvm_backup_$(date +%Y%m%d_%H%M%S).txt"
    log "Creating LVM configuration backup: $backup_file"
    
    {
        echo "=== LVM Backup $(date) ==="
        echo
        echo "=== Physical Volumes ==="
        pvs
        echo
        echo "=== Volume Groups ==="
        vgs
        echo
        echo "=== Logical Volumes ==="
        lvs
        echo
        echo "=== Filesystem Mounts ==="
        df -h
    } > "$backup_file"
    
    success "LVM configuration backed up to $backup_file"
}

# Function to reduce /var logical volume
reduce_var_lv() {
    local vg_name="$1"
    local var_lv="$2"
    local target_size_gb="$3"
    
    log "Preparing to reduce /var from current size to ${target_size_gb}GB..."
    
    # Get current size
    local current_size_gb=$(get_lv_size_gb "$var_lv")
    log "Current /var size: ${current_size_gb}GB"
    
    if [[ $current_size_gb -le $target_size_gb ]]; then
        warning "/var is already at or below target size. Skipping reduction."
        return 0
    fi
    
    # Check filesystem type
    local fs_type=$(get_fs_type "/var")
    log "Filesystem type for /var: $fs_type"
    
    if [[ "$fs_type" == "xfs" ]]; then
        error "Cannot shrink XFS filesystem. /var uses XFS which does not support shrinking.\n" \
              "You will need to:\n" \
              "1. Backup /var data\n" \
              "2. Recreate the logical volume at smaller size\n" \
              "3. Restore data\n" \
              "This script cannot automate XFS shrinking."
    fi
    
    # For ext4, we can shrink
    if [[ "$fs_type" == "ext4" ]] || [[ "$fs_type" == "ext3" ]]; then
        warning "Reducing ext4 filesystem requires unmounting /var"
        warning "This is risky and may require rescue mode or single-user mode"
        error "For safety, this script does not support online /var reduction.\n" \
              "Please use rescue mode or single-user mode to reduce /var manually."
    fi
    
    error "Unsupported filesystem type: $fs_type"
}

# Function to expand root logical volume
expand_root_lv() {
    local vg_name="$1"
    local root_lv="$2"
    local target_size_gb="$3"
    
    log "Preparing to expand root (/) to ${target_size_gb}GB..."
    
    # Get current size
    local current_size_gb=$(get_lv_size_gb "$root_lv")
    log "Current root size: ${current_size_gb}GB"
    
    if [[ $current_size_gb -ge $target_size_gb ]]; then
        success "Root is already at or above target size (${current_size_gb}GB >= ${target_size_gb}GB)"
        return 0
    fi
    
    # Calculate how much to expand
    local expand_gb=$((target_size_gb - current_size_gb))
    log "Will expand root by ${expand_gb}GB"
    
    # Check if we have enough free space in VG
    local vg_free_gb=$(get_vg_free_space_gb "$vg_name")
    log "Available space in volume group: ${vg_free_gb}GB"
    
    if [[ $vg_free_gb -lt $expand_gb ]]; then
        error "Not enough free space in volume group. Need ${expand_gb}GB but only ${vg_free_gb}GB available.\n" \
              "You need to free up space from other logical volumes first."
    fi
    
    # Extend the logical volume
    log "Extending logical volume ${root_lv} by ${expand_gb}GB..."
    if ! lvextend -L "+${expand_gb}g" "$root_lv"; then
        error "Failed to extend logical volume"
    fi
    success "Logical volume extended"
    
    # Grow the filesystem
    local fs_type=$(get_fs_type "/")
    log "Growing filesystem (type: $fs_type)..."
    
    if [[ "$fs_type" == "xfs" ]]; then
        if ! xfs_growfs /; then
            error "Failed to grow XFS filesystem"
        fi
    elif [[ "$fs_type" == "ext4" ]] || [[ "$fs_type" == "ext3" ]]; then
        if ! resize2fs "$root_lv"; then
            error "Failed to grow ext4 filesystem"
        fi
    else
        error "Unsupported filesystem type: $fs_type"
    fi
    
    success "Root filesystem expanded to ${target_size_gb}GB"
}

# Function to use alternative approach: move offline resources to /var
suggest_alternative_approach() {
    log "=== ALTERNATIVE APPROACH ==="
    echo
    warning "Since /var has 103GB free space and root (/) only has 4GB total,"
    warning "the recommended approach is to store offline resources in /var instead of root."
    echo
    log "Suggested solution:"
    echo "  1. Modify prepare_offline.sh to use /var/lme/offline_resources"
    echo "  2. This avoids risky LVM resizing operations"
    echo "  3. /var already has plenty of space (103GB free)"
    echo
    log "To implement this:"
    echo "  - Edit scripts/prepare_offline.sh"
    echo "  - Change: OUTPUT_DIR=\"/root/LME/offline_resources\""
    echo "  - To:     OUTPUT_DIR=\"/var/lme/offline_resources\""
    echo
    success "This is the safest and simplest solution!"
}

# Main execution
main() {
    log "LME LVM Rebalancing Script for Offline Preparation"
    echo
    
    # Show current status
    show_current_status
    
    # Check prerequisites
    local vg_name=$(check_prerequisites)
    
    # Get logical volume paths
    local root_lv=$(get_lv_info "/")
    local var_lv=$(get_lv_info "/var")
    
    if [[ -z "$root_lv" ]]; then
        error "Could not find logical volume for root (/)"
    fi
    
    if [[ -z "$var_lv" ]]; then
        error "Could not find logical volume for /var"
    fi
    
    log "Root LV: $root_lv"
    log "Var LV: $var_lv"
    echo
    
    # Check current free space in VG
    local vg_free_gb=$(get_vg_free_space_gb "$vg_name")
    log "Free space in volume group: ${vg_free_gb}GB"
    
    if [[ $vg_free_gb -ge 26 ]]; then
        # We have enough free space to expand root without shrinking /var
        log "Good news! Volume group has ${vg_free_gb}GB free space."
        log "We can expand root without shrinking /var."
        echo
        
        # Confirm with user
        if [[ "${1:-}" != "--yes" ]]; then
            warning "This will expand root (/) from 4GB to 30GB using free space in the volume group."
            echo
            read -p "Do you want to continue? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Operation cancelled by user"
                exit 0
            fi
        fi
        
        # Backup LVM config
        backup_lvm_config
        
        # Expand root
        expand_root_lv "$vg_name" "$root_lv" 30
        
        # Show final status
        echo
        log "=== Final Disk Usage ==="
        df -h | grep -E "(Filesystem|/dev/mapper|/dev/sda)"
        echo
        
        success "=== LVM REBALANCING COMPLETED SUCCESSFULLY ==="
        success "Root (/) has been expanded to 30GB"
        success "You can now run prepare_offline.sh"
        
    else
        # Not enough free space - need to shrink /var (risky with XFS)
        warning "Volume group only has ${vg_free_gb}GB free space."
        warning "Need to shrink /var to free up space for root."
        echo
        
        # Check if /var is XFS
        local var_fs_type=$(get_fs_type "/var")
        if [[ "$var_fs_type" == "xfs" ]]; then
            error "Cannot proceed: /var uses XFS filesystem which cannot be shrunk.\n" \
                  "See alternative approach below."
        fi
        
        suggest_alternative_approach
        exit 1
    fi
}

# Script usage
show_usage() {
    echo "Usage: $0 [--yes]"
    echo "  --yes     Skip confirmation prompts (for automation)"
    echo
    echo "This script rebalances LVM logical volumes for offline preparation:"
    echo "- Expands root (/) to 30GB for offline resources"
    echo "- Uses free space in volume group if available"
    echo "- Suggests alternative approach if resizing is risky"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
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
        show_usage
        exit 1
        ;;
esac

