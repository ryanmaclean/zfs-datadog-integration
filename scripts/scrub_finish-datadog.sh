#!/bin/sh
#
# ZFS Scrub Completion Zedlet
# Reports scrub results to Datadog
#
# Triggered by: scrub_finish events
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Check if monitoring is enabled
if [ "${MONITOR_SCRUB}" != "true" ]; then
    exit 0
fi

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"
EID=$(get_event_id)
# Real zevents carry no scan result: read the pool's scan line first, then any
# ZEVENT_POOL_SCRUB_* values a ZED build exports, else report unknown.
if RESULT=$(zpool_scan_result "$POOL" scrub); then
    ERRORS=${RESULT% *}
    DURATION=${RESULT#* }
else
    ERRORS=$(normalize_scan_number "${ZEVENT_POOL_SCRUB_ERRORS:-}" 18446744073709551615)
    DURATION=$(get_scan_duration "${ZEVENT_POOL_SCRUB_START:-}" "${ZEVENT_POOL_SCRUB_END:-}")
fi

if [ "$DURATION" != unknown ]; then
    DURATION_HOURS=$((DURATION / 3600))
    DURATION_MINS=$(((DURATION % 3600) / 60))
    DURATION_TEXT="${DURATION_HOURS}h ${DURATION_MINS}m"
else
    DURATION_TEXT="unknown"
fi

# Build tags
TAGS=$(build_tags) || exit 1
PROGRESS_TAGS=$(build_pool_tags) || exit 1

# Determine alert type based on errors
if [ "$ERRORS" = unknown ]; then
    ALERT_TYPE="info"
    STATUS="completed (result unknown)"
elif [ "$ERRORS" = 0 ]; then
    ALERT_TYPE="success"
    STATUS="completed successfully"
else
    # Never report a guessed 0 errors as success.
    ERRORS=unknown
    DURATION=0
    ALERT_TYPE="warning"
    TEXT="Pool: $POOL\nStatus: finished, result unavailable from zpool status\nErrors Found: unknown"
fi

# Prepare event details
TITLE="ZFS Scrub Completed: $POOL"
TEXT="Pool: $POOL\nEvent ID: $EID\nStatus: $STATUS\nErrors Found: $ERRORS\nDuration: ${DURATION_TEXT}"

# Attempt every sender, retaining any failure for the final exit status.
SEND_STATUS=0

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$TAGS" || SEND_STATUS=1

# Send metrics
if [ "$ERRORS" != unknown ]; then
    send_metric "zfs.scrub.errors" "$ERRORS" "gauge" "$TAGS" || SEND_STATUS=1
fi
if [ "$DURATION" != unknown ] && [ "$DURATION" -gt 0 ]; then
    send_metric "zfs.scrub.duration" "$DURATION" "gauge" "$TAGS" || SEND_STATUS=1
fi
# Clear in-progress flag set by scrub_start-datadog.sh
send_metric "zfs.scrub.in_progress" "0" "gauge" "$PROGRESS_TAGS" || SEND_STATUS=1

log_message "INFO" "Scrub completion event processed: $POOL - $ERRORS errors"

if [ "$SEND_STATUS" -ne 0 ]; then
    log_message "ERROR" "Scrub completion sender failure: $POOL"
fi

exit "$SEND_STATUS"
