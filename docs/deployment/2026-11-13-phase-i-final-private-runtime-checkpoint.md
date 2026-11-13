# EventSales — Phase H bootstrap and Phase I final private-runtime checkpoint

**Date:** 2026-11-13 (SAST, UTC+02:00)  
**Operational state at checkpoint:** `FINAL_PRIVATE_RUNNING` (owner-reported healthy/ready); **formal V9 `PRIVATE_ACCEPTED` not established**.  
**Scope:** Historical, documentation-only lock on the completed, narrow private-development H/V8 bootstrap and I final-runtime replacement. This checkpoint is **not** owner authorization for V9, D0 reactivation, public ingress, a VPS change, or production readmission.  
**Evidence provenance:** Owner-pasted root VPS script output in the interactive EventSales deployment session, supplemented by pinned repository source and the later **read-only D0 inventory**. No independent live host inspection or raw credential capture is claimed.  
**Source image:** `ghcr.io/jcschoeman96/eventsales@sha256:05fa2c451a366bab7f367685303e06984e4cf1a4603f02063e1810fac2f8ff0d`, application source `b647ad905d154b1ba4a82eda4fdacb5038564feb`.  
**Repository baseline:** `main` `6dd8ee2d038bebe42a15f5505dd7784943f80bbf`, merged PR #371. **Read alongside** the 2026-11-12 initial host evidence and 2026-11-13 temporary bootstrap-app checkpoint, not instead of them.

## 1. Exact completed transition — H/V8 initial bootstrap

Under a **separate, consumed, one-shot owner approval**, the existing healthy temporary bootstrap container invoked only `EventSales.Release.bootstrap()`. The protected transferred wrapper was verified by SHA-256 `2946e09666ae8d53946aca84ad818de4e7228ac150c7646ebf71cdd8c7b30636`. The reported terminal result was:

```text
SCRIPT_INTEGRITY=PASS
H_V8_CONTAINER_AND_RUNTIME=PASS
PRIVATE_HTTP_HEALTH_READY=PASS
FRESH_BOOTSTRAP_RECORDS=ABSENT
DATABASE_MIGRATIONS=52
H_V8_ONE_SHOT_PREFLIGHT=PASS
BOOTSTRAP_ONE_SHOT_AUTHORITY=CONSUMED
H_V8_BOOTSTRAP_INVOCATION=PASS
ADMIN_ROLE_ASSIGNMENT_SOURCE=VERIFIED
POST_BOOTSTRAP_HEALTH=PASS
DATA_CONTAINERS=UNCHANGED
HOST_PORTS=NONE
MIGRATIONS=UNCHANGED_52
H_V8_BOOTSTRAP=PASS
FINAL_PRIVATE_RUNTIME=NOT_STARTED
```

**Result:** One administrator identity, its global admin role and user-role assignment, and the configured active WooCommerce source were reported verified after bootstrap. No administrator email/name/password or source URL is recorded here. The implementation runs admin bootstrap then source bootstrap; a partial failure would not have been an atomic rollback, but this **invocation reported complete success**. The H authority is **consumed**; **never rerun `bootstrap()`, `migrate_and_bootstrap()`, or migration helpers** without an entirely new reviewed authorization.

## 2. Exact completed transition — Phase I final private runtime

Under another **separate, consumed, one-shot owner approval**, the Phase I wrapper was verified by SHA-256 `5e9d839bb870cc5efb0b1e927382cd1535a2f0e942c90ebeb69def5bdfe22b44`. It staged the pinned `deploy/vps/app/compose.yaml` contract, preserved evidence, removed **only the former temporary bootstrap container**, created the final Compose-managed app from the same pinned image and **runtime-only** environment, and reported:

```text
SCRIPT_INTEGRITY=PASS
PHASE_I_BOOTSTRAPPED_RUNTIME_PREFLIGHT=PASS
BOOTSTRAPPED_ADMIN_AND_SOURCE=VERIFIED
PINNED_PRIVATE_COMPOSE=STAGED_AND_VERIFIED
BOOTSTRAP_CONTAINER_EVIDENCE=PRESERVED
PHASE_I_ONE_SHOT_AUTHORITY=CONSUMED
BOOTSTRAP_CONTAINER=STOPPED
BOOTSTRAP_CONTAINER=REMOVED
FINAL_RUNTIME_CREATED_NO_BOOTSTRAP_ENV=PASS
FINAL_PRIVATE_PHOENIX=STARTED
FINAL_PRIVATE_RUNTIME=HEALTHY_READY
FINAL_RUNTIME_BOOTSTRAP_ENV=ABSENT
FINAL_RUNTIME_RESTART_POLICY=UNLESS_STOPPED
FINAL_PRIVATE_HOST_PORTS=NONE
DATABASE_MIGRATIONS=UNCHANGED_52
DATA_CONTAINERS=UNCHANGED
D0_PROOF_CONTAINERS=UNCHANGED
PHASE_I_FINAL_PRIVATE_RUNTIME=PASS
V9_PRIVATE_PROOF=NOT_RUN
PUBLIC_INGRESS=NOT_ENABLED
```

**Result and limits:** The reported final app uses the repository `eventsales-app` Compose project/service, has the `unless-stopped` restart policy, remains privately networked at `172.20.0.5` via `eventsales-prod_eventsales_data` (and joins the external edge network), and has **no host-published ports**. Docker environment inspection in the guarded wrapper verified **no `EVENTSALES_BOOTSTRAP_*` variables** in the final app. The protected bootstrap file and original evidence **may remain on the VPS**, outside the final app environment, and must not be printed or committed. Database migrations remain 52 and the three data-service containers and D0 proof containers were reported unchanged. No V9 proof, reverse-proxy, WordPress, firewall, DNS, public port or ingress transition was authorized or performed.

**Preservation boundary:** Keep `eventsales-prod-postgres-1`, `eventsales-prod-pgbouncer-1`, `eventsales-prod-redis-1`, the production PostgreSQL volume, both existing external networks, the final app and its runtime configuration, the historic D0 proof objects, host Redis, WordPress, OpenLiteSpeed and CyberPanel untouched. Earlier HBA Rule B migration access was removed and Rule A was preserved as documented by PR #371. No fresh HBA change or acceptance is implied by Phase I.

## 3. V9 blocker discovered after Phase I — do not work around on VPS

The follow-on **read-only** D0 prerequisite inventory reported:

```text
D0_OBJECT_COUNT=3_CONTAINERS_2_NETWORKS_1_VOLUME
D0_CURRENT_STATE=EXITED_0
V9_SMOKE=NOT_RUN
STOP=V9_D0_RUNNING_HEALTHY_REQUIREMENT_UNMET
```

This matches the previously reported historical D0 stopped state. The **pinned** `deploy/vps/app/scripts/probe-private.sh` `snapshot_d0()` implementation requires three `eventsales-d0-proof` containers to be **running, Docker healthy, and restart-free**, plus exactly two project networks and one project volume. Its current requirement is **incompatible** with the preserved stopped D0 state, so V9 is **blocked before execution**. Do not start D0 merely to pass the probe; do not weaken or edit the VPS copy of the proof script. The V9 proof also invokes `EventSales.Maintenance.PrivateRuntimeSmoke.run!()`, which performs bounded Oban inserts and Redis operations, so it is **not read-only** and must remain separately authorized. See [tracking issue #372](https://github.com/Carpe-Diem-Media/EventSales/issues/372).

**Formal governance remains open:** `D0_CURRENT_BASELINE=NOT_ACCEPTED`; `FUNCTIONAL_PROOF_ELIGIBLE=NO`; `DATA_PLANE_ACCEPTED=NO`; `V6_AUTHORIZED=NO`; state `EXISTING_UNVERIFIED`. The owner's expressly approved private-development exceptions explain why H and I ran; they did **not** satisfy the accepted production readmission lifecycle or turn app health/readiness into `PRIVATE_ACCEPTED`.

## 4. State/authority register and STOP policy

| Lifecycle | State | Transition guard and side effects |
| --- | --- | --- |
| Migration | `MIGRATED` (52) | No new migration or rollback without new authority |
| Temporary migrator HBA | `REMOVED_AND_RELOADED` | Preserve permanent PgBouncer access rule; no automatic restoration |
| Administrator + WooCommerce bootstrap | `BOOTSTRAPPED` | H/V8 authority consumed; resulting DB rows preserved |
| Temporary bootstrap container | `REMOVED_AFTER_EVIDENCE` | Do not recreate or reintroduce bootstrap credentials |
| Final private runtime | `FINAL_PRIVATE_RUNNING` | Phase I authority consumed; Compose-managed, reported healthy/ready, runtime-only env, no host ports |
| Historic D0 environment | `EXITED_0` / `BASELINE_NOT_ACCEPTED` | Preserve exactly three containers/two networks/one volume; no automatic startup |
| V9 private proof | `BLOCKED_D0_PREREQUISITE` / `NOT_RUN` | Reconcile documented D0 acceptance and probe contract; only separately authorize the write-bearing proof after guards pass |
| Formal private acceptance | `NOT_ACCEPTED` | Requires independent gate-specific proof, not application health alone |
| Loopback ingress, OpenLiteSpeed and public cutover | `NOT_AUTHORIZED` | No port publication or routing changes |

**Stop immediately** on image/Compose/credential/environment drift, any host-port publication, app/data/D0 unexpected restarts, D0 identity or history uncertainty, broken HBA/SQL path, an attempted bootstrap or migration rerun, an unauthorized V9 smoke write, or work that alters WordPress/host services. No blind retries, blanket Redis ACL grants, proof bypasses, environment secret output, or remedial container restarts. **Historical stdout and protected root-only files remain on the VPS; do not post raw Docker logs, URLs with credentials, `docker inspect .Config.Env`, database passwords, or admin PII to GitHub.**

## 5. Next smallest task — resolve issue #372 in the repository first

1. Preserve the installed VPS and final private runtime; this checkpoint itself changes **nothing**.
2. A coding agent should **read** the accepted D0 readmission owner-acceptance record, the exact pinned `probe-private.sh` and its tests, and the historical D0 evidence before proposing one **minimal repository-side fix or explicit no-code ruling**. Do **not** automatically convert `Exited(0)` into a passing V9 proof, and do not remove D0 continuity/security assertions.
3. If the correct resolution requires a code change, submit a narrow PR with tests and authority rationale; independently inspect its **exact diff, CI, and governing references** before any merge recommendation. A changed probe requires new on-host identity staging/verification and separate owner authorization; no unreviewed edits to VPS scripts.
4. The separate formal D0/data-plane readmission decision still must be resolved. Only after eligibility and a *new* one-shot write-bearing V9 authorization can the accepted private proof be run. Public ingress remains a different later decision.

**Documentation-only closeout:** This record preserves the H and I checkpoint, the exact V9 STOP and the next safe decision. It does not itself constitute deployment, code-change, proof, production acceptance or operational authority.
