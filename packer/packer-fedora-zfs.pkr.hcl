packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "fedora-zfs" {
  iso_url          = "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "output-fedora-zfs"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "fedora"
  ssh_password     = "fedora"
  ssh_timeout              = "30m"
  ssh_handshake_attempts   = 100
  ssh_pty                  = true
  cpus             = 2
  memory           = 4096
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  qemu_binary      = "qemu-system-x86_64"
  headless         = true
}

build {
  sources = ["source.qemu.fedora-zfs"]

  provisioner "shell" {
    inline = [
      "sudo dnf install -y kernel-devel",
      "sudo dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-5.fc41.noarch.rpm",
      "sudo dnf install -y zfs curl python3",
    ]
  }

  provisioner "file" {
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/zfs/zed.d",
      "sudo cp /tmp/*.sh /etc/zfs/zed.d/",
      "sudo cp /tmp/.env.local /etc/zfs/zed.d/",
      "sudo chmod 755 /etc/zfs/zed.d/*.sh",
      "sudo chmod 600 /etc/zfs/zed.d/config.sh /etc/zfs/zed.d/.env.local"
    ]
  }
}

variable "dd_api_key" {
  type    = string
  default = env("DD_API_KEY")
}
