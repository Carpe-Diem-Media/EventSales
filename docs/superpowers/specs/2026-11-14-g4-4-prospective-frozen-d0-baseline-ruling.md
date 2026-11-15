# G4.4 prospective frozen D0 baseline ruling

- **Document type:** Proposed owner governance decision
- **Date:** 2026-11-14
- **Status:** DRAFT, owner decision required
- **Tracking:** GitHub issue [#372](https://github.com/Carpe-Diem-Media/EventSales/issues/372) / Linear JC-347
- **Implementation and operations:** NOT AUTHORIZED

## Decision requested

Decide whether to approve a narrow exception to the accepted D1 readmission guards. The exception would let the owner accept a prospective snapshot of the currently observed, frozen D0 objects as a future no-drift reference, even though the historical stop remains unverified.

This is an exception to the current D1 route, not a claim that the route already permits skipping the D0 transition evidence. The 2026-10-20 D1 architecture records D0 as accepted evidence in a healthy, restart-free state and prohibits D1 tasks from changing it without later authority. The 2026-11-11 exception permits prospective evaluation only. The accepted 2026-11-12 readmission ruling requires the owner to review evidence explaining the D0 transition and accept a current baseline before proof eligibility. An owner decision at the same or higher authority than the D1 approval must explicitly amend that guard before this proposed route can proceed. Until then, the route is `BLOCKED_AUTHORITY`.

If approved, the exception would permit documentary acceptance of a *prospective current D0 baseline* while retaining the unresolved historical transition as unexplained and unverified. It would not make a downstream D1 guard pass by itself: each consumer would still need an explicit, reviewed compatibility mapping before that documentary acceptance could satisfy its named prerequisite. The exception would not turn the unknown history into proof or waive any D0 identity, preservation, application, data-plane or V9 proof check.

The decision would accept only a *prospective current-state reference*. It would not prove or authorize the historical stop, change D0, accept the production data plane, make the application proof eligible, or authorize V9 or V10.

## Keep the three evidence claims separate

| Evidence class | What it establishes | What it does not establish |
|---|---|---|
| Historical D0 proof | The approved D1 architecture treats the original D0 closeout as accepted evidence of three healthy services with zero restarts and the required functional proofs. | G4.3 found no accessible raw closeout record with its observation time and object IDs. The later stop's authorization, time, reason, exit codes and continuity to that closeout remain unverified or missing. |
| Prospective D0 baseline | G4.2 reports three containers with `Status=exited` and `RestartCount=0`, two networks and one volume. It records current container and network IDs, volume metadata, and a PostgreSQL attachment match. A separate owner-pasted read-only diagnostic in [issue #372](https://github.com/Carpe-Diem-Media/EventSales/issues/372), dated 2026-11-13, reports aggregate `D0_CURRENT_STATE=EXITED_0`; that is not per-container G4.2 evidence. | The G4.2 report does not independently record each container's `ExitCode` or `OOMKilled`; both remain unverified in its fingerprint. The collection is non-atomic. Current identity remains unverified; image-content identity is unverified; the immutable volume ID is unavailable; additional mount expectations remain unverified. It cannot establish historical continuity. |
| EventSales production proof | V9 separately checks the private production application, its security and resource settings, network topology, runtime behavior, health/readiness, and production data-plane stability. V10 separately proves loopback ingress. | A D0 baseline or Phase I application health does not satisfy V9, V10, data-plane acceptance, or their separate authorizations. V9 includes the write-bearing `PrivateRuntimeSmoke` operation. |

G4.2 facts above are the owner-reported classifications in [issue #372, G4.2](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6872781108). The protected root-only output was not copied to the issue or independently inspected for G4.3. G4.3 therefore concludes `D0_HISTORICAL_TRANSITION=UNVERIFIED`; see [issue #372, G4.3](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6873432052). This draft does not upgrade either report's evidence classifications.

The G4.2 authorization was single-use and is consumed. This ruling authorizes no rerun. A reviewer may assess the existing protected bundle through an approved evidence-review path; no host or Docker operation is implied.

## Proposed baseline evidence contract

The prospective baseline is a dated, owner-reviewed record of the exact evidence G4.2 captured. It must preserve the acquisition interval and the collector's non-atomic classification. It must not combine separate observations into a claim that all objects were measured atomically.

The record may include, only where the protected G4.2 evidence supports them:

- Each of the three containers' full IDs, Compose project and service labels, recorded image reference, reported state and restart count, and known mounts. Record per-container `ExitCode` and `OOMKilled` only if separate, independently reviewed evidence supports each value; G4.2 does not report those fields, so they remain `UNVERIFIED` in a G4.2-only fingerprint. The separate aggregate `EXITED_0` diagnostic does not fill this per-container gap.
- Both network IDs, labels and their observed container memberships.
- The volume name and observed metadata, plus the recorded PostgreSQL attachment details.
- The collector identity, run timestamps, exit status, integrity evidence, protected evidence location and per-field `VERIFIED`, `UNVERIFIED` or `MISSING` classifications.

Do not infer values absent from the captured evidence. In particular, retain `IMAGE_CONTENT_IDENTITY=UNVERIFIED`, `VOLUME_IMMUTABLE_ID=UNAVAILABLE`, and the additional-mount classifications as unverified. A volume name or attachment match is not an immutable volume identity. Names, one-date IDs, zero restarts and a successful collector exit do not establish historical continuity.

An independent reviewer must confirm that the available fingerprint is sufficient to detect changes relevant to a future no-drift check. If the raw record lacks any field needed to distinguish an identity, state or mount change, mark the proposed baseline `BLOCKED_RECONCILIATION` or `BLOCKED_PROOF_DESIGN`. Do not fill the gap by inference or by rerunning G4.2. Any further evidence collection requires a separate owner-approved scope and is outside this draft.

## Proposed lifecycle

This lifecycle records prospective evidence only. Its owner-approval transition is not effective until an explicit decision supersedes or amends the current D1 guard.

| Transition | Evidence guards | Owner authority | Side effects | Failure state | Preserved invariants |
|---|---|---|---|---|---|
| `EXISTING_UNVERIFIED` → `CURRENT_STATE_OBSERVED` | An independent reviewer examines the existing G4.2 bundle's provenance, integrity, per-object records and redactions through an approved evidence-review path. Preserve its non-atomic and unverified fields. The issue summary alone is not enough to construct the fingerprint. Do not repeat the consumed collection. | Owner confirms the review path and accepts the evidence review as the current observation record. This is documentary approval only. | Record the reviewed evidence reference and current-state classifications. No VPS, Docker or D0 action. | `BLOCKED_RECONCILIATION` if the protected evidence cannot be reviewed, provenance is unclear, a required field is missing, or records disagree. | D0 remains frozen at 3 containers, 2 networks and 1 volume. Historical transition and image-content identity remain unverified. |
| `CURRENT_STATE_OBSERVED` → `PROSPECTIVE_BASELINE_REVIEWED` | An independent reviewer prepares the exact fingerprint from the captured records and tests whether it can support no-drift comparison for all three containers, both networks, the volume, PostgreSQL attachment, stopped-state attributes and known mounts. List every unknown separately. Do not claim atomicity, historical identity, immutable volume identity or image-content identity. | Independent evidence review under the approved D1 authority. No acceptance decision is implied. | Create a reviewable baseline manifest and gap list. No production or D0 side effect. | `BLOCKED_RECONCILIATION` for conflicting or incomplete evidence; `BLOCKED_PROOF_DESIGN` if the fingerprint cannot support safe comparison. | No D0 state change. Production application/data-plane evidence remains separate and must not be derived from D0. |
| `PROSPECTIVE_BASELINE_REVIEWED` → `PROSPECTIVE_BASELINE_ACCEPTED` | The exact manifest and limitations are pinned. The reviewer confirms the baseline is useful as a prospective preservation reference and identifies any fields that still prevent V9 eligibility. Historical transition remains explicitly unverified. | A new, explicit owner decision at the same or higher authority than the D1 architecture approves this narrow exception and its recorded limits. | Documentary acceptance of the prospective reference only. It does not set a D1/V9/V10 gate to pass, make functional proof eligible, or authorize probe execution. No D0 transition or data-plane acceptance. | `BLOCKED_AUTHORITY` if the owner declines, the governing authority does not permit the exception, or another accepted rule conflicts. `BLOCKED_PROOF_DESIGN` remains if the exact fingerprint cannot safely guard V9. | Historical D0 records remain unchanged. All V9/V10 application and data-plane checks, D0 immutability and separate execution authorizations remain in force. |

`PROSPECTIVE_BASELINE_ACCEPTED` is a documentary state only. It records that the owner adopts the pinned current-state fingerprint as a future D0 preservation reference with stated limits; it does not change the historical record. After exact-manifest acceptance, record `D0_HISTORICAL_TRANSITION=UNVERIFIED` and `D0_PROSPECTIVE_BASELINE=ACCEPTED_WITH_LIMITATIONS`; keep the canonical `D0_CURRENT_BASELINE=NOT_ACCEPTED` unless and until a separate, reviewed compatibility decision explicitly maps the documentary state to a named downstream gate. That review must cover every consumer, including D1 governance, V9/V10 contracts and exact-string checks. Each consumer must fail closed when the mapping is absent or an unrecognized value is present; an unknown or merely non-`NOT_ACCEPTED` value is never a pass. Policy approval alone and manifest acceptance alone cannot satisfy a downstream prerequisite.

No automatic promotion follows. Functional-proof eligibility requires a separate guarded decision after the compatibility review, exact fingerprint sufficiency and all other D1/application/data-plane checks are reviewed. V9 execution requires its own explicit authorization after eligibility; V10 also requires separate authorization. Until those transitions are independently approved, retain `FUNCTIONAL_PROOF_ELIGIBLE=NO` and `V9_SMOKE=NOT_RUN`. If the owner does not approve the narrow exception, or a required compatibility mapping is absent or conflicts with an accepted rule, retain `D0_CURRENT_BASELINE=NOT_ACCEPTED` and `BLOCKED_AUTHORITY`.

The only possible progression is separate approval of the policy exception, acceptance of an exact manifest, per-consumer compatibility review, a distinct functional-proof eligibility decision, then separate V9 authorization and execution. No transition approves or automatically promotes the next one.

Any missing or unreviewable identity field that prevents exact comparison blocks the affected transition. No transition authorizes starting, stopping, restarting, recreating, renaming, detaching, deleting, reusing or reconfiguring D0.

## Later V9 and V10 implications

No probe change is approved by this draft. If the owner accepts the policy and a separate implementation review approves a change, the smallest V9 change would add one explicit mode for the exact owner-accepted fingerprint. It must reject arbitrary stopped containers and compare the same accepted D0 fingerprint before and after the smoke.

That mode must preserve checks for exactly three labeled containers, their accepted image references, both exact network identities and memberships, the volume, and PostgreSQL's attachment. It must compare the accepted stopped-state fields, including `exited`, exit code `0`, `RestartCount=0`, and `OOMKilled=false`; reject any identity, image-reference, state, exit-code, restart, OOM, network, volume or known-mount drift; and fail closed when a required field is unavailable. G4.2 alone does not establish per-container exit code or OOM values; until separate, independently reviewed evidence supports those fields, the exact fingerprint cannot satisfy these V9 guards and V9 remains blocked. The probe and any exact-string status reader must require an explicit reviewed compatibility mapping for the documentary `D0_PROSPECTIVE_BASELINE` status. Missing mappings and unknown or non-`NOT_ACCEPTED` values must fail closed. It must not convert unknown image contents, immutable volume identity or additional-mount expectations into verified claims. If the available fingerprint cannot detect required volume or mount drift, V9 remains blocked until separately authorized evidence can close that gap.

All existing production application and data-plane checks remain required: app identity and digest, runtime environment, security and resource limits, private networking, database/PgBouncer/Redis checks, node and PubSub behavior, health/readiness, and data-plane stability. The write-bearing `PrivateRuntimeSmoke` remains a separate, explicitly authorized operation. A prospective D0 acceptance alone does not authorize it.

`probe-loopback.sh` has the same running/healthy D0 prerequisite at its initial and final snapshots. A later reviewed PR must update the runbook and the applicable probe contract together so an explicitly mapped, accepted prospective state replaces only the historical-transition prerequisite. V10 and any exact-string reader must fail closed without that reviewed mapping; review the equivalent accepted-fingerprint behavior before V10, either in that PR or a separately approved change. V10 still requires its own authorization and all loopback exposure, health/readiness and external-denial checks.

Before implementation, require a separate reviewed PR and isolated fake-Docker regression tests. Tests must cover the exact accepted fingerprint and reject changes to IDs, labels, image references, networks, volume/attachment, mounts, state, exit code, restart count and OOM status. They must also show that the production app and data-plane checks remain enforced. No test or probe is authorized by this draft.

## Owner decision and current status

The one decision requested is whether to approve the narrow D1 exception described here: permit documentary acceptance of a reviewed prospective baseline with an explicit, permanent `D0_HISTORICAL_TRANSITION=UNVERIFIED` limitation in place of the unavailable historical-transition explanation. If approved, the owner must later accept a specific reviewed manifest by reference before the state reaches `PROSPECTIVE_BASELINE_ACCEPTED`. That policy decision and manifest acceptance do not map the resulting documentary status to any D1/V9/V10 gate. Any such compatibility mapping, functional-proof eligibility, implementation and runtime proof require separate review and approval. If the exception is not approved, retain `BLOCKED_AUTHORITY` and the current blocked state.

Until the owner records that decision, the status remains:

```text
D0_HISTORICAL_TRANSITION=UNVERIFIED
D0_CURRENT_BASELINE=NOT_ACCEPTED
FUNCTIONAL_PROOF_ELIGIBLE=NO
V9_SMOKE=NOT_RUN
VPS_CHANGES=NONE
CODE_CHANGES=NONE
```

## STOP conditions

Stop the prospective-baseline route if authority is not explicit, the protected G4.2 evidence cannot be reviewed, the exact fingerprint cannot be established, any object or state differs from the proposed manifest, a required identity or mount field is unavailable, or review would require an unapproved host operation. Preserve evidence and leave the affected transition blocked. Do not start D0, repeat G4.2, modify a probe, run V9/V10, or reinterpret historical evidence.

## Governing references

- [D1 architecture approval](2026-10-20-d1-vps-production-architecture-approval.md) and [approved D1 design](2026-10-20-d1-vps-production-architecture-design.md).
- [D0 stopped-baseline evaluation exception](2026-11-11-d0-stopped-baseline-evaluation-exception.md).
- [D1 readmission ruling](2026-11-11-d1-existing-data-plane-readmission-ruling.md) and [2026-11-12 owner acceptance](2026-11-12-d1-existing-data-plane-readmission-owner-acceptance.md).
- [D1 VPS production runbook](../../deployment/vps-production.md), especially V9 and V10.
- `deploy/vps/app/scripts/probe-private.sh` and `deploy/vps/app/scripts/probe-loopback.sh`.
- [G4.2 owner-reported evidence](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6872781108) and [G4.3 historical reconciliation](https://github.com/Carpe-Diem-Media/EventSales/issues/372#issuecomment-6873432052).

**Review boundary:** This is a governance proposal only. No D0 evidence was recollected, no VPS or Docker operation was performed, no code or tests were changed or run, and no owner decision was made.
