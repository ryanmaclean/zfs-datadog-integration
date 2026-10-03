#!/bin/sh
#
# ZFS vdev_attach event handler for Datadog
# Sends notification when a vdev is attached (mirror expansion)
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
EVENT_TYPE="vdev_attach"
TITLE="ZFS Device Attached: ${ZEVENT_POOL}"
TEXT="A new device has been attached to pool ${ZEVENT_POOL} on host ${HOSTNAME}. Resilvering will begin automatically."

# Alert type and priority
ALERT_TYPE="info"
PRIORITY="normal"

# Send event
send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$(build_tags)" "$PRIORITY" "$EVENT_TYPE"

exit 0
