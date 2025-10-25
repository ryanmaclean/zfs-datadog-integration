# 🖥️ macOS VM with Code-Server Setup

**Goal**: Run full VS Code in browser via macOS VM

---

## 🎯 **Overview**

This guide sets up:
1. macOS VM using Lima + IPSW
2. code-server inside the VM
3. Browser-based VS Code access from host
4. Full development environment

---

## 📋 **Prerequisites**

```bash
# Required
- macOS host (M-series or Intel)
- Lima installed (brew install lima)
- 50GB+ free disk space
- 8GB+ RAM available

# Optional
- Fast internet (for IPSW download)
- Tailscale (for remote access)
```

---

## 🚀 **Quick Start**

```bash
# 1. Download IPSW
./scripts/download-ipsw.sh

# 2. Create macOS VM
./scripts/create-macos-vm.sh

# 3. Install code-server
./scripts/install-code-server.sh

# 4. Access VS Code
open http://localhost:8080
```

**Total time**: ~30-60 minutes (mostly IPSW download)

---

## 📥 **Step 1: Download IPSW**

### **What is IPSW?**
IPSW = iOS/macOS firmware file
- Contains full macOS installation
- Required for VM creation
- Size: ~13-15GB
- Download time: 10-30 minutes

### **Download Script**
```bash
./scripts/download-ipsw.sh
```

**What it does**:
- Detects your Mac architecture (M1/M2/Intel)
- Downloads appropriate IPSW
- Verifies download
- Saves to `macos-vm/ipsw/`

### **Manual Download**
If script fails:
1. Go to https://ipsw.me
2. Select your Mac model
3. Download latest macOS IPSW
4. Save to `macos-vm/ipsw/`

---

## 🖥️ **Step 2: Create macOS VM**

### **Using Lima**
```bash
./scripts/create-macos-vm.sh
```

**What it does**:
- Creates Lima VM config
- Uses downloaded IPSW
- Allocates 8GB RAM, 50GB disk
- Sets up networking
- Starts macOS installation

### **VM Specs**
```yaml
Name: macos-dev
CPUs: 4
Memory: 8GB
Disk: 50GB
Network: Bridged
Display: VNC (optional)
```

### **Installation Process**
```
1. VM boots from IPSW
2. macOS installer starts
3. Follow on-screen prompts
4. Create user account
5. Wait for installation (15-20 min)
6. VM reboots
7. macOS ready!
```

---

## 💻 **Step 3: Install code-server**

### **What is code-server?**
- VS Code running in browser
- Full VS Code experience
- Access from any device
- Extensions support

### **Installation**
```bash
./scripts/install-code-server.sh
```

**What it does**:
- Connects to macOS VM
- Installs code-server
- Configures authentication
- Sets up systemd service
- Starts code-server

### **Manual Installation**
```bash
# SSH into VM
limactl shell macos-dev

# Install code-server
curl -fsSL https://code-server.dev/install.sh | sh

# Configure
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: your-secure-password
cert: false
EOF

# Start
code-server
```

---

## 🌐 **Step 4: Access VS Code**

### **From Host Mac**
```bash
# Get VM IP
limactl shell macos-dev -- hostname -I

# Access in browser
open http://VM_IP:8080

# Or use port forwarding
ssh -L 8080:localhost:8080 lima-macos-dev
open http://localhost:8080
```

### **From iPad/iPhone**
```bash
# Get Tailscale IP (if using Tailscale)
limactl shell macos-dev -- tailscale ip

# Access in Safari
http://TAILSCALE_IP:8080
```

### **From Windows/Linux**
```bash
# SSH tunnel
ssh -L 8080:localhost:8080 user@mac-host

# Access in browser
http://localhost:8080
```

---

## 🔧 **Configuration**

### **code-server Settings**
```yaml
# ~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: change-me
cert: false
user-data-dir: ~/.local/share/code-server
extensions-dir: ~/.local/share/code-server/extensions
```

### **Lima VM Config**
```yaml
# ~/.lima/macos-dev/lima.yaml
cpus: 4
memory: 8GiB
disk: 50GiB
firmware:
  legacyBIOS: false
images:
  - location: "file:///path/to/ipsw"
    arch: "aarch64"
```

---

## 🎯 **Use Cases**

### **1. Remote Development**
- Code from iPad/iPhone
- Access from anywhere
- Full VS Code features
- No local resources needed

### **2. Isolated Environment**
- Clean macOS install
- No host pollution
- Easy to reset
- Snapshot support

### **3. Testing**
- Test macOS apps
- Different OS versions
- Clean environment
- Easy rollback

### **4. Team Development**
- Shared dev environment
- Consistent setup
- Easy onboarding
- Centralized resources

---

## 📊 **Performance**

### **Expected Performance**
```
VM Boot: 30-60 seconds
code-server Start: 5-10 seconds
Browser Response: <100ms
Extension Install: Same as desktop
File Operations: Near-native
```

### **Resource Usage**
```
Host CPU: 10-30% (idle)
Host RAM: 8GB (VM allocation)
Host Disk: 50GB (VM disk)
Network: Minimal
```

---

## 🐛 **Troubleshooting**

### **IPSW Download Fails**
```bash
# Check internet connection
ping ipsw.me

# Try manual download
open https://ipsw.me

# Check disk space
df -h
```

### **VM Won't Start**
```bash
# Check Lima status
limactl list

# View logs
limactl shell macos-dev -- dmesg

# Restart Lima
limactl stop macos-dev
limactl start macos-dev
```

### **code-server Won't Start**
```bash
# Check if running
limactl shell macos-dev -- ps aux | grep code-server

# Check logs
limactl shell macos-dev -- journalctl -u code-server

# Restart service
limactl shell macos-dev -- systemctl restart code-server
```

### **Can't Access in Browser**
```bash
# Check firewall
limactl shell macos-dev -- sudo ufw status

# Check port
limactl shell macos-dev -- netstat -tulpn | grep 8080

# Test connection
curl http://VM_IP:8080
```

---

## 🔒 **Security**

### **Recommendations**
1. **Change default password**
   ```bash
   # Edit config
   vim ~/.config/code-server/config.yaml
   # Change password
   ```

2. **Use HTTPS**
   ```bash
   # Generate cert
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout ~/.config/code-server/key.pem \
     -out ~/.config/code-server/cert.pem
   
   # Update config
   cert: true
   cert-key: ~/.config/code-server/key.pem
   ```

3. **Use Tailscale**
   ```bash
   # Install in VM
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   
   # Access via Tailscale IP
   ```

4. **Firewall Rules**
   ```bash
   # Allow only specific IPs
   sudo ufw allow from YOUR_IP to any port 8080
   ```

---

## 📚 **Additional Resources**

### **Documentation**
- Lima: https://lima-vm.io
- code-server: https://coder.com/docs/code-server
- IPSW: https://ipsw.me

### **Related Guides**
- `QUICKSTART.md` - Quick setup
- `PORTABLE-SOLUTION.md` - Remote development
- `EXTENSION-SETUP.md` - VS Code extensions

---

## 🎉 **Benefits**

### **vs Desktop VS Code**
- ✅ Access from any device
- ✅ No local resources
- ✅ Consistent environment
- ✅ Easy sharing
- ⚠️ Requires network
- ⚠️ Slight latency

### **vs GitHub Codespaces**
- ✅ Free (self-hosted)
- ✅ Full control
- ✅ No usage limits
- ✅ Local network speed
- ⚠️ Requires setup
- ⚠️ Requires maintenance

### **vs Remote SSH**
- ✅ Browser-based
- ✅ No SSH client needed
- ✅ Works on iOS
- ✅ Easy sharing
- ⚠️ Requires code-server
- ⚠️ Different from desktop

---

## 🚀 **Next Steps**

After setup:
1. Install ML Code Assistant extension
2. Configure workspace settings
3. Set up Tailscale for remote access
4. Create snapshots for backup
5. Customize code-server settings

---

## ✅ **Status**

**Scripts**: Ready to create  
**Documentation**: Complete  
**Testing**: Needs verification  
**Status**: Ready to implement  

**Let's build it!** 🎯
