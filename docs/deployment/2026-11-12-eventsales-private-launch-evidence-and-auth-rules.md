# EventSales — VPS private-launch evidence and PostgreSQL access register

**Record date:** 2026-11-12 (SAST)<br>
**Purpose:** Preserve the exact findings and authorized changes from the owner's interactive VPS inspection; support the *first private development deployment* without disturbing existing WordPress/CyberPanel/OpenLiteSpeed services or D0.<br>
**Evidence provenance:** Owner-pasted terminal output from `root@vpsserver` and `jc-kubuntu` in the EventSales conversation; GitHub repository sources inspected separately. **This is a reported host observation, not a direct, independently captured host audit or formal data-plane acceptance.**<br>
**Repository baseline:** `Carpe-Diem-Media/EventSales`, `main` at `c7d496e0987421381768040ed0dc719ad0ae7589` (PR #369 merge).<br>
**Repository destination (proposed):** `docs/deployment/2026-11-12-eventsales-private-launch-evidence-and-auth-rules.md`.

## 1. Scope and locked preservation boundaries

- **Launch objective:** Run the Phoenix `event_sales` release privately on the existing VPS, complete initial migrations and bootstrap via separately authorized operations, and verify internal readiness. **No host-published application port, OpenLiteSpeed routing, CyberPanel changes, or public cutover in this milestone.**
- **Preserve:** Existing WordPress services/data/routing, OpenLiteSpeed, CyberPanel, host Redis, all three `eventsales-prod` data containers, both production Docker networks, `eventsales-prod_postgres_data`, and frozen `eventsales-d0-proof` containers/networks/volume/credentials/evidence.
- **Forbidden without a new, exact authorization:** `docker compose down --volumes`, production volume reset, re-provision of existing production objects, secret rotation, service restart, firewall or ingress changes, application start, schema migration, and cleanup. No automated fix-on-failure.
- **Development data decision:** The owner reports EventSales has never been used and its application data is disposable for the private-development launch; current schema inspection found no user tables. A full off-host EventSales database backup and restore drill is not being made a precondition for *private development*. This **does not waive** the accepted runbook's separate pre-migration backup/reversibility decision or its public-production recovery requirements. Never infer WordPress data is disposable.

## 2. Verified observations (reported host output)

| Area | Observed result | What this does **not** prove |
| --- | --- | --- |
| Host | Ubuntu 22.04.5 LTS; Docker server API `1.56`, minimum supported `1.40` | Host configuration and patch state are fully accepted |
| Capacity | ~46 GiB RAM total, ~32 GiB available; ~839 GB disk free; ~2 GiB swap, minimally used | Reserved capacity under actual app workload |
| Production containers | `eventsales-prod-postgres-1`, `eventsales-prod-pgbouncer-1`, `eventsales-prod-redis-1`: `running`, Docker `healthy`, **0 restarts** each | Functional data-plane acceptance or full SQL/Redis permission proofs |
| Pinned images | PostgreSQL `sha256:d33bd884995daddfb515d0ce9aec23b74d20d72e03ca42b72c4abf617c76bb19`; PgBouncer `sha256:965b0223f1096666471e11595f4f6dc5d32dfacbc688418b8ae2385946c41e3b`; Redis `sha256:953ca2c2ab4ff7a93f8abac31339ba4d913ec0914861453ab4faa29d154115a0` | Data integrity and operational backup readiness |
| Production data network | `eventsales-prod_eventsales_data` internal bridge, `172.20.0.0/16`, gateway `.1`; PG `.2`, PgBouncer `.3`, Redis `.4` | Permanent/reserved addressing after future recreate |
| Production edge network | `eventsales-prod_eventsales_edge` bridge, `172.21.0.0/16`, empty at inspection | Future edge IP selection or Internet reachability |
| Other Docker networks | Bridge `172.17.0.0/16`; D0 networks `172.18.0.0/16`, `172.19.0.0/16`; no overlap in listed Docker subnet allocations | External/VPN/CNI/routing/IPAM reservation conflicts everywhere |
| D0 | Three proof containers `Exited (0)`; no restart/change performed during inspection | Historical stopped-state authorization or accepted D0 baseline |
| Production volume | `eventsales-prod_postgres_data` exists, driver `local` | Independent volume identity, recoverability, or backup |
| Application | No `eventsales-app` Compose container; no locally downloaded application image; no TCP listener on host port `4100` in reported `ss` output | Port availability at later launch time |
| App image | GHCR index `ghcr.io/jcschoeman96/eventsales@sha256:05fa2c451a366bab7f367685303e06984e4cf1a4603f02063e1810fac2f8ff0d` resolves with `linux/amd64` manifest `sha256:606dda08fb2759c8af5541f55c6187f18e0a46379068e20428f31bcb6d65834b` | Image approved by V6 or already downloaded to VPS |
| Build provenance | GitHub Actions image run `42014330401` successful on source commit `b647ad905d154b1ba4a82eda4fdacb5038564feb`; artifact identified. Comparison to reviewed `main` showed only deployment audit/CI/docs changes since source (not application build inputs). | Deployment authorization or a complete supply-chain acceptance decision |
| Database catalog | `event_sales_prod` exists; owned by `eventsales_migrator`; roles `eventsales_migrator`, `eventsales_runtime`, `eventsales_backup` exist; **0 application tables** and no `public.schema_migrations` | Database is safe to destroy, or migration will succeed |
| PostgreSQL credentials | Migrator/runtime login enabled, password verifier present with SCRAM-SHA-256 format; `password_encryption=scram-sha-256`; `ssl=off` | All password paths work from every source |
| Protected files | Seven checked files exist with expected owner/group/mode/size; raw user/password values were not pasted (details below) | Every credential and file on the host is verified |
| PgBouncer runtime | After approved HBA correction, authenticated `SELECT current_user, current_database()` through PgBouncer returned `eventsales_runtime\|event_sales_prod` | DML, DDL denial, connection pooling, concurrency and transaction proof |
| Redis runtime | Existing raw credential SHA-256 matches on-disk ACL verifier; authenticated `AUTH eventsales_runtime PASSWORD` returned **`OK`** using stdin | Authenticated PING, key ACLs, TTLs, command families, or live ACL durability under restart |
| Proposed node IP | Host route for `172.20.0.10` points to production data bridge; current observed members occupy `.2`, `.3`, `.4` | `172.20.0.10` has been reserved, assigned, or cleared by a complete collision audit |

**Credential file metadata observed:** `postgres_bootstrap_password` `0:70:440:64`; `eventsales_migrator_password` `0:0:400:64`; `eventsales_runtime_client_password` `0:0:400:64`; `redis_runtime_password` `0:0:400:64`; `pgbouncer.ini` `0:65532:440:676`; `pgbouncer_users.txt` `0:65532:440:157`; `redis-users.acl` `0:65532:440:719`. These are `uid:gid:mode:bytes`, not file contents. Other secret files were not individually checked.

## 3. PostgreSQL `pg_hba.conf` — exact rules and authorization status

**Active file path reported by PostgreSQL:** `/var/lib/postgresql/18/data/pg_hba.conf` (inside the PostgreSQL data volume). Initial HBA file had six valid rules: `local all all trust`, loopback TCP `127.0.0.1` and `::1` trust, plus corresponding replication local/loopback trust rules. No Docker-bridge host rule existed initially. PostgreSQL `ssl=off`.

### Rule A — persistent PgBouncer backend access: **APPLIED AND FUNCTIONALLY VERIFIED**

```text
host event_sales_prod eventsales_runtime 172.20.0.3/32 scram-sha-256
```

- **Authority:** Owner approved the narrow PgBouncer HBA correction on 2026-11-12.
- **Execution:** Owner ran the bounded root shell operation: check PgBouncer IP `.3/16`; confirm active HBA path and `6:0` parsed-rule baseline; create a protected copy; append exactly the rule; check HBA parsing; call `pg_reload_conf()`; no PostgreSQL container restart requested.
- **Reported outcome:** `HBA_RULE=WRITTEN`, `HBA_BACKUP=CREATED`, `HBA_CORRECTION=APPLIED`, `POSTGRES_RESTART=NOT_REQUIRED`. Protected backup name reported by the executed script: `/var/lib/postgresql/18/data/pg_hba.conf.before-eventsales-pgbouncer-20261112` **(existence not separately rechecked)**.
- **Independent functional confirmation from owner terminal:** Authenticated SQL through PgBouncer returned `eventsales_runtime|event_sales_prod`. This proves the tested backend path worked at that moment.
- **Lifecycle:** `ABSENT → OWNER_APPROVED → APPLIED → AUTHENTICATED_SQL_PROVEN`. Preserve this rule while PgBouncer remains at the verified source IP. **On IP drift, STOP; do not broaden to `/16` or silently rewrite.**
- **Reproducibility risk:** The current `deploy/vps/data-plane/compose.yaml` does not declare or install an explicit `pg_hba.conf` host-access policy. Rule A is an observed **on-volume manual correction**, not a reproducible first-install configuration. The existing volume should retain it, but a fresh database initialization would need separately reviewed HBA provisioning. Track this before future rebuilds; do **not** rebuild the data plane now.

### Rule B — temporary direct migration access: **APPROVED, NOT APPLIED**

```text
host event_sales_prod eventsales_migrator 172.20.0.10/32 scram-sha-256
```

- **Authority:** Owner explicitly approved adding **this one temporary rule** on 2026-11-12, with protected backup, validation, reload, and mandatory removal **before** the final long-running private runtime. This approval **does not** authorize a migration, image pull, container creation, network attachment or other operations.
- **Current status:** `OWNER_APPROVED_NOT_APPLIED`. **No output has been provided showing that Rule B was written or reloaded. Do not claim otherwise.**
- **Guards before application:** Confirm Rule A remains correct; verify exact HBA path and backing volume; confirm currently parsed rules and backup identity; validate `.10` is reserved/available and will be the **actual TCP source** of the reviewed one-shot migration container; verify no concurrent app/container uses that IP; preserve a *new* protected pre-change backup without overwriting Rule A's backup. Avoid secret disclosure or a broad rule.
- **Permitted side effect under this approval:** Append **only** Rule B, verify `pg_hba_file_rules` matches exactly and shows no errors, reload via `pg_reload_conf()`, independently read back the rule. On error, **STOP**; do not blindly retry/restore/restart.
- **Migration remains a different authorization:** The initial `EventSales.Release.migrate()` creates database objects. It requires its own source/image/role/reversibility decision and exact, one-shot operational approval.
- **Required cleanup after migration:** Before final private app startup, separately execute the reviewed removal of **only Rule B**, validate parsing and reload, and independently verify the migrator rule is absent while Rule A and local rules remain intact. No automatic cleanup on migration failure; preserve evidence and request new authority.
- **Lifecycle:** `ABSENT → OWNER_APPROVED_NOT_APPLIED → APPLIED_VALIDATED → MIGRATION_ELIGIBLE → MIGRATION_COMPLETED → REMOVAL_AUTHORIZED → REMOVED_AND_RELOADED → CLOSED`. `BLOCKED` on drift, unexpected rule, failed reload/auth, incomplete migration or inability to prove removal. Approval of Rule B does not itself move the readmission lifecycle to `DATA_PLANE_ACCEPTED`.

**Never add:** `host all all 172.20.0.0/16 trust`, blanket network grants, host-published PostgreSQL/Redis/PgBouncer ports, or a permanent migrator exception. Do not change the existing local/loopback rules without a separate review (their `trust` setting is a separate hardening consideration, not authorization to make further changes now).

## 4. Private app contract and current gates

- **App Compose:** `deploy/vps/app/compose.yaml` is the private definition; **no host ports**. It joins `eventsales-prod_eventsales_data` and `eventsales-prod_eventsales_edge`. `eventsales-app` alias belongs only on the data network. `EVENTSALES_NODE_IP` must match the app's fixed data-network IPv4. The candidate `172.20.0.10` is **not yet approved/assigned**.
- **Future loopback overlay:** `deploy/vps/app/compose.ingress.yaml` publishes `127.0.0.1:4100:4000` only after private acceptance; **do not apply for first private runtime**.
- **Migration access:** `DIRECT_DATABASE_URL` uses `eventsales_migrator` with a direct PostgreSQL connection; it is migration-only, never a final runtime variable. Normal `DATABASE_URL` uses `eventsales_runtime` via `pgbouncer:6432/event_sales_prod`. Redis runtime identity is `eventsales_runtime` under `eventsales:prod:*`.
- **Image candidate:** immutable digest above is technically available; `V6_AUTHORIZED=NO` remains until a separate owner acceptance at the correct gate.
- **Initial schema:** no `public.schema_migrations`; first Ecto migrations required. No accidental bootstrap or implicit migration-on-start.
- **Release sequence:** `DATA_PLANE_ACCEPTED → IMAGE_APPROVED → APP_STAGED → MIGRATED → BOOTSTRAP_APP_RUNNING → BOOTSTRAPPED → FINAL_PRIVATE_RUNNING → PRIVATE_ACCEPTED`. Distinct approval per state change, and no host-published port or public traffic before private acceptance.
- **Accepted re-admission governance:** PR #369 merged, `READMISSION_ROUTE=OWNER_ACCEPTED`, `STATE=EXISTING_UNVERIFIED`; `D0_CURRENT_BASELINE=NOT_ACCEPTED`, `FUNCTIONAL_PROOF_ELIGIBLE=NO`, `DATA_PLANE_ACCEPTED=NO`, `V6_AUTHORIZED=NO` remain formally **not accepted**. These terminal/blocked requirements are not implicitly overridden by the ad hoc host checks. Where the owner chooses a narrower development exception, record it explicitly rather than quietly claiming a completed production gate.

## 5. Outstanding launch-critical items (no new audit framework)

1. **Read-back Rule A / current HBA** after the last change; preserve sanitized rule list, backup metadata and PgBouncer source IP. No secret contents.
2. **Independent source-IP/collision decision** for `172.20.0.10` before using it for the migration helper and later app. Host route output and lack of a current member are encouraging but not conclusive.
3. **Rule B installation and verification** under the above *already approved, narrow* authorization; no migration in the same operation. No reboot/restart.
4. **Migration authentication proof** from the actual assigned source under an approved bounded test; avoid another unapproved database modification.
5. **Confirm remaining role/ACL and bootstrap requirements** only to the extent they block private startup; Redis AUTH passed but key operations remain unproven. Do not rerun the accepted R4 one-shot probes or replay historical V3–V5 actions implicitly.
6. **Record deliberate owner decisions** for the data-plane readmission/D0 uncertainty, private-development backup/reversibility exception, immutable image selection and the separate migration/bootstrap/start operations. Existing governance currently blocks V6/V7 without those decisions.
7. **Start privately, then prove private readiness** using the repository's existing probe and no app host ports. Leave OLS/CyberPanel/WordPress untouched.

## 6. STOP / evidence handling

- **STOP** on a changed Docker source IP, HBA path or baseline, unexpected additional HBA rules, symlink/unsafe file ownership, failed parse/reload, secret exposure, unknown migration source, conflicted Docker address, nonzero restart count or unhealthy production service, D0 drift, or any proposed command that affects WordPress/OLS/CyberPanel.
- A successful HBA reload request is not on its own proof of successful authentication. Preserve independently observed PgBouncer SQL confirmation; separately confirm the temporary migration path once assigned.
- A successful Redis `AUTH` is **not** proof that all runtime commands are allowed; do not report `REDIS_FUNCTIONAL_PROOF=PASS` without bounded proof.
- Do not paste contents of `.env`, `pgbouncer.ini`, `pgbouncer_users.txt`, `redis-users.acl`, `pg_authid.rolpassword`, PostgreSQL URLs, or raw `docker inspect` environment arrays into repository evidence.
- Source-of-truth for observed host state is the dated terminal evidence; a tracked Markdown summary is a **handover**, not a substitute for time-stamped, independently accepted operational proof.

## 7. Governing repository references

- `docs/superpowers/specs/2026-11-12-d1-existing-data-plane-readmission-owner-acceptance.md`
- `docs/superpowers/specs/2026-11-11-d1-existing-data-plane-readmission-ruling.md`
- `docs/superpowers/specs/2026-10-21-d1-vps-production-cluster-node-ruling.md`
- `docs/deployment/vps-production.md`
- `deploy/vps/data-plane/compose.yaml`
- `deploy/vps/app/compose.yaml` and `deploy/vps/app/compose.ingress.yaml`
- `deploy/vps/data-plane/scripts/probe-pgbouncer.sh` and `deploy/vps/data-plane/scripts/probe-redis.sh`
- [EventSales GHCR image publication run](https://github.com/Carpe-Diem-Media/EventSales/actions/runs/42014330401)

**Document-only closeout:** This record does not itself install Rule B, perform a migration or grant additional VPS authority.
