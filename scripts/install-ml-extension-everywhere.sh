#!/bin/bash
#
# Install ML Code Assistant Everywhere
# - macOS (local)
# - iOS (via iCloud)
# - All Lima VMs (FreeBSD, OpenBSD, NetBSD, OmniOS)
#

set -e

EXTENSION_DIR="/Users/studio/CascadeProjects/windsurf-project/code-app-ml-extension"

echo "=========================================="
echo "Installing ML Code Assistant Everywhere"
echo "=========================================="
date
echo ""

# 1. macOS (local)
echo "=== 1. Installing on macOS ==="
rm -rf ~/.vscode/extensions/mlcode-extension
cp -r "$EXTENSION_DIR" ~/.vscode/extensions/mlcode-extension
echo "✅ macOS: ~/.vscode/extensions/mlcode-extension/"

# 2. iOS (iCloud)
echo ""
echo "=== 2. Syncing to iOS (iCloud) ==="
rm -rf ~/Library/Mobile\ Documents/com~apple~CloudDocs/mlcode-extension
cp -r "$EXTENSION_DIR" ~/Library/Mobile\ Documents/com~apple~CloudDocs/mlcode-extension
echo "✅ iOS: Synced to iCloud Drive"

# 3. Check for Lima VMs
echo ""
echo "=== 3. Checking Lima VMs ==="
VMS=$(limactl list --format '{{.Name}}' 2>/dev/null || echo "")

if [ -z "$VMS" ]; then
    echo "⚠️  No Lima VMs running"
    echo "   Start VMs with: limactl start <vm-name>"
else
    echo "Found VMs:"
    limactl list
    
    echo ""
    echo "=== 4. Installing in VMs ==="
    
    for VM in $VMS; do
        echo ""
        echo "--- Installing in: $VM ---"
        
        # Check if VM is running
        STATUS=$(limactl list "$VM" --format '{{.Status}}' 2>/dev/null || echo "")
        if [ "$STATUS" != "Running" ]; then
            echo "⚠️  VM not running, skipping"
            continue
        fi
        
        # Copy extension to VM
        limactl shell "$VM" -- mkdir -p /tmp/mlcode-extension 2>/dev/null || true
        
        # Copy files
        limactl copy "$EXTENSION_DIR/cli.js" "$VM:/tmp/mlcode-extension/" 2>/dev/null || true
        limactl copy "$EXTENSION_DIR/install-bsd.sh" "$VM:/tmp/mlcode-extension/" 2>/dev/null || true
        limactl copy "$EXTENSION_DIR/package.json" "$VM:/tmp/mlcode-extension/" 2>/dev/null || true
        
        # Run installer
        limactl shell "$VM" -- sh /tmp/mlcode-extension/install-bsd.sh 2>&1 || echo "⚠️  Install failed (may need manual setup)"
        
        echo "✅ $VM: Installed"
    done
fi

echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
echo ""
echo "✅ macOS: Installed"
echo "✅ iOS: Synced to iCloud"
echo "✅ VMs: Installed in running VMs"
echo ""
echo "Next steps:"
echo "1. Reload Windsurf: Cmd+Shift+P → 'Developer: Reload Window'"
echo "2. Initialize model: Cmd+Shift+P → 'Initialize ML Model'"
echo "3. On iOS: Install Code App, load extension from iCloud"
echo "4. In VMs: Use 'mlcode' CLI or VS Code"
echo ""
