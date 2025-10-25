#!/bin/sh
#
# Install ML Code Assistant - Universal Installer
# Supports: FreeBSD, OpenBSD, NetBSD, OmniOS, Linux, macOS
#

set -e

echo "🚀 ML Code Assistant - Universal Installer"
echo ""

# Detect OS
OS=$(uname -s)
echo "Detected OS: $OS"

case "$OS" in
  FreeBSD)
    echo "Installing for FreeBSD..."
    PKG_CMD="pkg install -y"
    ;;
  OpenBSD)
    echo "Installing for OpenBSD..."
    PKG_CMD="pkg_add"
    ;;
  NetBSD)
    echo "Installing for NetBSD..."
    PKG_CMD="pkgin -y install"
    ;;
  SunOS)
    echo "Installing for OmniOS/Illumos..."
    PKG_CMD="pkg install"
    ;;
  Linux)
    echo "Installing for Linux..."
    if command -v apt-get >/dev/null 2>&1; then
      PKG_CMD="apt-get install -y"
    elif command -v yum >/dev/null 2>&1; then
      PKG_CMD="yum install -y"
    elif command -v apk >/dev/null 2>&1; then
      PKG_CMD="apk add"
    else
      PKG_CMD="echo 'Install manually:'"
    fi
    ;;
  Darwin)
    echo "Installing for macOS..."
    PKG_CMD="brew install"
    ;;
  *)
    echo "Unknown OS: $OS (will try generic install)"
    PKG_CMD="echo 'Install manually:'"
    ;;
esac

# Check for Node.js
if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node.js..."
  case "$OS" in
    FreeBSD)
      sudo pkg install -y node npm
      ;;
    OpenBSD)
      doas pkg_add node
      ;;
    NetBSD)
      sudo pkgin -y install nodejs
      ;;
    SunOS)
      sudo pkg install nodejs
      ;;
  esac
else
  echo "✅ Node.js already installed: $(node --version)"
fi

# Install dependencies
echo ""
echo "Installing extension dependencies..."
npm install

# Create directories
mkdir -p ~/.vscode/extensions
mkdir -p ~/.local/share/mlcode

# Copy extension
echo ""
echo "Installing extension..."
cp -r . ~/.vscode/extensions/mlcode-extension
cp -r . ~/.local/share/mlcode/

# Make CLI executable
chmod +x ~/.vscode/extensions/mlcode-extension/cli.js
chmod +x ~/.local/share/mlcode/cli.js

# Create symlink
if [ "$OS" != "OpenBSD" ]; then
  sudo ln -sf ~/.local/share/mlcode/cli.js /usr/local/bin/mlcode 2>/dev/null || \
    ln -sf ~/.local/share/mlcode/cli.js ~/bin/mlcode
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Extension installed to:"
echo "  ~/.vscode/extensions/mlcode-extension/"
echo "  ~/.local/share/mlcode/"
echo ""
echo "CLI tool:"
if [ "$OS" != "OpenBSD" ]; then
  echo "  mlcode init"
  echo "  echo 'code' | mlcode complete"
else
  echo "  ~/.local/share/mlcode/cli.js init"
  echo "  echo 'code' | ~/.local/share/mlcode/cli.js complete"
fi
echo ""
echo "For VS Code:"
echo "  1. Install VS Code (if not installed)"
echo "  2. Reload VS Code"
echo "  3. Extension will be available"
echo ""
echo "For vim/emacs:"
echo "  See BSD-OMNIOS-SUPPORT.md for integration"
echo ""
