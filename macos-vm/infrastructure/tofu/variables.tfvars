# Example variables file
# Copy to terraform.tfvars and customize

vm_name    = "macos-dev"
vm_image   = "ghcr.io/cirruslabs/macos-ventura-base:latest"
cpu_count  = 4
memory_gb  = 8
auto_start = true

# Alternative configurations:

# High-performance VM
# vm_name    = "macos-dev-performance"
# cpu_count  = 8
# memory_gb  = 16

# Sonoma with Xcode
# vm_name    = "macos-sonoma-xcode"
# vm_image   = "ghcr.io/cirruslabs/macos-sonoma-xcode:latest"
# cpu_count  = 6
# memory_gb  = 12

# Multiple VMs for testing
# vm_name    = "macos-test-1"
# auto_start = false
