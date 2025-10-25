# 🏗️ Infrastructure as Code for macOS VMs

**Tools**: OpenTofu + Packer + Tart  
**Purpose**: Automated macOS VM creation and management

---

## 🎯 **What's Here**

### **Packer** (`packer/`)
- Builds custom macOS VM images
- Installs code-server
- Configures development tools
- Installs ML Code Assistant

### **OpenTofu** (`tofu/`)
- Manages VM lifecycle
- Provisions VMs
- Outputs connection info
- Handles multiple VMs

---

## 🚀 **Quick Start**

### **Option 1: Packer (Build Custom Image)**
```bash
cd infrastructure/packer

# Install Packer
brew install packer

# Initialize Packer
packer init macos-dev.pkr.hcl

# Build image (takes 15-20 minutes)
packer build macos-dev.pkr.hcl

# Result: Custom VM with everything pre-installed!
```

### **Option 2: OpenTofu (Manage VMs)**
```bash
cd infrastructure/tofu

# Install OpenTofu
brew install opentofu

# Initialize
tofu init

# Plan
tofu plan

# Apply (creates and starts VM)
tofu apply

# Get outputs
tofu output
```

---

## 📦 **Packer Build**

### **What It Does**
1. ✅ Pulls base macOS image
2. ✅ Updates system
3. ✅ Installs Homebrew
4. ✅ Installs dev tools (git, node, python, go, rust)
5. ✅ Installs VS Code
6. ✅ Installs code-server
7. ✅ Configures auto-start
8. ✅ Installs ML Code Assistant
9. ✅ Cleans up

### **Usage**
```bash
# Basic build
packer build macos-dev.pkr.hcl

# With custom variables
packer build \
  -var 'vm_name=my-dev-vm' \
  -var 'cpu_count=8' \
  -var 'memory_gb=16' \
  -var 'code_server_password=my-secure-password' \
  macos-dev.pkr.hcl

# Validate first
packer validate macos-dev.pkr.hcl
```

### **Result**
```
VM Name: macos-dev
code-server: ✅ Running on port 8080
Dev tools: ✅ Installed
ML Extension: ✅ Installed
Auto-start: ✅ Configured
```

---

## 🌍 **OpenTofu Management**

### **What It Does**
1. ✅ Checks Tart installation
2. ✅ Pulls VM image
3. ✅ Configures resources (CPU, RAM)
4. ✅ Starts VM
5. ✅ Gets VM IP
6. ✅ Outputs connection info

### **Usage**
```bash
# Initialize
tofu init

# Plan changes
tofu plan

# Apply (create VM)
tofu apply

# Show outputs
tofu output

# Destroy VM
tofu destroy
```

### **Outputs**
```bash
# After apply
tofu output vm_ip
# Output: 192.168.64.5

tofu output code_server_url
# Output: http://192.168.64.5:8080

tofu output ssh_command
# Output: ssh admin@192.168.64.5
```

---

## 🔧 **Configuration**

### **Packer Variables**
```hcl
# macos-dev.pkr.hcl
variable "vm_name" {
  default = "macos-dev"
}

variable "cpu_count" {
  default = 4
}

variable "memory_gb" {
  default = 8
}

variable "code_server_password" {
  default = "dev-2025"
  sensitive = true
}
```

### **OpenTofu Variables**
```hcl
# terraform.tfvars
vm_name    = "macos-dev"
vm_image   = "ghcr.io/cirruslabs/macos-ventura-base:latest"
cpu_count  = 4
memory_gb  = 8
auto_start = true
```

---

## 🎯 **Use Cases**

### **1. Single Development VM**
```bash
cd infrastructure/tofu
tofu apply
# Creates one VM, auto-starts, outputs URL
```

### **2. Multiple Test VMs**
```bash
# Create test-1
tofu apply -var="vm_name=test-1" -var="auto_start=false"

# Create test-2
tofu apply -var="vm_name=test-2" -var="auto_start=false"

# Create test-3
tofu apply -var="vm_name=test-3" -var="auto_start=false"
```

### **3. Custom Image with Packer**
```bash
cd infrastructure/packer

# Build custom image
packer build \
  -var 'vm_name=custom-dev' \
  -var 'cpu_count=8' \
  -var 'memory_gb=16' \
  macos-dev.pkr.hcl

# Use with OpenTofu
cd ../tofu
tofu apply -var="vm_name=custom-dev"
```

### **4. CI/CD Pipeline**
```yaml
# .github/workflows/test.yml
- name: Create test VM
  run: |
    cd infrastructure/tofu
    tofu init
    tofu apply -auto-approve
    VM_IP=$(tofu output -raw vm_ip)
    echo "VM_IP=$VM_IP" >> $GITHUB_ENV

- name: Run tests
  run: |
    ssh admin@$VM_IP "cd /project && npm test"

- name: Cleanup
  run: |
    cd infrastructure/tofu
    tofu destroy -auto-approve
```

---

## 📊 **Comparison**

| Method | Time | Complexity | Reusability |
|--------|------|------------|-------------|
| **Manual** | 30 min | Low | None |
| **Script** | 15 min | Medium | Some |
| **Packer** | 20 min | Medium | High |
| **OpenTofu** | 5 min | Low | High |
| **Both** | 25 min | High | Very High |

---

## 🔄 **Workflow**

### **Development Workflow**
```bash
# 1. Build custom image (once)
cd infrastructure/packer
packer build macos-dev.pkr.hcl

# 2. Create VM from image (many times)
cd ../tofu
tofu apply

# 3. Use VM
open http://$(tofu output -raw vm_ip):8080

# 4. Destroy when done
tofu destroy
```

### **Team Workflow**
```bash
# 1. Team lead builds image
packer build macos-dev.pkr.hcl

# 2. Team members create VMs
tofu apply -var="vm_name=dev-alice"
tofu apply -var="vm_name=dev-bob"
tofu apply -var="vm_name=dev-charlie"

# 3. Everyone has identical environment!
```

---

## 🐛 **Troubleshooting**

### **Packer Build Fails**
```bash
# Validate template
packer validate macos-dev.pkr.hcl

# Check Tart plugin
packer init macos-dev.pkr.hcl

# Enable debug
PACKER_LOG=1 packer build macos-dev.pkr.hcl
```

### **OpenTofu Apply Fails**
```bash
# Check state
tofu show

# Refresh state
tofu refresh

# Clean state
rm -rf .terraform terraform.tfstate*
tofu init
```

### **VM Won't Start**
```bash
# Check Tart
tart list

# Check resources
tart get macos-dev

# Manual start
tart run macos-dev
```

---

## 📚 **Documentation**

### **Packer**
- Docs: https://www.packer.io/docs
- Tart plugin: https://github.com/cirruslabs/packer-plugin-tart

### **OpenTofu**
- Docs: https://opentofu.org/docs
- vs Terraform: https://opentofu.org/docs/intro/vs-terraform

### **Tart**
- Docs: https://tart.run
- GitHub: https://github.com/cirruslabs/tart

---

## ✅ **Summary**

### **Packer**
- ✅ Builds custom images
- ✅ Installs everything
- ✅ Reusable
- ⏳ Takes 15-20 minutes

### **OpenTofu**
- ✅ Manages VMs
- ✅ Infrastructure as code
- ✅ Version controlled
- ⚡ Fast (5 minutes)

### **Together**
- ✅ **Best of both worlds**
- ✅ Build once, deploy many
- ✅ Consistent environments
- ✅ Fully automated

**Perfect for certified macOS developers!** 🚀
