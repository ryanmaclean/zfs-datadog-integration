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
ERRORS="${ZEVENT_POOL_RESILVER_ERRORS:-0}"
START_TIME="${ZEVENT_POOL_RESILVER_START:-0}"
END_TIME="${ZEVENT_POOL_RESILVER_END:-0}"

# Calculate duration
if [ "$START_TIME" -gt 0 ] && [ "$END_TIME" -gt 0 ]; then
    DURATION=$((END_TIME - START_TIME))
    DURATION_HOURS=$((DURATION / 3600))
    DURATION_MINS=$(((DURATION % 3600) / 60))
else
    DURATION=0
    DURATION_HOURS=0
    DURATION_MINS=0
fi

# Build tags
TAGS=$(build_tags)

# Determine alert type based on errors
if [ "$ERRORS" -eq 0 ]; then
    ALERT_TYPE="success"
    STATUS="completed successfully"
else
    ALERT_TYPE="error"
    STATUS="completed with errors"
fi

# Prepare event details
TITLE="ZFS Resilver Completed: $POOL"
TEXT="Pool: $POOL\nStatus: $STATUS\nErrors Found: $ERRORS\nDuration: ${DURATION_HOURS}h ${DURATION_MINS}m"

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$TAGS"

# Send metrics
send_metric "zfs.resilver.errors" "$ERRORS" "gauge" "$TAGS"
if [ "$DURATION" -gt 0 ]; then
    send_metric "zfs.resilver.duration" "$DURATION" "gauge" "$TAGS"
fi

log_message "INFO" "Resilver completion event processed: $POOL - $ERRORS errors"

exit 0
