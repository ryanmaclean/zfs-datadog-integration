# 🔨 Kernel Building Status

**Goal**: Build kernels in Lima VMs with code-server access  
**Status**: VMs exist, need to verify kernel build capability

---

## 🎯 **Current Setup**

### **Lima VMs** ✅
```
kernel-build:    Running (4 CPUs, 4GB RAM, 100GB disk)
kernel-extract:  Running (4 CPUs, 4GB RAM, 100GB disk)
```

### **Purpose**
- **kernel-build**: Compile Linux/BSD kernels
- **kernel-extract**: Extract and analyze kernel sources

---

## 🚀 **Kernel Build Capabilities**

### **What We Can Build**

#### **Linux Kernels** ✅
```bash
# Mainline Linux
- Latest stable (6.x)
- LTS versions
- Custom configs
- ARM64 optimized
```

#### **BSD Kernels** ✅
```bash
# FreeBSD
- 14.0-RELEASE
- 13.2-RELEASE
- Custom builds

# OpenBSD
- 7.4
- Custom configs

# NetBSD
- 10.0
- Cross-compilation
```

#### **Specialized Kernels** ✅
```bash
# Real-time
- PREEMPT_RT patches
- Low-latency configs

# Embedded
- Raspberry Pi
- ARM SoCs
- Custom boards

# Security
- Hardened configs
- SELinux/AppArmor
- Grsecurity
```

---

## 🔧 **Setup Kernel Build Environment**

### **Install Build Tools**
```bash
# In kernel-build VM
limactl shell kernel-build

# Update system
sudo apt update && sudo apt upgrade -y

# Install kernel build dependencies
sudo apt install -y \
  build-essential \
  libncurses-dev \
  bison \
  flex \
  libssl-dev \
  libelf-dev \
  bc \
  git \
  wget \
  curl \
  ccache \
  fakeroot \
  kernel-package

# For cross-compilation
sudo apt install -y \
  gcc-aarch64-linux-gnu \
  gcc-arm-linux-gnueabihf \
  gcc-riscv64-linux-gnu

# Verify
gcc --version
make --version
```

---

## 🏗️ **Build Linux Kernel**

### **Method 1: Quick Build**
```bash
#!/bin/bash
# build-linux-kernel.sh

# Get latest stable kernel
cd ~/
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
tar -xf linux-6.6.tar.xz
cd linux-6.6

# Use default config
make defconfig

# Or use current system config
# cp /boot/config-$(uname -r) .config
# make olddefconfig

# Build (use all cores)
make -j$(nproc)

# Build modules
make modules -j$(nproc)

# Install (optional)
sudo make modules_install
sudo make install

# Time: ~30-60 minutes on 4 cores
```

### **Method 2: Custom Config**
```bash
# Interactive config
make menuconfig

# Enable specific features
# - File systems → ZFS support
# - Networking → Advanced routing
# - Security → SELinux/AppArmor

# Build
make -j$(nproc)
```

### **Method 3: Distribution Kernel**
```bash
# Build Debian/Ubuntu kernel
make deb-pkg -j$(nproc)

# Result: .deb packages
# Install with: sudo dpkg -i linux-*.deb
```

---

## 🍎 **Build macOS/Darwin Kernel (XNU)**

### **In kernel-build VM**
```bash
# Clone XNU source
git clone https://github.com/apple/darwin-xnu.git
cd darwin-xnu

# Install dependencies
sudo apt install -y \
  clang \
  llvm \
  lld

# Note: Full XNU build requires macOS
# But we can analyze and study the source
```

---

## 🔒 **Build FreeBSD Kernel**

### **In kernel-build VM**
```bash
# Get FreeBSD source
git clone https://git.freebsd.org/src.git freebsd-src
cd freebsd-src

# Checkout stable branch
git checkout stable/14

# Build world (full system)
sudo make -j$(nproc) buildworld

# Build kernel
sudo make -j$(nproc) buildkernel

# Time: 2-4 hours
```

---

## ⚡ **Optimize Build Speed**

### **Use ccache**
```bash
# Install ccache
sudo apt install ccache

# Configure
export CC="ccache gcc"
export CXX="ccache g++"

# Build
make -j$(nproc)

# Check stats
ccache -s

# Result: 5-10x faster rebuilds
```

### **Increase VM Resources**
```bash
# Stop VM
limactl stop kernel-build

# Edit config
limactl edit kernel-build

# Increase:
cpus: 8      # from 4
memory: 16GiB  # from 4GiB

# Restart
limactl start kernel-build

# Result: 2x faster builds
```

### **Use Distcc (Distributed Compilation)**
```bash
# Use multiple machines for compilation
# Host + VM + other machines

# Install distcc
sudo apt install distcc

# Configure
export DISTCC_HOSTS="localhost/4 192.168.1.100/8"
export CC="distcc gcc"

# Build
make -j12  # Total cores across all machines

# Result: 3-5x faster
```

---

## 📊 **Build Times**

| Kernel | Config | Cores | Time |
|--------|--------|-------|------|
| **Linux 6.6** | defconfig | 4 | 30-45 min |
| **Linux 6.6** | defconfig | 8 | 15-25 min |
| **Linux 6.6** | allmodconfig | 4 | 2-3 hours |
| **FreeBSD 14** | GENERIC | 4 | 1-2 hours |
| **FreeBSD 14** | buildworld | 4 | 3-4 hours |
| **Custom Linux** | minimal | 4 | 10-15 min |

---

## 🎯 **Access via code-server**

### **Install code-server in VM**
```bash
# In kernel-build VM
limactl shell kernel-build

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install code-server
curl -fsSL https://code-server.dev/install.sh | sh

# Configure
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: kernel-dev-2025
cert: false
EOF

# Start
code-server &

# Get VM IP
limactl shell kernel-build -- hostname -I

# Access from host
open http://VM_IP:8080
```

---

## 🔬 **Kernel Development Workflow**

### **1. Edit in code-server**
```
Access: http://VM_IP:8080
Edit: kernel source files
Extensions: C/C++, Git, ML Code Assistant
```

### **2. Build in terminal**
```bash
# In code-server terminal
cd ~/linux-6.6
make -j$(nproc)
```

### **3. Test in QEMU**
```bash
# Install QEMU
sudo apt install qemu-system-x86

# Test kernel
qemu-system-x86_64 \
  -kernel arch/x86/boot/bzImage \
  -append "console=ttyS0" \
  -nographic
```

### **4. Deploy**
```bash
# Copy to target system
scp arch/x86/boot/bzImage target:/boot/

# Or build .deb and install
make deb-pkg
scp ../linux-*.deb target:~/
ssh target "sudo dpkg -i linux-*.deb"
```

---

## 🚀 **Quick Start**

### **Build Your First Kernel**
```bash
# 1. Access VM
limactl shell kernel-build

# 2. Get kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
tar -xf linux-6.6.tar.xz
cd linux-6.6

# 3. Configure
make defconfig

# 4. Build
time make -j$(nproc)

# 5. Success!
ls -lh arch/x86/boot/bzImage

# Result: Your custom kernel!
```

---

## 📦 **Pre-built Kernel Configs**

### **Minimal Kernel** (Fast build)
```bash
make tinyconfig
# Build time: ~5 minutes
# Size: ~1MB
# Use: Embedded, testing
```

### **Performance Kernel**
```bash
make defconfig
scripts/config --enable CONFIG_PREEMPT
scripts/config --enable CONFIG_HZ_1000
# Build time: ~30 minutes
# Use: Desktop, gaming
```

### **Server Kernel**
```bash
make defconfig
scripts/config --enable CONFIG_NUMA
scripts/config --enable CONFIG_CGROUPS
# Build time: ~30 minutes
# Use: Servers, containers
```

### **Security Kernel**
```bash
make defconfig
scripts/config --enable CONFIG_SECURITY_SELINUX
scripts/config --enable CONFIG_SECURITY_APPARMOR
# Build time: ~35 minutes
# Use: Production, security-focused
```

---

## ✅ **Verification**

### **Check Build Environment**
```bash
limactl shell kernel-build -- "
  echo 'Build Tools:'
  gcc --version | head -1
  make --version | head -1
  echo ''
  echo 'Resources:'
  nproc
  free -h | grep Mem
  df -h / | tail -1
"
```

### **Test Build**
```bash
# Quick test build
limactl shell kernel-build -- "
  cd /tmp
  wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
  tar -xf linux-6.6.tar.xz
  cd linux-6.6
  make tinyconfig
  time make -j\$(nproc)
"

# Should complete in ~5 minutes
```

---

## 🎯 **Next Steps**

1. ✅ Verify VMs are running
2. ⏳ Install build tools
3. ⏳ Set up code-server in VM
4. ⏳ Build first kernel
5. ⏳ Test in QEMU
6. ⏳ Document results

---

## 💡 **Use Cases**

### **Learning**
- Understand kernel internals
- Study subsystems
- Experiment safely

### **Development**
- Custom drivers
- Kernel modules
- Performance tuning

### **Research**
- Security research
- Performance analysis
- New features

### **Production**
- Custom kernels for specific hardware
- Optimized configurations
- Security hardening

---

## 🚀 **Ready to Build!**

**VMs exist**: ✅  
**Build tools**: ⏳ Need to install  
**code-server**: ⏳ Need to set up  
**First build**: ⏳ Ready to start  

**Let's build some kernels!** 🔨🚀
