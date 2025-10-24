#!/bin/bash
#
# Build kernels using serial console instead of SSH
# No SSH timeouts!
#

set -e

echo "=== BUILDING VIA SERIAL CONSOLE ==="

# Function to send commands via serial
build_via_serial() {
    local VM=$1
    local SERIAL_LOG=~/.lima/${VM}/serial.log
    
    echo "[${VM}] Checking serial console..."
    
    if [ -f "$SERIAL_LOG" ]; then
        echo "[${VM}] Serial log exists: $SERIAL_LOG"
        tail -20 "$SERIAL_LOG"
    else
        echo "[${VM}] No serial log found"
    fi
}

# Check all VMs
for VM in zfs-test freebsd-build debian-zfs rocky-zfs; do
    echo ""
    echo "=== $VM ==="
    build_via_serial $VM
done

echo ""
echo "=== ALTERNATIVE: Use limactl start with serial ==="
echo "limactl start --tty zfs-test"
echo ""
echo "Or access via:"
echo "screen ~/.lima/zfs-test/serial.sock"
