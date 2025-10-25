#!/bin/bash
#
# Verify extension build
#

set -e

echo "🔍 Verifying Extension Build..."
echo ""

# Check files
echo "✅ Checking files..."
FILES=(
  "package.json"
  "extension.js"
  "README.md"
  "node_modules/@mlc-ai/web-llm"
  "node_modules/@xenova/transformers"
)

for file in "${FILES[@]}"; do
  if [ -e "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ $file MISSING"
    exit 1
  fi
done

# Check package.json
echo ""
echo "✅ Checking package.json..."
if grep -q '"name": "mlcode-extension"' package.json; then
  echo "  ✅ Name correct"
else
  echo "  ❌ Name incorrect"
  exit 1
fi

if grep -q '"publisher":' package.json; then
  echo "  ✅ Publisher set"
else
  echo "  ❌ Publisher missing"
  exit 1
fi

if grep -q '"main": "./extension.js"' package.json; then
  echo "  ✅ Main entry correct"
else
  echo "  ❌ Main entry incorrect"
  exit 1
fi

# Check extension.js
echo ""
echo "✅ Checking extension.js..."
if grep -q "export.*function activate" extension.js; then
  echo "  ✅ activate() function found"
else
  echo "  ❌ activate() function missing"
  exit 1
fi

if grep -q "export.*function deactivate" extension.js; then
  echo "  ✅ deactivate() function found"
else
  echo "  ❌ deactivate() function missing"
  exit 1
fi

# Check dependencies
echo ""
echo "✅ Checking dependencies..."
if [ -d "node_modules/@mlc-ai/web-llm" ]; then
  echo "  ✅ @mlc-ai/web-llm installed"
else
  echo "  ❌ @mlc-ai/web-llm missing"
  exit 1
fi

if [ -d "node_modules/@xenova/transformers" ]; then
  echo "  ✅ @xenova/transformers installed"
else
  echo "  ❌ @xenova/transformers missing"
  exit 1
fi

# Test load
echo ""
echo "✅ Testing extension load..."
if node -e "const ext = require('./extension.js'); if (typeof ext.activate !== 'function') process.exit(1)" 2>/dev/null; then
  echo "  ✅ Extension loads successfully"
else
  echo "  ❌ Extension fails to load"
  exit 1
fi

# Check size
echo ""
echo "✅ Checking size..."
SIZE=$(du -sh . | awk '{print $1}')
echo "  Extension size: $SIZE"

# Summary
echo ""
echo "=========================================="
echo "✅ BUILD VERIFICATION PASSED"
echo "=========================================="
echo ""
echo "Extension is ready to install!"
echo ""
echo "To install:"
echo "  cp -r . ~/.vscode/extensions/mlcode-extension"
echo ""
echo "Then reload VS Code:"
echo "  Cmd+Shift+P → 'Developer: Reload Window'"
echo ""
