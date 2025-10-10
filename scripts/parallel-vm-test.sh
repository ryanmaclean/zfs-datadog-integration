#!/usr/bin/env bash
#
# Parallel VM Testing - All OSes Simultaneously
# Installs Datadog, ZFS, zedlets, creates test pools, runs scrubs
#

set -e

REMOTE="studio@i9-zfs-pop.local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VM configurations
declare -A VMS=(
    ["freebsd-zfs"]="5901:22:FreeBSD"
    ["truenas-scale"]="5902:22:TrueNAS-SCALE"
    ["truenas-core"]="5903:22:TrueNAS-CORE"
    ["openbsd-zfs"]="5904:22:OpenBSD"
    ["netbsd-zfs"]="5905:22:NetBSD"
)

echo "========================================"
echo "🚀 Parallel VM Testing - All OSes"
echo "========================================"
echo ""

# Function to test a single VM
test_vm() {
    local vm_name=$1
    local vnc_port=$2
    local ssh_port=$3
    local os_type=$4
    local log_file="vm-test-${vm_name}.log"
    
    echo "[${vm_name}] Starting test..." | tee -a "$log_file"
    
    # Wait for SSH (after manual installation)
    echo "[${vm_name}] Waiting for SSH on localhost:${ssh_port}..." | tee -a "$log_file"
    for i in {1..60}; do
        if nc -z localhost "$ssh_port" 2>/dev/null; then
            echo "[${vm_name}] SSH ready!" | tee -a "$log_file"
            break
        fi
        sleep 5
    done
    
    # Copy zedlets
    echo "[${vm_name}] Copying zedlets..." | tee -a "$log_file"
    scp -P "$ssh_port" -o StrictHostKeyChecking=no \
        .env.local config.sh zfs-datadog-lib.sh *-datadog.sh *-error.sh \
        root@localhost:/tmp/ >> "$log_file" 2>&1
    
    # Install based on OS type
    case "$os_type" in
        FreeBSD|TrueNAS-CORE)
            echo "[${vm_name}] Installing zedlets (FreeBSD paths)..." | tee -a "$log_file"
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log_file" 2>&1 <<'EOF'
cd /tmp
mkdir -p /usr/local/etc/zfs/zed.d
cp *.sh /usr/local/etc/zfs/zed.d/
chmod 755 /usr/local/etc/zfs/zed.d/*.sh
chmod 600 /usr/local/etc/zfs/zed.d/config.sh
service zfs-zed restart
EOF
            ;;
        *)
            echo "[${vm_name}] Installing zedlets (Linux paths)..." | tee -a "$log_file"
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log_file" 2>&1 <<'EOF'
cd /tmp
mkdir -p /etc/zfs/zed.d
cp *.sh /etc/zfs/zed.d/
chmod 755 /etc/zfs/zed.d/*.sh
chmod 600 /etc/zfs/zed.d/config.sh
systemctl restart zfs-zed
EOF
            ;;
    esac
    
    # Create test pool
    echo "[${vm_name}] Creating test pool..." | tee -a "$log_file"
    ssh -p "$ssh_port" root@localhost "bash -s" >> "$log_file" 2>&1 <<'EOF'
mkdir -p /tmp/zfs-test
dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=512
dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=512
zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img
zpool status testpool
EOF
    
    # Run scrub
    echo "[${vm_name}] Running scrub..." | tee -a "$log_file"
    ssh -p "$ssh_port" root@localhost "zpool scrub testpool" >> "$log_file" 2>&1
    
    # Wait for scrub to complete
    sleep 10
    
    echo "[${vm_name}] ✅ Test complete!" | tee -a "$log_file"
}

export -f test_vm

# Test all VMs in parallel
echo "Testing all VMs in parallel..."
echo ""

for vm in "${!VMS[@]}"; do
    IFS=: read -r vnc ssh os <<< "${VMS[$vm]}"
    test_vm "$vm" "$vnc" "$ssh" "$os" &
done

wait

echo ""
echo "========================================"
echo "✅ All VM Tests Complete"
echo "========================================"
echo ""
echo "Check Datadog for events from all OSes:"
echo "https://app.datadoghq.com/event/explorer"
echo ""
echo "Search: source:zfs"
echo ""
echo "Expected events from:"
for vm in "${!VMS[@]}"; do
    echo "  - $vm"
done
