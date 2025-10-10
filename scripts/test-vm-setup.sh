#!/bin/bash
#
# Test Environment Setup Script
# Sets up Lima VM with ZFS for testing Datadog integration
#

set -e

echo "Installing Lima (if not already installed)..."
if ! command -v limactl &> /dev/null; then
    echo "Installing Lima via Homebrew..."
    brew install lima
else
    echo "Lima already installed"
fi

echo ""
echo "Lima installed successfully!"
echo "Next steps:"
echo "1. Run: limactl start --name=zfs-test ubuntu-lts"
echo "2. Run: ./test-in-vm.sh"
