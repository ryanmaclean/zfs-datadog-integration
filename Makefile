# Makefile for M-series custom builds

.PHONY: all kernel-linux kernel-freebsd verify status monitor clean

# Build both kernels
all: kernel-linux kernel-freebsd

# Linux kernel (running now)
kernel-linux:
	@echo "Linux kernel building in zfs-test VM..."
	@tail -20 kernel-build-live.log || echo "Check logs"

# FreeBSD kernel (starting now)
kernel-freebsd:
	@echo "Starting FreeBSD kernel build..."
	@./scripts/build-freebsd-kernel-now.sh

# Verify everything
verify:
	@echo "Verifying builds..."
	@./scripts/verify-all.sh

# Status of all builds
status:
	@echo "=== VM Status ==="
	@limactl list | grep -E '(zfs-test|freebsd-build)'
	@echo ""
	@echo "=== Linux Kernel ==="
	@tail -5 kernel-build-live.log 2>/dev/null || echo "Not started"
	@echo ""
	@echo "=== FreeBSD Kernel ==="
	@tail -5 freebsd-kernel-build.log 2>/dev/null || echo "Not started"

# Monitor builds
monitor-linux:
	@tail -f kernel-build-live.log

monitor-freebsd:
	@tail -f freebsd-kernel-build.log

monitor:
	@echo "Linux kernel:"
	@tail -10 kernel-build-live.log 2>/dev/null || echo "Not started"
	@echo ""
	@echo "FreeBSD kernel:"
	@tail -10 freebsd-kernel-build.log 2>/dev/null || echo "Not started"

# Clean
clean:
	rm -f *.log
	rm -f baseline.txt verification.txt
