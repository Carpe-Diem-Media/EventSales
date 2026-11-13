# EventSales — private development launch checkpoint: Phoenix ready, bootstrap pending

**Record date:** 2026-11-13 (SAST, UTC+02:00)  
**Checkpoint state:** **PRIVATE_BOOTSTRAP_APP_RUNNING / BOOTSTRAP_NOT_RUN**  
**Scope:** Historical recovery and operational handover for the first **private-development** EventSales installation on the existing VPS. This is **not** a production-acceptance certificate or permission to advance any deployment gate.  
**Evidence quality:** Owner-pasted, successful shell output from \`root@vpsserver\` during the interactive deployment; repository code/runbook checked separately. This document is a **reported host observation**, not an independently executed host inspection or acceptance probe.  
**Repository baseline:** \`Carpe-Diem-Media/EventSales\` \`main\` at \`9c52186113059ca370a3671338767c92a56063ca\` (merged documentation PR #370).  
**Preceding checkpoint:** [2026-11-12 private-launch evidence and access register](2026-11-12-eventsales-private-launch-evidence-and-auth-rules.md). The older record is historically correct **as of its date**; this checkpoint advances Rule B and application status without rewriting that earlier evidence.

## 1. Exact achieved boundary

The owner's **final reported** recovery operation returned:

\`\`\`text
SCRIPT_INTEGRITY=PASS
RECOVERY_EXECUTION=AUTHORIZED
RECOVERY_PREFLIGHT=PASS
FAILED_CONTAINER_EVIDENCE=PRESERVED
FAILED_CONTAINER=REMOVED
REPLACEMENT_CONTAINER=CREATED
REPLACEMENT_PREFLIGHT=PASS
PRIVATE_PHOENIX=STARTED
PRIVATE_HOST_PORTS=NONE
PRIVATE_PHOENIX=HEALTHY
PRIVATE_HTTP_HEALTH=PASS
PRIVATE_HTTP_READY=PASS
PRIVATE_DATA_IP=172.20.0.5
DATA_CONTAINERS=UNCHANGED
BOOTSTRAP=NOT_RUN
PRIVATE_BOOTSTRAP_APP=RUNNING
\`\`\`

This proves the **reported** temporary container passed a Docker healthcheck and private HTTP \`/health\` (\`ok\`) and \`/ready\` (\`ready\`) checks, with no published host ports and no observed data-container state change in the recovery script. It **does not prove** complete Redis ACL command coverage, BEAM/EPMD binding, DNS-cluster correctness, PubSub behavior, end-to-end functionality, WordPress integration, the accepted V9 private smoke test, or formal production readiness.

**Stop point:** Preserve the current healthy temporary bootstrap app. **Do not invoke \`EventSales.Release.bootstrap()\`, recreate the app again, apply ingress, run the accepted private probe, modify the data plane, or merge deployment authorities** without the next distinct owner authorization. The current container includes temporary bootstrap credentials.

## 2. Immutable artifact, identities and preserved resources

| Item | Reported identity / state |
| --- | --- |
| Application GHCR index | \`ghcr.io/jcschoeman96/eventsales@sha256:05fa2c451a366bab7f367685303e06984e4cf1a4603f02063e1810fac2f8ff0d\` |
| App build/source | \`b647ad905d154b1ba4a82eda4fdacb5038564feb\`; GitHub Actions run \`42014330401\` |
| Private bootstrap container | \`eventsales-private-bootstrap-20261113\`, **running**, reported healthy/ready, zero restart changes |
| Data network | \`eventsales-prod_eventsales_data\`, internal, \`172.20.0.0/16\`, gateway \`.1\`; app fixed IPv4 \`172.20.0.5\` |
| Edge network | \`eventsales-prod_eventsales_edge\`, \`172.21.0.0/16\`; private HTTP probe via edge-network IP; no host-published port |
| Clustering alias | \`eventsales-app\` only on data network; not on edge network |
| PostgreSQL | \`eventsales-prod-postgres-1\` at \`172.20.0.2\`; preserved/healthy |
| PgBouncer | \`eventsales-prod-pgbouncer-1\` at \`172.20.0.3\`; preserved/healthy |
| Redis | \`eventsales-prod-redis-1\` at \`172.20.0.4\`; preserved/healthy |
| Persistent data | \`eventsales-prod_postgres_data\` preserved; 52 application migrations recorded in \`event_sales_prod\` |
| Other host assets | WordPress, CyberPanel, OpenLiteSpeed, host Redis and D0 **outside authorized operation scope**; no fresh independent proof of their complete continuity in this checkpoint |

The temporary bootstrap app was created with **direct Docker commands**, not the repository \`eventsales-app\` Compose project. It is a narrow private-development installation, not an assertion that repository Compose/V8/V9 acceptance was completed. Future formal private-runtime proof must use the reviewed deployment/probe identities, not assume this temporary container satisfies them.

## 3. How we reached this checkpoint

### 3.1 Database access and initial schema

1. The production data network and three data services already existed; read-only inspection found \`event_sales_prod\` initially empty, without \`public.schema_migrations\`.
2. Persistent PgBouncer backend HBA Rule A was added and authenticated SQL through the runtime path was proven:
   \`\`\`text
   host event_sales_prod eventsales_runtime 172.20.0.3/32 scram-sha-256
   \`\`\`
3. Separately authorized temporary migrator HBA Rule B granted only \`eventsales_migrator\` from \`172.20.0.10/32\`. A one-shot direct client authenticated at that source IP. The immutable application image was separately downloaded and verified.
4. Protected migration-only environment was created at \`/root/eventsales-private-migration-20261113/migration.env\`; the release migration used \`DIRECT_DATABASE_URL\` as the migrator, without starting Phoenix. One preflight initially stopped incorrectly because PostgreSQL \`boolean::text\` returned \`true\`, whereas the script expected \`t\`. Read-only SQL showed \`PUBLIC_TABLE_COUNT=0\`, \`SCHEMA_MIGRATIONS=ABSENT\`, \`BOOLEAN_TEXT=true\`.
5. Corrected, owner-approved \`EventSales.Release.migrate()\` then returned \`MIGRATION_EXECUTION=PASS\`, \`MIGRATIONS_APPLIED=52\`, \`LAST_MIGRATION=20261007045634\`, \`DATA_CONTAINERS=UNCHANGED\`, \`BOOTSTRAP=NOT_RUN\`. The one-shot migration container and protected output log were preserved.
6. Under a **separate** owner approval, temporary Rule B was removed from \`pg_hba.conf\` using an exact protected-backup comparison. PostgreSQL subsequently reported \`HBA_POSTREMOVAL_VALIDATION=PASS\`, \`MIGRATOR_HBA_RULE=REMOVED\`, \`PGBOUNCER_HBA_RULE=PRESERVED\`, \`POSTGRES_RELOAD_SIGNAL=ACCEPTED\`, no restart, and 52 recorded migrations. The final parsed configuration has seven rules. A separate post-removal live connection-denial test was **not** performed.

### 3.2 Protected application staging and failure/recovery

1. Root-owned protected files were staged in \`/root/eventsales-private-app-20261113/\`: \`runtime.env\` (19 entries, mode \`0400\`), \`bootstrap.env\` (6 entries, mode \`0400\`); directory mode \`0700\`. The runtime file contains **no** \`DIRECT_DATABASE_URL\` or \`EVENTSALES_BOOTSTRAP_*\` keys. The bootstrap file contains temporary admin/source-system values. Neither file's contents belong in Git.
2. Earlier staging attempts stopped safely: \`/dev/tty\` mistakenly opened in Python \`r+\` mode (not seekable); the local password allowlist rejected \`&\` although the password otherwise met strength requirements. Final staging passed. **Previously shared sample passwords must not be reused**; do not record any password or administrator identity here.
3. The first temporary Docker container was created privately. A pre-start guard incorrectly required an **assigned** IP before startup; Docker had the requested IP in \`NetworkSettings.Networks[DATA].IPAMConfig.IPv4Address\` but no assigned IP until started.
4. A second guard rejected an identical duplicate \`POOL_SIZE=20\` in the created container environment. A names-only diagnostic proved one identical duplicate, with no malformed variables. The subsequent guarded start passed private-network checks but the app exited with code \`1\` and zero restarts.
5. Classified and names-only logs isolated four \`Redix.Error\` exception occurrences and repeated Redis \`NOPERM\` on **\`SELECT\`**. Redix had attempted \`SELECT 0\` because the runtime Redis URL specified \`/0\`; the least-privilege Redis ACL intentionally did not permit \`SELECT\`. **No Redis ACL expansion was made.**
6. With owner approval, \`runtime.env\` was changed **only** by dropping the trailing \`/0\` from \`REDIS_URL\`; Redis continues to use default database 0. The original bytes were preserved at \`runtime.env.before-redis-select-fix-20261113\` (root-only). All other runtime variables and credentials were reported unchanged.
7. The initial recovery script stopped before mutation at a **case-sensitive** log-evidence check (\`b"SELECT"\`), despite a prior case-insensitive diagnostic proving \`NOPERM\`/SELECT. A subsequent read-only check confirmed \`SELECT_PRESENT=True\` and \`SELECT_EXACT_UPPERCASE=False\`; this was a guard false negative, not another Redis failure.
8. The revised recovery script was transferred from Kubuntu to the VPS using SCP. The owner checked root ownership, mode \`0600\`, Python syntax and SHA-256 integrity (\`2f4a12114bd67617bcda2d8d37c470e8b0a188e5eeda6be00c0bd7601c40bf50\`), then executed the already-approved scoped replacement **once**.
9. The recovery preserved the original failed container's evidence, removed only that exited temporary container, recreated it under the same name and immutable image with the corrected runtime file and existing bootstrap values, then started it once. The final checks returned healthy Phoenix, private HTTP health/readiness PASS, app data IP \`172.20.0.5\`, no host ports, preserved data containers, and \`BOOTSTRAP=NOT_RUN\`.

**Recovery evidence paths (protected, not for source control):**
- \`/root/eventsales-private-app-20261113/failed-phoenix-redis-select-20261113.log\`
- \`/root/eventsales-private-app-20261113/failed-phoenix-redis-select-20261113.json\`
- \`/root/eventsales-private-app-20261113/runtime.env.before-redis-select-fix-20261113\`
- \`/root/private_recovery_verified.py\` (reviewed transfer/execution artifact)
- \`/root/eventsales-private-migration-20261113/migration-20261113.log\`

The original failed container no longer exists; its protected evidence was reported preserved. Raw Docker logs or inspect/environment output must **not** be copied into this repository.

## 4. Lifecycle and authority ledger

| Domain lifecycle | State at this checkpoint | Guard / next authorized action |
| --- | --- | --- |
| SchemaMigration | \`MIGRATED\` — 52 recorded | No rerun, rollback or further schema writes under past authority |
| TemporaryHBA | \`REMOVED_AND_RELOADED\` | Preserve Rule A; no broad host rule or new migrator grant |
| ProtectedConfig | \`RUNTIME_AND_BOOTSTRAP_STAGED\` | Root-only; maintain bootstrap/runtime separation |
| BootstrapRuntime | \`RUNNING_HEALTHY_READY\` (temporary) | Only the scoped temporary container, no host-published port; preserve identity |
| AdminBootstrap | \`NOT_STARTED\` | Separate explicit H/V8 one-shot \`EventSales.Release.bootstrap()\` authorization |
| SourceSystemBootstrap | \`NOT_STARTED\` | Same one-shot operation; no automatic independent source creation |
| FinalPrivateRuntime | \`NOT_STARTED\` | After successful bootstrap, separately authorize replacement **without** bootstrap credentials |
| PrivateProof | \`NOT_ACCEPTED\` | Final-runtime state and separate reviewed V9 private probe required |
| LoopbackIngress / OLS / PublicCutover | \`NOT_AUTHORIZED\` | No host port, reverse-proxy, DNS, firewall, WordPress or OLS changes |
| Existing-state readmission | \`EXISTING_UNVERIFIED\` | Formal D0/data-plane acceptance remains outstanding |

Historical formal flags remain **\`D0_CURRENT_BASELINE=NOT_ACCEPTED\`**, **\`DATA_PLANE_ACCEPTED=NO\`**, **\`V6_AUTHORIZED=NO\`**, and **\`FUNCTIONAL_PROOF_ELIGIBLE=NO\`** under the accepted readmission route. The owner's per-operation **private-development exception** permitted the observed operations; it **does not change** these formal production-gate states or imply a completed production acceptance sequence.

### Temporary bootstrap credential handling

The current temporary container includes \`EVENTSALES_BOOTSTRAP_*\` values; privileged Docker access can expose these through container metadata. **Do not paste \`docker inspect .Config.Env\`, \`runtime.env\`, \`bootstrap.env\`, connection URLs, tokens, cookies, raw logs, user email or password.** Following a separately authorized and verified bootstrap, replace this container with a runtime-only container under a separate owner authorization; do not merely edit the host file and assume Docker updated existing environment values. The current configuration's \`PHX_HOST=localhost\` is a private-development placeholder, not the later public hostname.

## 5. Next smallest approved path (not authorized by this document)

1. **Checkpoint this record via a docs-only PR**; independently inspect the exact PR diff, CI and governing authority references before recommending merge. Do not edit prior checkpoint history or app code. A checkpoint merge is **not** permission to run bootstrap.
2. Obtain **separate owner approval** for one-shot \`EventSales.Release.bootstrap()\`. Before execution, read-only verify the temporary container is still healthy and ready, correct digest, no host ports, zero restarts, expected bootstrap keys and runtime-only database path through PgBouncer. Bootstrap will create/ensure the admin role/user assignment and active WooCommerce source record; it is a **database-writing operation**. On error, preserve evidence and do not blindly retry.
3. Obtain another approval to **replace the temporary container** with a private runtime-only configuration that excludes all \`EVENTSALES_BOOTSTRAP_*\` values. Use the reviewed deployment identity and image. Do not publish host ports.
4. Separately authorize the accepted \`deploy/vps/app/scripts/probe-private.sh\` proof with its reviewed wrapper, D0/host Redis baseline and bounded smoke side effects. Only success can justify considering the formal \`PRIVATE_ACCEPTED\` state; the current health/ready result does not.
5. Keep loopback ingress, OpenLiteSpeed integration and public cutover as **later distinct authorization gates**.

### Mandatory STOP / preservation rules

**STOP** on any unexplained app/data/D0 restart, identity or image drift, changed network/IP/alias, published host port, secret disclosure, unexpected HBA change, migration/catalog drift, denied database/Redis operation, failed readiness, or unexpected bootstrap data. Preserve the original evidence and currently running temporary container; **no automatic retry, removal, secret rotation, restoration, re-migration, bootstrap or public exposure**. The next operator must report the exact STOP code and seek a scoped decision rather than running an all-in-one repair script.

## 6. Repository authority and implementation references

- [Private VPS runbook](vps-production.md) — G temporary start, H explicit bootstrap, I final-runtime replacement and J/V9 private proof.
- [Prior 2026-11-12 evidence checkpoint](2026-11-12-eventsales-private-launch-evidence-and-auth-rules.md) — earlier, dated host state and PgBouncer/migrator access history.
- \`docs/superpowers/specs/2026-11-12-d1-existing-data-plane-readmission-owner-acceptance.md\` — formal existing-state acceptance limitations.
- \`deploy/vps/app/compose.yaml\`, \`deploy/vps/app/README.md\`, \`deploy/vps/app/scripts/probe-private.sh\` — private deployment and proof contracts.
- \`config/runtime.exs\`, \`rel/env.sh.eex\`, \`lib/event_sales/application.ex\`, \`lib/event_sales/release.ex\` — runtime configuration, node identity and release actions.
- \`deploy/vps/data-plane/templates/redis-users.acl.template\` — least-privilege runtime Redis ACL without \`SELECT\`.
- \`lib/event_sales/maintenance/admin_bootstrap.ex\` and \`lib/event_sales/maintenance/source_system_bootstrap.ex\` — separately gated bootstrap writes.

**Document-only closeout:** This file is a historical checkpoint and operator handover. It performs **no VPS action** and grants **no new deployment authorization**.
