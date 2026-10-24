#!/bin/sh
#
# ZFS Resilver Completion Zedlet
# Reports resilver results to Datadog
#
# Triggered by: resilver_finish events
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Check if monitoring is enabled
if [ "${MONITOR_RESILVER}" != "true" ]; then
    exit 0
fi

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"

# Build tags
TAGS=$(build_tags) || exit 1
SEND_STATUS=0

# The zevent itself carries no result; read it from the pool's scan line.
if RESULT=$(zpool_scan_result "$POOL" resilver); then
    ERRORS=${RESULT% *}
    DURATION=${RESULT#* }
    DURATION_HOURS=$((DURATION / 3600))
    DURATION_MINS=$(((DURATION % 3600) / 60))
    if [ "$ERRORS" -eq 0 ]; then
        ALERT_TYPE="success"
        STATUS="completed successfully"
    else
        ALERT_TYPE="error"
        STATUS="completed with errors"
    fi
    TEXT="Pool: $POOL\nStatus: $STATUS\nErrors Found: $ERRORS\nDuration: ${DURATION_HOURS}h ${DURATION_MINS}m"
else
    # Never report a guessed 0 errors as success.
    ERRORS=unknown
    DURATION=0
    ALERT_TYPE="warning"
    TEXT="Pool: $POOL\nStatus: finished, result unavailable from zpool status\nErrors Found: unknown"
fi

# Prepare event details
TITLE="ZFS Resilver Completed: $POOL"

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$TAGS" || SEND_STATUS=1

# Send metrics
if [ "$ERRORS" != unknown ]; then
    send_metric "zfs.resilver.errors" "$ERRORS" "gauge" "$TAGS" || SEND_STATUS=1
fi
if [ "$DURATION" -gt 0 ]; then
    send_metric "zfs.resilver.duration" "$DURATION" "gauge" "$TAGS" || SEND_STATUS=1
fi
# Clear in-progress flag set by resilver_start-datadog.sh
send_metric "zfs.resilver.in_progress" "0" "gauge" "$TAGS" || SEND_STATUS=1

log_message "INFO" "Resilver completion event processed: $POOL - $ERRORS errors"

exit "$SEND_STATUS"
