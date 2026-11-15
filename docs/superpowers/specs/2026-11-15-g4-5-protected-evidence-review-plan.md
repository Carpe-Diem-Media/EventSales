# G4.5 protected D0 evidence review plan

- **Document type:** Proposed read-only evidence-review procedure
- **Date:** 2026-11-15
- **Status:** DRAFT, ready for independent review
- **Tracking:** GitHub issue [#372](https://github.com/Carpe-Diem-Media/EventSales/issues/372) / Linear JC-347
- **Policy authority:** G4.4 owner-approved text at [PR #374, commit `523c9bd`](https://github.com/Carpe-Diem-Media/EventSales/blob/523c9bd8c14e7e8ff1ccac1be632fba38873e7c1/docs/superpowers/specs/2026-11-14-g4-4-prospective-frozen-d0-baseline-ruling.md)
- **Execution authority:** NOT GRANTED

## Decision and scope

This plan defines a possible one-time, offline review of the three existing G4.2 files. It does not authorize access to them, install a reviewer, recollect evidence, accept a D0 baseline, or change any operational status. The owner approved preparation of this plan only in [issue #372](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6890050870). G4.2's one-shot collection authority remains consumed.

G4.4 policy is owner-approved, but that approval does not accept a manifest or grant evidence-access authority. D0 remains frozen under the approved D1 invariant. The review must not start, stop, restart, recreate, rename, detach, delete, reuse, or reconfigure any D0 object.

The existing collector can support a partial, non-atomic current-state evidence assessment. It cannot support an exact V9 D0 fingerprint by itself. Per-container Docker exit codes and OOM state are absent, additional mount expectations remain unknown, immutable volume identity is unavailable, and historical continuity is unverified. The review must preserve those gaps and must not promote the manifest or functional-proof state.

## Existing evidence and source limits

The protected input directory is `/root/eventsales-g42-d0-evidence-20261113`. The only permitted input files are:

```text
/root/eventsales-g42-d0-evidence-20261113/collector.stdout
/root/eventsales-g42-d0-evidence-20261113/collector.stderr
/root/eventsales-g42-d0-evidence-20261113/metadata.json
```

The G4.2 issue report says the directory is root-only, the collection completed with exit status 1, its evidence integrity was reported verified, and its acquisition was non-atomic. It also records current container and network IDs, a volume metadata match, a PostgreSQL attachment match, and `UNVERIFIED` additional mounts. The report says the raw files were not copied to GitHub and were not independently reviewed there. These are owner-reported classifications, not this plan's independent verification.

The repository's approved collector is `deploy/vps/operator/agent-vps-d0-identity-audit`, Git blob `7d6e32ddb2c477d9288482c518b29a62061be34d`. It requires root, rejects arguments, clears its environment, and makes only bounded Docker API `GET` requests over the local socket. It permits at most 8 requests within 40 seconds. Those facts describe the past collection only. This review must not invoke that collector.

The current sudoers rule permits `agentops` to run only `/usr/local/sbin/agent-vps-d0-identity-audit` as root with no arguments. No G4.5 reader is authorized by that rule. The G4.2 wrapper source and `metadata.json` schema were not found in the reviewed tracked repository files or issue report. The metadata's field names, hash semantics, and independent integrity anchor therefore remain unverified until a separately approved reviewer inspects the existing files.

The collector report verifies expected `Config.Image` references. It does not inspect the image's content identity. It validates the volume name, driver, scope, labels, PostgreSQL mount destination, read/write flag, and equality between the volume mount source and volume mountpoint. It does not report an immutable volume ID. For mounts, it checks recognized `volume`, `bind`, or `tmpfs` types, but explicitly leaves the expected bind/tmpfs contract unverified, including when none are present. It marks acquisition `COLLECTION_ATOMIC=NO` and historical continuity `UNVERIFIED`.

## Evidence sufficiency matrix

`AVAILABLE` means the collector or an owner-reported G4.2 classification records the field. It does not mean this plan verified the protected bytes. `PARTIALLY_AVAILABLE` means the evidence supports only a limited assertion. `UNAVAILABLE` means this collection cannot establish the field. `REQUIRES_SEPARATE_AUTHORIZATION` identifies a new observation or operation outside G4.5.

| Field | Classification | What the existing collector/report supports | Remaining limit |
|---|---|---|---|
| Three container IDs | `AVAILABLE` | The collector records each full ID; the G4.2 issue report says all three were recorded. | Current IDs do not prove historical continuity. Keep full values in the protected assessment only. |
| Container stopped state and restart count | `AVAILABLE` | The collector checks `Status=exited` and zero restarts and reports both. | It does not prove the stop's authorization, time, or reason. |
| Per-container `ExitCode` and `OOMKilled` | `UNAVAILABLE` | The collector does not read or report either field. | A new Docker observation requires separate authorization and would establish only its own observation time. |
| Image reference | `AVAILABLE` | The collector compares `Config.Image` with the three pinned references and reports a match. | It does not establish image-content identity, which remains `UNVERIFIED`. |
| Two network IDs and checked metadata | `AVAILABLE` | The collector records both IDs and checks names, drivers, internal flags, and labels. | Full IDs stay protected; one-date IDs do not prove historical continuity. |
| Network membership | `PARTIALLY_AVAILABLE` | It checks configured data-network membership and records active endpoint counts when available. | Stopped-container endpoint IDs can be unavailable; historical membership is not established. |
| Volume name and metadata | `AVAILABLE` | The collector checks the expected name, driver, scope, and labels. | A name match is not an immutable volume identity. |
| Immutable volume identity | `UNAVAILABLE` | The collector reports `VOLUME_IMMUTABLE_ID=UNAVAILABLE`. | The existing evidence cannot supply this field. Any alternate host/storage identity source requires separate authorization and review. |
| PostgreSQL volume attachment | `PARTIALLY_AVAILABLE` | The collector checks the named volume, `/var/lib/postgresql` destination, writable flag, and source/mountpoint match; the issue reports `POSTGRES_VOLUME_ATTACHMENT=MATCH`. | The report does not establish an immutable volume identity. Full mount paths must remain in protected output. |
| Additional bind/tmpfs mount identities | `UNAVAILABLE` | The collector recognizes mount types but sets each `*_ADDITIONAL_MOUNTS=UNVERIFIED`. | Expected mounts and exact mount identities are not established. A new host observation requires separate authorization. |
| Collection result, exit status, and atomicity | `AVAILABLE` | The owner report says `COMPLETE`, collector exit status `1`, and `COLLECTION_ATOMIC=NO`. | Exit status 1 reflects unresolved assertions; it is not proof of drift or Docker failure. Exact timestamps still depend on unreviewed metadata. |
| File ownership, permissions, and integrity hashes | `PARTIALLY_AVAILABLE` | The owner report describes the bundle as root-only and integrity-verified. | Exact modes, owners, file hashes, and a trusted hash anchor are not available off-host. A hash computed during review identifies the bytes read but does not alone prove their origin. |
| Collector/wrapper provenance and one-shot binding | `PARTIALLY_AVAILABLE` | The source blob is identified above, and the owner report records `G42_ONE_SHOT_AUTHORITY=CONSUMED`. | The off-host record does not bind the exact wrapper bytes, collector digest, metadata, and three output files into one independently checked receipt. |
| Historical stop and cross-date object continuity | `UNAVAILABLE` | G4.3 records the history as unverified or missing. | G4.2 is a current, non-atomic snapshot and cannot prove the historical transition. |
| New current exit/OOM/mount observation | `REQUIRES_SEPARATE_AUTHORIZATION` | Not captured by the existing G4.2 output. | Do not obtain it as part of this review. It requires a distinct, narrowly scoped owner decision and would not fill historical gaps. |

The existing bundle may support a **partial evidence assessment** and a list of recorded current identities. It cannot support an exact, defensible V9 fingerprint by itself. In particular, the missing per-container exit/OOM fields, immutable volume identity, and exact additional-mount contract prevent a no-drift comparison for the proposed V9 guards. Preserve `D0_CURRENT_BASELINE=NOT_ACCEPTED`, `FUNCTIONAL_PROOF_ELIGIBLE=NO`, and `V9_SMOKE=NOT_RUN`.

## Proposed bounded procedure

Every command below is a proposal only. None was executed. No G4.5 reader currently exists in the repository or current sudoers rule. A separate review must approve the reader's exact bytes and a single-use sudoers entry before the proposed invocation can run.

### Approval and input guard

The proposed single-use review identifier is `G45-20261115-01`. The later owner authorization must name the approved reader's cryptographic digest, exact source commit, command, input paths, output path, file mode expectations, byte limits, redaction rules, and this review identifier. It authorizes one offline read of the three named files. It grants no Docker, database, Redis, network, VPS inspection beyond those file reads, or evidence-collection authority.

Proposed input requirements are a root-owned, mode `0700` source directory and three root-owned, mode `0600` regular files with one hard link each. The reader must reject symlinks, unexpected owners or modes, extra directory entries, missing files, changed files, and any path traversal. It must not repair permissions. If the actual approved G4.2 wrapper specifies different modes, stop and obtain an explicit review decision before changing this proposal.

Proposed per-file size ceilings are 16 KiB for `collector.stdout`, 16 KiB for `collector.stderr`, and 32 KiB for `metadata.json`. The reader must reject larger inputs rather than truncate them. It may parse only the known collector `KEY=VALUE` report format and a separately verified metadata schema. Duplicate keys, malformed records, unknown schema, invalid encodings, or unsupported fields stop the review.

### Proposed invocation

After a separate review approves the reader bytes and the matching sudoers entry, the only proposed operator command is:

```sh
sudo -n -- /usr/local/sbin/agent-vps-g45-evidence-review
```

The proposed sudoers grant is limited to that exact no-argument command:

```text
agentops ALL=(root) NOPASSWD: /usr/local/sbin/agent-vps-g45-evidence-review ""
```

The root-owned reader must contain the fixed input and output paths below. It must clear its environment, reject arguments, avoid a shell, run with networking disabled, and contain no Docker client, Docker socket, database, Redis, DNS, or HTTP access. It may open only the three input files and create the named output files. The proposed reader must fail if the output directory already exists. The command and sudoers entry are not currently installed or authorized.

### Integrity, provenance, and parsing

The reader must open each named file without following symlinks, verify ownership, mode, type, and link count through the same file descriptor used for the read, and reject any change observed during the read. It must hash each input with SHA-256 while reading and compare stdout/stderr digests with the metadata only if the verified metadata schema defines those fields. It must compare the metadata and collector identity against the independent, approved G4.2 authorization/receipt using values pinned into the reviewed reader before execution. The reader must not fetch a fourth file or contact GitHub. A self-reported hash in `metadata.json` is not an independent authenticity anchor. Missing hashes, missing external binding, or a wrapper/collector mismatch set provenance or integrity to `UNVERIFIED` and block manifest preparation.

The reader must never print raw inputs, full Docker IDs, network IDs, volume names, mount paths, hashes, or exception text to the terminal. It must write a protected per-object assessment containing the exact supported values and classifications, plus a redacted summary containing only object counts, field classifications, and blocker codes. It must not copy the raw files. A reviewer may publish the redacted summary only after a separate human disclosure check.

### Output and limits

The fixed output directory is `/root/eventsales-g45-review-20261115-01`. The reader creates it exclusively as `root:root 0700`; it must stop if that path already exists. It writes:

```text
/root/eventsales-g45-review-20261115-01/assessment.json
/root/eventsales-g45-review-20261115-01/redacted-summary.txt
/root/eventsales-g45-review-20261115-01/REVIEW_CONSUMED
```

All output files must be `root:root 0600`. The assessment may include full IDs and mount paths and must remain root-only. The summary must omit all raw identifiers, paths, file hashes, and metadata values. The reader must create the consumed marker before opening any input; a failure after that point is terminal and cannot be retried under the same authorization. It may emit only `G45_REVIEW=COMPLETE` or a fixed blocker code to stdout/stderr. The protected assessment is capped at 64 KiB and the redacted summary at 4 KiB. No output may be written to Git or an ordinary user home directory.

The reader returns exit status 0 only when it completes a consistent assessment. Proposed terminal failure codes are 10 for permissions/path, 11 for hash/integrity, 12 for provenance/authorization binding, 13 for schema/format, 14 for contradictory records, and 15 for missing required fingerprint fields. A zero exit status means only that the review completed; it does not mean a baseline was accepted or is V9-capable.

## Lifecycle and transition guards

| Transition | Approval guard | Evidence requirement | Permitted side effects | Terminal failure |
|---|---|---|---|---|
| `REVIEW_NOT_AUTHORIZED` → `REVIEW_AUTHORIZED` | Owner explicitly approves the exact reader digest, no-argument command, sudoers entry, three inputs, permissions, limits, output path, redaction, and single-use scope. | G4.4 policy approval and G4.2 consumed status are recorded; no claim about the protected bytes is made yet. | Documentary approval only. No file access or host operation. | Remain `REVIEW_NOT_AUTHORIZED`; use `BLOCKED_AUTHORITY` if scope or exact reader identity is unclear. |
| `REVIEW_AUTHORIZED` → `EVIDENCE_REVIEWED` | An operator runs the approved command once under the approved root-only grant. | All three files pass path, permission, size, integrity, metadata-schema, and provenance checks. The report records every supported and unavailable field. | Read only the three existing files; create only the protected report files above. No Docker, database, Redis, network, or collector operation. | `BLOCKED_EVIDENCE_PERMISSIONS`, `BLOCKED_EVIDENCE_INTEGRITY`, `BLOCKED_PROVENANCE`, `BLOCKED_FORMAT`, or `BLOCKED_RECONCILIATION`. The consumed marker makes the failed attempt terminal. |
| `EVIDENCE_REVIEWED` → `MANIFEST_PROPOSED` | An independent reviewer confirms the report provenance, per-object evidence, and exact supported-field mapping. | The proposal pins the non-atomic acquisition and marks every absent field `UNVERIFIED`, `MISSING`, or `UNAVAILABLE`. Full identifiers remain in the protected report. | Create a limited documentary proposal only. No acceptance, status promotion, D0 action, or production side effect. | `BLOCKED_RECONCILIATION` if provenance or evidence integrity is unresolved. `BLOCKED_PROOF_DESIGN` if a required V9 comparison field is missing. A partial proposal must not be called an exact V9 fingerprint. |

`MANIFEST_PROPOSED` is not `PROSPECTIVE_BASELINE_ACCEPTED`. A separate owner decision may accept only the exact reviewed manifest and its stated limitations under G4.4. If V9 comparison fields remain missing, that acceptance does not make the baseline V9-capable. Any downstream compatibility mapping, functional-proof eligibility, and V9/V10 execution remain separate guarded decisions. There is no automatic promotion between states.

## Failure and stop conditions

Stop immediately and preserve the input bundle if any file is missing, unexpected, changed, linked, outside the approved ownership/mode, over its size limit, malformed, or inconsistent with metadata. Stop if the exact collector or wrapper identity cannot be bound to the approved one-shot authorization, if metadata has no independent integrity anchor, or if any record contradicts the owner-reported G4.2 summary. Do not chmod, repair, recopy, re-hash through another procedure, re-run the reader, or invoke the G4.2 collector after a failure. A retry or additional evidence read requires a new owner authorization.

Stop any claim that the candidate is an exact V9 fingerprint if per-container `ExitCode` or `OOMKilled`, immutable volume identity, network membership, or additional-mount identity is required but unavailable. A limited manifest proposal may still list the supported fields and gaps if provenance and integrity pass. Do not infer missing fields from object names, current IDs, zero restarts, exit status 1, or a volume-name match. Any new observation needed to fill a gap requires separate authorization and cannot prove the historical stop or cross-date continuity.

## Current status and next decision

This plan does not change the actual governance or operational state:

```text
G44_POLICY_EXCEPTION=OWNER_APPROVED
G45_REVIEW_PLAN=READY_FOR_REVIEW
G45_EVIDENCE_ACCESS=NOT_AUTHORIZED
G42_ONE_SHOT_AUTHORITY=CONSUMED
D0_HISTORICAL_TRANSITION=UNVERIFIED
D0_CURRENT_BASELINE=NOT_ACCEPTED
D0_PROSPECTIVE_BASELINE=NOT_ACCEPTED
FUNCTIONAL_PROOF_ELIGIBLE=NO
V9_SMOKE=NOT_RUN
VPS_CHANGES=NONE
```

The single next owner decision is whether to authorize a separate code-only task to prepare and independently review the fixed-path offline reader and its exact sudoers grant. That decision would authorize no installation, VPS access, or evidence read. A later, separate owner decision must authorize one execution after the reader's exact bytes, command, permissions, paths, redactions, and terminal failure behavior are pinned. Neither decision accepts a manifest, authorizes new evidence collection, changes D0, or makes V9 eligible.

## References

- [G4.4 approved policy text at exact commit `523c9bd`](https://github.com/Carpe-Diem-Media/EventSales/blob/523c9bd8c14e7e8ff1ccac1be632fba38873e7c1/docs/superpowers/specs/2026-11-14-g4-4-prospective-frozen-d0-baseline-ruling.md).
- [G4.4 owner policy approval](https://github.com/Carpe-Diem-Media/EventSales/pull/374#issuecomment-6874150157).
- [D1 architecture approval](2026-10-20-d1-vps-production-architecture-approval.md) and [D0 frozen invariant](2026-10-20-d1-vps-production-architecture-design.md).
- [Accepted D1 readmission ruling](2026-11-11-d1-existing-data-plane-readmission-ruling.md) and [owner acceptance](2026-11-12-d1-existing-data-plane-readmission-owner-acceptance.md).
- [G4.2 owner-reported evidence summary](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6872781108) and [G4.3 historical reconciliation](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6873432052).
- [G4.5 planning-only owner approval](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6890050870).
- `deploy/vps/operator/agent-vps-d0-identity-audit` at blob `7d6e32ddb2c477d9288482c518b29a62061be34d` and `deploy/vps/operator/agent-vps-d0-identity-audit.sudoers`.
