# Makefile for M-series custom builds
# Actually execute everything

.PHONY: all kernel-live packer-alpine packer-freebsd verify clean

# Build everything
all: kernel-live verify

# Build kernel in existing VM (LIVE)
kernel-live:
	@echo "Building M-series kernel in zfs-test VM..."
	@./scripts/build-kernel-live.sh

# Build Alpine image with Packer
packer-alpine:
	@echo "Building Alpine M-series image with Packer..."
	cd packer && packer build alpine-m-series.pkr.hcl

# Build FreeBSD image with Packer
packer-freebsd:
	@echo "Building FreeBSD M-series image with Packer..."
	cd packer && packer build freebsd-m-series.pkr.hcl

# Verify everything works
verify:
	@echo "Verifying builds..."
	@./scripts/verify-all.sh

# Clean build artifacts
clean:
	rm -rf packer/output-*
	rm -f *.log
	rm -f baseline.txt verification.txt

# Show status
status:
	@echo "=== Build Status ==="
	@limactl list
	@echo ""
	@echo "=== Kernel Build Log ==="
	@tail -20 kernel-build-live.log || echo "Not started"

# Monitor kernel build
monitor:
	@tail -f kernel-build-live.log
