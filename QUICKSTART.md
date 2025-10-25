# ⚡ Quick Start Guide

**Get up and running in 15 minutes**

---

## 📋 **Prerequisites** (5 minutes)

### **Check What You Have**
```bash
# Check macOS version (need 11+)
sw_vers

# Check architecture (M-series or Intel)
uname -m  # arm64 = M-series, x86_64 = Intel

# Check disk space (need 20GB+)
df -h ~
```

### **Install Required Tools**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js (for ML extension)
brew install node

# Install Lima (for VMs)
brew install lima

# Verify installations
node --version  # Should show v18+
limactl --version  # Should show 0.x.x
```

**Time**: ~5 minutes (if downloading)

---

## 🧠 **ML Code Assistant** (10 minutes)

### **Install Extension**
```bash
# Navigate to extension directory
cd code-app-ml-extension

# Install dependencies (takes 2-3 minutes, downloads 295MB)
npm install

# Copy to VS Code extensions
cp -r . ~/.vscode/extensions/mlcode-extension/

# Verify installation
ls ~/.vscode/extensions/mlcode-extension/extension.js
```

### **Activate in VS Code**
```
1. Open VS Code/Windsurf
2. Press Cmd+Shift+P
3. Type: "Developer: Reload Window"
4. Press Enter
5. Wait 5 seconds
6. Press Cmd+Shift+P again
7. Type: "Initialize ML Model"
8. Wait 30 seconds for model download
9. Start coding!
```

### **Test It Works**
```bash
# Test CLI
echo "function build" | node cli.js complete

# Should output:
# () {
#   # TODO: implement
# }
```

**Time**: ~10 minutes (including npm install)

---

## 🏗️ **Kernel Building** (45 minutes)

### **Create VM** (5 minutes)
```bash
# Create kernel build VM
limactl create --name=kernel-build lima-configs/kernel-build-arm64.yaml

# Start VM (downloads Ubuntu image, ~500MB)
limactl start kernel-build

# Verify VM is running
limactl list
```

### **Build Kernel** (40 minutes)
```bash
# Run build script
bash scripts/build-arm64-kernel-now.sh

# Monitor progress
tail -f /tmp/kernel-build-host.log

# Or check in VM
limactl shell kernel-build -- tail -f /tmp/kernel-build.log
```

### **Timeline**
```
00:00 - Build starts
00:05 - Installing dependencies
00:10 - Downloading kernel source
00:15 - Configuring kernel
00:20 - Compilation starts
00:40 - ~50% complete
00:55 - ~90% complete
01:00 - Installation
01:05 - Complete!
```

**Time**: ~45 minutes (mostly waiting)

---

## 🌐 **Remote Development** (10 minutes)

### **Enable SSH on Mac**
```bash
# Enable Remote Login
sudo systemsetup -setremotelogin on

# Get your Mac's hostname
hostname

# Test SSH locally
ssh localhost
```

### **Install Tailscale** (Optional but Recommended)
```bash
# Install Tailscale
brew install tailscale

# Start Tailscale
sudo tailscale up

# Get your Tailscale IP
tailscale ip -4
```

### **Connect from iPad/iPhone**
```
1. Install Code App (free) or Prompt ($)
2. Add SSH connection:
   - Host: your-mac.local (or Tailscale IP)
   - User: your-username
   - Port: 22
3. Connect and start coding!
```

### **Connect from Windows/Linux**
```bash
# Using SSH
ssh user@mac.local

# Using VS Code Remote
code --remote ssh-remote+mac.local /path/to/project
```

**Time**: ~10 minutes

---

## ⏱️ **Time Estimates**

| Task | Time | Notes |
|------|------|-------|
| **Prerequisites** | 5 min | If already have Homebrew |
| **ML Extension** | 10 min | Includes npm install (2-3 min) |
| **Kernel Build** | 45 min | Mostly automated, just wait |
| **Remote Dev** | 10 min | SSH setup + testing |
| **Total** | 70 min | Can do ML + Remote while kernel builds |

---

## ✅ **Verification**

### **ML Extension**
```bash
# Check installation
ls ~/.vscode/extensions/mlcode-extension/extension.js

# Test CLI
echo "test" | node code-app-ml-extension/cli.js complete

# In VS Code: Cmd+Shift+P → "Initialize ML Model"
```

### **Kernel Build**
```bash
# Check VM
limactl list | grep kernel-build

# Check build progress
tail /tmp/kernel-build-host.log

# When complete, check kernel
limactl shell kernel-build -- ls -lh /boot/vmlinuz-*
```

### **Remote Development**
```bash
# Check SSH
sudo systemsetup -getremotelogin
# Should show: "Remote Login: On"

# Test connection
ssh localhost
# Should connect without errors

# Check Tailscale (if installed)
tailscale status
# Should show: "online"
```

---

## 🐛 **Common Issues**

### **Extension doesn't appear in VS Code**
```
Solution: Reload window
1. Cmd+Shift+P
2. Type: "Developer: Reload Window"
3. Wait 5 seconds
4. Check Extensions panel (Cmd+Shift+X)
```

### **npm install fails**
```bash
# Clear npm cache
npm cache clean --force

# Try again
npm install
```

### **VM won't start**
```bash
# Check Lima status
limactl list

# Delete and recreate
limactl delete kernel-build
limactl create --name=kernel-build lima-configs/kernel-build-arm64.yaml
limactl start kernel-build
```

### **Kernel build fails**
```bash
# Check disk space
df -h

# Check VM logs
limactl shell kernel-build -- tail -100 /tmp/kernel-build.log

# Clean and retry
limactl shell kernel-build -- rm -rf /usr/src/linux
bash scripts/build-arm64-kernel-now.sh
```

### **SSH connection refused**
```bash
# Enable SSH
sudo systemsetup -setremotelogin on

# Check firewall
# System Settings → Network → Firewall → Allow SSH

# Test locally first
ssh localhost
```

---

## 📚 **Next Steps**

### **After Installation**
1. **ML Extension**: Start coding, try completions
2. **Kernel Build**: Wait for completion, test kernel
3. **Remote Dev**: Connect from iPad/iPhone

### **Learn More**
- `PROJECT-SUMMARY.md` - Complete overview
- `code-app-ml-extension/INSTALL.md` - Detailed ML extension guide
- `PORTABLE-SOLUTION.md` - Remote development deep dive
- `SESSION-COMPLETE.md` - What we built

### **Get Help**
- Check `NEW-USER-TEST.md` for common friction points
- See troubleshooting sections in docs
- Open GitHub issue if stuck

---

## 🎯 **Success Criteria**

You're done when:
- ✅ ML extension shows in VS Code extensions panel
- ✅ CLI completions work: `echo "test" | node cli.js complete`
- ✅ VM is running: `limactl list` shows kernel-build
- ✅ SSH works: `ssh localhost` connects
- ✅ Can code from iPad/iPhone (if testing remote dev)

**Congratulations! You're ready to use the system!** 🎉
