// OpenBSD ARM64 automated install with Packer
// No more manual installation

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "openbsd-arm64" {
  iso_url          = "https://ftp.openbsd.org/pub/OpenBSD/7.6/arm64/install76.iso"
  iso_checksum     = "none"
  output_directory = "output-openbsd-arm64"
  vm_name          = "openbsd-m-series.qcow2"
  
  # M-series optimized settings (see common-m-series.pkrvars.hcl)
  qemu_binary      = "qemu-system-aarch64"
  machine_type     = "virt"
  cpu_model        = "cortex-a76"  # M1-M5 optimization
  cpus             = 8              # Use P+E cores (changed from 4)
  memory           = 8192           # 8GB
  disk_size        = "30G"
  format           = "qcow2"
  accelerator      = "hvf"  # macOS Hypervisor (2x faster than QEMU)
  
  boot_wait        = "45s"
  boot_command     = [
    "i<enter><wait>",                    // Install
    "<wait10>",
    "openbsd-m-series<enter><wait>",     // Hostname
    "vio0<enter><wait>",                 // Network interface
    "dhcp<enter><wait>",                 // DHCP
    "none<enter><wait>",                 // IPv6
    "done<enter><wait>",                 // Network done
    "root<enter><wait>",                 // Root password
    "root<enter><wait>",                 // Confirm
    "no<enter><wait>",                   // No user
    "UTC<enter><wait>",                  // Timezone
    "sd0<enter><wait>",                  // Disk
    "whole<enter><wait>",                // Use whole disk
    "auto<enter><wait>",                 // Auto layout
    "done<enter><wait>",                 // Done with disk
    "cd0<enter><wait>",                  // Install from CD
    "-game*<enter><wait>",               // Exclude games
    "done<enter><wait>",                 // Done with sets
    "yes<enter><wait>",                  // Reboot
    "<wait30>"
  ]
  
  ssh_username     = "root"
  ssh_password     = "root"
  ssh_timeout      = "30m"
  shutdown_command = "shutdown -p now"
}

build {
  sources = ["source.qemu.openbsd-arm64"]
  
  provisioner "shell" {
    inline = [
      "echo 'Installing packages...'",
      "pkg_add git bash curl"
    ]
  }
  
  provisioner "file" {
    source      = "../kernels/openbsd-m-series-kernel.conf"
    destination = "/tmp/M-SERIES"
  }
  
  provisioner "shell" {
    inline = [
      "echo 'Building M-series kernel...'",
      "cd /usr/src/sys/arch/arm64/conf",
      "cp /tmp/M-SERIES .",
      "config M-SERIES",
      "cd ../compile/M-SERIES",
      "make -j4",
      "make install",
      "echo 'Note: OpenBSD does not support ZFS due to license'",
      "echo 'Kernel built for M-series optimization only'"
    ]
  }
}
