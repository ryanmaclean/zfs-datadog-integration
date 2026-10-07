#!/bin/sh
#
# ZFS Pool Health Monitoring Zedlet
# Monitors pool state changes and reports to Datadog
#
# Triggered by: statechange events
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Check if monitoring is enabled
if [ "${MONITOR_POOL_HEALTH}" != "true" ]; then
    exit 0
fi

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"
VDEV_STATE="${ZEVENT_VDEV_STATE:-unknown}"
VDEV_PATH="${ZEVENT_VDEV_PATH:-}"

# Build tags
TAGS=$(build_tags)

# Get numeric health value and alert type
HEALTH_VALUE=$(get_pool_health_value "$VDEV_STATE")
ALERT_TYPE=$(get_alert_type "$VDEV_STATE")

# Prepare event details
if [ -n "$VDEV_PATH" ]; then
    VDEV_NAME=$(basename "$VDEV_PATH")
    TITLE="ZFS Pool Health Change: $POOL (vdev: $VDEV_NAME)"
    TEXT="Pool: $POOL\nVdev: $VDEV_NAME\nNew State: $VDEV_STATE\nPath: $VDEV_PATH"
else
    TITLE="ZFS Pool Health Change: $POOL"
    TEXT="Pool: $POOL\nNew State: $VDEV_STATE"
fi

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$TAGS"

# Send metric
send_metric "zfs.pool.health" "$HEALTH_VALUE" "gauge" "$TAGS"

log_message "INFO" "Pool health event processed: $POOL - $VDEV_STATE"

exit 0
