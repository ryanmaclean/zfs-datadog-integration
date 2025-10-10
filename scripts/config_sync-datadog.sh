#!/bin/sh
#
# ZFS config_sync event handler for Datadog
# Sends notification when pool configuration is synchronized
#

# Source the library
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

# Build event details
EVENT_TYPE="config_sync"
TITLE="ZFS Config Sync: ${ZEVENT_POOL}"
TEXT="Pool configuration synchronized for ${ZEVENT_POOL} on host ${HOSTNAME}"

# Alert type and priority (low priority as this is routine)
ALERT_TYPE="info"
PRIORITY="low"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"

exit 0
