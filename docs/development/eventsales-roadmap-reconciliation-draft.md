# EventSales roadmap reconciliation draft

- Review gate: `EVENTSALES_ROADMAP_RECONCILIATION_FINAL_REVIEW_REQUIRED`
- Checked: 2026-11-09
- Pinned main: `45afd6f2557f396f9cb0bf42cf0741b45a0a1149`

This draft reconciles the Path 1 roadmap, M5-05D4 topology gates, D1 pooling records, current GitHub main, and Linear issue JC-361. It records evidence and proposed next actions.

## Snapshot and authority

GitHub `main`, local `main`, and `origin/main` resolve to the pinned SHA. Its tree is `fb42121fc8ed42cfd07b633b30739c310784ede2`, equal to the first-parent tree of PR #362. PR #363 merged as the pinned commit and restored the tree that preceded PR #362.

The repository identifies [path-1-phase-breakdown.md](../path-1/path-1-phase-breakdown.md) as the canonical Path 1 execution roadmap. Its version is v31, and it claims authority over Path 1 sequencing. The [current-state-and-path-handoff.md](../roadmap/current-state-and-path-handoff.md) sets program priority and Path 2 resumption. It is version v30. Both were last updated on 2026-10-10. Their latest explicit status blocks agree that D4 is next and authorized but not started. The handoff also retains older embedded snapshots that still say `NEXT: M5-05D1`.

## Current facts

### Path 1 and M5-05D4

The two Path 1 documents say M5-05D4, `C_TOPOLOGY_ATTRIBUTION_REPLAY`, is authorized and has not started. They name it as the next Path 1 task. They also record the actual production runtime route, PgBouncer mode, and database connection budget as unverified. M5-05D5, M5-05E, M5-05F, and M5-05G remain blocked or unauthorized. Path 2 remains paused. See the roadmap status block in [path-1-phase-breakdown.md](../path-1/path-1-phase-breakdown.md), lines 230 to 243 and 1543 to 1549, and the handoff, lines 136 to 171.

The phase roadmap's line 243 says D4 execution follows PR #317 admission. Its v31 revision log records that PR #317 merged, and the same roadmap marks D4 authorized. Treat that dependency as satisfied. The handoff's older snapshots at lines 855 to 856 and 1173 to 1174 still say `NEXT: M5-05D1`; its current blocks at lines 136 to 171 and 271 to 279 point to D4. Treat the M5-05D1 text as stale embedded state, not the current next task.

The [M5-05D4 experiment plan](m5-05-topology-attribution-experiment.plan.md) requires sanitized, authoritative evidence for the runtime route, node count, application Ecto pool size, PgBouncer presence and mode, backend connection budget, and a representative isolated non-production route. It permits `DIRECT_POSTGRES` and `PGBOUNCER_SESSION`; `PGBOUNCER_TRANSACTION` is outside the current experiment plan and requires a separately approved architecture decision and a reviewed D4 plan amendment before that topology is admitted. D1's approved future transaction-pooling target does not establish the deployed route or, by itself, bar D4. If the verified relevant route is direct PostgreSQL or session pooling, a representative experiment may proceed under the current plan after its other gates pass; a direct-PostgreSQL result does not certify the future transaction-pooling architecture. An unknown route is an unresolved admission guard during planning. Keep D4 at `AUTHORIZED_NOT_STARTED` until a bounded topology preflight is initiated; use `INSUFFICIENT_EVIDENCE` only if that preflight cannot establish a required fact. The plan prohibits production PgBouncer admin access and production measurement.

The plan also defers its canonical command until runtime Repo pool behavior is proven. It requires a representative runtime pool, prohibits using SQL Sandbox as canonical evidence, and specifies one canonical run only after the topology, harness, and workload gates pass. Its recorded `BASE_SHA` is `84cf6af8bca1c5af2a99ddad8c570bf14870bf4d`. Current main is newer and includes later event-refresh-fence commits `725fb884` and `a29bfbe`. Any future runner needs an exact current source SHA before its artifact and command are frozen.

### D1 pooling authority and evidence

The current [database topology](../architecture/db-topology.md), [Oban and PgBouncer decision](../architecture/oban-pgbouncer.md), and [PgBouncer strategy](../deployment/pgbouncer.md) all name PgBouncer transaction pooling as the approved D1 production target. They place normal runtime traffic on `DATABASE_URL` and migrations on direct PostgreSQL through `DIRECT_DATABASE_URL`. These documents say the target has not been deployed or certified in production.

The [D1 certification](../evidence/m5-05-deterministic-sales-velocity-certification.md) reports a local measurement with a TEST pool size of 10. For dense 60-minute C50, the recorded p99 values are 183,787 microseconds end to end, 37,531 microseconds for the Repo query, and 146,488 microseconds for pool checkout. The end-to-end gate failed. The same record says `PGBOUNCER_TRANSACTION_MODE_CERTIFIED=NO` and that the local result does not prove a pool-size change or PgBouncer would fix it. These measurements do not verify the production route or resolve the D4 gate.

### JC-361 and current main

Linear [JC-361](https://linear.app/jc-dev/issue/JC-361/eventsales-audit-ash-functions-v6v7-baseline-drift-and-false-green) is `Done`, assigned to JC Schoeman, and was last updated at `2026-11-06T05:31:27.440Z`. Its description still pins main to `b647ad905d154b1ba4a82eda4fdacb5038564feb` and retains the superseded `ASH_EXTENSION_BASELINE_ANALYSIS_REVIEW_REQUIRED` stop. The completed investigation establishes `BASELINE_DRIFT_CONFIRMED`: AshPostgres 2.15.2 expects Ash functions version 7, while the repository snapshot records version 6; disposable PostgreSQL 18 proof confirmed the v6/v7 behavioral difference. The locally generated version-7 migration and extension snapshot at `1fa1590` passed independent static review. Preserve this evidence and replace the stale issue text with the remaining implementation gates; do not repeat the baseline investigation.

Current main still records `ash_functions_version: 6` in `priv/resource_snapshots/repo/extensions.json`. The current [CI workflow](../../.github/workflows/ci.yml), lines 158 to 159 and 225 to 226, still uses false-green `mix ash.codegen --dry-run` checks followed by `git diff --exit-code` for generated files. PR #362's temporary proof job is absent from current main.

GitHub confirms [PR #362](https://github.com/JCSchoeman96/EventSales/pull/362) merged at `746a8d376f0bbdb2e36561ef5f06d8206b1d1799` and [PR #363](https://github.com/JCSchoeman96/EventSales/pull/363) merged at the pinned main SHA. PR #363 removed the proof job and `scripts/ci/ash_functions_v6_v7_proof.sh`. The latest Linear comment predates that merge and says PR #363 is still open. That comment is historical; GitHub is the current source for the PR state.

The local commit `1fa1590b1b90b9fbee23a8730bb5518ca77ffff5`, whose parent is the old `b647ad...` main, contains the independently reviewed but unmerged migration and version-7 extension snapshot. Its proposed migration has an unqualified `CREATE OR REPLACE FUNCTION ash_required(...)` and an empty `down/0`. The prepared JC-361 migration was not executed during local preparation or the disposable proof. The actual target database function and migration state remain unverified. Before a future draft PR, bring this commit onto the then-current `main` and review the resulting two-file diff against that exact base. Remaining JC-361 gates are a separate migration PR, isolated application and migration validation, forward-only recovery design, target database preflight, and later `mix ash.codegen --check` enforcement. A separate disposable CI proof ran under PR #362; it did not apply the migration. Neither file is part of the pinned main tree.

PR #363 also exposed an unrelated ETS test-fixture lifecycle defect. Its first CI attempt failed in `test/event_sales/analytics/event_snapshot_refresh_concurrency_test.exs:40` when `DashboardCache.put_event_summary` returned `{:error, :unavailable}` before the transaction-fence assertions; a retry passed 8/8. The named ETS table is owned by `HotStateAggregator`, and related tests can delete it without restoring it. The exact preceding deleter was not established. Track a separate test-only fixture/lifecycle correction; do not fold it into JC-361 migration work or D4.

Read-only Linear searches in the JC-Dev team returned no issue title matching `M5-05D4` or `C_TOPOLOGY_ATTRIBUTION_REPLAY`. No D4 Linear status correction is recommended from the available records.

## Historical facts

- Path 1 roadmap v31 and the program handoff v30 were last updated on 2026-10-10. Their M5-05D4 status is `AUTHORIZED_NOT_STARTED`; they are planning records, not proof that topology was verified.
- D1 measured a local workload on 2026-10-09. Its checkout result is local historical evidence, not production capacity evidence.
- PR #362 added only a disposable Ash-function proof job and its script. PR #363 later removed both. The pinned tree matches the tree before PR #362.
- Linear's most recent JC-361 note was written before PR #363 merged. Its PR state and main SHA are stale; the baseline investigation described above is now complete, while implementation gates remain.
- The version-7 migration and snapshot at local commit `1fa1590` were prepared outside main. Their two-file contents passed static review, but the commit must be brought onto then-current `main` before any future draft PR. The migration was not executed during local preparation or the disposable proof; the target database state remains unverified.
- PR #363's first CI attempt exposed the ETS test-fixture lifecycle failure described above; the retry passed, but that does not resolve the separate test-only follow-up.

## Conflicting authorities and required handling

| Conflict | Evidence | Required handling |
| --- | --- | --- |
| D1 target versus D4 topology admission | D1 architecture documents approve transaction pooling as a future target. D4 currently permits direct PostgreSQL and session pooling. The deployed route is unverified. | `UNRESOLVED ADMISSION GUARD`. Verify the relevant route. Direct PostgreSQL or session pooling may be admitted under the existing plan once other gates pass. If the route uses transaction pooling, obtain a separately approved architecture decision and a reviewed D4 plan amendment before admitting that topology. Do not treat the planning conflict alone as `INSUFFICIENT_EVIDENCE`. |
| Duplicated Path 1 roadmap snapshots | The phase roadmap still makes D4 conditional on PR #317 merging, although its v31 history records that merge. Older handoff snippets still say `NEXT: M5-05D1`, while its current status blocks say D4. | Use the latest v31/v30 status blocks: D4 is the next task, authorized but not started. Treat the old condition as satisfied and the M5-05D1 snippets as stale. Flag them for later documentation cleanup. |
| JC-361 status and pinned baseline | Linear says `Done` and pins `b647ad...`; current main is `45afd6...`. The issue's completed investigation establishes `BASELINE_DRIFT_CONFIRMED`, but implementation gates remain. | Preserve the accepted v6/v7 investigation evidence. If implementation remains unauthorized, recommend `Done` → `Backlog`; refresh the issue's main SHA and PR state, and list the separate remaining gates. Do not repeat the baseline investigation or treat the proof PR merge as completion of migration or CI enforcement. |
| Last Linear comment versus GitHub PR state | The last JC-361 comment says PR #363 is open. GitHub shows it merged as current main. | Use the pinned GitHub main and PR records for current state. Preserve the comment as dated history. |
| D1 target versus production fact | Architecture documents approve transaction pooling but state it has not been deployed or certified. The Path 1 documents say the actual runtime route is unverified. | This is not evidence that production uses transaction pooling. Keep target and deployed state as separate fields. |

## Recommended next-action register

| Order | Action | Gate and stop condition |
| --- | --- | --- |
| 1 | Resolve the D4 admission guard by verifying the relevant runtime route from authoritative sanitized evidence. Keep M5-05D4 at `AUTHORIZED_NOT_STARTED` during planning. | A direct-PostgreSQL or session-pooling route can be admitted under the existing plan once all other gates pass. A transaction-pooling route requires a separately approved architecture decision and a reviewed D4 plan amendment first. The D1 future target alone does not decide the deployed route. |
| 2 | When a bounded topology preflight is initiated, record `TOPOLOGY_VERIFICATION` and establish route, node count, Ecto pool, PgBouncer presence and mode, backend budget, and a representative isolated non-production route. | Record `INSUFFICIENT_EVIDENCE` only if this preflight cannot establish a required fact. Do not use production admin access, production load, shared DEV/TEST databases, or secret-bearing output. No canonical measurement is part of resolving the current admission decision. |
| 3 | Before any later D4 harness admission, pin the source under test to the then-current main SHA and prove the explicit runtime Repo pool independently of SQL Sandbox. Freeze the runner and command only after that proof. | The experiment plan limits work to a diagnostic and one canonical run. It authorizes no pool tuning, PgBouncer changes, SQL/index changes, cache work, or remediation. |
| 4 | Preserve JC-361's completed investigation as `BASELINE_DRIFT_CONFIRMED`. If implementation remains unauthorized, recommend moving the issue from `Done` to `Backlog`; refresh its main SHA to `45afd6f2557f396f9cb0bf42cf0741b45a0a1149` and record that #362 and #363 both merged. | Remaining gates are the separate migration PR, isolated application/migration validation, forward-only recovery design, target database preflight, and later `mix ash.codegen --check` enforcement. This reconciliation ran none of them and authorizes no migration or CI change. |
| 5 | Track the ETS test-fixture lifecycle correction as a separate test-only task. | Keep it outside JC-361 migration work and D4. No tracker mutation or implementation is authorized by this reconciliation. |
| 6 | Before any future draft migration PR, bring local commit `1fa1590b1b90b9fbee23a8730bb5518ca77ffff5` onto the then-current `main` and review the resulting two-file diff against that base. Keep migration PR, isolated validation, recovery design, target database preflight, and later CI enforcement as distinct gates. | The existing static review does not make the old-parent commit current. Do not apply the migration or edit CI under this reconciliation. |

## Recommended status corrections

- **JC-361:** record `BASELINE_DRIFT_CONFIRMED` and retain the completed AshPostgres 2.15.2 / version-6 snapshot investigation and PostgreSQL 18 proof. `Done` → `Backlog` is a reasonable recommendation while implementation remains unauthorized. The separate migration PR, isolated application/migration validation, forward-only recovery design, target database preflight, and later `mix ash.codegen --check` enforcement remain open. Do not repeat the completed investigation.
- **M5-05D4:** keep `AUTHORIZED_NOT_STARTED` while topology admission is unresolved in planning. Once a bounded preflight starts, use `TOPOLOGY_VERIFICATION`; use terminal `INSUFFICIENT_EVIDENCE` only if that preflight cannot establish a required fact. Direct PostgreSQL or session pooling may proceed under the current plan after all other gates; transaction pooling requires a separately approved architecture decision and a reviewed D4 plan amendment before admission. Do not mark D4 complete.
- **M5-05D5 and M5-05E/F/G:** leave their recorded blocked or unauthorized statuses unchanged. No matching D4 Linear issue was found, so this draft does not invent or create one.
- **JC-357:** leave it Done. JC-361 records it as a separate completed issue with a `relatedTo` relation.
- **ETS test fixture:** create or assign a separate test-only correction task for the confirmed ETS table lifecycle defect. Keep it out of JC-361 migration and D4 scope.

## Review stop

`STOP=EVENTSALES_ROADMAP_RECONCILIATION_FINAL_REVIEW_REQUIRED`

This draft is the requested handoff. It must be reviewed before anyone changes roadmap authority, Linear status, CI, source code, migrations, deployment configuration, or experiment admission.
