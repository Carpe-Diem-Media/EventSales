# G4.8 D0 current-state inspection execution procedure

- **Document type:** Proposed one-time operational procedure
- **Date:** 2026-11-16
- **Status:** DRAFT, independent review required
- **Base:** `fade6a58024ba4e21f2a7bbcf887f6d8ec58c9ae`
- **Tracking:** GitHub issue #372 / Linear JC-347
- **Installation and execution authority:** NOT GRANTED
- **Evidence-read authority:** NOT GRANTED

## Purpose and limits

This procedure describes how a separately authorized operator could install the merged G4.6 collector, run the merged G4.7 one-shot wrapper once, preserve its protected output, and remove the installed tools. This draft authorizes none of those actions. No command below was run against the VPS.

The collector makes bounded Docker Engine API `GET` requests through `/run/docker.sock`. It does not start, stop, restart, create, remove, rename, detach, or reconfigure D0 objects. It does not query PostgreSQL, PgBouncer, Redis, or a network service. Its two matching observations are sequential, not atomic, and cannot prove historical continuity.

The wrapper must be the only entry point. Do not run the collector directly, pipe or redirect wrapper output, add an outer timeout, set environment overrides, or invoke Docker commands for this task. The collector's JSON includes full Docker IDs and host mount paths. The wrapper writes that JSON to protected files and prints only a fixed result code.

This procedure covers installation and one capture only. It does not review evidence, accept a D0 baseline, establish functional-proof eligibility, change V9/V10, or authorize V9/V10 execution.

## Pinned artifacts and paths

The source commit is the merged G4.7 commit on `main`. The wrapper hash below is the SHA-256 of the exact file bytes in that commit, calculated with `sha256sum`; it is not a Git blob identifier.

| Component | Exact source | Installed path | Required bytes and mode | SHA-256 |
| --- | --- | --- | --- | --- |
| G4.6 collector | `deploy/vps/operator/agent-vps-d0-current-state-inspect` | `/usr/local/sbin/agent-vps-d0-current-state-inspect` | `root:root`, `0755` | `91e7f6adce032f514eeff512998952b623b20232e95d71b3cf00e4fc4c15a124` |
| G4.7 capture wrapper | `deploy/vps/operator/agent-vps-d0-current-state-once` | `/usr/local/sbin/agent-vps-d0-current-state-once` | `root:root`, `0755` | `b566ad95284eb58f714531c56da090cbf640a3799c4beb033b04e14067a4f56f` |
| Protected capture | Created by the wrapper | `/root/eventsales-d0-current-state-once` | Directory `root:root 0700`; `collector.stdout`, `collector.stderr`, and `metadata.json` each `root:root 0600` | Recorded in protected metadata; do not publish hashes |

The wrapper pins the collector SHA-256 shown above. It refuses arguments, requires effective UID/GID 0, clears the child environment, checks the installed collector's ownership, mode, size and digest, and invokes it at most once. The final paths and hashes are fixed. Do not install an alternate version or use environment variables to redirect either component or the evidence directory.

## Approval boundaries

Two owner approvals are required and must be recorded separately:

1. **Installation approval** names the exact base commit, both hashes, both installed paths, root ownership and modes, transfer and cleanup paths, and the operator using an existing owner-approved administrative root path. It authorizes file transfer and installation only. It does not authorize executing the collector or reading Docker state.
2. **Read authorization** names the exact no-argument wrapper command, one attempt, the fixed Docker socket, the protected output path, the 55-second wrapper limit, the output limits below, and the terminal failure rules. It authorizes this collector's bounded Docker `GET` requests and capture only. It does not authorize a person to open or export the resulting raw evidence.

Use an owner-operated, already authorized root session for installation and the single wrapper invocation. Do not add a sudoers rule for this task. The existing exact-command grants for other D0 audit tools do not authorize either G4.8 component and must not be changed or reused. If the owner cannot use an existing administrative root path, stop and seek a separately reviewed privilege decision. Do not improvise a temporary grant.

The later human or tool access to the protected capture requires a third, separate evidence-review authorization. Neither approval above grants it.

## Lifecycle and guards

| Transition | Approval guard | Permitted side effects | Failure state and handling |
| --- | --- | --- | --- |
| `UNPREPARED` → `REVIEWED` | Independent reviewers approve this exact procedure, pinned source commit and hashes, paths, privileges, limits, cleanup, redaction, and G4.4 compatibility warning. | Document review only. | `BLOCKED_DOCUMENT_REVIEW` or `BLOCKED_AUTHORITY`. No host action. |
| `REVIEWED` → `INSTALL_AUTHORIZED` | The owner separately approves installation of only the two pinned files and their exact cleanup. | Record the approval. No VPS or Docker operation. | Remain `REVIEWED`; do not transfer or install files. |
| `INSTALL_AUTHORIZED` → `STAGED` | An operator verifies the source bytes and private transfer, confirms the destination directory is trusted, and verifies both installed hashes, owners, and modes. Both final paths and temporary stage paths must be absent before creation. | Copy the two files to root-owned staging and the exact `/usr/local/sbin` paths. Do not execute either file. No sudoers change. | `BLOCKED_INSTALL` on a hash, owner, mode, path, or permission mismatch. Do not execute. Remove only exact G4.8 staging files if their identity is known and the installation approval covers cleanup. |
| `STAGED` → `READ_AUTHORIZED` | After independent confirmation of the installed bytes, the owner separately authorizes one wrapper invocation with the exact command and output path. Installation approval alone is insufficient. | Record the read authorization. No Docker request yet. | `BLOCKED_READ_AUTHORITY`; do not invoke. The owner may separately authorize cleanup of staged files. |
| `READ_AUTHORIZED` → `CONSUMED` | The operator runs the exact command once. The wrapper exclusively creates the fixed evidence directory before it verifies and starts the collector. | Up to 19 bounded Docker API `GET` requests; one collector invocation; protected output creation. No D0 mutation. | Any failure is terminal for this authorization. Preserve any evidence directory and partial files. Never retry, remove the marker, or reuse the path. |
| `CONSUMED` → `CLEANED` | The installation approval includes removal of the exact installed files and staging paths. The operator verifies their hashes before removal. | Remove only the two pinned installed files and G4.8 transfer/root staging files. Keep the evidence directory and its three files unchanged. Confirm no G4.8 sudoers file exists. | `BLOCKED_CLEANUP` if a file differs, cleanup fails, or privilege state is uncertain. Preserve evidence and do not rerun. |

`CLEANED` means the temporary code and transfer staging are gone. It does not mean the evidence was reviewed or accepted. If read authorization is withheld after staging, do not leave the tools installed indefinitely; obtain the already-scoped cleanup approval and move to a recorded no-execution cleanup outcome. A later attempt requires a new review and new explicit authorizations.

For this procedure, the first wrapper invocation is treated as consuming the authorization even if it exits before creating the evidence directory. Mechanically, the wrapper's one-shot marker is the exclusive creation of `/root/eventsales-d0-current-state-once`, which occurs before collector identity verification. If that directory exists, including after an incomplete attempt, it is terminal. Do not delete it to permit another run.

## Proposed preparation and installation commands

These commands are instructions for a future separately authorized operation. Do not run them as part of this PR. Use the repository root at the pinned base commit and a private local staging directory. The approved VPS SSH alias must be named by the owner; this document does not select a host or provide credentials.

On the source workstation, create private copies from the exact commit and compare the printed SHA-256 values with the table above:

```sh
set -eu
umask 077
SOURCE_DIR="$(mktemp -d "$HOME/eventsales-g4-8-source.XXXXXX")"
git show fade6a58024ba4e21f2a7bbcf887f6d8ec58c9ae:deploy/vps/operator/agent-vps-d0-current-state-inspect > "$SOURCE_DIR/agent-vps-d0-current-state-inspect"
git show fade6a58024ba4e21f2a7bbcf887f6d8ec58c9ae:deploy/vps/operator/agent-vps-d0-current-state-once > "$SOURCE_DIR/agent-vps-d0-current-state-once"
sha256sum "$SOURCE_DIR/agent-vps-d0-current-state-inspect" "$SOURCE_DIR/agent-vps-d0-current-state-once"
```

Stop if either digest differs. After the owner names the approved SSH alias, create a new operator-owned upload directory at `/home/agentops/.eventsales-g4-8-upload`, mode `0700`, and refuse to reuse an existing path. The `agentops` account name follows the current operator convention. Stop if that account or home path does not exist as expected. Replace the quoted placeholder below with the alias recorded in the owner authorization. Run the first command from the workstation to create the directory as `agentops`, then transfer only these two files:

```sh
ssh '<approved-ssh-alias>' 'test ! -e /home/agentops/.eventsales-g4-8-upload && test ! -L /home/agentops/.eventsales-g4-8-upload && mkdir -m 0700 /home/agentops/.eventsales-g4-8-upload'
scp -- "$SOURCE_DIR/agent-vps-d0-current-state-inspect" "$SOURCE_DIR/agent-vps-d0-current-state-once" '<approved-ssh-alias>:/home/agentops/.eventsales-g4-8-upload/'
rm -- "$SOURCE_DIR/agent-vps-d0-current-state-inspect" "$SOURCE_DIR/agent-vps-d0-current-state-once"
rmdir -- "$SOURCE_DIR"
```

Using the already authorized root path, verify the upload directory is owned by `agentops`, mode `0700`, and contains only the two expected regular files owned by `agentops` with mode `0600`. Confirm `/usr/local/sbin` is a root-owned directory that is not group- or world-writable, and `/root` is `root:root 0700`. The two final paths, `/root/.eventsales-g4-8-install`, the evidence directory, and `/etc/sudoers.d/agent-vps-d0-current-state-once` must be absent. Any unexpected path or permission is a STOP condition. Do not overwrite or delete it.

```sh
sudo -- stat -c '%U:%G %a %F %n' /usr/local/sbin /root /home/agentops/.eventsales-g4-8-upload /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once
sudo -- test -d /usr/local/sbin
sudo -- test ! -L /usr/local/sbin
sudo -- test -d /root
sudo -- test ! -L /root
sudo -- test -d /home/agentops/.eventsales-g4-8-upload
sudo -- test ! -L /home/agentops/.eventsales-g4-8-upload
sudo -- test -f /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect
sudo -- test ! -L /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect
sudo -- test -f /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once
sudo -- test ! -L /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once
sudo -- find /home/agentops/.eventsales-g4-8-upload -mindepth 1 -maxdepth 1 -printf '%f\n'
for path in /usr/local/sbin/agent-vps-d0-current-state-inspect /usr/local/sbin/agent-vps-d0-current-state-once /root/.eventsales-g4-8-install /root/eventsales-d0-current-state-once /etc/sudoers.d/agent-vps-d0-current-state-once; do
  sudo -- test ! -e "$path" || exit 1
  sudo -- test ! -L "$path" || exit 1
done
```

Create a fresh root-only staging directory, copy the uploaded files into it with fixed modes, and verify their digests before installation:

```sh
sudo -- mkdir -m 0700 /root/.eventsales-g4-8-install
sudo -- install -o root -g root -m 0600 /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect /root/.eventsales-g4-8-install/agent-vps-d0-current-state-inspect
sudo -- install -o root -g root -m 0600 /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once /root/.eventsales-g4-8-install/agent-vps-d0-current-state-once
sudo -- sha256sum /root/.eventsales-g4-8-install/agent-vps-d0-current-state-inspect /root/.eventsales-g4-8-install/agent-vps-d0-current-state-once
```

Only after both staging digests match, prepare root-owned temporary regular files in `/usr/local/sbin`. The absent-path checks below are diagnostic only. For each executable, `ln -T` publishes a same-filesystem hard link atomically and fails if the exact destination already exists, including when it is a symlink or directory. Do not use ordinary `install`, `cp`, or `mv` on either final path, and do not add `-f` to `ln`. Publication is atomic per file, not as a pair; the second publication can fail after the first succeeds.

```sh
set -eu
TMP_INSPECT="$(sudo -- mktemp /usr/local/sbin/.agent-vps-d0-current-state-inspect.g4-8.XXXXXX)"
sudo -- stat -c '%U:%G %a %F %d:%i %n' "$TMP_INSPECT"
TMP_ONCE="$(sudo -- mktemp /usr/local/sbin/.agent-vps-d0-current-state-once.g4-8.XXXXXX)"
sudo -- stat -c '%U:%G %a %F %d:%i %n' "$TMP_ONCE"
sudo -- test -f "$TMP_INSPECT"
sudo -- test ! -L "$TMP_INSPECT"
sudo -- test -f "$TMP_ONCE"
sudo -- test ! -L "$TMP_ONCE"
sudo -- cp -- /root/.eventsales-g4-8-install/agent-vps-d0-current-state-inspect "$TMP_INSPECT"
sudo -- cp -- /root/.eventsales-g4-8-install/agent-vps-d0-current-state-once "$TMP_ONCE"
sudo -- chown root:root "$TMP_INSPECT" "$TMP_ONCE"
sudo -- stat -c '%U:%G %a %F %d:%i %n' "$TMP_INSPECT" "$TMP_ONCE"
sudo -- sha256sum "$TMP_INSPECT" "$TMP_ONCE"
```

Record each temporary path and its device/inode (`%d:%i`) immediately after its exclusive `mktemp` creation. Require both temporary files to remain regular non-symlinks, `root:root`, mode `600`, and to match their pinned hashes. Only after both hashes match, make the verified files executable and publish them:

```sh
sudo -- chmod 0755 "$TMP_INSPECT" "$TMP_ONCE"
sudo -- stat -c '%U:%G %a %F %d:%i %n' "$TMP_INSPECT" "$TMP_ONCE"
sudo -- ln -T -- "$TMP_INSPECT" /usr/local/sbin/agent-vps-d0-current-state-inspect
sudo -- ln -T -- "$TMP_ONCE" /usr/local/sbin/agent-vps-d0-current-state-once
sudo -- stat -c '%U:%G %a %F %d:%i %n' "$TMP_INSPECT" /usr/local/sbin/agent-vps-d0-current-state-inspect "$TMP_ONCE" /usr/local/sbin/agent-vps-d0-current-state-once
sudo -- sha256sum /usr/local/sbin/agent-vps-d0-current-state-inspect /usr/local/sbin/agent-vps-d0-current-state-once
```

Require each final path to be a regular non-symlink, `root:root`, mode `755`, with its pinned hash and the same device/inode as its corresponding recorded temporary path. If either `ln -T` fails, stop; do not try another publication command or execute either file. If the first final link was created but the second publication fails, remove the first final path only when it is still a regular non-symlink `root:root 0755` file, its hash matches the pinned collector digest, and its device/inode still matches `$TMP_INSPECT`. Then verify that exact path is absent. Never remove or alter the destination that caused `ln -T` to fail. If rollback succeeds, remove the two recorded temporary names only if each still has its recorded device/inode and remains a regular non-symlink `root:root` file; otherwise leave it and record `BLOCKED_INSTALL`. If any rollback condition is not met, leave paths untouched and record `BLOCKED_INSTALL`.

If publication fails before any final link is made, remove only the temporary paths recorded from this attempt, and only when each remains a regular non-symlink `root:root` file with the same device/inode recorded immediately after its exclusive `mktemp` creation. After both final links pass verification, remove only the two recorded temporary link names and only after confirming each still shares a device/inode with its corresponding final file. A cleanup mismatch or failure is `BLOCKED_INSTALL`; preserve the remaining paths for an owner decision. Do not use a wildcard for temporary-file cleanup. Do not proceed to `READ_AUTHORIZED` on any publication, verification, or cleanup failure. No collector invocation occurs during staging or installation.

## One-time execution and capture

After the separate read authorization, invoke only:

```sh
sudo -- /usr/local/sbin/agent-vps-d0-current-state-once
```

Pass no arguments. Do not add `timeout`, `tee`, redirection, a shell trace, or an environment override. The wrapper internally clears the environment and enforces its deadlines. It prints only `D0_CAPTURE=COMPLETE` or `D0_CAPTURE=INCOMPLETE STOP=<fixed-code>`.

The collector allows at most 19 Docker API requests, each with a 3-second request deadline and a 40-second total deadline. It limits response bodies to 256 KiB and its JSON report to 65,536 bytes. The wrapper allows 55 seconds for the collector, kills its process group on timeout or handled interruption, and caps each captured stdout/stderr file at 65,536 bytes. Metadata is capped at 16,384 bytes. The wrapper records the collector digest, invocation count, exit status, timeout, timestamps, output sizes, truncation flags, and stdout/stderr hashes.

`D0_CAPTURE=COMPLETE` means the pinned collector exited successfully and the wrapper completed its bounded capture. It does not accept the D0 baseline. An incomplete result, timeout, output overflow, signal, collector digest mismatch, existing evidence directory, or missing/invalid file is terminal. The wrapper retains whatever protected files it could write. Do not rerun the wrapper, invoke the collector directly, or remove or repair the evidence directory.

The wrapper creates `/root/eventsales-d0-current-state-once` exclusively at mode `0700`, with `collector.stdout`, `collector.stderr`, and `metadata.json` at mode `0600`, all owned by `root:root`. The stdout file contains the collector JSON and must be treated as sensitive. Do not use `cat`, `jq`, shell substitution, a terminal pager, Git, or a general-purpose upload on it.

## Capture verification, review, and redaction

The operator records only the fixed terminal classification and command outcome. That is not an independent evidence review. A later evidence review needs separate owner authorization for exact paths, reviewer identity, reader bytes, read-only runtime, output location, and redaction rules.

G4.5's proposed reader is scoped to the existing G4.2 bundle and its schema. It does not authorize reading this G4.6/G4.7 capture or parse its JSON. Do not reuse it unchanged. Before an independent reviewer reads this capture, approve a G4.6-compatible offline assessment method that:

- reads only the three named files from `/root/eventsales-d0-current-state-once`;
- makes no Docker, database, Redis, or network requests;
- verifies directory/file ownership, modes, exact file set, metadata schema, output sizes, and recorded stdout/stderr hashes;
- verifies metadata schema `eventsales.g47.one-shot-capture.v1`, `result=COMPLETE`, `failure_code=null`, `collector_invocation_count=1`, collector exit code `0`, no timeout or truncation, and the expected collector digest;
- parses collector schema `eventsales.d0.current-state-inspection.v1` without printing it and preserves `collection_atomic=NO`, `historical_continuity=UNVERIFIED`, `d0_historical_transition=UNVERIFIED`, `d0_current_baseline=NOT_ACCEPTED`, and every unavailable or partial field;
- writes any full per-object assessment to a separate root-only location and emits only a redacted summary.

The reviewer must work on the VPS or another explicitly approved protected environment. Do not copy the raw bundle off-host. The only external summary may contain the result classification, counts, acquisition interval, supported/unverified/missing fields, and failure reasons. It must omit full or partial Docker IDs, IP/MAC addresses, container/network/volume identifiers, image IDs, mount paths, evidence file hashes, and raw metadata values. The owner may carry that summary to issue #372 after the independent reviewer signs off. If the approved G4.6-compatible reader is absent, evidence review is blocked; do not substitute manual shell inspection or treat the wrapper's success line as independent verification.

Successful file-level verification is a later, separately authorized review action. It must confirm the exact three files and permissions, recompute stdout/stderr hashes against `metadata.json`, validate the required metadata and collector JSON fields above, and produce only the protected assessment and redacted summary. Keep any calculated file hashes inside the protected assessment. A wrapper success or matching hashes alone does not establish baseline acceptance, authenticity independent of the wrapper, historical continuity, or V9 eligibility.

## Cleanup and failure handling

After a captured attempt, confirm each installed file is a regular non-symlink `root:root 0755` file and compare its digest with the pinned value. Confirm each root staging file is a regular non-symlink `root:root 0600` file and each upload is a regular non-symlink `agentops`-owned `0600` file; compare all staged-file digests with the same pins. Under the installation approval, remove only these exact files if their type, owner, mode, and digest still match:

```text
/usr/local/sbin/agent-vps-d0-current-state-inspect
/usr/local/sbin/agent-vps-d0-current-state-once
/root/.eventsales-g4-8-install/agent-vps-d0-current-state-inspect
/root/.eventsales-g4-8-install/agent-vps-d0-current-state-once
/home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect
/home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once
```

Then remove only the empty G4.8 staging directories and confirm both installed paths are absent. The future cleanup commands, after the digest checks pass, are:

```sh
sudo -- rm -- /usr/local/sbin/agent-vps-d0-current-state-inspect /usr/local/sbin/agent-vps-d0-current-state-once
sudo -- rm -- /root/.eventsales-g4-8-install/agent-vps-d0-current-state-inspect /root/.eventsales-g4-8-install/agent-vps-d0-current-state-once
sudo -- rmdir -- /root/.eventsales-g4-8-install
ssh '<approved-ssh-alias>' 'rm -- /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-inspect /home/agentops/.eventsales-g4-8-upload/agent-vps-d0-current-state-once && rmdir -- /home/agentops/.eventsales-g4-8-upload'
sudo -- test ! -e /usr/local/sbin/agent-vps-d0-current-state-inspect
sudo -- test ! -e /usr/local/sbin/agent-vps-d0-current-state-once
sudo -- test ! -e /etc/sudoers.d/agent-vps-d0-current-state-once
```

Do not remove `/root/eventsales-d0-current-state-once` or any file beneath it. No G4.8 sudoers entry is expected or permitted. If a digest changed, a path is unexpected, a cleanup command fails, or the sudoers check finds an entry, stop as `BLOCKED_CLEANUP`; preserve evidence and request a new owner decision. Do not broaden cleanup to nearby files or directories.

For a lost SSH session or unknown wrapper result, treat the authorization as consumed. Do not invoke again. Preserve the evidence path if it exists and wait for a separately authorized evidence review. If no evidence path exists, record the result as unknown and require a new review and explicit authorization before another attempt.

## G4.4 and downstream compatibility decision

G4.4 permits consideration of a prospective frozen D0 baseline while the historical stop remains unverified. Its evidence route describes review of the existing G4.2 bundle. A new G4.6/G4.7 capture is a separate, later current-state observation. It cannot replace or augment the G4.2 review automatically, and it cannot establish the historical stop or cross-date object continuity. At this base, the G4.4 file still labels itself `DRAFT, owner decision required`, while G4.5 records owner approval of the exact G4.4 policy text. Before relying on that policy for any operational decision, an independent reviewer must confirm that the recorded approval covers the exact G4.4 bytes at the pinned commit. Otherwise, retain `BLOCKED_AUTHORITY`.

Before anyone accepts a prospective baseline or marks functional proof eligible, the owner and the authority responsible for D1 must make an explicit compatibility decision that answers all of the following:

1. Does the G4.6/G4.7 capture supplement the G4.2 evidence review, or may it replace any specified G4.2 evidence requirement? Name each accepted field and preserve all unsupported G4.2 and historical claims as unverified.
2. Does G4.5's review plan need a separately reviewed amendment or G4.6-compatible reader before it can assess this capture?
3. Which exact D1, V9, and V10 prerequisites may consume the prospective manifest, and what exact fail-closed status mapping must each consumer implement?

Until that decision, an accepted procedure, a complete capture, or an evidence review cannot change `D0_CURRENT_BASELINE=NOT_ACCEPTED`, `FUNCTIONAL_PROOF_ELIGIBLE=NO`, or `V9_SMOKE=NOT_RUN`. The accepted D1 readmission guard also requires review of the D0 transition evidence and acceptance of a current baseline before functional-proof eligibility. If the authority does not explicitly amend that guard, retain `BLOCKED_AUTHORITY`. Any later probe change, functional-proof eligibility decision, and V9/V10 execution require separate review and owner authorization. The historical transition remains `UNVERIFIED` in all cases.

## Current state and stop conditions

This draft makes no operational or governance transition:

```text
G48_PROCEDURE=READY_FOR_REVIEW
G48_INSTALL_AUTHORIZED=NO
G48_READ_AUTHORIZED=NO
G48_EVIDENCE_READ_AUTHORIZED=NO
D0_HISTORICAL_TRANSITION=UNVERIFIED
D0_CURRENT_BASELINE=NOT_ACCEPTED
FUNCTIONAL_PROOF_ELIGIBLE=NO
V9_SMOKE=NOT_RUN
VPS_CHANGES=NONE
```

Stop on any base/hash mismatch, unexpected existing path, ownership or mode mismatch, need for a new sudoers grant, G4.4/D1 authority conflict, unapproved evidence reader, unexpected collector output, interrupted/unknown outcome, or cleanup failure. Preserve D0 and any captured evidence. Do not retry under the same authorization.

## References

- [G4.4 prospective frozen D0 baseline ruling](../specs/2026-11-14-g4-4-prospective-frozen-d0-baseline-ruling.md), including its separate downstream compatibility mapping requirement.
- [G4.5 protected evidence review plan](../specs/2026-11-15-g4-5-protected-evidence-review-plan.md), scoped to the existing G4.2 evidence bundle.
- [D1 architecture approval](../specs/2026-10-20-d1-vps-production-architecture-approval.md) and [approved D1 design](../specs/2026-10-20-d1-vps-production-architecture-design.md), including the frozen D0 invariant.
- [Accepted D1 readmission ruling](../specs/2026-11-11-d1-existing-data-plane-readmission-ruling.md) and [owner acceptance](../specs/2026-11-12-d1-existing-data-plane-readmission-owner-acceptance.md).
- G4.6 collector at source commit `fade6a58024ba4e21f2a7bbcf887f6d8ec58c9ae`, SHA-256 `91e7f6adce032f514eeff512998952b623b20232e95d71b3cf00e4fc4c15a124`.
- G4.7 wrapper at source commit `fade6a58024ba4e21f2a7bbcf887f6d8ec58c9ae`, SHA-256 `b566ad95284eb58f714531c56da090cbf640a3799c4beb033b04e14067a4f56f`.

**Execution boundary:** This is a procedure proposal only. No root command, VPS access, Docker request, evidence read, installation, sudoers change, D0 change, or V9/V10 operation was performed.
