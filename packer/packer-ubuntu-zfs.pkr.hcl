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

  # Fail before ZFS provisioning. An Agent package, its selected license
  # graph, and Agent-local intake fixture have not been admitted.
  provisioner "shell" {
    inline = ["printf '%s\\n' 'HOLD: Ubuntu image lacks reviewed packaged Datadog Agent and Agent-local intake proof' >&2; exit 1"]
  }

  # Install ZFS and dependencies
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y zfsutils-linux curl netcat-openbsd python3 jq",
      "sudo modprobe zfs"
    ]
  }

  # Upload into a private directory owned by the provisioning account.
  provisioner "shell" {
    inline = ["install -d -m 700 /tmp/zfs-datadog-upload"]
  }

  provisioner "file" {
    sources = [
      "${path.root}/../scripts/zfs-datadog-lib.sh",
      "${path.root}/../scripts/config.sh",
      "${path.root}/../scripts/install.sh",
      "${path.root}/../scripts/scrub_finish-datadog.sh",
      "${path.root}/../scripts/scrub_start-datadog.sh",
      "${path.root}/../scripts/resilver_finish-datadog.sh",
      "${path.root}/../scripts/resilver_start-datadog.sh",
      "${path.root}/../scripts/statechange-datadog.sh",
      "${path.root}/../scripts/config_sync-datadog.sh",
      "${path.root}/../scripts/pool_import-datadog.sh",
      "${path.root}/../scripts/pool_destroy-datadog.sh",
      "${path.root}/../scripts/vdev_attach-datadog.sh",
      "${path.root}/../scripts/vdev_remove-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.checksum-datadog.sh",
      "${path.root}/../scripts/ereport.fs.zfs.io-datadog.sh"
    ]
    destination = "/tmp/zfs-datadog-upload/"
  }

  provisioner "file" {
    sources = [
      "${path.root}/../scripts/checksum-error.sh",
      "${path.root}/../scripts/io-error.sh",
      "${path.root}/../scripts/payload.sha256"
    ]
    destination = "/tmp/zfs-datadog-upload/"
  }

  # Seal the uploaded payload in a root-owned source tree, then use the
  # guarded installer. Never copy public helpers into the ZED scan directory.
  provisioner "shell" {
    inline = [
      "sudo mkdir -m 700 /root/zfs-datadog-src",
      "sudo cp /tmp/zfs-datadog-upload/install.sh /tmp/zfs-datadog-upload/config.sh /tmp/zfs-datadog-upload/zfs-datadog-lib.sh /tmp/zfs-datadog-upload/statechange-datadog.sh /tmp/zfs-datadog-upload/scrub_start-datadog.sh /tmp/zfs-datadog-upload/scrub_finish-datadog.sh /tmp/zfs-datadog-upload/resilver_start-datadog.sh /tmp/zfs-datadog-upload/resilver_finish-datadog.sh /tmp/zfs-datadog-upload/config_sync-datadog.sh /tmp/zfs-datadog-upload/pool_import-datadog.sh /tmp/zfs-datadog-upload/pool_destroy-datadog.sh /tmp/zfs-datadog-upload/vdev_attach-datadog.sh /tmp/zfs-datadog-upload/vdev_remove-datadog.sh /tmp/zfs-datadog-upload/ereport.fs.zfs.checksum-datadog.sh /tmp/zfs-datadog-upload/ereport.fs.zfs.io-datadog.sh /tmp/zfs-datadog-upload/checksum-error.sh /tmp/zfs-datadog-upload/io-error.sh /tmp/zfs-datadog-upload/payload.sha256 /root/zfs-datadog-src/",
      "sudo sh -ec 'cd /root/zfs-datadog-src; set -- $(openssl dgst -sha256 payload.sha256); [ \"$2\" = \"1e74fefba1ad377d2e3d73a4ce1715d728528b01734826b1078e118aa4b333f0\" ] || exit 1; set -- $(openssl dgst -sha256 install.sh); [ \"$2\" = \"e3f8009df25e541b08fca0237f0f61e881bcb99e38723cc229b3df8a54fdbef3\" ]'",
      "sudo env ZFS_DD_EXPECTED_MANIFEST_SHA=1e74fefba1ad377d2e3d73a4ce1715d728528b01734826b1078e118aa4b333f0 sh /root/zfs-datadog-src/install.sh"
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
