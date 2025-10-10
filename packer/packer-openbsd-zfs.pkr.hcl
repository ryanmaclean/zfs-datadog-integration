packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "openbsd-zfs" {
  iso_url                = "https://cdn.openbsd.org/pub/OpenBSD/7.6/amd64/install76.iso"
  iso_checksum           = "none"
  output_directory       = "output-openbsd-zfs"
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
    "S<enter><wait5>",
    "dhclient vio0<enter><wait10>",
    "ftp -o /tmp/install.conf http://{{ .HTTPIP }}:{{ .HTTPPort }}/openbsd-install.conf<enter><wait>",
    "install -af /tmp/install.conf<enter>"
  ]
}

build {
  sources = ["source.qemu.openbsd-zfs"]

  provisioner "shell" {
    inline = [
      "pkg_add openzfs curl python3"
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
