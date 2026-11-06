#!/usr/bin/env bash
set -Eeuo pipefail

readonly EXPECTED_BASE_SHA='b647ad905d154b1ba4a82eda4fdacb5038564feb'
readonly EXPECTED_ASH_POSTGRES_VERSION='2.15.2'
readonly EXPECTED_ASH_FUNCTIONS_VERSION='7'
readonly OWNER_ROLE='jc361_ash_functions_owner'
readonly CALLER_ROLE='jc361_ash_functions_caller'
readonly PROOF_DATABASE='jc361_ash_functions_proof'
readonly MIGRATION_FILE='priv/repo/migrations/20260513173458_ash_baseline_auth_user_proof_extensions_1.exs'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

admin_psql() {
  psql -X -q -w -v ON_ERROR_STOP=1 \
    -h "$ASH_PROOF_HOST" \
    -p "$ASH_PROOF_PORT" \
    -U "$ASH_PROOF_ADMIN_USER" \
    -d "$ASH_PROOF_ADMIN_DATABASE" \
    "$@"
}

owner_psql() {
  psql -X -q -A -t -w -v ON_ERROR_STOP=1 \
    -h "$ASH_PROOF_HOST" \
    -p "$ASH_PROOF_PORT" \
    -U "$OWNER_ROLE" \
    -d "$PROOF_DATABASE" \
    "$@"
}

caller_psql() {
  psql -X -q -A -t -w -v ON_ERROR_STOP=1 \
    -h "$ASH_PROOF_HOST" \
    -p "$ASH_PROOF_PORT" \
    -U "$CALLER_ROLE" \
    -d "$PROOF_DATABASE" \
    "$@"
}

capture_one() {
  local output
  output=$("$@") || return 1
  [[ -n "$output" && "$output" != *$'\n'* ]] || return 1
  printf '%s' "$output"
}

function_count_sql() {
  cat <<'SQL'
SELECT count(*)
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required';
SQL
}

function_identity_sql() {
  cat <<'SQL'
SELECT concat_ws(E'\t',
  p.oid::text,
  n.nspname,
  pg_get_function_identity_arguments(p.oid),
  pg_get_function_result(p.oid),
  pg_get_userbyid(p.proowner),
  COALESCE(p.proacl::text, '<NULL>'),
  COALESCE(p.proconfig::text, '<NULL>'),
  l.lanname,
  p.provolatile::text,
  p.prosecdef::text,
  p.proisstrict::text,
  p.proparallel::text
)
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
JOIN pg_language AS l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
SQL
}

function_metadata_sql() {
  cat <<'SQL'
SELECT jsonb_build_object(
  'oid', p.oid,
  'schema', n.nspname,
  'signature', pg_get_function_identity_arguments(p.oid),
  'return_type', pg_get_function_result(p.oid),
  'owner', pg_get_userbyid(p.proowner),
  'acl', COALESCE(p.proacl::text, '<NULL>'),
  'proconfig', COALESCE(p.proconfig::text, '<NULL>'),
  'language', l.lanname,
  'volatility', p.provolatile,
  'security_definer', p.prosecdef,
  'strict', p.proisstrict,
  'parallel', p.proparallel,
  'definition', pg_get_functiondef(p.oid)
)::text
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
JOIN pg_language AS l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
SQL
}

function_definition_sql() {
  cat <<'SQL'
SELECT pg_get_functiondef(p.oid)
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
SQL
}

function_body_hash_sql() {
  cat <<'SQL'
SELECT md5(pg_get_functiondef(p.oid))
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
SQL
}

extract_function_ddl() {
  local source_file="$1"
  local signature="$2"
  local output_file="$3"

  awk -v signature="$signature" '
    /execute\("""/ { inside = 1; selected = 0; next }
    inside && /"""\)/ { inside = 0; selected = 0; next }
    inside {
      line = $0
      sub(/^    /, "", line)
      if (!selected && index(line, signature) == 1) {
        selected = 1
        matches++
      }
      if (selected) print line
    }
    END { if (matches != 1) exit 42 }
  ' "$source_file" > "$output_file" || fail "expected exactly one DDL block for $signature in $source_file"
}

notice_value() {
  local label="$1"
  local log_file="$2"

  awk -v label="$label" '
    BEGIN { marker = label "=" }
    {
      line = $0
      sub(/^psql:.*:[0-9]+:[[:space:]]*/, "", line)
      if (line !~ /^NOTICE:[[:space:]]*/) next
      sub(/^NOTICE:[[:space:]]*/, "", line)
      if (index(line, marker) == 1) {
        matches++
        value = substr(line, length(marker) + 1)
      }
    }
    END {
      if (matches == 0) exit 1
      if (matches != 1) exit 2
      print value
    }
  ' "$log_file"
}

capture_labeled_value() {
  local label="$1"
  local log_file="$2"

  awk -v label="$label" '
    BEGIN { marker = label "=" }
    index($0, marker) == 1 {
      matches++
      value = substr($0, length(marker) + 1)
    }
    END {
      if (matches == 0) exit 1
      if (matches != 1) exit 2
      print value
    }
  ' "$log_file"
}

parse_null_result() {
  local prefix="$1"
  local log_file="$2"
  local sqlstate=''
  local message=''
  local returned_null=''
  local returned_value=''
  local has_sqlstate=false
  local has_message=false
  local has_returned_null=false
  local has_returned_value=false
  local status

  if sqlstate=$(notice_value "${prefix}_NULL_SQLSTATE" "$log_file"); then
    has_sqlstate=true
  else
    status=$?
    [[ "$status" == '1' ]] || return "$status"
  fi

  if message=$(notice_value "${prefix}_NULL_MESSAGE" "$log_file"); then
    has_message=true
  else
    status=$?
    [[ "$status" == '1' ]] || return "$status"
  fi

  if returned_null=$(notice_value "${prefix}_NULL_RETURNED" "$log_file"); then
    has_returned_null=true
  else
    status=$?
    [[ "$status" == '1' ]] || return "$status"
  fi

  if returned_value=$(notice_value "${prefix}_NULL_RETURNED_VALUE" "$log_file"); then
    has_returned_value=true
  else
    status=$?
    [[ "$status" == '1' ]] || return "$status"
  fi

  if [[ "$has_sqlstate" == true ]]; then
    [[ "$has_message" == true && "$has_returned_null" == false && "$has_returned_value" == false ]] || return 1
    [[ -n "$sqlstate" && -n "$message" ]] || return 1
    printf 'ERROR\t%s\t%s\n' "$sqlstate" "$message"
  elif [[ "$has_message" == false && "$has_returned_null" == true && "$has_returned_value" == false && "$returned_null" == 'NULL' ]]; then
    printf 'RETURNED_NULL\tNONE\treturned NULL without an error\n'
  elif [[ "$has_message" == false && "$has_returned_null" == false && "$has_returned_value" == true ]]; then
    printf 'RETURNED_VALUE\tNONE\t%s\n' "$returned_value"
  else
    return 1
  fi
}

cleanup_attempted=false
provisioning_started=false
work_dir=''

cleanup_database() {
  cleanup_attempted=true

  if ! admin_psql <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'jc361_ash_functions_proof'
  AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS jc361_ash_functions_proof;
DROP ROLE IF EXISTS jc361_ash_functions_owner;
DROP ROLE IF EXISTS jc361_ash_functions_caller;
SQL
  then
    return 1
  fi

  local remaining
  remaining=$(capture_one admin_psql -Atq -c "SELECT (SELECT count(*) FROM pg_database WHERE datname = '$PROOF_DATABASE')::text || ':' || (SELECT count(*) FROM pg_roles WHERE rolname IN ('$OWNER_ROLE', '$CALLER_ROLE'))::text") || return 1
  [[ "$remaining" == '0:0' ]]
}

cleanup_on_exit() {
  local exit_status="$1"
  trap - EXIT
  set +e

  if [[ "$provisioning_started" == true && "$cleanup_attempted" == false ]]; then
    if cleanup_database; then
      printf 'DATABASE_CLEANUP=PASS\n'
    else
      printf 'DATABASE_CLEANUP=FAIL\n' >&2
      exit_status=1
    fi
  elif [[ "$provisioning_started" == false && "$cleanup_attempted" == false ]]; then
    printf 'DATABASE_CLEANUP=NOT_REQUIRED\n'
  fi

  if [[ -n "$work_dir" && -d "$work_dir" && "$work_dir" == "$RUNNER_TEMP"/jc361-ash-functions.* ]]; then
    rm -rf -- "$work_dir"
  fi

  exit "$exit_status"
}

[[ "${GITHUB_ACTIONS:-}" == 'true' ]] || fail 'must run inside a GitHub Actions runner'
[[ "${CI:-}" == 'true' ]] || fail 'CI environment marker is missing'
[[ "${ASH_PROOF_EXPECTED_BASE_SHA:-}" == "$EXPECTED_BASE_SHA" ]] || fail 'PR base SHA does not match the approved baseline'
[[ "${ASH_PROOF_PR_HEAD_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || fail 'PR head SHA is missing or malformed'
[[ "${ASH_PROOF_HOST:-}" == '127.0.0.1' ]] || fail 'proof host must be the runner loopback address'
[[ "${ASH_PROOF_PORT:-}" == '55434' ]] || fail 'proof port does not match the dedicated PostgreSQL service'
[[ "${ASH_PROOF_ADMIN_USER:-}" == 'postgres' ]] || fail 'unexpected proof service administrator role'
[[ "${ASH_PROOF_ADMIN_DATABASE:-}" == 'postgres' ]] || fail 'unexpected proof service administrator database'
[[ -n "${RUNNER_TEMP:-}" && -d "$RUNNER_TEMP" ]] || fail 'GitHub runner temp directory is unavailable'
[[ -f "$MIGRATION_FILE" ]] || fail "checked-in v6 migration is missing: $MIGRATION_FILE"

if ! git cat-file -e "${ASH_PROOF_EXPECTED_BASE_SHA}^{commit}"; then
  fail 'approved baseline commit is unavailable in the checkout'
fi
if ! git merge-base --is-ancestor "$ASH_PROOF_EXPECTED_BASE_SHA" HEAD; then
  fail 'approved baseline is not an ancestor of the proof checkout'
fi
if ! git cat-file -e "${ASH_PROOF_PR_HEAD_SHA}^{commit}" || ! git merge-base --is-ancestor "$ASH_PROOF_PR_HEAD_SHA" HEAD; then
  fail 'PR head commit is unavailable or is not part of the proof checkout'
fi

mapfile -t changed_paths < <(git diff --name-only "${ASH_PROOF_EXPECTED_BASE_SHA}...HEAD")
expected_paths=$'.github/workflows/ci.yml\nscripts/ci/ash_functions_v6_v7_proof.sh'
actual_paths=$(printf '%s\n' "${changed_paths[@]}")
[[ "$actual_paths" == "$expected_paths" ]] || fail "unexpected changed paths from approved baseline: $actual_paths"
git diff --check "${ASH_PROOF_EXPECTED_BASE_SHA}...HEAD"

grep -Fq "\"ash_postgres\": {:hex, :ash_postgres, \"$EXPECTED_ASH_POSTGRES_VERSION\"," mix.lock || fail 'mix.lock does not pin AshPostgres 2.15.2'

work_dir=$(mktemp -d "$RUNNER_TEMP/jc361-ash-functions.XXXXXX")
trap 'cleanup_on_exit "$?"' EXIT
[[ "$work_dir" != *[[:space:]]* ]] || fail 'runner temp path contains whitespace and cannot be safely passed to psql'

printf 'CI_DISPOSABLE_PROOF=RUNNING\n'
printf 'PROOF_BASE_SHA=%s\n' "$ASH_PROOF_EXPECTED_BASE_SHA"
printf 'PROOF_PR_HEAD_SHA=%s\n' "$ASH_PROOF_PR_HEAD_SHA"
printf 'PROOF_CHECKOUT_SHA=%s\n' "$(git rev-parse HEAD)"
printf 'LOCKED_ASH_POSTGRES=%s\n' "$EXPECTED_ASH_POSTGRES_VERSION"
printf 'PROOF_DATABASE_HOST=%s\n' "$ASH_PROOF_HOST"
printf 'PROOF_DATABASE_PORT=%s\n' "$ASH_PROOF_PORT"
printf 'PSQL_CLIENT_VERSION=%s\n' "$(psql --version)"

v6_helper_sql="$work_dir/v6-helper.sql"
v6_function_sql="$work_dir/v6-ash-required.sql"
v7_generated="$work_dir/v7-generated-migration.exs"
v7_function_sql="$work_dir/v7-ash-required.sql"
v6_setup_sql="$work_dir/v6-setup.sql"

extract_function_ddl "$MIGRATION_FILE" 'CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)' "$v6_helper_sql"
extract_function_ddl "$MIGRATION_FILE" 'CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)' "$v6_function_sql"

if ! env MIX_ENV=test mix run --no-start -e '
  module = AshPostgres.MigrationGenerator.AshFunctions
  version = module.latest_version()
  if version != 7, do: raise("expected AshPostgres ash-functions version 7, got #{version}")
  IO.write(module.install(6))
' > "$v7_generated" 2> "$work_dir/mix-run.stderr"; then
  cat "$work_dir/mix-run.stderr" >&2
  fail 'could not read the pinned AshPostgres 2.15.2 v7 migration output'
fi
[[ ! -s "$work_dir/mix-run.stderr" ]] || cat "$work_dir/mix-run.stderr" >&2
extract_function_ddl "$v7_generated" 'CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)' "$v7_function_sql"

[[ "$(grep -Fc 'CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)' "$v6_helper_sql")" == '1' ]] || fail 'v6 helper extraction is not exact'
[[ "$(grep -Fc 'CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)' "$v6_function_sql")" == '1' ]] || fail 'v6 ash_required extraction is not exact'
[[ "$(grep -Fc 'CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)' "$v7_function_sql")" == '1' ]] || fail 'v7 ash_required extraction is not exact'
grep -Fq 'RETURN ash_raise_error(payload, value);' "$v6_function_sql" || fail 'v6 NULL path no longer matches the checked-in migration'
grep -Fq "RAISE EXCEPTION 'ash_error: %', payload::text;" "$v7_function_sql" || fail 'v7 direct Ash error raise is missing'
grep -Fq 'RETURN value;' "$v7_function_sql" || fail 'v7 non-NULL return is missing'
grep -Fq "SET search_path = '';" "$v6_function_sql" || fail 'v6 empty search_path setting is missing'
grep -Fq "SET search_path = '';" "$v7_function_sql" || fail 'v7 empty search_path setting is missing'

printf 'ASH_FUNCTIONS_LATEST_VERSION=%s\n' "$EXPECTED_ASH_FUNCTIONS_VERSION"
printf 'V6_HELPER_SQL_SHA256=%s\n' "$(sha256sum "$v6_helper_sql" | awk '{print $1}')"
printf 'V6_ASH_REQUIRED_SQL_SHA256=%s\n' "$(sha256sum "$v6_function_sql" | awk '{print $1}')"
printf 'V7_ASH_REQUIRED_SQL_SHA256=%s\n' "$(sha256sum "$v7_function_sql" | awk '{print $1}')"
printf 'ASH_REQUIRED_SOURCE_DIFF_BEGIN\n'
if diff -u --label 'checked-in v6 migration' --label 'AshPostgres 2.15.2 install(6) v7' "$v6_function_sql" "$v7_function_sql" > "$work_dir/function.diff"; then
  printf 'ASH_REQUIRED_SOURCE_DIFF=NO_CHANGE\n'
else
  diff_status=$?
  [[ "$diff_status" == '1' ]] || fail 'could not compare v6 and v7 function SQL'
  cat "$work_dir/function.diff"
fi
printf 'ASH_REQUIRED_SOURCE_DIFF_END\n'
printf 'V7_GENERATED_FUNCTION_SQL_BEGIN\n'
cat "$v7_function_sql"
printf 'V7_GENERATED_FUNCTION_SQL_END\n'

server_version=$(capture_one admin_psql -Atq -c 'SHOW server_version') || fail 'could not read disposable PostgreSQL server version'
server_major=${server_version%%.*}
[[ "$server_major" == '18' ]] || fail "expected disposable PostgreSQL 18, got $server_version"
printf 'POSTGRES_SERVER_VERSION=%s\n' "$server_version"

collision_count=$(capture_one admin_psql -Atq -c "SELECT (SELECT count(*) FROM pg_database WHERE datname = '$PROOF_DATABASE') + (SELECT count(*) FROM pg_roles WHERE rolname IN ('$OWNER_ROLE', '$CALLER_ROLE'))") || fail 'could not check disposable service for role/database collisions'
[[ "$collision_count" == '0' ]] || fail 'proof database or roles already exist in the disposable service'
provisioning_started=true

admin_psql -c "CREATE ROLE $OWNER_ROLE LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOINHERIT NOBYPASSRLS"
admin_psql -c "CREATE ROLE $CALLER_ROLE LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOINHERIT NOBYPASSRLS"
admin_psql -c "GRANT $CALLER_ROLE TO $OWNER_ROLE WITH ADMIN FALSE, INHERIT FALSE, SET TRUE"
admin_psql -c "CREATE DATABASE $PROOF_DATABASE OWNER $OWNER_ROLE"
admin_psql -c "REVOKE ALL ON DATABASE $PROOF_DATABASE FROM PUBLIC"
admin_psql -c "GRANT CONNECT ON DATABASE $PROOF_DATABASE TO $CALLER_ROLE"

role_metadata=$(capture_one admin_psql -Atq -c "SELECT string_agg(rolname || ':' || CASE WHEN rolsuper THEN '1' ELSE '0' END || ':' || CASE WHEN rolcreatedb THEN '1' ELSE '0' END || ':' || CASE WHEN rolcreaterole THEN '1' ELSE '0' END || ':' || CASE WHEN rolreplication THEN '1' ELSE '0' END || ':' || CASE WHEN rolinherit THEN '1' ELSE '0' END || ':' || CASE WHEN rolbypassrls THEN '1' ELSE '0' END, ',' ORDER BY rolname) FROM pg_roles WHERE rolname IN ('$OWNER_ROLE', '$CALLER_ROLE')") || fail 'could not inspect proof roles'
printf 'PROOF_ROLE_METADATA=%s\n' "$role_metadata"
[[ "$role_metadata" == "$CALLER_ROLE:0:0:0:0:0:0,$OWNER_ROLE:0:0:0:0:0:0" ]] || fail 'proof roles have broader privileges than expected'
role_membership_options=$(capture_one admin_psql -Atq -c "SELECT CASE WHEN pg_has_role('$OWNER_ROLE', '$CALLER_ROLE', 'MEMBER') AND pg_has_role('$OWNER_ROLE', '$CALLER_ROLE', 'SET') AND NOT pg_has_role('$OWNER_ROLE', '$CALLER_ROLE', 'USAGE') AND (SELECT count(*) = 1 AND bool_and(set_option) AND NOT bool_or(inherit_option) AND NOT bool_or(admin_option) FROM pg_auth_members AS membership JOIN pg_roles AS target ON target.oid = membership.roleid JOIN pg_roles AS member ON member.oid = membership.member WHERE target.rolname = '$CALLER_ROLE' AND member.rolname = '$OWNER_ROLE') THEN 'PASS' ELSE 'FAIL' END") || fail 'could not inspect restricted role membership options'
[[ "$role_membership_options" == 'PASS' ]] || fail 'owner-to-caller role membership must allow SET only, without inheritance or admin'
printf 'OWNER_TO_CALLER_ROLE_MEMBERSHIP=SET_ONLY\n'

cat > "$v6_setup_sql" <<'SQL'
SET search_path = public;
SQL
cat "$v6_helper_sql" "$v6_function_sql" >> "$v6_setup_sql"
cat >> "$v6_setup_sql" <<SQL
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO $CALLER_ROLE;
REVOKE ALL ON FUNCTION public.ash_raise_error(jsonb, anycompatible) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ash_raise_error(jsonb, anycompatible) TO $CALLER_ROLE;
REVOKE ALL ON FUNCTION public.ash_required(anycompatible, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ash_required(anycompatible, jsonb) TO $CALLER_ROLE;
SQL
owner_psql -f "$v6_setup_sql"

function_count=$(capture_one owner_psql -Atq -c "$(function_count_sql)") || fail 'could not count installed ash_required functions'
[[ "$function_count" == '1' ]] || fail "expected one public ash_required function after v6 setup, got $function_count"

v6_identity=$(capture_one owner_psql -Atq -c "$(function_identity_sql)") || fail 'could not capture v6 pg_proc identity'
[[ "$v6_identity" == *$'\tpublic\t'* ]] || fail 'v6 ash_required is not in public schema'
function_signature_ok=$(capture_one owner_psql -Atq -c "SELECT CASE WHEN strpos(pg_get_function_identity_arguments(p.oid), 'anycompatible') > 0 AND strpos(pg_get_function_identity_arguments(p.oid), 'jsonb') > 0 AND pg_get_function_result(p.oid) = 'anycompatible' THEN 'PASS' ELSE 'FAIL' END FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2") || fail 'could not inspect v6 function signature'
[[ "$function_signature_ok" == 'PASS' ]] || fail 'v6 ash_required signature or return type changed'
printf 'FUNCTION_SIGNATURE_MATCH=%s\n' "$function_signature_ok"
[[ "$v6_identity" == *$'\t'"$OWNER_ROLE"$'\t'* ]] || fail 'v6 ash_required owner is not the restricted DDL role'
[[ "$v6_identity" == *"$CALLER_ROLE=X/$OWNER_ROLE"* ]] || fail 'v6 ash_required ACL does not grant the restricted caller EXECUTE'
v6_empty_search_path=$(capture_one owner_psql -Atq -c "SELECT CASE WHEN array_position(p.proconfig, concat('search_path=', chr(34), chr(34))) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2") || fail 'could not inspect v6 function search_path configuration'
[[ "$v6_empty_search_path" == 'PASS' ]] || fail 'v6 ash_required does not record an empty function search_path'
printf 'V6_EMPTY_SEARCH_PATH=%s\n' "$v6_empty_search_path"

v6_metadata=$(capture_one owner_psql -Atq -c "$(function_metadata_sql)") || fail 'could not capture full v6 pg_proc metadata'
v6_definition_file="$work_dir/v6.pg_get_functiondef.sql"
owner_psql -Atq -c "$(function_definition_sql)" > "$v6_definition_file"
v6_body_hash=$(capture_one owner_psql -Atq -c "$(function_body_hash_sql)") || fail 'could not hash v6 definition'
printf 'V6_PG_PROC=%s\n' "$v6_metadata"
printf 'V6_IDENTITY=%s\n' "$v6_identity"
printf 'V6_BODY_MD5=%s\n' "$v6_body_hash"
printf 'V6_FUNCTION_DEFINITION_BEGIN\n'
cat "$v6_definition_file"
printf 'V6_FUNCTION_DEFINITION_END\n'

caller_schema_usage=$(capture_one owner_psql -Atq -c "SELECT has_schema_privilege('$CALLER_ROLE', 'public', 'USAGE')") || fail 'could not check caller schema permission'
caller_execute=$(capture_one owner_psql -Atq -c "SELECT has_function_privilege('$CALLER_ROLE', 'public.ash_required(anycompatible,jsonb)', 'EXECUTE')") || fail 'could not check caller function permission'
[[ "$caller_schema_usage" == 't' && "$caller_execute" == 't' ]] || fail 'restricted caller lacks required schema/function permission'
printf 'V6_CALLER_SCHEMA_USAGE=%s\n' "$caller_schema_usage"
printf 'V6_CALLER_FUNCTION_EXECUTE=%s\n' "$caller_execute"

public_table_count=$(capture_one owner_psql -Atq -c "SELECT count(*) FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')") || fail 'could not verify empty application schema'
[[ "$public_table_count" == '0' ]] || fail 'unexpected tables exist in the proof database'
printf 'PUBLIC_APPLICATION_TABLES_BEFORE=%s\n' "$public_table_count"

cat > "$work_dir/v6-null-probe.sql" <<'SQL'
\set ON_ERROR_STOP on
\set VERBOSITY terse
BEGIN;
SAVEPOINT null_probe;
DO $jc361$
DECLARE
  result_value text;
  error_state text;
  error_message text;
BEGIN
  RAISE NOTICE '@PREFIX@_NULL_CURRENT_USER=%', current_user;
  BEGIN
    result_value := public.ash_required(NULL::text, '{"field":"required"}'::jsonb);
    IF result_value IS NULL THEN
      RAISE NOTICE '@PREFIX@_NULL_RETURNED=NULL';
    ELSE
      RAISE NOTICE '@PREFIX@_NULL_RETURNED_VALUE=%', result_value;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_state = RETURNED_SQLSTATE, error_message = MESSAGE_TEXT;
    RAISE NOTICE '@PREFIX@_NULL_SQLSTATE=%', error_state;
    RAISE NOTICE '@PREFIX@_NULL_MESSAGE=%', error_message;
  END;
END;
$jc361$;
ROLLBACK TO SAVEPOINT null_probe;
SELECT '@PREFIX@_SAVEPOINT_RECOVERED=1';
COMMIT;
SQL
sed -i 's/@PREFIX@/V6/g' "$work_dir/v6-null-probe.sql"
if caller_psql -f "$work_dir/v6-null-probe.sql" > "$work_dir/v6-null.log" 2>&1; then
  cat "$work_dir/v6-null.log"
else
  cat "$work_dir/v6-null.log" >&2
  fail 'v6 typed NULL probe could not complete under the restricted caller role'
fi
v6_null_result=$(parse_null_result 'V6' "$work_dir/v6-null.log") || fail 'v6 probe has missing, duplicate, or conflicting NULL-result notices'
IFS=$'\t' read -r v6_null_kind v6_null_state v6_null_message <<< "$v6_null_result"
[[ "$v6_null_kind" == 'ERROR' ]] || fail "v6 NULL result kind was '$v6_null_kind', expected ERROR"
[[ "$v6_null_state" == '42883' ]] || fail "v6 NULL SQLSTATE was '$v6_null_state', expected 42883"
[[ "$v6_null_message" == 'function ash_raise_error(jsonb, text) does not exist' ]] || fail "v6 NULL message was '$v6_null_message', expected missing ash_raise_error helper"
printf 'V6_NULL_KIND=%s\n' "$v6_null_kind"
printf 'V6_NULL_SQLSTATE=%s\n' "$v6_null_state"
printf 'V6_NULL_MESSAGE=%s\n' "$v6_null_message"

v6_null_current_user=$(notice_value 'V6_NULL_CURRENT_USER' "$work_dir/v6-null.log") || fail 'v6 NULL probe has a missing or duplicate current-user notice'
[[ "$v6_null_current_user" == "$CALLER_ROLE" ]] || fail 'v6 NULL call did not run as the restricted caller'
v6_savepoint_recovered=$(capture_labeled_value 'V6_SAVEPOINT_RECOVERED' "$work_dir/v6-null.log") || fail 'v6 NULL probe has a missing or duplicate savepoint result'
[[ "$v6_savepoint_recovered" == '1' ]] || fail 'v6 NULL probe did not recover to its savepoint'

v6_nonnull=$(capture_one caller_psql -Atq -c "SELECT public.ash_required('jc361-proof-value'::text, '{\"field\":\"required\"}'::jsonb)") || fail 'v6 typed non-NULL call failed'
[[ "$v6_nonnull" == 'jc361-proof-value' ]] || fail "unexpected v6 non-NULL result: $v6_nonnull"
printf 'V6_NONNULL_RESULT=%s\n' "$v6_nonnull"

v7_transaction_sql="$work_dir/v7-transaction.sql"
{
  cat <<'SQL'
\set ON_ERROR_STOP on
\set VERBOSITY terse
CREATE TEMP TABLE jc361_v6_baseline AS
SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) AS function_identity,
       md5(pg_get_functiondef(p.oid)) AS body_md5,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
JOIN pg_language AS l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
BEGIN;
SET LOCAL search_path = public;
\echo V7_TRANSACTION_BEGIN
SQL
  printf '\\i %s\n' "$v7_function_sql"
  cat <<'SQL'
\echo V7_FUNCTION_REPLACED_ONCE
SELECT 'V7_IDENTITY_ONCE=' || (SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace JOIN pg_language AS l ON l.oid = p.prolang WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
DO $jc361_assert$
DECLARE
  identity_matches boolean;
BEGIN
  SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) = (SELECT function_identity FROM pg_temp.jc361_v6_baseline)
  INTO identity_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  JOIN pg_language AS l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF identity_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'v7 replacement changed function identity or permissions';
  END IF;
END;
$jc361_assert$;
\echo V7_IDENTITY_PRESERVED=PASS
CREATE TEMP TABLE jc361_v7_baseline AS
SELECT md5(pg_get_functiondef(p.oid)) AS body_md5
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'ash_required'
  AND p.pronargs = 2;
SELECT 'V7_BODY_MD5_ONCE=' || body_md5 FROM pg_temp.jc361_v7_baseline;
SELECT 'V7_PG_PROC=' || (SELECT jsonb_build_object('oid', p.oid, 'schema', n.nspname, 'signature', pg_get_function_identity_arguments(p.oid), 'return_type', pg_get_function_result(p.oid), 'owner', pg_get_userbyid(p.proowner), 'acl', COALESCE(p.proacl::text, '<NULL>'), 'proconfig', COALESCE(p.proconfig::text, '<NULL>'), 'language', l.lanname, 'volatility', p.provolatile, 'security_definer', p.prosecdef, 'strict', p.proisstrict, 'parallel', p.proparallel, 'definition', pg_get_functiondef(p.oid))::text FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace JOIN pg_language AS l ON l.oid = p.prolang WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
\echo V7_FUNCTION_DEFINITION_BEGIN
SELECT pg_get_functiondef(p.oid) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2;
\echo V7_FUNCTION_DEFINITION_END
SAVEPOINT v7_nonnull_probe;
SET LOCAL ROLE jc361_ash_functions_caller;
SELECT 'V7_NONNULL_CURRENT_USER=' || current_user;
SELECT 'V7_NONNULL_RESULT=' || public.ash_required('jc361-proof-value'::text, '{"field":"required"}'::jsonb);
ROLLBACK TO SAVEPOINT v7_nonnull_probe;
SAVEPOINT v7_null_probe;
SET LOCAL ROLE jc361_ash_functions_caller;
DO $jc361$
DECLARE
  result_value text;
  error_state text;
  error_message text;
BEGIN
  RAISE NOTICE 'V7_NULL_CURRENT_USER=%', current_user;
  BEGIN
    result_value := public.ash_required(NULL::text, '{"field":"required"}'::jsonb);
    IF result_value IS NULL THEN
      RAISE NOTICE 'V7_NULL_RETURNED=NULL';
    ELSE
      RAISE NOTICE 'V7_NULL_RETURNED_VALUE=%', result_value;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_state = RETURNED_SQLSTATE, error_message = MESSAGE_TEXT;
    RAISE NOTICE 'V7_NULL_SQLSTATE=%', error_state;
    RAISE NOTICE 'V7_NULL_MESSAGE=%', error_message;
  END;
END;
$jc361$;
ROLLBACK TO SAVEPOINT v7_null_probe;
SELECT 'V7_SAVEPOINT_RECOVERED=1';
SQL
  printf '\\i %s\n' "$v7_function_sql"
  cat <<'SQL'
\echo V7_FUNCTION_REPLACED_TWICE
SELECT 'V7_IDENTITY_REPEAT=' || (SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace JOIN pg_language AS l ON l.oid = p.prolang WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
SELECT 'V7_BODY_MD5_REPEAT=' || (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
DO $jc361_assert$
DECLARE
  identity_matches boolean;
BEGIN
  SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) = (SELECT function_identity FROM pg_temp.jc361_v6_baseline)
  INTO identity_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  JOIN pg_language AS l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF identity_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'repeated v7 replacement changed function identity or permissions';
  END IF;
END;
$jc361_assert$;
\echo V7_REPEAT_IDENTITY_PRESERVED=PASS
DO $jc361_assert$
DECLARE
  body_matches boolean;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)) = (SELECT body_md5 FROM pg_temp.jc361_v7_baseline)
  INTO body_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF body_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'repeated v7 replacement changed the function definition';
  END IF;
END;
$jc361_assert$;
\echo V7_REPEAT_BODY_PRESERVED=PASS
ROLLBACK;
\echo V7_TRANSACTION_ROLLED_BACK
SELECT 'ROLLBACK_IDENTITY=' || (SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace JOIN pg_language AS l ON l.oid = p.prolang WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
SELECT 'ROLLBACK_BODY_MD5=' || (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
DO $jc361_assert$
DECLARE
  identity_matches boolean;
BEGIN
  SELECT concat_ws(E'\t', p.oid::text, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), pg_get_userbyid(p.proowner), COALESCE(p.proacl::text, '<NULL>'), COALESCE(p.proconfig::text, '<NULL>'), l.lanname, p.provolatile::text, p.prosecdef::text, p.proisstrict::text, p.proparallel::text) = (SELECT function_identity FROM pg_temp.jc361_v6_baseline)
  INTO identity_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  JOIN pg_language AS l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF identity_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'transaction rollback did not restore function identity or permissions';
  END IF;
END;
$jc361_assert$;
\echo ROLLBACK_IDENTITY_RESTORED=PASS
DO $jc361_assert$
DECLARE
  body_matches boolean;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)) = (SELECT body_md5 FROM pg_temp.jc361_v6_baseline)
  INTO body_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF body_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'transaction rollback did not restore the v6 function body';
  END IF;
END;
$jc361_assert$;
\echo ROLLBACK_BODY_RESTORED=PASS
DO $jc361_assert$
DECLARE
  definition_matches boolean;
BEGIN
  SELECT pg_get_functiondef(p.oid) = (SELECT definition FROM pg_temp.jc361_v6_baseline)
  INTO definition_matches
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'ash_required'
    AND p.pronargs = 2;

  IF definition_matches IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'transaction rollback did not restore the exact v6 definition';
  END IF;
END;
$jc361_assert$;
\echo ROLLBACK_DEFINITION_RESTORED=PASS
SELECT 'ROLLBACK_PG_PROC=' || (SELECT jsonb_build_object('oid', p.oid, 'schema', n.nspname, 'signature', pg_get_function_identity_arguments(p.oid), 'return_type', pg_get_function_result(p.oid), 'owner', pg_get_userbyid(p.proowner), 'acl', COALESCE(p.proacl::text, '<NULL>'), 'proconfig', COALESCE(p.proconfig::text, '<NULL>'), 'language', l.lanname, 'volatility', p.provolatile, 'security_definer', p.prosecdef, 'strict', p.proisstrict, 'parallel', p.proparallel, 'definition', pg_get_functiondef(p.oid))::text FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace JOIN pg_language AS l ON l.oid = p.prolang WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2);
\echo ROLLBACK_FUNCTION_DEFINITION_BEGIN
SELECT pg_get_functiondef(p.oid) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'ash_required' AND p.pronargs = 2;
\echo ROLLBACK_FUNCTION_DEFINITION_END
SQL
} > "$v7_transaction_sql"

if owner_psql -f "$v7_transaction_sql" > "$work_dir/v7-transaction.log" 2>&1; then
  cat "$work_dir/v7-transaction.log"
else
  cat "$work_dir/v7-transaction.log" >&2
  fail 'v7 replacement transaction or rollback verification failed'
fi

v7_identity_once=$(capture_labeled_value 'V7_IDENTITY_ONCE' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate first-replacement identity'
v7_identity_repeat=$(capture_labeled_value 'V7_IDENTITY_REPEAT' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate repeated-replacement identity'
v7_body_once=$(capture_labeled_value 'V7_BODY_MD5_ONCE' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate first-replacement body hash'
v7_body_repeat=$(capture_labeled_value 'V7_BODY_MD5_REPEAT' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate repeated-replacement body hash'
rollback_identity=$(capture_labeled_value 'ROLLBACK_IDENTITY' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate rollback identity'
rollback_body=$(capture_labeled_value 'ROLLBACK_BODY_MD5' "$work_dir/v7-transaction.log") || fail 'transaction log has a missing or duplicate rollback body hash'
[[ "$v7_identity_once" == "$v6_identity" ]] || fail 'schema, signature, OID, owner, ACL, configuration, or function properties changed during replacement'
[[ "$v7_identity_repeat" == "$v6_identity" ]] || fail 'repeated replacement changed function identity or permissions'
[[ "$v7_body_once" == "$v7_body_repeat" ]] || fail 'repeated replacement changed the generated v7 SQL definition'
[[ "$rollback_identity" == "$v6_identity" ]] || fail 'transaction rollback did not restore v6 function identity or permissions'
[[ "$rollback_body" == "$v6_body_hash" ]] || fail 'transaction rollback did not restore the original v6 function body'
rollback_definition_file="$work_dir/rollback.pg_get_functiondef.sql"
owner_psql -Atq -c "$(function_definition_sql)" > "$rollback_definition_file"
cmp -s "$v6_definition_file" "$rollback_definition_file" || fail 'pg_get_functiondef differs after rollback'

v7_null_result=$(parse_null_result 'V7' "$work_dir/v7-transaction.log") || fail 'v7 probe has missing, duplicate, or conflicting NULL-result notices'
IFS=$'\t' read -r v7_null_kind v7_null_state v7_null_message <<< "$v7_null_result"
[[ "$v7_null_kind" == 'ERROR' ]] || fail "v7 NULL path returned instead of raising the expected Ash error ($v7_null_kind)"
[[ "$v7_null_state" == 'P0001' ]] || fail "v7 NULL SQLSTATE was '$v7_null_state', expected P0001"
[[ "$v7_null_message" == 'ash_error: {"field": "required"}' ]] || fail "v7 NULL message was '$v7_null_message', expected ash_error payload for field required"
printf 'V7_NULL_SQLSTATE=%s\n' "$v7_null_state"
printf 'V7_NULL_MESSAGE=%s\n' "$v7_null_message"
v7_null_current_user=$(notice_value 'V7_NULL_CURRENT_USER' "$work_dir/v7-transaction.log") || fail 'v7 NULL probe has a missing or duplicate current-user notice'
[[ "$v7_null_current_user" == "$CALLER_ROLE" ]] || fail 'v7 NULL call did not run as the restricted caller'
v7_nonnull_current_user=$(capture_labeled_value 'V7_NONNULL_CURRENT_USER' "$work_dir/v7-transaction.log") || fail 'v7 non-NULL probe has a missing or duplicate current-user result'
[[ "$v7_nonnull_current_user" == "$CALLER_ROLE" ]] || fail 'v7 non-NULL call did not run as the restricted caller'
v7_nonnull=$(capture_labeled_value 'V7_NONNULL_RESULT' "$work_dir/v7-transaction.log") || fail 'v7 non-NULL probe has a missing or duplicate result'
[[ "$v7_nonnull" == "$v6_nonnull" ]] || fail 'non-NULL result changed between v6 and v7'
v7_savepoint_recovered=$(capture_labeled_value 'V7_SAVEPOINT_RECOVERED' "$work_dir/v7-transaction.log") || fail 'v7 NULL probe has a missing or duplicate savepoint result'
[[ "$v7_savepoint_recovered" == '1' ]] || fail 'v7 NULL probe did not recover to its savepoint'

rollback_v6_sql="$work_dir/rollback-v6-null-probe.sql"
sed 's/V6/ROLLBACK_V6/g' "$work_dir/v6-null-probe.sql" > "$rollback_v6_sql"
if caller_psql -f "$rollback_v6_sql" > "$work_dir/rollback-v6-null.log" 2>&1; then
  cat "$work_dir/rollback-v6-null.log"
else
  cat "$work_dir/rollback-v6-null.log" >&2
  fail 'post-rollback v6 NULL behavior could not be checked'
fi
rollback_v6_result=$(parse_null_result 'ROLLBACK_V6' "$work_dir/rollback-v6-null.log") || fail 'post-rollback v6 probe has missing, duplicate, or conflicting NULL-result notices'
IFS=$'\t' read -r rollback_v6_kind rollback_v6_state rollback_v6_message <<< "$rollback_v6_result"
[[ "$rollback_v6_kind" == "$v6_null_kind" && "$rollback_v6_state" == "$v6_null_state" && "$rollback_v6_message" == "$v6_null_message" ]] || fail 'post-rollback v6 NULL behavior differs from the original v6 call'
rollback_v6_current_user=$(notice_value 'ROLLBACK_V6_NULL_CURRENT_USER' "$work_dir/rollback-v6-null.log") || fail 'post-rollback v6 probe has a missing or duplicate current-user notice'
[[ "$rollback_v6_current_user" == "$CALLER_ROLE" ]] || fail 'post-rollback v6 NULL call did not run as the restricted caller'
rollback_v6_savepoint=$(capture_labeled_value 'ROLLBACK_V6_SAVEPOINT_RECOVERED' "$work_dir/rollback-v6-null.log") || fail 'post-rollback v6 probe has a missing or duplicate savepoint result'
[[ "$rollback_v6_savepoint" == '1' ]] || fail 'post-rollback v6 probe did not recover to its savepoint'

rollback_nonnull=$(capture_one caller_psql -Atq -c "SELECT public.ash_required('jc361-proof-value'::text, '{\"field\":\"required\"}'::jsonb)") || fail 'post-rollback v6 non-NULL call failed'
[[ "$rollback_nonnull" == "$v6_nonnull" ]] || fail 'post-rollback non-NULL behavior differs from original v6'
public_table_count_after=$(capture_one owner_psql -Atq -c "SELECT count(*) FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')") || fail 'could not verify proof database remained free of application tables'
[[ "$public_table_count_after" == '0' ]] || fail 'unexpected tables were created in the proof database'

printf 'NON_NULL_BEHAVIOR=PASS:%s\n' "$v6_nonnull"
printf 'FUNCTION_IDENTITY=PASS:%s\n' "$v6_identity"
printf 'OWNER_ACL_PRESERVED=PASS\n'
printf 'DDL_IDEMPOTENCY=PASS\n'
printf 'ROLLBACK_RESTORATION=PASS\n'
printf 'APPLICATION_TABLES_AFTER=%s\n' "$public_table_count_after"

if ! cleanup_database; then
  printf 'DATABASE_CLEANUP=FAIL\n' >&2
  fail 'bounded disposable database/role cleanup failed; no retry will be attempted'
fi
printf 'DATABASE_CLEANUP=PASS\n'
provisioning_started=false
printf 'CI_DISPOSABLE_PROOF=PASS\n'
