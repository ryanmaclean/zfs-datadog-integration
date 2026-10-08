#!/bin/sh
# Legacy wrapper deletes named vfkit directories, writes VM disks, then can claim tests passed without safe ZFS execution.
printf '%s\n' 'HOLD (78): test-all-vms requires proven disposable off-NAS storage and a real test verdict.' >&2
exit 78
