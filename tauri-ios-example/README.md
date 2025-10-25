# 📱 Tauri iOS App for ZFS Development

A native iOS app built with Tauri that lets you develop and manage ZFS/kernel builds from your iPad/iPhone.

## ✨ Features

### **Code Editor**
- Monaco Editor (VS Code engine)
- Syntax highlighting for Bash, Rust, etc.
- Works offline
- Auto-save to iCloud

### **iCloud Integration**
- All files sync via iCloud Drive
- Access from Mac automatically
- Edit on iPad, build on Mac
- Offline support

### **Mac Connection**
- Connect to code-server on Mac
- Run SSH commands via HTTP proxy
- Monitor VM status
- Start/stop builds remotely

### **VM Management**
- List running VMs
- Start/stop kernel-build VM
- Check disk space
- View build logs

## 🚀 Setup

### **1. Install Dependencies**
```bash
# Install Tauri CLI
cargo install tauri-cli

# Install Node dependencies
npm install
```

### **2. Configure for iOS**
```bash
# Add iOS target
rustup target add aarch64-apple-ios

# Install Xcode (required)
xcode-select --install
```

### **3. Build for iOS**
```bash
# Development
npm run tauri ios dev

# Production
npm run tauri ios build
```

### **4. Setup Mac Side**

**Option A: code-server**
```bash
# On Mac
brew install code-server
code-server --bind-addr 0.0.0.0:8080
```

**Option B: HTTP Command Proxy**
```bash
# Simple Node.js server on Mac
node mac-proxy-server.js
```

## 📁 File Storage

### **iCloud Drive**
Files are stored in:
```
~/Library/Mobile Documents/iCloud~com~zfsdev/Documents/
```

This syncs automatically to:
- Mac: Same path
- iPad: Files app → iCloud Drive → ZFS Dev Tools
- iPhone: Same as iPad

### **Accessing from Mac**
```bash
# Files appear automatically
cd ~/Library/Mobile\ Documents/iCloud~com~zfsdev/Documents/

# Edit on iPad, builds run on Mac automatically!
```

## 🔧 Mac HTTP Proxy Server

```javascript
// mac-proxy-server.js
const express = require('express');
const { exec } = require('child_process');

const app = express();
app.use(express.json());

app.post('/exec', (req, res) => {
  const { command } = req.body;
  
  // Whitelist safe commands
  const allowed = ['limactl', 'df', 'ls'];
  const cmd = command.split(' ')[0];
  
  if (!allowed.includes(cmd)) {
    return res.status(403).json({ error: 'Command not allowed' });
  }
  
  exec(command, (error, stdout, stderr) => {
    res.json({
      stdout: stdout,
      stderr: stderr,
      error: error ? error.message : null
    });
  });
});

app.listen(3000, () => {
  console.log('Mac proxy server running on port 3000');
});
```

## 📱 Usage

### **On iPad/iPhone**
1. Open ZFS Dev Tools app
2. Files sync from iCloud automatically
3. Edit scripts in Monaco editor
4. Save → Auto-syncs to Mac
5. Connect to Mac
6. Run builds remotely

### **Workflow**
```
iPad: Edit script → Save to iCloud
  ↓ (auto-sync)
Mac: File appears → Run build
  ↓
iPad: Monitor progress → View logs
```

## 🎯 What Works

- ✅ Full code editor (Monaco)
- ✅ iCloud sync (automatic)
- ✅ SSH to Mac (via HTTP proxy)
- ✅ VM control (start/stop/status)
- ✅ Works offline (edit files)
- ✅ Native iOS app (fast)

## ❌ What Doesn't Work

- ❌ Can't run VMs on iOS
- ❌ Can't compile kernels on iOS
- ❌ No direct SSH (use HTTP proxy)
- ❌ No Node.js runtime on iOS

## 💡 Best Use Case

**Edit code on iPad → Auto-sync to Mac → Build on Mac → Monitor from iPad**

Perfect for:
- Editing scripts on the go
- Monitoring long builds
- Quick fixes from iPad
- Code review on iPhone
