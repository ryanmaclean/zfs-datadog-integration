#!/bin/bash
#
# Test ML Code Assistant on BSD VMs
#

set -e

EXTENSION_DIR="/Users/studio/CascadeProjects/windsurf-project/code-app-ml-extension"

echo "=========================================="
echo "Testing ML Extension on BSD VMs"
echo "=========================================="
date
echo ""

# Create FreeBSD VM
echo "=== Creating FreeBSD VM ==="
if limactl list | grep -q "freebsd-ml"; then
    echo "VM already exists, deleting..."
    limactl delete -f freebsd-ml 2>/dev/null || true
fi

echo "Creating new FreeBSD VM..."
limactl create --name=freebsd-ml lima-configs/freebsd-ml-test.yaml

echo ""
echo "=== Starting FreeBSD VM ==="
limactl start freebsd-ml

echo ""
echo "=== Waiting for VM to be ready ==="
sleep 30

echo ""
echo "=== Checking VM status ==="
limactl list | grep freebsd-ml

echo ""
echo "=== Installing ML extension in FreeBSD ==="

# Copy extension files
echo "Copying extension files..."
limactl shell freebsd-ml -- mkdir -p /tmp/mlcode 2>/dev/null || true

# Copy individual files
for file in cli.js install-bsd.sh package.json BSD-OMNIOS-SUPPORT.md; do
    if [ -f "$EXTENSION_DIR/$file" ]; then
        limactl copy "$EXTENSION_DIR/$file" freebsd-ml:/tmp/mlcode/ 2>&1 || echo "⚠️  Failed to copy $file"
    fi
done

echo ""
echo "=== Running installer in FreeBSD ==="
limactl shell freebsd-ml -- sh /tmp/mlcode/install-bsd.sh 2>&1 || echo "⚠️  Installer had issues"

echo ""
echo "=== Testing CLI in FreeBSD ==="

# Test 1: Basic completion
echo "Test 1: limactl completion"
echo "limactl " | limactl shell freebsd-ml -- node /tmp/mlcode/cli.js complete 2>&1 || echo "❌ Test 1 failed"

echo ""
echo "Test 2: ZFS completion"
echo "zpool " | limactl shell freebsd-ml -- node /tmp/mlcode/cli.js complete 2>&1 || echo "❌ Test 2 failed"

echo ""
echo "Test 3: Function completion"
echo "function build" | limactl shell freebsd-ml -- node /tmp/mlcode/cli.js complete 2>&1 || echo "❌ Test 3 failed"

echo ""
echo "=== Checking installed files ==="
limactl shell freebsd-ml -- ls -la /tmp/mlcode/ 2>&1 || echo "❌ Files not found"

echo ""
echo "=========================================="
echo "FreeBSD ML Test Complete"
echo "=========================================="
echo ""
echo "VM Status:"
limactl list | grep freebsd-ml
echo ""
echo "To access VM:"
echo "  limactl shell freebsd-ml"
echo ""
echo "To test manually:"
echo "  echo 'code' | limactl shell freebsd-ml -- node /tmp/mlcode/cli.js complete"
echo ""
echo "To stop VM:"
echo "  limactl stop freebsd-ml"
echo ""
echo "To delete VM:"
echo "  limactl delete freebsd-ml"
echo ""
