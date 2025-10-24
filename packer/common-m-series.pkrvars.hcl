# Common variables for all M-series Packer builds
# Use: packer build -var-file=common-m-series.pkrvars.hcl <template>.pkr.hcl

# M-series hardware specs
m_series_cpus   = 8
m_series_memory = "8192"  # 8GB
m_series_disk   = "30G"

# M-series optimizations
cpu_model    = "cortex-a76"  # Best match for M-series
machine_type = "virt"
accelerator  = "hvf"         # macOS Hypervisor Framework

# Build settings
qemu_binary = "qemu-system-aarch64"
arch        = "aarch64"

# Common kernel config flags
kernel_crypto_flags = [
  "--enable ARM64_CRYPTO",
  "--enable CRYPTO_AES_ARM64_CE",
  "--enable CRYPTO_SHA256_ARM64",
  "--enable CRYPTO_CRC32_ARM64_CE"
]

# SSH settings (common for automated installs)
ssh_timeout = "30m"
