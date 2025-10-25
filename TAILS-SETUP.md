# 🔒 code-server on Tails Linux

**Question**: Can code-server run on Tails Linux live ISO?  
**Answer**: Yes, but with challenges!

---

## 🎯 **What is Tails?**

**Tails** = The Amnesic Incognito Live System
- Privacy-focused Linux distribution
- Runs from USB/DVD (live system)
- Routes all traffic through Tor
- Leaves no trace on computer
- Resets on every boot

---

## ⚠️ **Challenges**

### **Tails is Designed to be Ephemeral**
```
Problem: Everything resets on reboot
Solution: Use persistent storage

Problem: Limited package installation
Solution: Use AppImage or portable binaries

Problem: All traffic goes through Tor
Solution: Configure localhost exceptions

Problem: Read-only filesystem
Solution: Install to persistent storage
```

---

## ✅ **Can It Work?**

### **Short Answer**: Yes, with persistent storage!

| Feature | Status | Notes |
|---------|--------|-------|
| **Install Node.js** | ✅ Possible | Via persistent storage |
| **Install code-server** | ✅ Possible | Via npm or AppImage |
| **Run locally** | ✅ Works | localhost bypasses Tor |
| **Access remotely** | ⚠️ Complex | Need .onion service |
| **Persistent data** | ✅ Possible | With persistent storage |
| **ML Extension** | ✅ Works | Pure JavaScript |

---

## 🚀 **Installation Methods**

### **Method 1: Persistent Storage (Recommended)**

#### **Setup Persistent Storage**
```bash
# 1. Enable persistent storage in Tails
# Applications → Tails → Configure persistent volume

# 2. Enable "Additional Software" persistence
# This allows installing packages that persist across reboots

# 3. Reboot Tails
```

#### **Install Node.js**
```bash
# Add Debian repository
echo "deb http://deb.debian.org/debian bookworm main" | \
  sudo tee /etc/apt/sources.list.d/debian.list

# Update
sudo apt update

# Install Node.js
sudo apt install nodejs npm

# Verify
node --version
npm --version
```

#### **Install code-server**
```bash
# Install globally
npm install -g code-server

# Or download binary
curl -fsSL https://code-server.dev/install.sh | sh

# Configure
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 127.0.0.1:8080
auth: password
password: $(openssl rand -base64 32)
cert: false
EOF

# Start
code-server
```

---

### **Method 2: Portable AppImage**

#### **Download AppImage**
```bash
# Create persistent directory
mkdir -p ~/Persistent/code-server

# Download code-server AppImage (if available)
# Or use portable Node.js + code-server

# Download portable Node.js
cd ~/Persistent/code-server
wget https://nodejs.org/dist/v20.10.0/node-v20.10.0-linux-x64.tar.xz
tar -xf node-v20.10.0-linux-x64.tar.xz

# Add to PATH
export PATH=$HOME/Persistent/code-server/node-v20.10.0-linux-x64/bin:$PATH

# Install code-server
npm install -g code-server

# Run
code-server
```

---

### **Method 3: Docker (If Available)**

```bash
# If Docker is available in Tails
docker run -it -p 127.0.0.1:8080:8080 \
  -v "$HOME/Persistent/projects:/home/coder/project" \
  codercom/code-server:latest
```

---

## 🔒 **Security Considerations**

### **Tails Security Model**
```
✅ All network traffic through Tor (except localhost)
✅ Amnesia (resets on reboot)
✅ No trace on computer
⚠️ Persistent storage can leave traces
⚠️ code-server stores data locally
```

### **Best Practices**
```bash
# 1. Only bind to localhost
bind-addr: 127.0.0.1:8080  # NOT 0.0.0.0

# 2. Use strong password
password: $(openssl rand -base64 32)

# 3. Store sensitive data in persistent encrypted storage
# Use Tails persistent storage with encryption

# 4. Don't expose to network
# Keep it localhost-only

# 5. Clear data when done
rm -rf ~/.local/share/code-server/*
```

---

## 🌐 **Access from Other Devices**

### **Problem**: Tails routes all traffic through Tor

### **Solution 1: Onion Service**
```bash
# Create hidden service for code-server
sudo nano /etc/tor/torrc

# Add:
HiddenServiceDir /var/lib/tor/code-server/
HiddenServicePort 80 127.0.0.1:8080

# Restart Tor
sudo systemctl restart tor

# Get .onion address
sudo cat /var/lib/tor/code-server/hostname

# Access from Tor Browser
http://YOUR_ONION_ADDRESS
```

### **Solution 2: SSH Tunnel**
```bash
# From another machine with Tor
torsocks ssh -L 8080:localhost:8080 user@tails-onion-address

# Access
http://localhost:8080
```

---

## 📦 **Persistent Setup Script**

```bash
#!/bin/bash
# save-to-persistent.sh
# Run this to set up code-server in Tails persistent storage

set -e

PERSISTENT_DIR="$HOME/Persistent/code-server"
mkdir -p "$PERSISTENT_DIR"

echo "Installing Node.js..."
cd "$PERSISTENT_DIR"

# Download portable Node.js
if [ ! -d "node" ]; then
    wget https://nodejs.org/dist/v20.10.0/node-v20.10.0-linux-x64.tar.xz
    tar -xf node-v20.10.0-linux-x64.tar.xz
    mv node-v20.10.0-linux-x64 node
    rm node-v20.10.0-linux-x64.tar.xz
fi

# Add to PATH
export PATH="$PERSISTENT_DIR/node/bin:$PATH"

echo "Installing code-server..."
npm install -g code-server

echo "Creating config..."
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 127.0.0.1:8080
auth: password
password: $(openssl rand -base64 32)
cert: false
EOF

echo "Creating startup script..."
cat > "$PERSISTENT_DIR/start-code-server.sh" <<'EOF'
#!/bin/bash
export PATH="$HOME/Persistent/code-server/node/bin:$PATH"
code-server
EOF

chmod +x "$PERSISTENT_DIR/start-code-server.sh"

echo "Done!"
echo "To start: $PERSISTENT_DIR/start-code-server.sh"
echo "Access: http://localhost:8080"
echo "Password: $(grep password ~/.config/code-server/config.yaml | awk '{print $2}')"
```

---

## 🎯 **Use Cases**

### **Why Use code-server on Tails?**

1. **Anonymous Development**
   - Develop without revealing identity
   - All traffic through Tor
   - No trace on host computer

2. **Secure Coding**
   - Isolated environment
   - Encrypted persistent storage
   - Privacy-focused

3. **Portable Development**
   - USB stick with Tails + code-server
   - Work on any computer
   - Leave no trace

4. **Whistleblower/Journalist Work**
   - Secure document editing
   - Anonymous communication
   - Protected environment

---

## ⚠️ **Limitations**

### **What Doesn't Work Well**
```
❌ Remote access (Tor only, slow)
❌ Large file operations (USB speed)
❌ Heavy extensions (limited RAM)
❌ Persistent state (resets on boot without persistent storage)
⚠️ Performance (slower than native)
⚠️ Extension marketplace (Tor routing)
```

### **What Works Well**
```
✅ Local development
✅ Text editing
✅ Small projects
✅ Privacy-focused work
✅ ML Code Assistant (pure JS)
```

---

## 📊 **Performance**

### **Expected Performance on Tails**
```
Startup: 10-20 seconds
Memory: ~500MB
CPU: 10-20% idle
Disk I/O: Limited by USB speed
Network: Tor routing (slow for external)
Localhost: Normal speed
```

---

## 🔧 **Troubleshooting**

### **Node.js Not Found**
```bash
# Add to PATH
export PATH="$HOME/Persistent/code-server/node/bin:$PATH"

# Make permanent
echo 'export PATH="$HOME/Persistent/code-server/node/bin:$PATH"' >> ~/.bashrc
```

### **Can't Install Packages**
```bash
# Tails restricts package installation
# Use persistent storage
# Or use portable binaries
```

### **Tor Blocking npm**
```bash
# npm might be slow through Tor
# Use --no-audit flag
npm install --no-audit

# Or download packages manually
```

---

## ✅ **Summary**

### **Can code-server run on Tails?**
**Yes!** With persistent storage.

### **Is it practical?**
**Depends on use case:**
- ✅ Privacy-focused development
- ✅ Anonymous coding
- ✅ Portable environment
- ⚠️ Performance limitations
- ⚠️ Setup complexity

### **Best For**
- Journalists
- Whistleblowers
- Privacy advocates
- Secure development
- Anonymous work

### **Not Best For**
- Heavy development
- Large projects
- Performance-critical work
- Team collaboration

---

## 🚀 **Quick Start**

```bash
# 1. Boot Tails with persistent storage
# 2. Enable "Additional Software" persistence
# 3. Run setup script
./save-to-persistent.sh

# 4. Start code-server
~/Persistent/code-server/start-code-server.sh

# 5. Access
http://localhost:8080

# 6. Code anonymously!
```

---

## 🔒 **Privacy Tips**

1. **Only use localhost** (127.0.0.1, not 0.0.0.0)
2. **Use strong passwords**
3. **Encrypt persistent storage**
4. **Clear data when done**
5. **Don't expose to network** (unless via .onion)
6. **Use Tor Browser** to access (if remote)
7. **Be aware of metadata**

---

## 💡 **Conclusion**

**code-server on Tails = Possible and Useful!**

Perfect for:
- 🔒 Anonymous development
- 🔐 Secure coding
- 💼 Whistleblower work
- 📝 Private documentation
- 🌍 Portable environment

**With persistent storage, it works!** 🚀🔒
