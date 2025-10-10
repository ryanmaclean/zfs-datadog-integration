# Packer template for FreeBSD with ZFS and zedlets
# Builds on i9-zfs-pop.local

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
  default = "packer-freebsd-zfs"
}

variable "iso_path" {
  type    = string
  default = "/tank3/vms/isos/FreeBSD-14.3-RELEASE-amd64-disc1.iso"
}

source "qemu" "freebsd-zfs" {
  vm_name          = var.vm_name
  iso_url          = "https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/amd64/Latest/FreeBSD-14.2-RELEASE-amd64.qcow2.xz"
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "output-freebsd-zfs"
  shutdown_command = "shutdown -p now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  memory           = 4096
  cpus             = 2
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  qemu_binary      = "qemu-system-x86_64"
  headless         = true

  ssh_username             = "root"
  ssh_password             = "root"
  ssh_timeout              = "5m"
  ssh_handshake_attempts   = 100
  ssh_pty                  = true
}

build {
  sources = ["source.qemu.freebsd-zfs"]

  # Install ZFS (already included in FreeBSD)
  provisioner "shell" {
    inline = [
      "pkg install -y curl python3"
    ]
  }

  # Copy zedlets
  provisioner "file" {
  }

  provisioner "file" {
    sources = [
      "zfs-datadog-lib.sh",
      "config.sh",
      "scrub_finish-datadog.sh",
      "resilver_finish-datadog.sh",
      "statechange-datadog.sh",
      "all-datadog.sh",
      ".env.local"
    ]
    destination = "/tmp/"
  }

  # Install zedlets
  provisioner "shell" {
    inline = [
      "mkdir -p /usr/local/etc/zfs/zed.d",
      "cp /tmp/*.sh /usr/local/etc/zfs/zed.d/",
      "chmod 755 /usr/local/etc/zfs/zed.d/*.sh",
      "chmod 600 /usr/local/etc/zfs/zed.d/config.sh",
      "service zfs-zed restart"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "pkg clean -y",
      "rm -rf /tmp/*"
    ]
  }
}
