#!/bin/bash
#
# Mock Datadog Server for Testing
# Runs the repository's mock Datadog server (Events API on :8080,
# DogStatsD on :8125) to capture API calls from zedlets.
# Run this in the VM to test without real Datadog credentials.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOCK_SERVER="${SCRIPT_DIR}/../mock-datadog-server.py"

echo "Starting Mock Datadog Server..."
echo "This will capture API calls from zedlets"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "Python3 not available" >&2
    exit 1
fi

if [ ! -f "$MOCK_SERVER" ]; then
    echo "Mock server not found: $MOCK_SERVER" >&2
    exit 1
fi

exec python3 "$MOCK_SERVER"
