#!/bin/bash
#
# Quick Start: Parallel Multi-OS Testing
# One command to rule them all
#

set -e

echo "========================================"
echo "🚀 Parallel Multi-OS Testing Pipeline"
echo "========================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v packer >/dev/null 2>&1 || { echo "Installing Packer..."; brew install packer; }
command -v parallel >/dev/null 2>&1 || { echo "Installing GNU Parallel..."; brew install parallel; }
command -v jq >/dev/null 2>&1 || { echo "Installing jq..."; brew install jq; }

echo "✓ Packer: $(packer version)"
echo "✓ Parallel: $(parallel --version | head -1)"
echo "✓ CPU Cores: $(sysctl -n hw.ncpu)"
echo ""

# Step 1: Build golden images in parallel
echo "Step 1: Building golden images (parallel)..."
echo "This will use all available CPU cores"
echo ""

MAX_PARALLEL=$(sysctl -n hw.ncpu) ./build-all-images.sh

echo ""
echo "Step 2: Testing all images (parallel)..."
echo ""

MAX_PARALLEL=4 ./test-all-golden-images.sh

echo ""
echo "========================================"
echo "✅ Complete Multi-OS Testing Done!"
echo "========================================"
echo ""
echo "Results:"
echo "  - Build logs: logs/"
echo "  - Test results: test-results/"
echo "  - HTML report: test-results/*/report.html"
echo ""
echo "Next: Review results and deploy to production"
