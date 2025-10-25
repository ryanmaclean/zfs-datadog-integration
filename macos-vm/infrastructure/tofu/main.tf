# OpenTofu configuration for macOS development VMs
# Manages Tart VMs as infrastructure

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Variables
variable "vm_name" {
  description = "Name of the macOS VM"
  type        = string
  default     = "macos-dev"
}

variable "vm_image" {
  description = "Tart image to use"
  type        = string
  default     = "ghcr.io/cirruslabs/macos-ventura-base:latest"
}

variable "cpu_count" {
  description = "Number of CPUs"
  type        = number
  default     = 4
}

variable "memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 8
}

variable "auto_start" {
  description = "Auto-start VM after creation"
  type        = bool
  default     = true
}

# Check if Tart is installed
resource "null_resource" "check_tart" {
  provisioner "local-exec" {
    command = "command -v tart || (echo 'Installing Tart...' && brew install cirruslabs/cli/tart)"
  }
}

# Pull Tart image
resource "null_resource" "pull_image" {
  depends_on = [null_resource.check_tart]
  
  provisioner "local-exec" {
    command = "tart clone ${var.vm_image} ${var.vm_name} || echo 'Image already exists'"
  }
  
  triggers = {
    vm_name = var.vm_name
    vm_image = var.vm_image
  }
}

# Configure VM resources
resource "null_resource" "configure_vm" {
  depends_on = [null_resource.pull_image]
  
  provisioner "local-exec" {
    command = <<-EOT
      tart set ${var.vm_name} --cpu ${var.cpu_count} || true
      tart set ${var.vm_name} --memory ${var.memory_gb} || true
    EOT
  }
  
  triggers = {
    cpu_count = var.cpu_count
    memory_gb = var.memory_gb
  }
}

# Start VM
resource "null_resource" "start_vm" {
  depends_on = [null_resource.configure_vm]
  count      = var.auto_start ? 1 : 0
  
  provisioner "local-exec" {
    command = "tart run --no-graphics ${var.vm_name} &"
  }
}

# Get VM IP
data "external" "vm_ip" {
  depends_on = [null_resource.start_vm]
  
  program = ["bash", "-c", "echo '{\"ip\":\"'$(tart ip ${var.vm_name} 2>/dev/null || echo 'not-running')'\"}'"]
}

# Outputs
output "vm_name" {
  description = "Name of the created VM"
  value       = var.vm_name
}

output "vm_ip" {
  description = "IP address of the VM"
  value       = data.external.vm_ip.result.ip
}

output "code_server_url" {
  description = "URL to access code-server"
  value       = "http://${data.external.vm_ip.result.ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = "ssh admin@${data.external.vm_ip.result.ip}"
}

output "management_commands" {
  description = "Useful management commands"
  value = {
    start   = "tart run ${var.vm_name}"
    stop    = "tart stop ${var.vm_name}"
    ip      = "tart ip ${var.vm_name}"
    list    = "tart list"
    delete  = "tart delete ${var.vm_name}"
  }
}
