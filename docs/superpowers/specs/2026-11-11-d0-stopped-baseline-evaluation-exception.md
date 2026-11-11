# D0 stopped-baseline evaluation exception

**Decision date:** 2026-11-11

**Status:** Owner approved the prospective evaluation exception in the EventSales task conversation. This document records that decision for independent review; this draft PR does not authorize an operational transition.

## Decision and provenance

On 2026-11-11 the owner approved evaluating a prospective stopped D0 baseline. The decision followed the G3.2 local evidence reconciliation and G3.3 inspection-path review, and is bounded by the existing-data-plane reconciliation document merged in [PR #366](https://github.com/JCSchoeman96/EventSales/pull/366), merge commit `2d89e8a5b4aedc7b4623d193d943e7fb0fcbb1cc`.

```text
D0_HISTORICAL_TRANSITION=UNVERIFIED
D0_EVALUATION_EXCEPTION=OWNER_APPROVED
D0_CURRENT_BASELINE=NOT_ACCEPTED
D0_INSPECTION_AUTHORIZED=NO
FUNCTIONAL_PROOF_ELIGIBLE=NO
V6_AUTHORIZED=NO
```

This exception permits evaluation of a prospective stopped-state baseline only. It neither accepts that baseline nor retroactively authorizes the historical stop. The stop's authorization, time, reason and object continuity remain unverified. No inference from names, image references or zero restarts may replace the missing historical evidence.

## Evidence and preservation boundary

The historical closeout records D0 as running and healthy; G3.1 later observed three stopped D0 containers. G3.2 did not establish the transition between those states. G3.3 found that the existing read-only audit does not independently attest both D0 network objects and the D0 volume. Those findings do not alter the historical closeout or establish historical continuity.

Before considering a current baseline, independently verify the full IDs, image references, states and restart counts of the three D0 containers; both D0 network objects and their identities; the PostgreSQL volume identity; and its current attachment to the D0 PostgreSQL container. Identify comparisons for which historical object IDs are unavailable as `HISTORICAL_CONTINUITY_UNVERIFIED`. A later owner decision must review the resulting evidence and any remaining discrepancies before accepting a baseline.

D0 remains frozen. Do not start, stop, restart, recreate, rename, detach, delete, reuse, rotate or repurpose its containers, networks, volume, credentials or proof artifacts under this exception. Preserve the original closeout and its evidence.

## Authority limits

This decision does not authorize VPS access, host or Docker operations, installation or execution of a wrapper, secret access, database or Redis queries, functional probes, repairs, data-plane acceptance, V6 image approval, or public deployment. A future inspection needs a separately reviewed mechanism and explicit owner authorization. Any later operational transition requires its own authority.

## References

- [Existing-data-plane reconciliation ruling](2026-11-11-d1-existing-data-plane-readmission-ruling.md), merged in PR #366 and still marked draft.
- [Approved D1 architecture and frozen D0 invariant](2026-10-20-d1-vps-production-architecture-design.md).
- G3.1 protected evidence bundle: `/home/jcschoeman96/.local/state/eventsales/g3.1/20261111T124023Z-2418340`; local evidence, not a repository artifact.
- G3.2 and G3.3 findings and the 2026-11-11 owner exception: EventSales task conversation; the owner decision and evidence need durable independent review.
