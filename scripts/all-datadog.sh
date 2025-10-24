#!/bin/sh
#
# ZFS All Events Router for Datadog
# Routes checksum and I/O error events to appropriate handlers
#
# Triggered by: all ZFS events (filters for checksum and io)
# Place in: /etc/zfs/zed.d/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Get event class
EVENT_CLASS="${ZEVENT_CLASS:-}"

if command -v logger >/dev/null 2>&1; then
    logger -t zfs-datadog "[DEBUG] all-datadog received event class: $EVENT_CLASS"
fi

# Route to appropriate handler based on event class
case "$EVENT_CLASS" in
    *checksum*)
        # Handle checksum errors
        if [ -x "$SCRIPT_DIR/checksum-error.sh" ]; then
            command -v logger >/dev/null 2>&1 && logger -t zfs-datadog "[DEBUG] routing checksum event to checksum-error.sh"
            exec "$SCRIPT_DIR/checksum-error.sh"
        fi
        ;;
    *io*)
        # Handle I/O errors
        if [ -x "$SCRIPT_DIR/io-error.sh" ]; then
            command -v logger >/dev/null 2>&1 && logger -t zfs-datadog "[DEBUG] routing io event to io-error.sh"
            exec "$SCRIPT_DIR/io-error.sh"
        fi
        ;;
    *)
        # Not a checksum or I/O error, ignore
        exit 0
        ;;
esac

exit 0
