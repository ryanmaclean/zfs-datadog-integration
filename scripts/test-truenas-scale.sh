#!/usr/bin/env bash
# bash-required: pipefail
# Never use a generic localhost:2222/root login as proof of a disposable
# TrueNAS VM. The old script disabled SSH host-key checks and rewrote sealed
# ZED configuration after install.
set -euo pipefail

printf '%s\n' \
  'HOLD: TrueNAS Agent-local integration requires a pinned disposable VM identity.' \
  'A reviewed packaged Agent, strict SSH host identity, and an isolated pool are not bound.' \
  'No appliance, ZED service, pool, or config is touched by this gate.' \
  'See AGENT-LOCAL-VM-FIXTURE.md.' >&2
exit 78
