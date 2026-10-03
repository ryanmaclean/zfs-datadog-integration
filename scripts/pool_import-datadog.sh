#!/bin/sh
#
# ZFS pool_import event handler for Datadog
# Sends notification when a pool is imported
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
EVENT_TYPE="pool_import"
TITLE="ZFS Pool Imported: ${ZEVENT_POOL}"
TEXT="Pool ${ZEVENT_POOL} has been imported on host ${HOSTNAME}"

# Alert type and priority
ALERT_TYPE="info"
PRIORITY="low"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$(build_tags)" "$PRIORITY" "$EVENT_TYPE"

exit 0
