#!/usr/bin/env bash
# A higher-level driver must fail before a Lima/QEMU boot, results directory,
# or inherited historical PASS can bypass the Agent-local fixture gate.
set -euo pipefail

printf '%s\n' \
  'HOLD: multi-OS VM validation has no reviewed packaged Agent-local fixture.' \
  'No guest is started and no prior percentage or manual status is a pass.' \
  'See AGENT-LOCAL-VM-FIXTURE.md.' >&2
exit 78
