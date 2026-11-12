# D1 existing data-plane readmission owner acceptance

**Decision date:** 2026-11-12
**Status:** OWNER ACCEPTED
**Decision scope:** Documentary governance transition only

## Decision authority

The owner explicitly approved G4.1 with `OWNER APPROVED` in the EventSales conversation on 2026-11-12. This record documents that approval for the exact ruling version below. It does not change the ruling's content or expand its authority.

```text
REPOSITORY=EventSales
RULING_COMMIT=adc657197cb755c07fa2369ed5f6418e3ec5ee53
RULING_TREE=e84cf607f8d967d04d4c36b8e35aaaab62cd0b66
RULING_DOCUMENT=docs/superpowers/specs/2026-11-11-d1-existing-data-plane-readmission-ruling.md
APPROVAL_DATE=2026-11-12
APPROVAL_SOURCE=OWNER_EXPLICIT_APPROVAL_IN_EVENTSALES_CONVERSATION
```

The accepted ruling defines a separate route for reconciling the production objects reported as pre-existing. This decision does not verify their current presence or identities. The D1 architecture, frozen D0 invariant, and first-installation requirements remain in force where the ruling does not define this separate route.

## Approved transition

```text
AUTHORITY_RECONCILIATION_REQUIRED
  -> EXISTING_UNVERIFIED
```

The guard is the owner's explicit approval of the ruling at the exact commit and tree above. The sole side effect is this documentary acceptance record and the governance state below. No host or production state is read or changed by this decision.

```text
READMISSION_ROUTE=OWNER_ACCEPTED
STATE=EXISTING_UNVERIFIED
D0_HISTORICAL_TRANSITION=UNVERIFIED
D0_EVALUATION_EXCEPTION=OWNER_APPROVED
D0_CURRENT_BASELINE=NOT_ACCEPTED
D0_INSPECTION_AUTHORIZED=NO
VPS_INSPECTION_AUTHORIZED=NO
FUNCTIONAL_PROOF_ELIGIBLE=NO
DATA_PLANE_ACCEPTED=NO
V6_AUTHORIZED=NO
```

`EXISTING_UNVERIFIED` is a documentary state. It does not accept the reported stopped D0 state or its history, establish the current D0 baseline, accept `eventsales-prod`, or establish historical V3, V4, or V5 outcomes.

## Preservation and authority limits

D0 remains frozen. Preserve its containers, networks, volume, credentials, and proof artifacts. Preserve the existing `eventsales-prod` containers, networks, and volume. This decision authorizes no restart, recreation, reset, deletion, detach, reconfiguration, or other VPS, Docker, Compose, database, PgBouncer, Redis, or OpenLiteSpeed operation.

This decision authorizes no VPS inspection, network audit, functional proof, repair, migration, application start, image approval, ingress change, public cutover, or rollback. It does not authorize V6. Each later operational action requires its own reviewed scope and explicit owner authorization.

## Next transition guards

| Transition | Guard | Side effect | Blocked condition |
| --- | --- | --- | --- |
| `EXISTING_UNVERIFIED` to `CURRENT_STATE_OBSERVED` | Separate explicit owner approval for a bounded read-only inventory that names exact commands, evidence destination, and redactions. | Non-secret evidence capture only. No mutation or automatic repair. | `BLOCKED_RECONCILIATION` on drift, unknown identity, missing evidence, secret exposure, or unexpected mutation. |
| `CURRENT_STATE_OBSERVED` to `FUNCTIONAL_PROOF_ELIGIBLE` | Owner reviews current-state evidence, historical proof records, evidence explaining the D0 stop, an accepted current D0 baseline, one-shot markers, and a safe proof design. | Documentary eligibility decision only. | `BLOCKED_PROOF_DESIGN` if evidence is missing or the proposed proof is unsafe, unclear, incompatible, or could replay a consumed action. |
| `FUNCTIONAL_PROOF_ELIGIBLE` to `FUNCTIONAL_PROOF_RECORDED` | New, distinct owner authorization naming the bounded functional proof operations. | Only the approved proof effects, if any. | `BLOCKED_FUNCTIONAL_PROOF` at the first failed check. No blind retry or cleanup. |
| `FUNCTIONAL_PROOF_RECORDED` to `DATA_PLANE_ACCEPTED` | Independent owner review accepts the required PostgreSQL, PgBouncer, Redis, network, security, health, restart, D0, and host-Redis evidence. | Acceptance record only. | `BLOCKED_ACCEPTANCE` if a material identity, test, or continuity result is missing, inconsistent, or failed. |
| `DATA_PLANE_ACCEPTED` to V6 image review eligibility | V6 source, digest, drift, and authority preconditions are independently satisfied. | No automatic image approval, staging, migration, or traffic. | V6 remains blocked until its separate approval. |

G4.2 preparation of a read-only inventory and its authorization remains a separate owner decision. This record does not authorize executing the G3.5 collector or any other inspection mechanism.

## Unresolved evidence

The merged G3.5 identity collector reports non-atomic collection, unverified historical continuity, unverified image-content identity, and an unavailable immutable volume ID. Its output alone cannot establish `D0_CURRENT_BASELINE=ACCEPTED`. The historical D0 stop's authorization, time, reason, and object continuity remain unresolved. Current production runtime identity and health, data-plane functional proofs, and backup and restore evidence also remain unverified.

Any authority conflict blocks the affected transition as `BLOCKED_AUTHORITY`. A failure makes the relevant authorization terminal. Further work requires a new review and explicit authorization.

## Governing references

- [Accepted readmission ruling](2026-11-11-d1-existing-data-plane-readmission-ruling.md), pinned above.
- [D0 stopped-baseline evaluation exception](2026-11-11-d0-stopped-baseline-evaluation-exception.md).
- [D1 architecture approval](2026-10-20-d1-vps-production-architecture-approval.md) and [approved architecture](2026-10-20-d1-vps-production-architecture-design.md).
- [D1 VPS production runbook](../../deployment/vps-production.md).
- G3.5 collector: `deploy/vps/operator/agent-vps-d0-identity-audit`.
