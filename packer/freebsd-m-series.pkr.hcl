// Packer script to build FreeBSD M-series image
// With custom kernel + native ZFS

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
  default = "output-freebsd-m-series"
}

source "qemu" "freebsd-m-series" {
  iso_url          = "https://download.freebsd.org/releases/ISO-IMAGES/14.2/FreeBSD-14.2-RELEASE-arm64-aarch64-disc1.iso"
  iso_checksum     = "file:https://download.freebsd.org/releases/ISO-IMAGES/14.2/CHECKSUM.SHA256-FreeBSD-14.2-RELEASE-arm64-aarch64"
  output_directory = var.output_dir
  vm_name          = "freebsd-m-series.qcow2"
  
  # M-series specific
  # M-series optimized settings (see common-m-series.pkrvars.hcl)
  qemu_binary      = "qemu-system-aarch64"
  machine_type     = "virt"
  cpu_model        = "cortex-a76"  # M1-M5 optimization
  cpus             = 8              # Use P+E cores
  memory           = 8192           # 8GB
  disk_size        = "30G"
  format           = "qcow2"
  accelerator      = "hvf"  # macOS Hypervisor (2x faster than QEMU)
  
  # Network
  net_device       = "virtio-net"
  
  # Boot
  boot_wait        = "45s"
  
  # SSH
  ssh_username     = "root"
  ssh_password     = "freebsd"
  ssh_timeout      = "30m"
  shutdown_command = "shutdown -p now"
}

build {
  sources = ["source.qemu.freebsd-m-series"]
  
  # Update system
  provisioner "shell" {
    inline = [
      "pkg update",
      "pkg install -y git bash"
    ]
  }
  
  # Build M-series kernel
  provisioner "file" {
    source      = "../kernels/freebsd-m-series-kernel.conf"
    destination = "/tmp/M-SERIES"
  }
  
  # Build M-series optimized FreeBSD kernel
  provisioner "shell" {
    inline = [
      "cd /usr/src",
      "cat > sys/arm64/conf/M-SERIES << 'EOF'",
      "include GENERIC",
      "ident M-SERIES",
      "options ZFS",
      "nooptions INVARIANTS",
      "nooptions WITNESS",
      "nooptions DDB",
      "EOF",
      "make -j8 buildkernel KERNCONF=M-SERIES",
      "make installkernel KERNCONF=M-SERIES"
    ]
  }
  
  # Cleanup
  provisioner "shell" {
    inline = [
      "pkg clean -y",
      "rm -rf /tmp/*"
    ]
  }
  
  post-processor "compress" {
    output = "${var.output_dir}/freebsd-m-series.qcow2.xz"
  }
}
