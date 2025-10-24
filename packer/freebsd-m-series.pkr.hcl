// Packer script to build FreeBSD M-series image
// With custom kernel + native ZFS

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
  default = "output-freebsd-m-series"
}

source "limactl" "freebsd-m-series" {
  vm_name          = "freebsd-m-series"
  lima_home        = "${env("HOME")}/.lima"
  
  # Use existing Lima config
  lima_yaml        = "../examples/lima/lima-freebsd-arm64.yaml"
  
  # M-series optimized (QEMU aarch64)
  cpus             = 4
  memory           = "8GiB"
  disk             = "30GiB"
  
  ssh_timeout      = "30m"
  shutdown_command = "sudo shutdown -p now"
}

build {
  sources = ["source.limactl.freebsd-m-series"]
  
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
