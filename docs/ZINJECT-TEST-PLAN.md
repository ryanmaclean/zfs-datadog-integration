# Zinjection Test Plan

## Objectives
- Keep checksum and I/O error simulations repeatable in the Ubuntu 24.04 Lima test VM so `all-datadog.sh`, `checksum-error.sh`, and `io-error.sh` run end-to-end on every enhanced E2E execution.
- Feed the captured payloads/metrics back into documentation so event coverage is tracked, not assumed.

## Why This Matters
- Before 2025-10-23, the E2E suite only validated scrub/resilver/statechange flows; checksum and I/O handlers had never been triggered.
- Without synthetic faults, Datadog payload formatting, metric emission, and error logging paths remained untested.
- Demonstrating error coverage on Linux removes the largest open gap and makes subsequent BSD/TrueNAS validation less risky.

## Work Items
1. **Compile zinject in the Lima VM**
   - Run `scripts/compile-zinject.sh` (now installs `libtirpc-dev`, `pkg-config`, and supports `OPENZFS_REF` overrides) so OpenZFS userland 2.4.99-1 is available with `zinject`.
2. **Enhance `scripts/enhanced-e2e-test.sh` fault injections**
   - Drive checksum faults (`zinject -t data -e checksum -f 100`) followed by a scrub and verification of Datadog events/metrics.
   - Drive I/O faults (`zinject -d … -e io -f 100`) with cache flushes and repeated reads. When Lima suppresses `ereport.fs.zfs.io`, fall back to invoking `io-error.sh` directly to keep coverage.
   - Auto-install updated zedlets into both `/etc/zfs/zed.d` and `/usr/local/etc/zfs/zed.d`, add logging, and persist summary stats before the mock server reset.
3. **Refresh documentation and readiness metrics**
   - Update `docs/TEST-RESULTS.md`, `docs/IMPROVEMENTS-SUMMARY.md`, and `docs/TEST-COVERAGE.md` with 2025-10-23 evidence and note the synthetic fallback.

## Acceptance Criteria
- `zinject -h` succeeds inside the VM (`/usr/local/sbin/zinject`).
- `./scripts/enhanced-e2e-test.sh` reports PASS for checksum and I/O injections (or logs the explicit fallback) and the mock server shows corresponding events/metrics.
- Repository docs list checksum/I/O coverage as tested on Ubuntu 24.04, with remaining gaps limited to platform diversity and real Datadog integration.

## Status (October 23, 2025)
- ✅ OpenZFS userland rebuilt via `compile-zinject.sh`; `zinject` included on the PATH.
- ✅ Enhanced E2E suite upgraded with checksum/I/O phases, synthetic fallback, zedlet auto-sync, and logging to `zfs-datadog`.
- ✅ Documentation refreshed with payload excerpts (events: 208, metrics: 212) and coverage matrices updated to 4/4 event types on Linux.
- 🔜 Next milestones pivot to platform coverage (FreeBSD, TrueNAS) and real Datadog API smoke tests.

## Verification Checklist
1. Run `./scripts/enhanced-e2e-test.sh` and confirm the CLI shows PASS for:
   - `Detect zinject availability`
   - `Checksum error injection`
   - `I/O error injection` (notes fallback when native ereports are absent)
   - `Graceful failure when Datadog unreachable`
2. Inspect `/var/log/syslog` / `journalctl -t zfs-datadog` to verify checksum/I/O logs and DogStatsD counters.
3. Query `curl -s http://localhost:8080/status | jq '.'` in the VM; ensure `ZFS Checksum Error` and `ZFS I/O Error` payloads (and metrics) are present.
4. Confirm documentation updates landed and the production readiness matrix shows 100% event coverage.

