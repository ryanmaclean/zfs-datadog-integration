// Packer script to build Alpine Linux M-series image
// With custom kernel + ZFS

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "output_dir" {
  type    = string
  default = "output-alpine-m-series"
}

source "qemu" "alpine-m-series" {
  iso_url          = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-virt-3.19.0-aarch64.iso"
  iso_checksum     = "sha256:4990142221b333e62dea4aef7f8b14684fc37a06a35fa39d6a3de3f3e3f9d6c3"
  output_directory = var.output_dir
  vm_name          = "alpine-m-series.qcow2"
  
  # M-series specific
  # M-series optimized settings (see common-m-series.pkrvars.hcl)
  qemu_binary      = "qemu-system-aarch64"
  machine_type     = "virt"
  cpu_model        = "cortex-a76"  # M1-M5 optimization
  cpus             = 8              # Use P+E cores
  memory           = 8192           # 8GB
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "hvf"  # macOS Hypervisor (2x faster than QEMU)  # macOS hypervisor
  
  # Boot config
  boot_wait        = "30s"
  boot_command     = [
    "root<enter><wait>",
    "setup-alpine<enter><wait5>",
    "us<enter><wait>",
    "us<enter><wait>",
    "alpine-m-series<enter><wait>",
    "eth0<enter><wait>",
    "dhcp<enter><wait>",
    "n<enter><wait>",
    "changeme<enter><wait>",
    "changeme<enter><wait>",
    "UTC<enter><wait>",
    "n<enter><wait>",
    "openssh<enter><wait>",
    "chrony<enter><wait>",
    "vda<enter><wait>",
    "sys<enter><wait>",
    "y<enter><wait60>",
    "reboot<enter>"
  ]
  
  # SSH
  ssh_username     = "root"
  ssh_password     = "changeme"
  ssh_timeout      = "20m"
  shutdown_command = "poweroff"
}

build {
  sources = ["source.qemu.alpine-m-series"]
  
  # Update system
  provisioner "shell" {
    inline = [
      "apk update",
      "apk upgrade",
      "apk add bash curl git build-base linux-headers"
    ]
  }
  
  # Install ZFS
  provisioner "shell" {
    inline = [
      "echo '@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories",
      "apk update",
      "apk add zfs@testing zfs-scripts@testing"
    ]
  }
  
  # Build M-series kernel
  provisioner "file" {
    source      = "../kernels/alpine-m-series.config"
    destination = "/tmp/kernel-config"
  }
  
  # Build M-series optimized kernel
  provisioner "shell" {
    inline = [
      "cd /usr/src/linux",
      "make defconfig",
      "scripts/config --enable ARM64_CRYPTO",
      "scripts/config --enable CRYPTO_AES_ARM64_CE",
      "scripts/config --enable CRYPTO_SHA256_ARM64",
      "scripts/config --enable CRYPTO_CRC32_ARM64_CE",
      "scripts/config --set-val ARM64_PAGE_SHIFT 14",  # 16K pages
      "make olddefconfig",
      "make -j8 Image modules",
      "make modules_install",
      "cp arch/arm64/boot/Image /boot/vmlinuz-m-series"
    ]
  }
  
  # Configure ZFS
  provisioner "file" {
    source      = "../kernels/zfs-m-series-tuning.conf"
    destination = "/etc/modprobe.d/zfs.conf"
  }
  
  # Enable services
  provisioner "shell" {
    inline = [
      "rc-update add zfs-import boot",
      "rc-update add zfs-mount boot",
      "rc-update add zfs-zed default"
    ]
  }
  
  # Cleanup
  provisioner "shell" {
    inline = [
      "apk cache clean",
      "rm -rf /tmp/*"
    ]
  }
  
  post-processor "compress" {
    output = "${var.output_dir}/alpine-m-series.qcow2.xz"
  }
}
