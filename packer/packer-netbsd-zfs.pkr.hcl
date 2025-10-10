packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "netbsd-zfs" {
  iso_url                = "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/images/NetBSD-10.0-amd64.iso"
  iso_checksum           = "none"
  output_directory       = "output-netbsd-zfs"
  shutdown_command       = "shutdown -p now"
  disk_size              = "20G"
  format                 = "qcow2"
  accelerator            = "kvm"
  ssh_username           = "root"
  ssh_password           = "packer"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
  ssh_pty                = true
  cpus                   = 2
  memory                 = 4096
  disk_interface         = "virtio"
  net_device             = "virtio-net"
  qemu_binary            = "qemu-system-x86_64"
  headless               = true

  boot_wait = "30s"
  boot_command = [
    "<enter><wait30>",
    "a<enter><wait>",
    "a<enter><wait>",
    "b<enter><wait>",
    "a<enter><wait>",
    "x<enter><wait>",
    "x<enter><wait>"
  ]
}

build {
  sources = ["source.qemu.netbsd-zfs"]

  provisioner "shell" {
    inline = [
      "pkgin -y install zfs curl python3"
    ]
  }

  provisioner "file" {
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /usr/local/etc/zfs/zed.d",
      "cp /tmp/*.sh /usr/local/etc/zfs/zed.d/",
      "cp /tmp/.env.local /usr/local/etc/zfs/zed.d/",
      "chmod 755 /usr/local/etc/zfs/zed.d/*.sh",
      "chmod 600 /usr/local/etc/zfs/zed.d/config.sh /usr/local/etc/zfs/zed.d/.env.local"
    ]
  }
}

variable "dd_api_key" {
  type    = string
  default = env("DD_API_KEY")
}
