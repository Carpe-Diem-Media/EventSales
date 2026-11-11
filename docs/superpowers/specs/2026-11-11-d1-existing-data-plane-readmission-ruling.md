# EventSales D1 — Existing Data-Plane Reconciliation Ruling (Draft)

**Document type:** Proposed owner decision / governance addendum; not an operational authorization

**Date:** 2026-11-11

**Status:** DRAFT — owner acceptance remains to be verified

**Repository path:** `docs/superpowers/specs/2026-11-11-d1-existing-data-plane-readmission-ruling.md`

**Reference checkout:** `afbd9d21a819625035558c3147c850232df6d3fa`, tree `8ee096c8161177affb79b83f6d0dabefc7f53c3e` (verified locally, not freshly fetched from GitHub)

## 1. Decision and purpose

EventSales retains its **existing Docker Compose deployment architecture**, with independently managed `eventsales-prod` data plane, `eventsales-app` application project, and existing OpenLiteSpeed public ingress. Coolify and a new `jcs-vps` deployment controller are out of scope for this launch.

The original **first-installation** V0/V3 route is **not valid as a re-admission procedure for existing production objects**. It explicitly requires the EventSales production networks and volume to be absent and the D0 containers to be healthy and running. The 2026-11-10 operator report instead records existing production data containers/networks/volume and stopped D0 containers. Do not attempt the first-installation V0/V3 actions on these resources. This is a **scope-specific reconciliation**, not a weakening of their prerequisites or an assertion that the historical V3/V4/V5 transitions passed.

Create a **separate, evidence-backed existing-data-plane re-admission route** before allowing progression to V6. The design of a re-admission route may be reviewed without touching production. Every later host operation requires its own explicit, narrowly scoped owner authorization.

## 2. Authority and observations

Authority order remains that in `docs/deployment/vps-production.md`: current accepted repository evidence at the exact reviewed commit/tree, `R1-RULING-01`, approved D1 architecture and implementation plan, accepted R3/R4 decisions, the runbook, and finally operator reports. An untracked operator report is dated evidence, **not authority**. No later chat summary, draft, agent opinion or uploaded copy can silently supersede a higher-level approved document.

The externally supplied operator report `vps-agentops-status-2026-11-10.md`, recorded on 2026-11-10, is untracked and is not included in this repository or PR. Its provenance is the reported restricted `agentops` read-only host inspection and follow-up described in the report. Before operational acceptance, preserve a suitably redacted copy with its source, collection date, integrity identity and separately approved evidence location so reviewers can inspect it. The report records:

- `eventsales-prod-postgres-1`, `eventsales-prod-pgbouncer-1`, `eventsales-prod-redis-1` running, with no data-service host-published ports shown.
- `eventsales-prod_eventsales_data` (internal), `eventsales-prod_eventsales_edge`, and `eventsales-prod_postgres_data` existing.
- D0's three proof containers stopped; its two networks and database volume retained.
- No EventSales app container observed, and no `4100` listener.
- Host Redis and WordPress host services observed separately; application and functional data-plane acceptance **not demonstrated**.
- The `vps_deploy_contract` GitHub required check reportedly enabled at its 2026-11-10 live readback, contradicting the older tracked runbook wording. Recheck current live governance before reliance; do not treat an enabled required check as a passing check.
- Existing EventSales PostgreSQL logical backup, encrypted off-host copy and disposable restore proof not established.

All of the above are **dated observations**, not a claim about the VPS's present condition. The accepted D0 closeout records healthy containers, while the later report says they were stopped. Reconcile that change with evidence explaining the transition and obtain owner review and acceptance of the current D0 baseline before functional eligibility or data-plane acceptance. Resolve any conflict with the approved D0 invariant through a separately reviewed owner authority decision; this draft does not supersede it. Missing or unexplained evidence blocks progression; this does not authorize a D0 action or revise the historical closeout. Current runtime identity, health, restart counts, database grants/roles, PgBouncer behavior, Redis ACLs, one-shot markers, host Redis and D0 preservation remain unverified for re-admission. PR #356 was reported open at that inspection; current PR/CI/ruleset state requires independent verification before any merge recommendation.

## 3. Explicit preservation rules

The following are protected and cannot be recreated, restarted, reset, deleted, detached, reconfigured or treated as disposable without a separately reviewed and expressly authorized transition:

- Production data plane `eventsales-prod`, its three containers, `eventsales-prod_postgres_data`, and its two approved networks.
- `eventsales-app` project identity, private data-network membership and approved edge/loopback ingress model.
- Existing secrets and root-owned staged artifact identities; never read or print secret values or password verifiers.
- Frozen D0 proof containers, networks and volume. **Do not start D0 merely to satisfy the first-installation runbook.**
- Existing host Redis, OpenLiteSpeed/CyberPanel and WordPress workloads.
- The `R1-RULING-01` node contract: `RELEASE_DISTRIBUTION=name`, node name `event_sales@EVENTSALES_NODE_IP`, DNS query `eventsales-app` only on `eventsales-prod_eventsales_data`, no edge-network alias. A future selected node IP must pass the approved collision audit and match the app's data-network `ipv4_address`.

Never run production data-volume removal or `docker compose down --volumes` as part of reconciliation. Do not interpret the existence of installed V3/V4/V5 wrappers as permission to replay them.

## 4. Re-admission lifecycle

This is a **reconciliation/evidence lifecycle**, separate from the original first-installation lifecycle. It does not rewrite recorded historical gate outcomes.

| State | Allowed transition | Guard | Side effects | Terminal or blocked condition |
| --- | --- | --- | --- | --- |
| `AUTHORITY_RECONCILIATION_REQUIRED` | → `EXISTING_UNVERIFIED` | Owner accepts this narrow addendum after exact authority review | Documentary decision only; no VPS action | `BLOCKED_AUTHORITY` if documents conflict or evidence is insufficient to identify scope |
| `EXISTING_UNVERIFIED` | → `CURRENT_STATE_OBSERVED` | Separate owner approval for bounded **read-only** host inventory; exact commands, credentials, evidence destination and redactions reviewed | Non-secret evidence capture only; no mutating commands or automatic repair | `BLOCKED_RECONCILIATION` on drift, unknown identity, missing evidence, secrets in output or any unexpected mutation |
| `CURRENT_STATE_OBSERVED` | → `FUNCTIONAL_PROOF_ELIGIBLE` | Owner reviews exact current state, historical proof records, evidence explaining the D0 transition and the accepted current D0 baseline, safe probes, one-shot markers, expected side effects and any independent acceptance requirements | Documentary eligibility decision only | `BLOCKED_PROOF_DESIGN` if D0 evidence is missing or the probe is unsafe, unclear, incompatible or would replay a consumed action |
| `FUNCTIONAL_PROOF_ELIGIBLE` | → `FUNCTIONAL_PROOF_RECORDED` | **New distinct** owner authorization for specifically listed functional proof operations using reviewed immutable bytes and bounded effects | Only approved test-object/key creation, if unavoidable; preserve artifacts | `BLOCKED_FUNCTIONAL_PROOF` at first failed check; no blind retry or cleanup |
| `FUNCTIONAL_PROOF_RECORDED` | → `DATA_PLANE_ACCEPTED` | Independent owner review accepts the complete current PostgreSQL, PgBouncer, Redis, network, security, health/restart and D0/host-Redis continuity evidence | Acceptance record only | `BLOCKED_ACCEPTANCE` if any material test or identity is missing, inconsistent or failed |
| `DATA_PLANE_ACCEPTED` | → V6 image review eligibility | V6's separate authority, source/digest and drift preconditions are independently satisfied | No automatic image approval, app staging, migration or public traffic | V6 remains blocked until specifically approved |

A failure state is terminal **for the relevant authorization**; further work requires a newly reviewed scope and authorization. Read-only inspection can be designed to be repeatable, but existing one-shot grants are not implicitly renewed. Once this ruling is independently reviewed and accepted by the owner, V6 prior acceptance may be established either by accepted original V5 evidence or by independently accepted existing-state re-admission evidence. The latter must satisfy every V5 functional proof requirement and the reconciled D0 baseline without rewriting a missing or failed historical V3, V4 or V5 verdict. V6 remains blocked until its prerequisites and separate authorization are satisfied.

## 5. Minimal evidence contract

The first authorized host action, if separately approved, should be a **bounded read-only inventory**, reusing an existing vetted read-only audit path where adequate. It must capture only the facts needed to determine the next transition:

1. Exact live container IDs, immutable image digests, Compose project/service labels, health status, restart counts, network memberships, volume identity, port publications and resource limits.
2. D0 identities and current state, evidence explaining the transition from the accepted healthy closeout to the later reported stopped state, and an owner-reviewed accepted current baseline for subsequent no-drift comparisons; host Redis and OpenLiteSpeed/WordPress continuity, in scope without accessing user data. Do not treat the reported stopped state as accepted without that decision.
3. Privilege and wrapper installed-byte identities, version/checksum metadata, consumed-operation marker **metadata** where safe and authorized, not protected credential contents.
4. Exact accepted Git source/tree and available accepted V3/V4/V5 evidence; current GitHub required-check status only through separately permitted read-only access.
5. Clear PASS/FAIL/UNKNOWN classification against the approved topology, with timestamps, redacted evidence references and STOP reasons.

Do not silently replace the canonical probes with custom ad hoc mutation. A fresh proof plan must say what it writes, what it cannot write, its maximum runtime/timeout, how it handles disconnects/container cleanup, and how failures leave evidence. The prior blocked lifecycle fixture report does **not** authorize executable proof or establish its safety; only resume that work if the approved proof design actually needs it.

## 6. Later requirements remain unchanged

- V6 immutable GHCR application image approval is a separate owner decision, followed by staging, separately authorized V7 migration, V8 bootstrap, final private runtime, V9 private proof, V10 loopback, V11 OpenLiteSpeed and V12 public acceptance.
- Before migration, separately assess database backup and schema/data reversibility. Before public acceptance, obtain a current PostgreSQL logical backup, encrypted off-host copy and disposable restore proof, plus monitoring/retention owner.
- Preserve runtime PgBouncer vs direct-migration PostgreSQL credential separation, transaction pooling, Redis namespace/ACLs, network isolation and DB final integrity authority.
- Current resource capacity, DNS/OLS behavior, LiveView WebSockets, and the accepted app image are not established by this document.

## 7. What this decision does **not** authorize

**NO production SSH, sudo, Docker, Compose, PostgreSQL, PgBouncer, Redis or OpenLiteSpeed operation. NO GitHub ruleset mutation. NO application migration, runtime start, ingress change, public cutover or rollback. NO merge based only on this draft.**

The next action is independent PR review of the exact diff, current CI and governing authority references, followed by owner acceptance of the exact ruling. Any current-state inspection requires its own separately reviewed scope and explicit authorization. No merge recommendation follows from this draft alone.

## 8. Immediate STOP conditions

`STOP=AUTHORITY_CONFLICT` for conflicting accepted decisions; `STOP=UNVERIFIED_SOURCE` for uncertain commit/tree; `STOP=PRODUCTION_DRIFT` for mismatch in exact protected identities; `STOP=SECRET_EXPOSURE` for credentials in evidence; `STOP=UNREVIEWED_PRIVILEGE` for any host or Docker action outside reviewed authority; `STOP=PROOF_SIDE_EFFECT_UNDEFINED` if proposed proof writes/cleanup are not bounded; and `STOP=BACKUP_GAP` before any migration whose recovery requirements are unmet. Preserve safe evidence and report one narrowly scoped next step, not new deployment machinery.

---

**Source basis:** `docs/deployment/vps-production.md` (runbook, including V0 and V3–V5); the externally supplied, untracked `vps-agentops-status-2026-11-10.md` (dated host/operator report); the D1 approval and `R1-RULING-01`; historical agent fixture result (blocked). No fresh VPS verification was performed in preparing this draft.
