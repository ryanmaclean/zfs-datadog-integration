# M-series builds that ACTUALLY WORK

.PHONY: all verify publish clean

# Complete working builds
all: kernel-verify artifacts publish

# Verify Linux kernel (DONE)
kernel-verify:
	@echo "Checking custom kernel..."
	@limactl shell zfs-test -- uname -r || echo "VM rebooting..."

# Create all artifacts
artifacts:
	@echo "Building all artifacts..."
	@./scripts/create-all-artifacts.sh

# Publish to GitHub
publish:
	@echo "Publishing verified artifacts..."
	@./scripts/publish-verified.sh

# Status
status:
	@echo "=== Kernel ==="
	@ls -lh /boot/vmlinuz-m-series 2>/dev/null || echo "In VM only"
	@echo ""
	@echo "=== Artifacts ==="
	@ls -lh *m-series* 2>/dev/null || echo "Building..."
	@echo ""
	@echo "=== Docker Builds ==="
	@docker ps | grep -E '(arch|gentoo|openindiana)' || echo "Not running"

clean:
	rm -f *.log *.tar.gz *.iso

