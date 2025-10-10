packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "arch-zfs" {
  iso_url          = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "output-arch-zfs"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "arch"
  ssh_password     = "arch"
  ssh_timeout              = "30m"
  ssh_handshake_attempts   = 100
  ssh_pty                  = true
  cpus             = 2
  memory           = 4096
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  qemu_binary      = "qemu-system-x86_64"
  headless         = true

  cd_files = ["http/user-data-arch", "http/meta-data"]
  cd_label = "cidata"
}

build {
  sources = ["source.qemu.arch-zfs"]

  provisioner "shell" {
    inline = [
      "sudo pacman -Syu --noconfirm",
      "sudo pacman -S --noconfirm linux-headers",
      "sudo pacman -S --noconfirm zfs-linux curl python",
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
