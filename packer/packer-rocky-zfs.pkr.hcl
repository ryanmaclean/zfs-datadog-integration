packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "rocky-zfs" {
  iso_url          = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "output-rocky-zfs"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "rocky"
  ssh_password     = "rocky"
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
  sources = ["source.qemu.rocky-zfs"]

  provisioner "shell" {
    inline = [
      "sudo dnf install -y epel-release",
      "sudo dnf install -y kernel-devel",
      "sudo dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3.el9.noarch.rpm",
      "sudo dnf install -y zfs curl python3",
    ]
  }

  provisioner "file" {
    sources = [
      "${path.root}/../scripts/install.sh",
      "${path.root}/../scripts/config.sh",
      "${path.root}/../scripts/zfs-datadog-lib.sh",
      "${path.root}/../scripts/statechange-datadog.sh",
      "${path.root}/../scripts/scrub_start-datadog.sh",
      "${path.root}/../scripts/scrub_finish-datadog.sh",
      "${path.root}/../scripts/resilver_start-datadog.sh",
      "${path.root}/../scripts/resilver_finish-datadog.sh",
      "${path.root}/../scripts/config_sync-datadog.sh",
      "${path.root}/../scripts/pool_import-datadog.sh",
      "${path.root}/../scripts/pool_destroy-datadog.sh",
      "${path.root}/../scripts/vdev_attach-datadog.sh",
      "${path.root}/../scripts/vdev_remove-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.checksum-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.io-datadog.sh",
      "${path.root}/../scripts/checksum-error.sh",
      "${path.root}/../scripts/io-error.sh",
    ]
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "sudo install -d -m 700 /root/zfs-datadog-src",
      "sudo cp /tmp/*.sh /root/zfs-datadog-src/",
      "sudo chown root:root /root/zfs-datadog-src/*.sh",
      "sudo chmod go-w /root/zfs-datadog-src/*.sh",
      "sudo sh /root/zfs-datadog-src/install.sh"
    ]
  }
}

variable "dd_api_key" {
  type    = string
  default = env("DD_API_KEY")
}
