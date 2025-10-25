#!/bin/bash
#
# Reboot VM with new kernel and verify
#

set -e

VM="zfs-test"

echo "=== Rebooting $VM with new kernel ==="

# Get current kernel
OLD_KERNEL=$(limactl shell $VM -- uname -r 2>/dev/null || echo "unknown")
echo "Current kernel: $OLD_KERNEL"

# Reboot
echo "Rebooting VM..."
limactl shell $VM -- sudo reboot || true

# Wait for VM to go down
echo "Waiting for VM to shutdown..."
sleep 5

# Wait for VM to come back up
echo "Waiting for VM to restart..."
for i in {1..30}; do
  if limactl shell $VM -- echo "alive" >/dev/null 2>&1; then
    echo "VM is back online!"
    break
  fi
  echo -n "."
  sleep 2
done
echo ""

# Verify new kernel
echo ""
echo "Verifying new kernel..."
NEW_KERNEL=$(limactl shell $VM -- uname -r)
echo "New kernel: $NEW_KERNEL"

if [[ "$NEW_KERNEL" == *"m-series"* ]]; then
  echo "✅ SUCCESS! Running M-series kernel"
else
  echo "⚠️  WARNING: Not running M-series kernel"
  echo "Check boot configuration:"
  limactl shell $VM -- cat /boot/grub/grub.cfg | grep menuentry | head -5
fi

echo ""
echo "Full kernel info:"
limactl shell $VM -- uname -a
