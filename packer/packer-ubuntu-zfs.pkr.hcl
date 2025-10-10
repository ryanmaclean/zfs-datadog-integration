# Packer template for Ubuntu with ZFS and zedlets pre-installed
# Creates a golden image for fast testing

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "ubuntu-zfs-datadog"
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

source "qemu" "ubuntu-zfs" {
  vm_name                = var.vm_name
  iso_url                = var.iso_url
  iso_checksum           = var.iso_checksum
  disk_image             = true
  output_directory       = "output-ubuntu-zfs"
  shutdown_command       = "echo 'ubuntu' | sudo -S shutdown -P now"
  disk_size              = "20G"
  format                 = "qcow2"
  accelerator            = "kvm"
  ssh_username           = "ubuntu"
  ssh_password           = "ubuntu"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
  ssh_pty                = true
  cpus                   = 2
  memory                 = 4096
  disk_interface         = "virtio"
  net_device             = "virtio-net"
  qemu_binary            = "qemu-system-x86_64"
  headless               = true

  cd_files = ["http/user-data", "http/meta-data"]
  cd_label = "cidata"
}

build {
  sources = ["source.qemu.ubuntu-zfs"]

  # Install ZFS and dependencies
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y zfsutils-linux curl netcat-openbsd python3 jq",
      "sudo modprobe zfs"
    ]
  }

  # Copy zedlets
  provisioner "file" {
  }

  provisioner "file" {
    sources     = ["zfs-datadog-lib.sh", "config.sh", "scrub_finish-datadog.sh", "resilver_finish-datadog.sh", "statechange-datadog.sh", "all-datadog.sh", ".env.local"]
    destination = "/tmp/"
  }

  provisioner "file" {
    sources = [
      "checksum-error.sh",
      "io-error.sh"
    ]
    destination = "/tmp/"
  }

  provisioner "file" {
    source      = ".env.local"
    destination = "/tmp/.env.local"
  }

  # Install zedlets
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/zfs/zed.d",
      "sudo cp /tmp/*.sh /etc/zfs/zed.d/",
      "sudo cp /tmp/.env.local /etc/zfs/zed.d/",
      "sudo chmod 755 /etc/zfs/zed.d/*.sh",
      "sudo chmod 600 /etc/zfs/zed.d/config.sh /etc/zfs/zed.d/.env.local"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*"
    ]
  }

  post-processor "manifest" {
    output = "manifest-ubuntu.json"
  }
}
