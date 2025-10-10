#!/bin/bash
#
# Check VM Status and Provide Next Steps
#

echo "VM Status Check"
echo "==============="
echo ""

# Check for running QEMU processes
QEMU_PROCS=$(ps aux | grep qemu-system | grep -v grep)

if [ -z "$QEMU_PROCS" ]; then
    echo "Status: No VMs running"
    echo ""
    echo "To start VMs:"
    echo "  ./qemu-truenas-scale.sh"
    echo "  ./qemu-truenas-core.sh"
else
    echo "Running VMs:"
    echo "$QEMU_PROCS" | awk '{print "  PID " $2 ": " $NF}'
    echo ""
fi

# Check SSH availability
echo "SSH Connectivity:"
echo ""

# TrueNAS SCALE
echo -n "  TrueNAS SCALE (port 2222): "
if nc -z -w 1 localhost 2222 2>/dev/null; then
    if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@localhost "echo test" 2>/dev/null; then
        echo "✓ Ready"
        echo "    Run: ./test-truenas-scale.sh"
    else
        echo "⏳ Port open, waiting for SSH"
    fi
else
    echo "✗ Not available (complete installation)"
fi

# TrueNAS CORE
echo -n "  TrueNAS CORE (port 2223): "
if nc -z -w 1 localhost 2223 2>/dev/null; then
    if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2223 root@localhost "echo test" 2>/dev/null; then
        echo "✓ Ready"
        echo "    Run: ./test-truenas-core.sh"
    else
        echo "⏳ Port open, waiting for SSH"
    fi
else
    echo "✗ Not available"
fi

echo ""
echo "Web UIs:"
echo "  TrueNAS SCALE: https://localhost:8443"
echo "  TrueNAS CORE:  https://localhost:8444"
echo ""

# Check for downloaded images
echo "Downloaded Images:"
ls -lh truenas*.iso 2>/dev/null | awk '{print "  " $9 " - " $5}' || echo "  None"
echo ""

# Check for disk images
echo "VM Disks:"
ls -lh truenas*.qcow2 2>/dev/null | awk '{print "  " $9 " - " $5}' || echo "  None"
echo ""

echo "Next Steps:"
echo "==========="
echo ""
echo "1. Complete TrueNAS installation in QEMU window"
echo "2. Set root password during installation"
echo "3. Configure network (DHCP should work)"
echo "4. After reboot, enable SSH in web UI"
echo "5. Run automated tests:"
echo "   ./test-truenas-scale.sh"
echo "   ./test-truenas-core.sh"
