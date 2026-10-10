#!/bin/sh
#
# ZFS Scrub Start Zedlet
# Reports scrub start to Datadog for in-progress tracking
#
# Triggered by: scrub_start events
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
TIMESTAMP="${ZEVENT_TIME:-0}"
EID="${ZEVENT_EID:-0}"

# Build tags
TAGS=$(build_tags) || exit 1
SEND_STATUS=0

# Emit counter — one increment per scrub start
send_metric "zfs.scrub.start" "1" "counter" "$TAGS" || SEND_STATUS=1

# Emit in-progress flag — cleared by scrub_finish-datadog.sh
send_metric "zfs.scrub.in_progress" "1" "gauge" "$TAGS" || SEND_STATUS=1

# Send informational event to the local Agent
TITLE="ZFS Scrub Started: $POOL"
TEXT="Pool: $POOL\nEvent ID: $EID\nStarted at: $TIMESTAMP"
send_datadog_event "$TITLE" "$TEXT" "info" "$TAGS" || SEND_STATUS=1

log_message "INFO" "Scrub start event processed: pool=$POOL eid=$EID"

exit "$SEND_STATUS"
