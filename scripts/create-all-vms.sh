#!/bin/sh
# Legacy VM creation targeted the failing i9 ZFS host; retained as a HOLD entrypoint.
printf '%s\n' 'HOLD (78): create-all-vms targeted i9/tank3; no verified off-NAS disposable route.' >&2
exit 78
