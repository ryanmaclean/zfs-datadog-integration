#!/bin/sh
#
# ZFS Checksum Error Zedlet
# Reports checksum errors to Datadog
#
# Triggered by: checksum events
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Check if monitoring is enabled
if [ "${MONITOR_CHECKSUM_ERRORS}" != "true" ]; then
    exit 0
fi

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"
VDEV_PATH="${ZEVENT_VDEV_PATH:-unknown}"
VDEV_STATE="${ZEVENT_VDEV_STATE:-}"
CHECKSUM_ERRORS="${ZEVENT_VDEV_CKSUM_ERRORS:-1}"

# Build tags
TAGS=$(build_tags)

# Prepare event details
VDEV_NAME=$(basename "$VDEV_PATH")
TITLE="ZFS Checksum Error: $POOL"
TEXT="Pool: $POOL\nVdev: $VDEV_NAME\nChecksum Errors: $CHECKSUM_ERRORS\nPath: $VDEV_PATH"

if [ -n "$VDEV_STATE" ]; then
    TEXT="${TEXT}\nVdev State: $VDEV_STATE"
fi

# Attempt both senders and retain any reporting failure.
REPORT_STATUS=0
send_datadog_event "$TITLE" "$TEXT" "error" "$TAGS" || REPORT_STATUS=1

# Send metric
send_metric "zfs.checksum.errors" "$CHECKSUM_ERRORS" "counter" "$TAGS" || REPORT_STATUS=1

log_message "ERROR" "Checksum error detected: $POOL - $VDEV_NAME - $CHECKSUM_ERRORS errors"

if [ "$REPORT_STATUS" -ne 0 ]; then
    log_message "ERROR" "Checksum error reporting failed: $POOL - $VDEV_NAME"
fi

# UDP submission success does not confirm backend delivery.
exit "$REPORT_STATUS"
