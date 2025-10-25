# 🦄 Esoteric OS Testing Suite

**Boot and test unusual operating systems with code-server access**

---

## 🚀 Quick Start

### **Quick Demo (5 minutes)**
```bash
cd esoteric-os
./quick-demo.sh
```

This will:
1. Boot Plan 9 in Lima VM
2. Install code-server
3. Start QEMU with Plan 9
4. Give you access URLs

---

## 🧪 Test Suite

### **Test All OSes**
```bash
./test-all-vms.sh
```

Select from:
1. Plan 9 from Bell Labs
2. Redox OS (Rust)
3. MINIX 3
4. Haiku (BeOS)
5. TempleOS
6. All of the above
7. Quick test (Plan 9 only)

### **What Gets Tested**
- ✅ VM boots successfully
- ✅ VM is running
- ✅ code-server is accessible
- ✅ QEMU is installed
- ✅ ISO is downloaded
- ✅ Start scripts exist

---

## 🎯 Individual OS Testing

### **Plan 9 from Bell Labs**
```bash
./boot-esoteric.sh plan9

# Access
open http://$(limactl shell plan9 hostname -I | awk '{print $1}'):8080
# Password: plan9-dev-2025

# Start Plan 9
limactl shell plan9 -- ./start-plan9.sh

# VNC access
open vnc://localhost:5901
```

### **Redox OS (Rust)**
```bash
./boot-esoteric.sh redox

# Access
open http://$(limactl shell redox hostname -I | awk '{print $1}'):8080
# Password: redox-dev-2025

# Start Redox
limactl shell redox -- ./start-redox.sh
```

### **MINIX 3**
```bash
./boot-esoteric.sh minix

# Access
open http://$(limactl shell minix hostname -I | awk '{print $1}'):8080
# Password: minix-dev-2025

# Start MINIX
limactl shell minix -- ./start-minix.sh
```

### **Haiku (BeOS)**
```bash
./boot-esoteric.sh haiku

# Access
open http://$(limactl shell haiku hostname -I | awk '{print $1}'):8080
# Password: haiku-dev-2025

# Start Haiku
limactl shell haiku -- ./start-haiku.sh

# VNC access
open vnc://localhost:5903
```

### **TempleOS**
```bash
./boot-esoteric.sh templeos

# Access
open http://$(limactl shell templeos hostname -I | awk '{print $1}'):8080
# Password: temple-dev-2025

# Start TempleOS
limactl shell templeos -- ./start-templeos.sh

# VNC access
open vnc://localhost:5904
```

---

## 📊 Expected Results

| OS | Boot Time | ISO Size | Memory | Status |
|----|-----------|----------|--------|--------|
| **Plan 9** | 2-3 min | ~50MB | 1GB | ✅ Works |
| **Redox** | 3-5 min | ~400MB | 2GB | ✅ Works |
| **MINIX 3** | 2-3 min | ~600MB | 1GB | ✅ Works |
| **Haiku** | 3-5 min | ~800MB | 2GB | ✅ Works |
| **TempleOS** | 1-2 min | ~3MB | 512MB | ✅ Works |

---

## 🔧 Troubleshooting

### **VM Won't Boot**
```bash
# Check Lima status
limactl list

# View logs
limactl shell <os-name> -- dmesg

# Restart VM
limactl stop <os-name>
limactl start <os-name>
```

### **code-server Not Accessible**
```bash
# Start manually
limactl shell <os-name> -- code-server &

# Check if running
limactl shell <os-name> -- ps aux | grep code-server

# Check port
limactl shell <os-name> -- netstat -tlnp | grep 8080
```

### **ISO Download Failed**
```bash
# Check download
limactl shell <os-name> -- ls -lh /opt/<os-name>/

# Re-download manually
limactl shell <os-name>
cd /opt/<os-name>
wget <iso-url>
```

### **QEMU Won't Start**
```bash
# Check QEMU
limactl shell <os-name> -- which qemu-system-x86_64

# Test QEMU
limactl shell <os-name> -- qemu-system-x86_64 --version

# Check ISO path
limactl shell <os-name> -- ls /opt/<os-name>/*.iso
```

---

## 🎮 Usage Examples

### **Example 1: Quick Test**
```bash
# Boot Plan 9
./quick-demo.sh

# Access in browser
# http://VM_IP:8080

# Start Plan 9 in code-server terminal
tail -f ~/plan9.log

# Done!
```

### **Example 2: Full Test Suite**
```bash
# Test all OSes
./test-all-vms.sh

# Select option 6 (all)
# Wait for tests to complete
# Review results
```

### **Example 3: Custom OS**
```bash
# Boot custom OS
./boot-esoteric.sh myos http://example.com/myos.iso 2048 4

# Access
open http://$(limactl shell myos hostname -I | awk '{print $1}'):8080

# Start OS
limactl shell myos -- ./start-myos.sh
```

---

## 📝 Notes

### **VNC Ports**
```
Plan 9:     5901 (vnc://localhost:5901)
Redox:      5902 (vnc://localhost:5902)
Haiku:      5903 (vnc://localhost:5903)
TempleOS:   5904 (vnc://localhost:5904)
MINIX:      Serial console only
```

### **Passwords**
```
All code-server instances use:
<os-name>-dev-2025

Example:
plan9-dev-2025
redox-dev-2025
minix-dev-2025
```

### **Resources**
```
Plan 9:     1GB RAM, 2 CPUs
Redox:      2GB RAM, 2 CPUs
MINIX:      1GB RAM, 2 CPUs
Haiku:      2GB RAM, 2 CPUs
TempleOS:   512MB RAM, 1 CPU
```

---

## ✅ Verification

### **Check All VMs**
```bash
limactl list
```

### **Check Specific VM**
```bash
limactl shell <os-name> -- "
  echo 'System Info:'
  uname -a
  echo ''
  echo 'Resources:'
  free -h
  df -h /
  echo ''
  echo 'QEMU:'
  qemu-system-x86_64 --version
  echo ''
  echo 'code-server:'
  code-server --version
"
```

---

## 🧹 Cleanup

### **Stop All VMs**
```bash
for vm in plan9 redox minix haiku templeos; do
    limactl stop $vm 2>/dev/null || true
done
```

### **Delete All VMs**
```bash
for vm in plan9 redox minix haiku templeos; do
    limactl delete $vm 2>/dev/null || true
done
```

---

## 🎉 Success!

**You can now boot and test esoteric operating systems!**

Each OS runs in:
- ✅ Isolated Lima VM
- ✅ QEMU virtualization
- ✅ code-server for development
- ✅ VNC for GUI access
- ✅ Serial console for debugging

**Happy exploring! 🦄🚀**
