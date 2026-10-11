#!/bin/sh
#
# ZFS config_sync event handler for Datadog
# Sends notification when pool configuration is synchronized
#

# Source the library
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

# zfs-datadog-lib.sh sets HOSTNAME, but restate the POSIX-portable default
# here so this handler does not depend on HOSTNAME being exported by the
# caller or by a future version of the sourced library.
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Build event details
EVENT_TYPE="config_sync"
TITLE="ZFS Config Sync: ${ZEVENT_POOL}"
TEXT="Pool configuration synchronized for ${ZEVENT_POOL} on host ${HOSTNAME}"

# Alert type and priority (low priority as this is routine)
ALERT_TYPE="info"
PRIORITY="low"

# Send event
TAGS=$(build_tags) || exit 1
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$TAGS" "$PRIORITY" "$EVENT_TYPE" || exit 1

exit 0
