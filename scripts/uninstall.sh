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
            cat << EOF2
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
EOF2
            exit 0
            ;;
        *)
            printf '%sUnknown option: %s%s\n' "$RED" "$1" "$NC" >&2
            exit 1
            ;;
    esac
    shift
done

# Check if running as root
if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    printf '%sError: This script must be run as root%s\n' "$RED" "$NC" >&2
    printf 'Try: sudo %s\n' "$0" >&2
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

printf '%sZFS Datadog Integration Uninstaller%s\n' "$GREEN" "$NC"
printf '=====================================\n\n'

if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sDRY RUN MODE - No files will be removed%s\n\n' "$YELLOW" "$NC"
fi

# List of zedlet files to remove
ZEDLET_FILES="
scrub_finish-datadog.sh
scrub_start-datadog.sh
resilver_finish-datadog.sh
resilver_start-datadog.sh
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

printf 'Checking for installed files...\n\n'

# Remove zedlets
printf 'Zedlet Scripts:\n'
for file in $ZEDLET_FILES; do
    filepath="$ZED_DIR/$file"
    if [ -f "$filepath" ] || [ -L "$filepath" ]; then
        FILES_TO_REMOVE=$((FILES_TO_REMOVE + 1))
        if [ "$VERBOSE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
            printf '  - %s\n' "$filepath"
        fi
        if [ "$DRY_RUN" -eq 0 ]; then
            rm -f "$filepath"
            FILES_REMOVED=$((FILES_REMOVED + 1))
            [ "$VERBOSE" -eq 1 ] && printf '    %s✓ Removed%s\n' "$GREEN" "$NC"
        fi
    fi
done

# Remove config files (unless --keep-config)
if [ "$KEEP_CONFIG" -eq 0 ]; then
    printf '\nConfiguration Files:\n'
    for file in $CONFIG_FILES; do
        filepath="$ZED_DIR/$file"
        if [ -f "$filepath" ]; then
            FILES_TO_REMOVE=$((FILES_TO_REMOVE + 1))
            if [ "$VERBOSE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
                printf '  - %s\n' "$filepath"
            fi
            if [ "$DRY_RUN" -eq 0 ]; then
                rm -f "$filepath"
                FILES_REMOVED=$((FILES_REMOVED + 1))
                [ "$VERBOSE" -eq 1 ] && printf '    %s✓ Removed%s\n' "$GREEN" "$NC"
            fi
        fi
    done
else
    printf '\n%sKeeping configuration files (--keep-config)%s\n' "$YELLOW" "$NC"
fi

# Summary
printf '\n'
if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sSummary (Dry Run):%s\n' "$YELLOW" "$NC"
    printf '  Would remove: %s file(s)\n' "$FILES_TO_REMOVE"
else
    printf '%sSummary:%s\n' "$GREEN" "$NC"
    printf '  Removed: %s file(s)\n' "$FILES_REMOVED"

    if [ "$FILES_REMOVED" -eq 0 ]; then
        printf '\n%sNo files were found to remove.%s\n' "$YELLOW" "$NC"
        printf 'ZFS Datadog Integration may not be installed.\n'
    else
        printf '\n%s✓ Uninstallation complete!%s\n\n' "$GREEN" "$NC"

        # Restart ZED if files were removed
        printf 'Restarting ZFS Event Daemon...\n'
        case "$OS_TYPE" in
            freebsd|truenas)
                service zfs restart 2>/dev/null || printf '%sNote: Could not restart ZED automatically%s\n' "$YELLOW" "$NC"
                ;;
            *)
                systemctl restart zfs-zed 2>/dev/null || \
                service zfs-zed restart 2>/dev/null || \
                printf '%sNote: Could not restart ZED automatically%s\n' "$YELLOW" "$NC"
                ;;
        esac

        printf '\n%sZFS Event Daemon restarted%s\n' "$GREEN" "$NC"
        printf '\nDatadog events will no longer be sent for ZFS events.\n'

        if [ "$KEEP_CONFIG" -eq 1 ]; then
            printf '\n%sConfiguration preserved for future reinstall.%s\n' "$YELLOW" "$NC"
        fi
    fi
fi

exit 0
