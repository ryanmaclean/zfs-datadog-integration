#!/bin/sh
# Wrapper to route data ereports to the Datadog handler
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/.data-error.sh"
