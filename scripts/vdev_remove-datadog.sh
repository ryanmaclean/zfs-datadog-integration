#!/bin/sh
#
# ZFS vdev_remove event handler for Datadog
# Sends notification when a vdev is removed from pool
#

# Source the library
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

# Build event details
EVENT_TYPE="vdev_remove"
TITLE="ZFS Device Removed: ${ZEVENT_POOL}"
TEXT="A device has been removed from pool ${ZEVENT_POOL} on host ${HOSTNAME}"

# Alert type and priority
ALERT_TYPE="warning"
PRIORITY="normal"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"

exit 0
