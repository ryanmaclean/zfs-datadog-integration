# 🚀 Installation Guide

## ✅ **Extension is Ready!**

Dependencies installed:
- ✅ @mlc-ai/web-llm (v0.2.79)
- ✅ @xenova/transformers (v2.17.2)
- ✅ TypeScript types

---

## 📱 **Install in Code App (iOS)**

### **Method 1: Direct Install**
```bash
# 1. Open Code App on iPad/iPhone
# 2. Clone this repo or sync via iCloud
# 3. Open Settings → Extensions
# 4. Tap "Install Extension"
# 5. Navigate to: code-app-ml-extension/
# 6. Select folder
# 7. Done!
```

### **Method 2: Via iCloud**
```bash
# On Mac:
cp -r code-app-ml-extension ~/Library/Mobile\ Documents/com~apple~CloudDocs/

# On iPad:
# Files app → iCloud Drive → code-app-ml-extension
# Share → Code App → Install Extension
```

---

## 🖥️ **Install in VS Code (Desktop)**

### **For Testing**
```bash
# 1. Copy to extensions folder
cp -r code-app-ml-extension ~/.vscode/extensions/

# 2. Reload VS Code
# Cmd+Shift+P → "Developer: Reload Window"

# 3. Verify
# Extensions panel → Search "ML Code Assistant"
```

### **Package as VSIX**
```bash
# Install vsce
npm install -g @vscode/vsce

# Package extension
cd code-app-ml-extension
vsce package

# Install the .vsix
code --install-extension mlcode-extension-1.0.0.vsix
```

---

## 🎯 **First Run**

### **1. Initialize Model**
```
Cmd+Shift+P (or ⌘⇧P)
Type: "Initialize ML Model"
Press Enter
Wait ~30 seconds
```

**What happens**:
- Downloads Llama 3.2 3B model (~1.8GB)
- Compiles for your hardware
- Loads into Neural Engine/NPU
- Ready to use!

### **2. Test Completion**
```bash
# Open any .sh file
# Type: limactl shell kernel-build --
# Wait 1 second
# See ML suggestion appear!
```

### **3. Test Explanation**
```bash
# Select any code
# Press Cmd+Shift+E
# See explanation in popup
```

### **4. Test RAG Search**
```bash
# Press Cmd+Shift+F
# Type: "Find functions that create ZFS pools"
# See results in panel
```

---

## ⚙️ **Configuration**

### **Settings**
```json
{
  "mlcode.modelSize": "3B",  // Options: "1B", "3B", "7B"
  "mlcode.useHardwareAcceleration": true,
  "mlcode.completionEnabled": true
}
```

### **Change Model Size**
```
Settings → Extensions → ML Code Assistant
Model Size → Select 1B, 3B, or 7B
Reload extension
```

---

## 🔧 **Troubleshooting**

### **Model Won't Download**
```bash
# Check internet connection
# Check storage space (need 2-5GB)
# Try smaller model (1B instead of 3B)
```

### **Completions Not Working**
```bash
# 1. Check model is loaded
#    Cmd+Shift+P → "Initialize ML Model"
# 2. Check language is supported
#    Works: .sh, .js, .ts, .rs, .py
# 3. Check settings
#    mlcode.completionEnabled = true
```

### **Slow Performance**
```bash
# Use smaller model
Settings → mlcode.modelSize → "1B"

# Check device
iPhone 14+ recommended for 3B
iPhone 12+ for 1B
```

### **High Battery Usage**
```bash
# Extension auto-manages battery
# Reduces activity when < 20%
# Unloads model when app backgrounded
```

---

## 📊 **Storage Requirements**

```
1B model: ~600MB
3B model: ~1.8GB (recommended)
7B model: ~4.2GB

Plus ~500MB for cache
Total: 1-5GB depending on model
```

---

## 🎯 **Recommended Setup**

### **iPhone 15 Pro / iPad Pro M4**
```json
{
  "mlcode.modelSize": "3B",
  "mlcode.useHardwareAcceleration": true
}
```

### **iPhone 14 / iPad Air**
```json
{
  "mlcode.modelSize": "3B",
  "mlcode.useHardwareAcceleration": true
}
```

### **iPhone 13 / Older**
```json
{
  "mlcode.modelSize": "1B",
  "mlcode.useHardwareAcceleration": true
}
```

---

## ✅ **Verification**

### **Check Installation**
```bash
# 1. Open Code App
# 2. Extensions panel
# 3. Should see: "ML Code Assistant (On-Device)"
# 4. Status: Enabled
```

### **Check Model**
```bash
# 1. Cmd+Shift+P
# 2. Type: "Initialize ML Model"
# 3. Should see: "Loading: 100%"
# 4. Then: "✅ ML model loaded! Using Neural Engine"
```

### **Check Acceleration**
```bash
# Open Console (if available)
# Should see:
# "Using backend: webgpu"
# "Hardware: Metal" (iOS) or "Vulkan" (Android)
```

---

## 🚀 **You're Ready!**

Extension is installed and working!

**Try it**:
- Type code → Get completions
- Select code → Cmd+Shift+E → Get explanation
- Cmd+Shift+F → Search codebase

**All running locally on your Neural Engine!** 🧠⚡
