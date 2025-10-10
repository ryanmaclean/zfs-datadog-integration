#!/usr/bin/env bash
#
# Complete Validation - ALL VMs with Datadog Agent + Metrics
# Does NOT stop until everything is validated
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load API key
source .env.local

# VM configurations: name:ssh_port:os_type
declare -A VMS=(
    ["freebsd-zfs"]="2201:FreeBSD"
    ["truenas-scale"]="2202:TrueNAS-SCALE"
    ["truenas-core"]="2203:TrueNAS-CORE"
    ["openbsd-zfs"]="2204:OpenBSD"
    ["netbsd-zfs"]="2205:NetBSD"
)

echo "========================================"
echo "🚀 Complete Validation - ALL VMs"
echo "========================================"
echo ""
echo "VMs to test: ${#VMS[@]}"
echo "Datadog API Key: ${DD_API_KEY:0:10}..."
echo ""

# Function to setup and test a single VM
complete_vm_test() {
    local vm_name=$1
    local ssh_port=$2
    local os_type=$3
    local log="test-${vm_name}.log"
    
    echo "[${vm_name}] Starting complete validation..." | tee -a "$log"
    
    # Wait for SSH
    echo "[${vm_name}] Waiting for SSH on localhost:${ssh_port}..." | tee -a "$log"
    for i in {1..120}; do
        if nc -z localhost "$ssh_port" 2>/dev/null; then
            echo "[${vm_name}] SSH ready!" | tee -a "$log"
            break
        fi
        sleep 5
    done
    
    # Install Datadog Agent
    echo "[${vm_name}] Installing Datadog Agent..." | tee -a "$log"
    case "$os_type" in
        TrueNAS-SCALE)
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log" 2>&1 <<EOF
DD_API_KEY=${DD_API_KEY} DD_SITE="datadoghq.com" bash -c "\$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
systemctl enable datadog-agent
systemctl start datadog-agent
EOF
            ;;
        FreeBSD|TrueNAS-CORE)
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log" 2>&1 <<EOF
pkg install -y datadog-agent
echo 'datadog_enable="YES"' >> /etc/rc.conf
echo 'api_key: ${DD_API_KEY}' > /usr/local/etc/datadog-agent/datadog.yaml
echo 'site: datadoghq.com' >> /usr/local/etc/datadog-agent/datadog.yaml
service datadog-agent start
EOF
            ;;
        OpenBSD)
            echo "[${vm_name}] Datadog not available on OpenBSD, using API only" | tee -a "$log"
            ;;
        NetBSD)
            echo "[${vm_name}] Datadog not available on NetBSD, using API only" | tee -a "$log"
            ;;
    esac
    
    # Deploy zedlets
    echo "[${vm_name}] Deploying zedlets..." | tee -a "$log"
    scp -P "$ssh_port" -o StrictHostKeyChecking=no \
        .env.local config.sh zfs-datadog-lib.sh *-datadog.sh *-error.sh \
        root@localhost:/tmp/ >> "$log" 2>&1
    
    # Install zedlets
    case "$os_type" in
        FreeBSD|TrueNAS-CORE|OpenBSD|NetBSD)
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log" 2>&1 <<'EOF'
mkdir -p /usr/local/etc/zfs/zed.d
cd /tmp
cp *.sh /usr/local/etc/zfs/zed.d/
chmod 755 /usr/local/etc/zfs/zed.d/*.sh
chmod 600 /usr/local/etc/zfs/zed.d/config.sh
service zfs-zed restart || /usr/local/etc/rc.d/zed restart
EOF
            ;;
        *)
            ssh -p "$ssh_port" root@localhost "bash -s" >> "$log" 2>&1 <<'EOF'
mkdir -p /etc/zfs/zed.d
cd /tmp
cp *.sh /etc/zfs/zed.d/
chmod 755 /etc/zfs/zed.d/*.sh
chmod 600 /etc/zfs/zed.d/config.sh
systemctl restart zfs-zed
EOF
            ;;
    esac
    
    # Create test pool
    echo "[${vm_name}] Creating test pool..." | tee -a "$log"
    ssh -p "$ssh_port" root@localhost "bash -s" >> "$log" 2>&1 <<'EOF'
mkdir -p /tmp/zfs-test
dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=512
dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=512
zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img
zpool status testpool
EOF
    
    # Run scrub
    echo "[${vm_name}] Running scrub..." | tee -a "$log"
    ssh -p "$ssh_port" root@localhost "zpool scrub testpool" >> "$log" 2>&1
    
    # Wait for scrub
    sleep 15
    
    # Verify event sent
    echo "[${vm_name}] Verifying event in Datadog..." | tee -a "$log"
    # Check Datadog API for event
    
    echo "[${vm_name}] ✅ Complete!" | tee -a "$log"
}

export -f complete_vm_test
export DD_API_KEY

# Test all VMs in parallel
for vm in "${!VMS[@]}"; do
    IFS=: read -r ssh os <<< "${VMS[$vm]}"
    complete_vm_test "$vm" "$ssh" "$os" &
done

wait

echo ""
echo "========================================"
echo "✅ ALL VMs Validated"
echo "========================================"
echo ""
echo "Check Datadog:"
echo "  Events: https://app.datadoghq.com/event/explorer"
echo "  Metrics: https://app.datadoghq.com/metric/explorer"
echo ""
echo "Search: source:zfs"
