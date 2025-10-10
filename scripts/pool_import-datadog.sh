#!/bin/sh
#
# ZFS pool_import event handler for Datadog
# Sends notification when a pool is imported
#

# Source the library
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

# Build event details
EVENT_TYPE="pool_import"
TITLE="ZFS Pool Imported: ${ZEVENT_POOL}"
TEXT="Pool ${ZEVENT_POOL} has been imported on host ${HOSTNAME}"

# Alert type and priority
ALERT_TYPE="info"
PRIORITY="low"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"

exit 0
