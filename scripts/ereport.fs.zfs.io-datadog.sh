#!/bin/sh
# Wrapper to route I/O ereports to the Datadog handler
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/io-error.sh"
