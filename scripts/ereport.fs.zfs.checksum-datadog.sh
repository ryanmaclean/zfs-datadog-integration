#!/bin/sh
# Wrapper to route checksum ereports to the Datadog handler
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/checksum-error.sh"
