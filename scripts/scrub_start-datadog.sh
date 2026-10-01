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
TAGS=$(build_tags)

# Emit counter — one increment per scrub start
send_metric "zfs.scrub.start" "1" "counter" "$TAGS"

# Emit in-progress flag — cleared by scrub_finish-datadog.sh
send_metric "zfs.scrub.in_progress" "1" "gauge" "$TAGS"

# Send informational event to Datadog Events API
TITLE="ZFS Scrub Started: $POOL"
TEXT="Pool: $POOL\nEvent ID: $EID\nStarted at: $TIMESTAMP"
send_datadog_event "$TITLE" "$TEXT" "info" "$TAGS"

log_message "INFO" "Scrub start event processed: pool=$POOL eid=$EID"

exit 0
