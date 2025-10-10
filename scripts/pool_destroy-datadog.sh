#!/bin/sh
#
# ZFS pool_destroy event handler for Datadog
# Sends notification when a pool is destroyed
#

# Source the library
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

# Build event details
EVENT_TYPE="pool_destroy"
TITLE="ZFS Pool Destroyed: ${ZEVENT_POOL}"
TEXT="Pool ${ZEVENT_POOL} has been destroyed on host ${HOSTNAME}"

# Alert type and priority
ALERT_TYPE="warning"
PRIORITY="normal"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"

exit 0
