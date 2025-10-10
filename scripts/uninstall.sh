#!/bin/sh
# ZFS Datadog Integration - Uninstall Script
# Removes zedlets and optionally config files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=0
KEEP_CONFIG=0
VERBOSE=0

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --keep-config)
            KEEP_CONFIG=1
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Uninstall ZFS Datadog Integration zedlets.

OPTIONS:
    --dry-run       Show what would be removed without removing
    --keep-config   Keep configuration files (config.sh)
    -v, --verbose   Verbose output
    -h, --help      Show this help message

EXAMPLES:
    # Remove all zedlets
    sudo $0

    # Keep config for reinstall
    sudo $0 --keep-config

    # Preview what would be removed
    sudo $0 --dry-run
EOF
            exit 0
            ;;
        *)
            printf "${RED}Unknown option: $1${NC}\n" >&2
            exit 1
            ;;
    esac
    shift
done

# Check if running as root
if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    printf "${RED}Error: This script must be run as root${NC}\n" >&2
    printf "Try: sudo $0\n" >&2
    exit 1
fi

# Detect OS and set paths
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="$ID"
else
    OS_TYPE="unknown"
fi

# Set ZED path based on OS
case "$OS_TYPE" in
    freebsd|truenas)
        ZED_DIR="/usr/local/etc/zfs/zed.d"
        ;;
    *)
        ZED_DIR="/etc/zfs/zed.d"
        ;;
esac

printf "${GREEN}ZFS Datadog Integration Uninstaller${NC}\n"
printf "=====================================\n\n"

if [ "$DRY_RUN" -eq 1 ]; then
    printf "${YELLOW}DRY RUN MODE - No files will be removed${NC}\n\n"
fi

# List of zedlet files to remove
ZEDLET_FILES="
scrub_finish-datadog.sh
resilver_finish-datadog.sh
statechange-datadog.sh
checksum-error-datadog.sh
io-error-datadog.sh
all-datadog.sh
zfs-datadog-lib.sh
"

CONFIG_FILES="
config.sh
"

# Count files
FILES_TO_REMOVE=0
FILES_REMOVED=0

printf "Checking for installed files...\n\n"

# Remove zedlets
printf "Zedlet Scripts:\n"
for file in $ZEDLET_FILES; do
    filepath="$ZED_DIR/$file"
    if [ -f "$filepath" ] || [ -L "$filepath" ]; then
        FILES_TO_REMOVE=$((FILES_TO_REMOVE + 1))
        if [ "$VERBOSE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
            printf "  - $filepath\n"
        fi
        if [ "$DRY_RUN" -eq 0 ]; then
            rm -f "$filepath"
            FILES_REMOVED=$((FILES_REMOVED + 1))
            [ "$VERBOSE" -eq 1 ] && printf "    ${GREEN}✓ Removed${NC}\n"
        fi
    fi
done

# Remove config files (unless --keep-config)
if [ "$KEEP_CONFIG" -eq 0 ]; then
    printf "\nConfiguration Files:\n"
    for file in $CONFIG_FILES; do
        filepath="$ZED_DIR/$file"
        if [ -f "$filepath" ]; then
            FILES_TO_REMOVE=$((FILES_TO_REMOVE + 1))
            if [ "$VERBOSE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
                printf "  - $filepath\n"
            fi
            if [ "$DRY_RUN" -eq 0 ]; then
                rm -f "$filepath"
                FILES_REMOVED=$((FILES_REMOVED + 1))
                [ "$VERBOSE" -eq 1 ] && printf "    ${GREEN}✓ Removed${NC}\n"
            fi
        fi
    done
else
    printf "\n${YELLOW}Keeping configuration files (--keep-config)${NC}\n"
fi

# Summary
printf "\n"
if [ "$DRY_RUN" -eq 1 ]; then
    printf "${YELLOW}Summary (Dry Run):${NC}\n"
    printf "  Would remove: $FILES_TO_REMOVE file(s)\n"
else
    printf "${GREEN}Summary:${NC}\n"
    printf "  Removed: $FILES_REMOVED file(s)\n"
    
    if [ "$FILES_REMOVED" -eq 0 ]; then
        printf "\n${YELLOW}No files were found to remove.${NC}\n"
        printf "ZFS Datadog Integration may not be installed.\n"
    else
        printf "\n${GREEN}✓ Uninstallation complete!${NC}\n\n"
        
        # Restart ZED if files were removed
        printf "Restarting ZFS Event Daemon...\n"
        case "$OS_TYPE" in
            freebsd|truenas)
                service zfs restart 2>/dev/null || printf "${YELLOW}Note: Could not restart ZED automatically${NC}\n"
                ;;
            *)
                systemctl restart zfs-zed 2>/dev/null || \
                service zfs-zed restart 2>/dev/null || \
                printf "${YELLOW}Note: Could not restart ZED automatically${NC}\n"
                ;;
        esac
        
        printf "\n${GREEN}ZFS Event Daemon restarted${NC}\n"
        printf "\nDatadog events will no longer be sent for ZFS events.\n"
        
        if [ "$KEEP_CONFIG" -eq 1 ]; then
            printf "\n${YELLOW}Configuration preserved for future reinstall.${NC}\n"
        fi
    fi
fi

exit 0
