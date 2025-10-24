// Packer script to build Alpine Linux M-series image
// With custom kernel + ZFS

packer {
  required_plugins {
    limactl = {
      version = ">= 0.1.0"
      source  = "github.com/nofuturekid/limactl"
    }
  }
}

variable "output_dir" {
  type    = string
  default = "output-alpine-m-series"
}

source "limactl" "alpine-m-series" {
  vm_name          = "alpine-m-series"
  lima_home        = "${env("HOME")}/.lima"
  
  # Use existing Lima config
  lima_yaml        = "../examples/lima/lima-alpine-arm64.yaml"
  
  # M-series optimized (using VZ backend from Lima config)
  cpus             = 8
  memory           = "12GiB"
  disk             = "40GiB"
  
  
  # Lima handles boot automatically
  ssh_timeout      = "20m"
  shutdown_command = "sudo poweroff"
}

build {
  sources = ["source.limactl.alpine-m-series"]
  
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
