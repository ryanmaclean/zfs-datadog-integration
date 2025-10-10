packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "openindiana-zfs" {
  iso_url          = "https://dlc.openindiana.org/isos/hipster/20241026/OI-hipster-text-20241026.iso"
  iso_checksum     = "none"
  output_directory = "output-openindiana-zfs"
  shutdown_command = "shutdown -i5 -g0 -y"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "root"
  ssh_password     = "packer"
  ssh_timeout              = "30m"
  ssh_handshake_attempts   = 100
  ssh_pty                  = true
  cpus             = 2
  memory           = 4096
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  qemu_binary      = "qemu-system-x86_64"
  headless         = true

  boot_wait = "45s"
  boot_command = [
    "<enter><wait30>",
    "3<enter><wait10>",
    "<enter><wait>",
    "<enter><wait>"
  ]
}

build {
  sources = ["source.qemu.openindiana-zfs"]

  provisioner "shell" {
    inline = [
      "pkg install curl python-39"
    ]
  }

  provisioner "file" {
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/zfs/zed.d",
      "cp /tmp/*.sh /etc/zfs/zed.d/",
      "cp /tmp/.env.local /etc/zfs/zed.d/",
      "chmod 755 /etc/zfs/zed.d/*.sh",
      "chmod 600 /etc/zfs/zed.d/config.sh /etc/zfs/zed.d/.env.local",
      "svcadm restart zfs-zed"
    ]
  }
}

variable "dd_api_key" {
  type    = string
  default = env("DD_API_KEY")
}
