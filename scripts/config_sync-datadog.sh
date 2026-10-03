#!/bin/sh
#
# ZFS config_sync event handler for Datadog
# Sends notification when pool configuration is synchronized
#

# Source the library
ZED_DIR="$(dirname "$0")"
# shellcheck disable=SC1091  # resolved at runtime relative to the installed zedlet dir, not this checkout
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
# shellcheck disable=SC1091  # resolved at runtime relative to the installed zedlet dir, not this checkout
. "${ZED_DIR}/config.sh" || exit 1

# zfs-datadog-lib.sh sets HOSTNAME, but restate the POSIX-portable default
# here so this handler does not depend on HOSTNAME being exported by the
# caller or by a future version of the sourced library.
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Build event details
EVENT_TYPE="config_sync"
TITLE="ZFS Config Sync: ${ZEVENT_POOL}"
TEXT="Pool configuration synchronized for ${ZEVENT_POOL} on host ${HOSTNAME}"

# Alert type and priority (low priority as this is routine)
ALERT_TYPE="info"
PRIORITY="low"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$(build_tags)" "$PRIORITY" "$EVENT_TYPE"

exit 0
