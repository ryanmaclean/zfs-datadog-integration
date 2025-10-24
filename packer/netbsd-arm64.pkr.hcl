// NetBSD ARM64 automated install with Packer
// No more manual installation

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "netbsd-arm64" {
  iso_url          = "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/images/NetBSD-10.0-evbarm-aarch64.iso"
  iso_checksum     = "none"
  output_directory = "output-netbsd-arm64"
  vm_name          = "netbsd-m-series.qcow2"
  
  # M-series optimized settings (see common-m-series.pkrvars.hcl)
  qemu_binary      = "qemu-system-aarch64"
  machine_type     = "virt"
  cpu_model        = "cortex-a76"  # M1-M5 optimization
  cpus             = 8              # Use P+E cores (changed from 4)
  memory           = 8192           # 8GB
  disk_size        = "30G"
  format           = "qcow2"
  accelerator      = "hvf"  # macOS Hypervisor (2x faster than QEMU)
  
  boot_wait        = "60s"
  boot_command     = [
    "1<enter><wait>",           // Install NetBSD
    "a<enter><wait>",           // Installation messages in English
    "a<enter><wait>",           // Keyboard type
    "a<enter><wait>",           // Install to hard disk
    "b<enter><wait>",           // Use entire disk
    "a<enter><wait>",           // Yes
    "a<enter><wait>",           // Use default bootblocks
    "a<enter><wait>",           // Use default partition sizes
    "b<enter><wait>",           // Standard installation
    "a<enter><wait>",           // Install from CD-ROM
    "a<enter><wait>",           // Configure network
    "a<enter><wait>",           // DHCP
    "a<enter><wait>",           // Yes to network
    "<wait10>",
    "root<enter><wait>",        // Root password
    "root<enter><wait>",        // Confirm
    "d<enter><wait>",           // Enable sshd
    "x<enter><wait>",           // Finish
    "a<enter><wait>"            // Reboot
  ]
  
  ssh_username     = "root"
  ssh_password     = "root"
  ssh_timeout      = "30m"
  ssh_wait_timeout = "30m"
  shutdown_command = "shutdown -p now"
}

build {
  sources = ["source.qemu.netbsd-arm64"]
  
  provisioner "shell" {
    inline = [
      "echo 'Installing packages...'",
      "pkgin update",
      "pkgin -y install git bash curl"
    ]
  }
  
  provisioner "file" {
    source      = "../kernels/netbsd-m-series-kernel.conf"
    destination = "/tmp/M-SERIES"
  }
  
  provisioner "shell" {
    inline = [
      "echo 'Building M-series kernel...'",
      "cd /usr/src/sys/arch/evbarm/conf",
      "cp /tmp/M-SERIES .",
      "config M-SERIES",
      "cd ../compile/M-SERIES",
      "make -j4",
      "make install",
      "echo 'Kernel built and installed'"
    ]
  }
}
