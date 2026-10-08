#!/bin/sh
# Legacy NFS mount targeted the failing i9 ZFS host and /Volumes/tank3.
printf '%s\n' 'HOLD (78): mount-remote-storage targeted i9/tank3; no verified safe route.' >&2
exit 78
