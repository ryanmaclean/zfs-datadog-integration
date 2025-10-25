# 🔓 VSCodium - Truly Open-Source VS Code

**What**: VS Code without Microsoft telemetry and branding  
**License**: MIT (100% open-source)  
**Why**: No telemetry, no proprietary bits, pure open-source

---

## 🎯 **What is VSCodium?**

### **VS Code vs VSCodium**

| Feature | VS Code | VSCodium |
|---------|---------|----------|
| **Source Code** | ✅ MIT | ✅ MIT |
| **Binary** | ⚠️ Proprietary license | ✅ MIT |
| **Telemetry** | ❌ Enabled by default | ✅ Disabled |
| **Branding** | Microsoft | Community |
| **Extensions** | Microsoft marketplace | Open VSX |
| **Updates** | Microsoft | Community |
| **License** | Mixed | 100% MIT |

### **Key Differences**
```
VS Code:
- Source: MIT (open)
- Binary: Proprietary Microsoft license
- Telemetry: Enabled (can disable)
- Marketplace: Microsoft only
- Branding: Microsoft

VSCodium:
- Source: MIT (open)
- Binary: MIT (open)
- Telemetry: Completely removed
- Marketplace: Open VSX (open)
- Branding: Community
```

---

## 🚀 **Installation**

### **macOS**
```bash
# Install VSCodium
brew install --cask vscodium

# Launch
open -a VSCodium
```

### **Linux**
```bash
# Debian/Ubuntu
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list
sudo apt update && sudo apt install codium

# Arch
yay -S vscodium-bin
```

### **Windows**
```powershell
# Chocolatey
choco install vscodium

# Scoop
scoop bucket add extras
scoop install vscodium
```

---

## 🔧 **Setup with ML Extension**

### **Install ML Code Assistant**
```bash
# Copy extension to VSCodium
cp -r code-app-ml-extension ~/.vscode-oss/extensions/mlcode-extension/

# Or create symlink
ln -s $(pwd)/code-app-ml-extension ~/.vscode-oss/extensions/mlcode-extension

# Install dependencies
cd ~/.vscode-oss/extensions/mlcode-extension
npm install
```

### **Configure Workspace**
```bash
# VSCodium uses different paths
# Extensions: ~/.vscode-oss/extensions/
# Settings: ~/.config/VSCodium/User/settings.json
# Workspace: .vscode/ (same as VS Code)
```

---

## 📦 **Extension Marketplace**

### **Open VSX vs Microsoft Marketplace**

**Microsoft Marketplace**:
- ❌ Proprietary
- ❌ Requires Microsoft account
- ❌ Telemetry
- ✅ More extensions

**Open VSX**:
- ✅ Open-source
- ✅ No account needed
- ✅ No telemetry
- ⚠️ Fewer extensions (but growing!)

### **Using Microsoft Marketplace in VSCodium**
```json
// settings.json
{
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false,
  
  // Optional: Use Microsoft marketplace (not recommended)
  "extensions.gallery": {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "itemUrl": "https://marketplace.visualstudio.com/items"
  }
}
```

### **Recommended: Use Open VSX**
```bash
# Install extensions from Open VSX
# Built-in by default in VSCodium
# Search and install like normal
```

---

## 🎯 **Our Setup**

### **Project Structure**
```
windsurf-project/
├── .vscode/                    # Works with both!
│   ├── extensions.json         # Recommends ML extension
│   └── settings.json           # Workspace settings
├── code-app-ml-extension/      # Our ML extension
└── ...
```

### **Make ML Extension Work**
```bash
# 1. Copy to VSCodium extensions
cp -r code-app-ml-extension ~/.vscode-oss/extensions/mlcode-extension/

# 2. Install dependencies
cd ~/.vscode-oss/extensions/mlcode-extension
npm install

# 3. Reload VSCodium
# Cmd+Shift+P → "Developer: Reload Window"

# 4. Verify
# Extensions panel should show "ML Code Assistant"
```

---

## 🔒 **Privacy & Telemetry**

### **VS Code Telemetry**
```json
// What VS Code collects (even when "disabled"):
{
  "machineId": "...",
  "sessionId": "...",
  "timestamp": "...",
  "platform": "darwin",
  "product": "vscode",
  "version": "1.85.0",
  // ... and more
}
```

### **VSCodium Telemetry**
```
None. Completely removed from source code.
```

### **Verification**
```bash
# VS Code: Check network traffic
# You'll see requests to:
# - vortex.data.microsoft.com
# - dc.services.visualstudio.com
# - mobile.events.data.microsoft.com

# VSCodium: Check network traffic
# No telemetry requests!
```

---

## 📊 **Comparison**

| Feature | VS Code | VSCodium | code-server | Winner |
|---------|---------|----------|-------------|---------|
| **Open-Source** | ⚠️ Partial | ✅ 100% | ✅ 100% | VSCodium/code-server |
| **Telemetry** | ❌ Yes | ✅ None | ✅ None | VSCodium/code-server |
| **License** | Mixed | MIT | Apache 2.0 | All open |
| **Extensions** | Most | Many | Most | VS Code |
| **Multi-Platform** | Desktop | Desktop | Browser | code-server |
| **iOS/iPad** | ❌ | ❌ | ✅ | code-server |
| **Multi-User** | ❌ | ❌ | ✅ | code-server |
| **Privacy** | ⚠️ | ✅ | ✅ | VSCodium/code-server |

---

## 🎯 **Use Cases**

### **Use VSCodium when:**
- ✅ You want desktop app
- ✅ You care about privacy
- ✅ You want 100% open-source
- ✅ You don't need Microsoft marketplace
- ✅ You work locally

### **Use code-server when:**
- ✅ You need browser access
- ✅ You need iOS/iPad support
- ✅ You need multi-user
- ✅ You want remote access
- ✅ You want zero install for users

### **Use both!**
```
VSCodium: Local development (privacy + open-source)
code-server: Remote/multi-platform (browser + multi-user)
```

---

## 🚀 **Quick Start**

### **Install VSCodium**
```bash
brew install --cask vscodium
```

### **Install ML Extension**
```bash
cp -r code-app-ml-extension ~/.vscode-oss/extensions/mlcode-extension/
cd ~/.vscode-oss/extensions/mlcode-extension
npm install
```

### **Open Project**
```bash
codium /Users/studio/CascadeProjects/windsurf-project
```

### **Verify**
```bash
# Check extensions
# Cmd+Shift+X
# Should see "ML Code Assistant"

# Test completion
# Type some code
# Should get ML completions
```

---

## 💡 **Best Setup**

### **The Trinity** 🎯
```
1. Native Windsurf
   - Daily work
   - Fastest (0ms)
   - Full features

2. VSCodium
   - Privacy-focused work
   - 100% open-source
   - Desktop app

3. code-server
   - iPad/iPhone access
   - Multi-user
   - Browser-based
```

### **When to Use Each**
```
Daily coding: Windsurf (fastest, most features)
Privacy work: VSCodium (no telemetry, pure open-source)
Remote/mobile: code-server (browser, any device)
Team work: code-server (multi-user, O(1) scaling)
```

---

## 📝 **Configuration**

### **VSCodium Settings**
```json
// ~/.config/VSCodium/User/settings.json
{
  // Disable any remaining tracking
  "telemetry.telemetryLevel": "off",
  "update.mode": "manual",
  
  // ML Code Assistant
  "mlcode.enabled": true,
  "mlcode.autoComplete": true,
  "mlcode.modelSize": "3B",
  "mlcode.hardwareAcceleration": true,
  
  // Editor
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  
  // Git
  "git.enableSmartCommit": true,
  "git.confirmSync": false
}
```

### **Workspace Settings** (same as VS Code)
```json
// .vscode/settings.json
{
  "mlcode.enabled": true,
  "mlcode.autoComplete": true
}
```

---

## 🔍 **Verify Installation**

### **Check Version**
```bash
codium --version
```

### **Check Extensions Path**
```bash
ls ~/.vscode-oss/extensions/
```

### **Check ML Extension**
```bash
ls ~/.vscode-oss/extensions/mlcode-extension/
```

### **Test ML Completions**
```bash
# Open VSCodium
codium .

# Create test file
# Type: function test
# Should get ML completion
```

---

## ✅ **Summary**

### **VSCodium** = VS Code - Microsoft
```
✅ 100% open-source (MIT)
✅ No telemetry
✅ No proprietary bits
✅ Desktop app
✅ Privacy-focused
⚠️ Fewer extensions (Open VSX)
```

### **Perfect For**
- Privacy-conscious developers
- Open-source purists
- Desktop-first workflow
- No telemetry requirement

### **Combined with code-server**
```
VSCodium: Desktop, privacy, open-source
code-server: Browser, multi-platform, multi-user

Best of both worlds! 🎯
```

---

## 🎉 **Ready to Use**

```bash
# Install
brew install --cask vscodium

# Setup ML extension
cp -r code-app-ml-extension ~/.vscode-oss/extensions/mlcode-extension/
cd ~/.vscode-oss/extensions/mlcode-extension && npm install

# Launch
codium /Users/studio/CascadeProjects/windsurf-project

# Start coding with 100% open-source tools!
```

**VSCodium + code-server = Perfect open-source development environment!** 🔓
