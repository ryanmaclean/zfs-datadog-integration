#!/usr/bin/env bash
# Stop before spawning parallel Lima guests or writing a misleading report.
set -euo pipefail

printf '%s\n' \
  'HOLD: parallel Lima validation has no reviewed packaged Agent-local fixture.' \
  'No VM is started and no distribution is marked PASS.' \
  'See AGENT-LOCAL-VM-FIXTURE.md.' >&2
exit 78
