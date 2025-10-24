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
  default = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
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
  output_directory       = "output-ubuntu-zfs-arm64"
  shutdown_command       = "echo 'ubuntu' | sudo -S shutdown -P now"
  disk_size              = "20G"
  format                 = "qcow2"
  accelerator            = "hvf"
  ssh_username           = "ubuntu"
  ssh_password           = "ubuntu"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
  ssh_pty                = true
  cpus                   = 2
  memory                 = 4096
  disk_interface         = "virtio"
  net_device             = "virtio-net"
  qemu_binary            = "qemu-system-aarch64"
  machine_type           = "virt"
  cpu_model              = "cortex-a57"
  headless               = true
  firmware               = "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"

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

  provisioner "file" {
    sources = [
      "${path.root}/../scripts/zfs-datadog-lib.sh",
      "${path.root}/../scripts/config.sh",
      "${path.root}/../scripts/scrub_finish-datadog.sh",
      "${path.root}/../scripts/resilver_finish-datadog.sh",
      "${path.root}/../scripts/statechange-datadog.sh",
      "${path.root}/../scripts/all-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.checksum-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.io-datadog.sh"
    ]
    destination = "/tmp/"
  }

  provisioner "file" {
    sources = [
      "${path.root}/../scripts/checksum-error.sh",
      "${path.root}/../scripts/io-error.sh"
    ]
    destination = "/tmp/"
  }

  provisioner "file" {
    source      = "${path.root}/../.env.local"
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
