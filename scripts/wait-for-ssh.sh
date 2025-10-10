#!/bin/bash
#
# Wait for SSH to become available on VM
#

HOST=${1:-localhost}
PORT=${2:-2222}
MAX_WAIT=${3:-300}  # 5 minutes default

echo "Waiting for SSH on ${HOST}:${PORT}..."
echo "Max wait time: ${MAX_WAIT}s"

START=$(date +%s)
while true; do
    if nc -z -w 1 "$HOST" "$PORT" 2>/dev/null; then
        echo "✓ SSH port is open"
        
        # Try actual SSH connection
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" root@"$HOST" "echo test" 2>/dev/null; then
            echo "✓ SSH connection successful"
            ELAPSED=$(($(date +%s) - START))
            echo "Connected in ${ELAPSED}s"
            exit 0
        fi
    fi
    
    ELAPSED=$(($(date +%s) - START))
    if [ $ELAPSED -gt $MAX_WAIT ]; then
        echo "✗ Timeout waiting for SSH after ${ELAPSED}s"
        exit 1
    fi
    
    echo -n "."
    sleep 5
done
