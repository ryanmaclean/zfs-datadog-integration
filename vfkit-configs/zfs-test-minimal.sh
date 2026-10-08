#!/bin/sh
# Legacy vfkit reuses a named VM disk and cloud-init creates testpool without storage provenance.
printf '%s\n' 'HOLD (78): zfs-test-minimal vfkit requires a verified disposable off-NAS disk.' >&2
exit 78
