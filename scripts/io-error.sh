#!/bin/sh
#
# ZFS I/O Error Zedlet
# Reports I/O errors to Datadog
#
# Triggered by: io events
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Check if monitoring is enabled
if [ "${MONITOR_IO_ERRORS}" != "true" ]; then
    exit 0
fi

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"
VDEV_PATH="${ZEVENT_VDEV_PATH:-unknown}"
VDEV_STATE="${ZEVENT_VDEV_STATE:-}"
READ_ERRORS="${ZEVENT_VDEV_READ_ERRORS:-0}"
WRITE_ERRORS="${ZEVENT_VDEV_WRITE_ERRORS:-0}"

# Build tags
TAGS=$(build_tags)

# Prepare event details
VDEV_NAME=$(basename "$VDEV_PATH")
TITLE="ZFS I/O Error: $POOL"
TEXT="Pool: $POOL\nVdev: $VDEV_NAME\nRead Errors: $READ_ERRORS\nWrite Errors: $WRITE_ERRORS\nPath: $VDEV_PATH"

if [ -n "$VDEV_STATE" ]; then
    TEXT="${TEXT}\nVdev State: $VDEV_STATE"
fi

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "error" "$TAGS"

# Send metrics
if [ "$READ_ERRORS" -gt 0 ]; then
    send_metric "zfs.io.read_errors" "$READ_ERRORS" "counter" "$TAGS"
fi

if [ "$WRITE_ERRORS" -gt 0 ]; then
    send_metric "zfs.io.write_errors" "$WRITE_ERRORS" "counter" "$TAGS"
fi

log_message "ERROR" "I/O error detected: $POOL - $VDEV_NAME - R:$READ_ERRORS W:$WRITE_ERRORS"

exit 0
