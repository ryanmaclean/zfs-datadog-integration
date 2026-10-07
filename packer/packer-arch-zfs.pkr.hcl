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

  # Upload into a private directory owned by the provisioning account.
  provisioner "shell" {
    inline = ["install -d -m 700 /tmp/zfs-datadog-upload"]
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
      "${path.root}/../scripts/payload.sha256",
    ]
    destination = "/tmp/zfs-datadog-upload/"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -m 700 /root/zfs-datadog-src",
      "sudo cp /tmp/zfs-datadog-upload/install.sh /tmp/zfs-datadog-upload/config.sh /tmp/zfs-datadog-upload/zfs-datadog-lib.sh /tmp/zfs-datadog-upload/statechange-datadog.sh /tmp/zfs-datadog-upload/scrub_start-datadog.sh /tmp/zfs-datadog-upload/scrub_finish-datadog.sh /tmp/zfs-datadog-upload/resilver_start-datadog.sh /tmp/zfs-datadog-upload/resilver_finish-datadog.sh /tmp/zfs-datadog-upload/config_sync-datadog.sh /tmp/zfs-datadog-upload/pool_import-datadog.sh /tmp/zfs-datadog-upload/pool_destroy-datadog.sh /tmp/zfs-datadog-upload/vdev_attach-datadog.sh /tmp/zfs-datadog-upload/vdev_remove-datadog.sh /tmp/zfs-datadog-upload/ereport.fs.zfs.checksum-datadog.sh /tmp/zfs-datadog-upload/ereport.fs.zfs.io-datadog.sh /tmp/zfs-datadog-upload/checksum-error.sh /tmp/zfs-datadog-upload/io-error.sh /tmp/zfs-datadog-upload/payload.sha256 /root/zfs-datadog-src/",
      "sudo sh -ec 'cd /root/zfs-datadog-src; set -- $(openssl dgst -sha256 payload.sha256); [ \"$2\" = \"1de71ec228764649a5310e00ca76054a8488be3c9ccf92dff60cc2124c992e16\" ] || exit 1; set -- $(openssl dgst -sha256 install.sh); [ \"$2\" = \"c0b4db0fc4bafb554e40f7e54f21b5bf664ef52717159c46302a44ec6a015835\" ]'",
      "sudo env ZFS_DD_EXPECTED_MANIFEST_SHA=1de71ec228764649a5310e00ca76054a8488be3c9ccf92dff60cc2124c992e16 sh /root/zfs-datadog-src/install.sh"
    ]
  }
}

variable "dd_api_key" {
  type    = string
  default = env("DD_API_KEY")
}
