#!/usr/bin/env bash
#
# Build ALL OS images with Packer in parallel on i9-zfs-pop
# Automated testing without manual installation
#

set -e

REMOTE="studio@i9-zfs-pop.local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "🚀 Packer Automated Build - ALL OSes"
echo "========================================"
echo ""

# Copy Packer templates to i9-zfs-pop
echo "Copying Packer templates to i9-zfs-pop..."
scp *.pkr.hcl *.sh .env.local $REMOTE:/tank3/vms/

# Build on i9-zfs-pop
ssh $REMOTE "bash -s" <<'REMOTE_BUILD'
cd /tank3/vms

# Install Packer if not present
if ! command -v packer &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y packer
fi

echo "Packer version: $(packer version)"

# Initialize Packer
packer init packer-ubuntu-zfs.pkr.hcl

# Build Ubuntu image (fastest, test first)
echo "Building Ubuntu image..."
time packer build packer-ubuntu-zfs.pkr.hcl

# Build FreeBSD image
echo "Building FreeBSD image..."
time packer build packer-freebsd-zfs.pkr.hcl

echo "✅ Packer builds complete!"
ls -lh /tank3/vms/packer-output-*/
REMOTE_BUILD

echo ""
echo "✅ All Packer builds complete on i9-zfs-pop"
echo ""
echo "Images available at:"
echo "  /tank3/vms/packer-output-*/"
echo ""
echo "Next: Deploy and test images"
