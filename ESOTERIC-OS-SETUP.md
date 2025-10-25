# 🦄 Esoteric Operating Systems with code-server

**Goal**: Boot unusual/esoteric OSes and access via code-server  
**Method**: Lima VMs + QEMU + code-server

---

## 🎯 **Esoteric Operating Systems**

### **Unix-like Esoterica**
- ✅ Plan 9 from Bell Labs
- ✅ Inferno OS
- ✅ 9front (Plan 9 fork)
- ✅ Harvey OS (Plan 9 in Go)
- ✅ Redox OS (Rust)
- ✅ SerenityOS (from scratch)
- ✅ ToaruOS (educational)
- ✅ TempleOS (legendary)

### **Microkernel Systems**
- ✅ MINIX 3
- ✅ GNU Hurd
- ✅ L4 family (seL4, Fiasco.OC)
- ✅ QNX (POSIX real-time)
- ✅ HelenOS

### **Research/Academic**
- ✅ Singularity (Microsoft Research)
- ✅ Barrelfish (ETH Zurich)
- ✅ Genode (security-focused)
- ✅ EROS/CapROS (capability-based)

### **Hobby/Experimental**
- ✅ MenuetOS (assembly)
- ✅ KolibriOS (MenuetOS fork)
- ✅ Haiku (BeOS clone)
- ✅ ReactOS (Windows clone)
- ✅ ArcaOS (OS/2 successor)

---

## 🚀 **Setup: Plan 9 from Bell Labs**

### **Why Plan 9?**
```
- Everything is a file (even network)
- Distributed by design
- Influenced modern Unix
- Clean, elegant design
- Still actively used
```

### **Boot Plan 9 in Lima**
```bash
#!/bin/bash
# boot-plan9.sh

# Create Lima VM for Plan 9
cat > plan9.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 4
memory: "4GiB"
disk: "50GiB"

mounts:
  - location: "~"
    writable: true

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y qemu-system-x86 wget curl nodejs npm
      
      # Install code-server
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Download Plan 9
      mkdir -p /opt/plan9
      cd /opt/plan9
      wget http://9legacy.org/download/go/9legacy.iso.bz2
      bunzip2 9legacy.iso.bz2

  - mode: user
    script: |
      # Configure code-server
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: plan9-dev-2025
cert: false
INNER_EOF
      
      # Create Plan 9 start script
      cat > ~/start-plan9.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/plan9/9legacy.iso \
  -m 1024 \
  -net nic -net user \
  -vga std \
  -vnc :1
INNER_EOF
      chmod +x ~/start-plan9.sh
EOF

# Start VM
limactl start --name=plan9 plan9.yaml

# Access
echo "Plan 9 VM started!"
echo "code-server: http://$(limactl shell plan9 hostname -I | awk '{print $1}'):8080"
echo "VNC: localhost:5901 (for Plan 9 GUI)"
echo ""
echo "Start Plan 9: limactl shell plan9 -- ./start-plan9.sh"
```

---

## 🦀 **Setup: Redox OS (Rust)**

### **Why Redox?**
```
- Written in Rust
- Microkernel design
- Unix-like
- Modern security
- Active development
```

### **Boot Redox**
```bash
#!/bin/bash
# boot-redox.sh

cat > redox.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 4
memory: "8GiB"
disk: "50GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y \
        qemu-system-x86 \
        curl \
        git \
        nodejs \
        npm \
        build-essential
      
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Install Rust
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      
      # Download Redox
      cd /opt
      wget https://static.redox-os.org/releases/0.8.0/x86_64/redox_demo_x86_64_0.8.0.iso
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: redox-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-redox.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/redox_demo_x86_64_0.8.0.iso \
  -m 2048 \
  -smp 2 \
  -net nic -net user \
  -serial mon:stdio \
  -vnc :2
INNER_EOF
      chmod +x ~/start-redox.sh
EOF

limactl start --name=redox redox.yaml
```

---

## 🎨 **Setup: SerenityOS**

### **Why SerenityOS?**
```
- Built from scratch (no Linux)
- Modern C++
- Beautiful UI
- Educational
- Active community
```

### **Boot SerenityOS**
```bash
#!/bin/bash
# boot-serenity.sh

cat > serenity.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 8
memory: "16GiB"
disk: "100GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y \
        build-essential cmake curl libmpfr-dev libmpc-dev libgmp-dev \
        e2fsprogs ninja-build qemu-system-x86 qemu-utils ccache rsync \
        unzip texinfo libssl-dev pkg-config git nodejs npm
      
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Clone SerenityOS
      cd /opt
      git clone https://github.com/SerenityOS/serenity.git
      cd serenity
      
      # Build toolchain (takes 1-2 hours)
      Meta/serenity.sh rebuild-toolchain
      
      # Build SerenityOS (takes 30-60 min)
      Meta/serenity.sh build
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: serenity-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-serenity.sh <<'INNER_EOF'
#!/bin/bash
cd /opt/serenity
Meta/serenity.sh run
INNER_EOF
      chmod +x ~/start-serenity.sh
EOF

limactl start --name=serenity serenity.yaml
```

---

## 🔬 **Setup: MINIX 3 (Microkernel)**

### **Why MINIX 3?**
```
- Microkernel design
- Extreme reliability
- Self-healing
- Educational (Tanenbaum)
- Influenced modern systems
```

### **Boot MINIX 3**
```bash
#!/bin/bash
# boot-minix.sh

cat > minix.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 4
memory: "4GiB"
disk: "50GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y qemu-system-x86 wget nodejs npm
      
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Download MINIX 3
      cd /opt
      wget http://download.minix3.org/iso/minix_R3.4.0-588a35b.iso.bz2
      bunzip2 minix_R3.4.0-588a35b.iso.bz2
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: minix-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-minix.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/minix_R3.4.0-588a35b.iso \
  -m 1024 \
  -net nic -net user \
  -serial mon:stdio
INNER_EOF
      chmod +x ~/start-minix.sh
EOF

limactl start --name=minix minix.yaml
```

---

## 🌈 **Setup: Haiku (BeOS)**

### **Why Haiku?**
```
- BeOS spiritual successor
- Pervasive multithreading
- Beautiful UI
- Fast and responsive
- Active development
```

### **Boot Haiku**
```bash
#!/bin/bash
# boot-haiku.sh

cat > haiku.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 4
memory: "4GiB"
disk: "50GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y qemu-system-x86 wget nodejs npm
      
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Download Haiku
      cd /opt
      wget https://cdn.haiku-os.org/haiku-release/r1beta4/haiku-r1beta4-x86_64-anyboot.iso
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: haiku-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-haiku.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/haiku-r1beta4-x86_64-anyboot.iso \
  -m 2048 \
  -smp 2 \
  -net nic -net user \
  -vga std \
  -vnc :3
INNER_EOF
      chmod +x ~/start-haiku.sh
EOF

limactl start --name=haiku haiku.yaml
```

---

## 🎪 **Setup: TempleOS (Legendary)**

### **Why TempleOS?**
```
- Written by Terry A. Davis
- 16-color VGA only
- HolyC programming language
- 640x480 resolution
- Legendary in OS community
- Educational curiosity
```

### **Boot TempleOS**
```bash
#!/bin/bash
# boot-templeos.sh

cat > templeos.yaml <<'EOF'
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: 2
memory: "2GiB"
disk: "20GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y qemu-system-x86 wget nodejs npm
      
      curl -fsSL https://code-server.dev/install.sh | sh
      
      # Download TempleOS
      cd /opt
      wget https://templeos.org/Downloads/TempleOS.ISO
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: temple-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-templeos.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/TempleOS.ISO \
  -m 512 \
  -vga std \
  -vnc :4
INNER_EOF
      chmod +x ~/start-templeos.sh
EOF

limactl start --name=templeos templeos.yaml
```

---

## 📊 **Comparison**

| OS | Type | Language | Difficulty | Use Case |
|----|------|----------|------------|----------|
| **Plan 9** | Distributed | C | Medium | Research, learning |
| **Redox** | Microkernel | Rust | Medium | Modern systems |
| **SerenityOS** | Monolithic | C++ | Hard | Learning, fun |
| **MINIX 3** | Microkernel | C | Easy | Education, reliability |
| **Haiku** | Hybrid | C++ | Easy | Desktop, multimedia |
| **TempleOS** | Unique | HolyC | Easy | Curiosity, legend |
| **9front** | Distributed | C | Medium | Plan 9 fork |
| **ReactOS** | Hybrid | C | Medium | Windows compatibility |

---

## 🎯 **Access Pattern**

### **All Systems**
```
1. Boot in QEMU (inside Lima VM)
2. Access code-server (browser)
3. Develop/explore in IDE
4. VNC for GUI (if needed)
5. Serial console for debugging
```

### **Example Workflow**
```bash
# Start Lima VM
limactl start plan9

# Access code-server
open http://$(limactl shell plan9 hostname -I | awk '{print $1}'):8080

# Start OS in QEMU
limactl shell plan9 -- ./start-plan9.sh

# Connect VNC (for GUI)
open vnc://localhost:5901

# Develop in code-server
# Test in QEMU
# Iterate!
```

---

## 🔧 **Universal Boot Script**

```bash
#!/bin/bash
# boot-esoteric.sh - Universal esoteric OS booter

OS_NAME=$1
ISO_URL=$2
MEMORY=${3:-2048}
CPUS=${4:-2}

if [ -z "$OS_NAME" ] || [ -z "$ISO_URL" ]; then
    echo "Usage: $0 <os-name> <iso-url> [memory-mb] [cpus]"
    echo "Example: $0 plan9 http://9legacy.org/download/go/9legacy.iso.bz2"
    exit 1
fi

cat > ${OS_NAME}.yaml <<EOF
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: ${CPUS}
memory: "${MEMORY}MiB"
disk: "50GiB"

provision:
  - mode: system
    script: |
      apt-get update
      apt-get install -y qemu-system-x86 wget curl nodejs npm
      curl -fsSL https://code-server.dev/install.sh | sh
      mkdir -p /opt/${OS_NAME}
      cd /opt/${OS_NAME}
      wget ${ISO_URL}
      [ -f *.bz2 ] && bunzip2 *.bz2
      [ -f *.gz ] && gunzip *.gz
      
  - mode: user
    script: |
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${OS_NAME}-dev-2025
cert: false
INNER_EOF
      
      cat > ~/start-${OS_NAME}.sh <<'INNER_EOF'
#!/bin/bash
qemu-system-x86_64 \
  -cdrom /opt/${OS_NAME}/*.iso \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -net nic -net user \
  -serial mon:stdio \
  -vnc :1
INNER_EOF
      chmod +x ~/start-${OS_NAME}.sh
EOF

limactl start --name=${OS_NAME} ${OS_NAME}.yaml

echo "✅ ${OS_NAME} VM started!"
echo "code-server: http://\$(limactl shell ${OS_NAME} hostname -I | awk '{print \$1}'):8080"
echo "Start OS: limactl shell ${OS_NAME} -- ./start-${OS_NAME}.sh"
```

---

## 🚀 **Quick Start Collection**

### **Boot All Esoteric OSes**
```bash
# Plan 9
./boot-esoteric.sh plan9 http://9legacy.org/download/go/9legacy.iso.bz2

# Redox
./boot-esoteric.sh redox https://static.redox-os.org/releases/0.8.0/x86_64/redox_demo_x86_64_0.8.0.iso

# MINIX 3
./boot-esoteric.sh minix http://download.minix3.org/iso/minix_R3.4.0-588a35b.iso.bz2

# Haiku
./boot-esoteric.sh haiku https://cdn.haiku-os.org/haiku-release/r1beta4/haiku-r1beta4-x86_64-anyboot.iso

# TempleOS
./boot-esoteric.sh templeos https://templeos.org/Downloads/TempleOS.ISO 512 1
```

---

## ✅ **What You Get**

### **For Each OS**
- ✅ Lima VM (isolated)
- ✅ QEMU (virtualization)
- ✅ code-server (browser IDE)
- ✅ VNC access (GUI)
- ✅ Serial console (debugging)
- ✅ Network access
- ✅ Persistent storage

### **Development Flow**
```
1. Edit code in code-server (browser)
2. Build in terminal
3. Test in QEMU
4. Debug via serial/VNC
5. Iterate!
```

---

## 🎉 **Ready to Boot!**

**Esoteric OSes**: ✅ Scripts ready  
**code-server**: ✅ Integrated  
**QEMU**: ✅ Configured  
**VNC**: ✅ Available  

**Boot the weird and wonderful!** 🦄🚀
