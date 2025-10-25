# 🌍 code-server on OmniOS/Solaris

**Complete guide for running code-server on illumos-based systems**

---

## 🎯 **What This Does**

Installs and configures code-server on:
- ✅ OmniOS (r151048+)
- ✅ Solaris 11.4+
- ✅ OpenIndiana
- ✅ Any illumos distribution

---

## 🚀 **Quick Start**

### **Automated Installation**
```bash
# On OmniOS/Solaris
./install-code-server.sh

# Follow prompts
# Save the password!
# Start code-server
```

### **Manual Installation**
```bash
# 1. Install Node.js
pkg install nodejs

# 2. Install code-server
npm install -g code-server

# 3. Configure
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: your-secure-password
cert: false
EOF

# 4. Start
code-server

# 5. Access
# http://YOUR_OMNIOS_IP:8080
```

---

## 📋 **Prerequisites**

### **OmniOS**
```bash
# Update package manager
pkg refresh

# Install required packages
pkg install nodejs npm
```

### **Solaris 11.4**
```bash
# Update IPS
pkg refresh

# Install Node.js
pkg install nodejs
```

### **OpenIndiana**
```bash
# Update packages
pkg refresh

# Install Node.js
pkg install nodejs
```

---

## 🔧 **Installation Steps**

### **Step 1: Install Node.js**
```bash
# Via pkg (recommended)
pkg install nodejs

# Verify
node --version  # Should be v18+ or v20+
npm --version
```

### **Step 2: Install code-server**
```bash
# Global installation
npm install -g code-server

# Verify
code-server --version
```

### **Step 3: Configure**
```bash
# Create config directory
mkdir -p ~/.config/code-server

# Create config file
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $(openssl rand -base64 32)
cert: false
EOF

# View password
cat ~/.config/code-server/config.yaml | grep password
```

### **Step 4: Install ML Extension**
```bash
# Copy extension
mkdir -p ~/.local/share/code-server/extensions
cp -r /path/to/code-app-ml-extension ~/.local/share/code-server/extensions/mlcode-extension

# Install dependencies
cd ~/.local/share/code-server/extensions/mlcode-extension
npm install
```

### **Step 5: Start code-server**
```bash
# Start manually
code-server

# Or in background
nohup code-server > ~/code-server.log 2>&1 &

# Check logs
tail -f ~/code-server.log
```

---

## 🎯 **SMF Service (OmniOS)**

### **Create Service**
```bash
# Create manifest
cat > /tmp/code-server.xml <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">
<service_bundle type='manifest' name='code-server'>
  <service name='application/code-server' type='service' version='1'>
    <create_default_instance enabled='true' />
    <single_instance />
    
    <dependency name='network' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/milestone/network:default' />
    </dependency>
    
    <exec_method type='method' name='start' exec='/usr/bin/code-server' timeout_seconds='60'>
      <method_context>
        <method_credential user='YOUR_USER' />
      </method_context>
    </exec_method>
    
    <exec_method type='method' name='stop' exec=':kill' timeout_seconds='60' />
    
    <property_group name='startd' type='framework'>
      <propval name='duration' type='astring' value='child' />
    </property_group>
    
    <stability value='Evolving' />
  </service>
</service_bundle>
EOF

# Import service
sudo cp /tmp/code-server.xml /var/svc/manifest/application/
sudo svccfg import /var/svc/manifest/application/code-server.xml

# Enable service
sudo svcadm enable code-server

# Check status
svcs code-server

# View logs
svcs -L code-server
```

---

## 🌐 **Access from Other Devices**

### **From macOS/Linux**
```bash
# Get OmniOS IP
ssh omnios-server "ifconfig -a | grep 'inet '"

# Access in browser
open http://OMNIOS_IP:8080
```

### **From iPad/iPhone**
```bash
# In Safari
http://OMNIOS_IP:8080

# Enter password
# Full VS Code in browser!
```

### **From Windows**
```bash
# In any browser
http://OMNIOS_IP:8080
```

---

## 🔒 **Security**

### **Firewall Rules**
```bash
# Allow port 8080
# OmniOS uses ipfilter

# Create rules file
cat > /tmp/ipf.rules <<EOF
# Allow SSH
pass in quick proto tcp from any to any port = 22

# Allow code-server
pass in quick proto tcp from any to any port = 8080
EOF

# Load rules
sudo ipf -Fa -f /tmp/ipf.rules

# Enable on boot
sudo svcadm enable ipfilter
```

### **HTTPS (Optional)**
```bash
# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ~/.config/code-server/key.pem \
  -out ~/.config/code-server/cert.pem

# Update config
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: your-password
cert: ~/.config/code-server/cert.pem
cert-key: ~/.config/code-server/key.pem
EOF

# Restart code-server
# Access: https://OMNIOS_IP:8080
```

---

## 📊 **Performance**

### **Expected Performance on OmniOS**
```
Startup time: 5-10 seconds
Memory usage: ~500MB
CPU usage: 5-10% idle
Response time: <50ms (LAN)
```

### **Optimization**
```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=4096"

# Start code-server
code-server
```

---

## 🐛 **Troubleshooting**

### **Node.js Not Found**
```bash
# Check if installed
pkg list nodejs

# Install if missing
pkg install nodejs

# Add to PATH
export PATH=/usr/bin:/usr/node/bin:$PATH
```

### **code-server Won't Start**
```bash
# Check logs
cat ~/.local/share/code-server/code-server.log

# Check port
netstat -an | grep 8080

# Kill existing process
pkill -f code-server

# Restart
code-server
```

### **Can't Access from Network**
```bash
# Check firewall
ipfstat -io

# Check binding
netstat -an | grep 8080
# Should show: *.8080 or 0.0.0.0:8080

# Check config
cat ~/.config/code-server/config.yaml
# Should have: bind-addr: 0.0.0.0:8080
```

---

## ✅ **Verification**

### **Check Installation**
```bash
# Node.js
node --version
npm --version

# code-server
code-server --version
which code-server

# Config
cat ~/.config/code-server/config.yaml

# Extensions
ls ~/.local/share/code-server/extensions/
```

### **Test Access**
```bash
# Local
curl http://localhost:8080

# Network
curl http://OMNIOS_IP:8080

# Should return HTML
```

---

## 🎉 **Success!**

### **What You Have**
- ✅ code-server running on OmniOS
- ✅ Accessible from any browser
- ✅ ML Code Assistant installed
- ✅ Full VS Code experience
- ✅ True cross-platform development

### **Access From**
- ✅ macOS (any browser)
- ✅ iOS/iPad (Safari)
- ✅ Android (Chrome)
- ✅ Windows (any browser)
- ✅ Linux (any browser)
- ✅ Another OmniOS/Solaris machine

---

## 📚 **Additional Resources**

- code-server docs: https://coder.com/docs/code-server
- OmniOS docs: https://omnios.org/info/
- Node.js on illumos: https://nodejs.org/en/download/

---

## 🚀 **Next Steps**

1. ✅ Install code-server (done!)
2. ✅ Configure for network access
3. ✅ Install ML extension
4. ✅ Set up SMF service (optional)
5. ✅ Access from any device
6. ✅ Start coding!

**code-server on OmniOS = True portable development!** 🌍
