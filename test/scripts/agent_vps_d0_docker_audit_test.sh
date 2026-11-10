#!/usr/bin/env bash
set -euo pipefail
set +x
export LC_ALL=C
repo_root=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
python3 -I -S -B - "$repo_root" <<'PY'
import fcntl
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import types
import unittest

ROOT = pathlib.Path(sys.argv[1])
WRAPPER = ROOT / 'deploy/vps/operator/agent-vps-d0-docker-audit'


class AuditContractTests(unittest.TestCase):
    def test_privileged_source_exists(self):
        self.assertTrue(WRAPPER.is_file(), 'approved audit wrapper is not implemented')

    def test_source_boundary_and_ci(self):
        source = WRAPPER.read_text()
        self.assertEqual(source.splitlines()[0], '#!/bin/bash -p')
        self.assertIn('/usr/bin/env -i', source)
        self.assertIn('/usr/bin/python3 -I -S -B', source)
        sudoers = WRAPPER.with_name(WRAPPER.name + '.sudoers').read_text()
        self.assertEqual(sudoers, 'agentops ALL=(root) NOPASSWD: /usr/local/sbin/agent-vps-d0-docker-audit ""\n')
        self.assertIn('bash test/scripts/agent_vps_d0_docker_audit_test.sh',
                      (ROOT / '.github/workflows/ci.yml').read_text())
        compile(source.split("<<'PY'", 1)[1].rsplit('\nPY', 1)[0], 'audit-collector', 'exec')

    def test_bash_entry_environment_isolation(self):
        with tempfile.TemporaryDirectory(prefix='eventsales-r5-entry-') as temp:
            base = pathlib.Path(temp)
            hostile = base / 'hostile'
            hostile.write_text('printf SENSITIVE_SENTINEL')
            prefix = WRAPPER.read_text().split("<<'PY'", 1)[0]
            prefix = prefix.replace('EUID != 0', 'EUID != ' + str(os.geteuid()))
            fixture = base / 'entry'
            fixture.write_text(prefix + "<<'PY'\n" +
                               'import os,sys\n' +
                               'assert sys.flags.isolated and sys.flags.no_site and sys.flags.dont_write_bytecode\n' +
                               'assert not any(k.startswith(("BASH_", "PYTHON", "LD_")) for k in os.environ)\n' +
                               'assert os.getcwd() == "/"\n' +
                               'assert os.umask(0o077) == 0o077\n' +
                               'print("ENTRY=PASS")\nPY\n')
            fixture.chmod(0o700)
            env = dict(os.environ, BASH_ENV=str(hostile), ENV=str(hostile),
                       PYTHONPATH=str(base), PYTHONINSPECT='1', SHELLOPTS='xtrace')
            env['BASH_FUNC_printf%%'] = '() { builtin printf SENSITIVE_SENTINEL; }'
            result = subprocess.run([str(fixture)], env=env, capture_output=True, timeout=3)
            if b'SENSITIVE_SENTINEL' in result.stdout + result.stderr:
                self.fail('STOP=R5_HOSTILE_ENVIRONMENT_EXECUTION')
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b'ENTRY=PASS\n')
            self.assertEqual(result.stderr, b'')
            rejected = subprocess.run([str(fixture), 'unexpected'], capture_output=True, timeout=3)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertNotIn(b'ENTRY=PASS', rejected.stdout)


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='eventsales-r5-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = pathlib.Path(self.temp.name)
        self.prod = self.base / 'root' / 'eventsales-prod'
        self.prod.mkdir(parents=True, mode=0o700)
        self.prod.parent.chmod(0o700)
        self.log = self.base / 'calls'
        self.state = self.base / 'state.json'
        self.fake = self.base / 'docker'
        self.runner = self.base / 'runner.py'
        self.ids = [str(i) * 64 for i in range(1, 7)]
        self.names = ['eventsales-prod-' + s + '-1' for s in ('postgres', 'pgbouncer', 'redis')]
        self.names += ['eventsales-d0-proof-' + s + '-1' for s in ('postgres', 'pgbouncer', 'redis')]
        self.data_id = 'a' * 64
        self.edge_id = 'b' * 64
        self.d0_id = 'c' * 64
        self.pg_image = 'dhi.io/postgres:18.6-alpine3.24@sha256:d33bd884995daddfb515d0ce9aec23b74d20d72e03ca42b72c4abf617c76bb19'
        self.redis_image = 'dhi.io/redis:8.10.2-debian13@sha256:953ca2c2ab4ff7a93f8abac31339ba4d913ec0914861453ab4faa29d154115a0'
        images = [self.pg_image,
                  'ghcr.io/jcschoeman96/eventsales-pgbouncer@sha256:965b0223f1096666471e11595f4f6dc5d32dfacbc688418b8ae2385946c41e3b', self.redis_image,
                  self.pg_image,
                  'dhi.io/pgbouncer:1.26.1-debian13@sha256:78fe21ad5b7c1ab497e9828eea9b951f9d6a58eb638946ddc61ef1f99737f1b1', self.redis_image]
        records = []
        containers = {}
        for index, (ident, name, image) in enumerate(zip(self.ids, self.names, images)):
            project = 'eventsales-prod' if index < 3 else 'eventsales-d0-proof'
            service = ('postgres', 'pgbouncer', 'redis')[index % 3]
            records.append('\t'.join((ident, name, project, service)))
            containers[ident] = {
                'ID': ident, 'State': 'running' if index < 3 else 'exited',
                'Health': 'healthy', 'RestartCount': 0, 'OOMKilled': False,
                'Image': image, 'Memory': [3221225472, 134217728, 536870912, 3221225472, 67108864, 536870912][index],
                'NanoCPUs': 2000000000 if index % 3 == 0 else 500000000,
                'PidsLimit': None,
                'Networks': {project + '_eventsales_data': self.data_id if index < 3 else self.d0_id},
                'PortBindings': 0, 'PostgresVolume': True}
        self.fixture = {'inventory': '\n'.join(records) + '\n', 'containers': containers,
                        'networks': {'eventsales-prod_eventsales_data': self.data_id + '|eventsales-prod_eventsales_data|bridge|true',
                                     'eventsales-prod_eventsales_edge': self.edge_id + '|eventsales-prod_eventsales_edge|bridge|false'},
                        'volume': 'eventsales-prod_postgres_data|local|local', 'mode': 'normal'}
        self.fake.write_text('#!/usr/bin/env -S /usr/bin/python3 -I -S -B\n' + FAKE_DOCKER)
        self.fake.chmod(0o700)
        self.runner.write_text(RUNNER)

    def run_audit(self, *, patches=None):
        self.state.write_text(json.dumps(self.fixture))
        config = {'DOCKER': str(self.fake), 'ROOT_UID': os.getuid(), 'ROOT_GID': os.getgid(),
                  'MARKER_ROOT': str(self.prod), 'TRUSTED_ROOT': str(self.base),
                  'PER_COMMAND_SECONDS': 0.3, 'WORK_SECONDS': 4, 'TOTAL_SECONDS': 6,
                  'TERM_SECONDS': 0.1, 'REAP_SECONDS': 0.2}
        config.update(patches or {})
        started = time.monotonic()
        result = subprocess.run([sys.executable, '-I', '-S', '-B', str(self.runner), str(WRAPPER),
                                 json.dumps(config)], capture_output=True, timeout=9)
        self.assertLess(time.monotonic() - started, 9)
        if b'SENSITIVE_SENTINEL' in result.stdout + result.stderr:
            raise AssertionError('STOP=R5_SENSITIVE_OUTPUT_LEAK')
        if b'Traceback' in result.stdout + result.stderr:
            raise AssertionError('STOP=R5_TRACEBACK_LEAK')
        self.assertLessEqual(len(result.stdout) + len(result.stderr), 16384)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        self.assertLessEqual(len(calls), 10)
        for call in calls:
            self.assertEqual(call[:2], ['--host', 'unix:///var/run/docker.sock'])
            self.assertIn(call[2], ('ps', 'inspect', 'network', 'volume'))
        report = {}
        for line in result.stdout.decode('ascii').splitlines():
            key, value = line.split('=', 1)
            self.assertNotIn(key, report)
            report[key] = value
        self.assertEqual(report.get('REPORT_END'), 'YES')
        return result.returncode, report, calls

    def test_complete_operational_contract(self):
        code, report, calls = self.run_audit()
        self.assertEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'COMPLETE')
        self.assertEqual(report['OPERATIONAL_CONTRACT'], 'PASS')
        self.assertEqual(len(calls), 10)
        self.assertEqual(report['V3_ACCEPTANCE'], 'UNRESOLVED')

    def test_compliance_separate_from_collection(self):
        for field, value in [('Health', 'unhealthy'), ('RestartCount', 2), ('Memory', 1),
                             ('PortBindings', 1), ('OOMKilled', True), ('Image', self.redis_image)]:
            with self.subTest(field=field):
                original = self.fixture['containers'][self.ids[0]][field]
                self.fixture['containers'][self.ids[0]][field] = value
                self.log.unlink(missing_ok=True)
                code, report, _ = self.run_audit()
                self.assertEqual(code, 0)
                self.assertEqual(report['COLLECTION_RESULT'], 'COMPLETE')
                self.assertEqual(report['OPERATIONAL_CONTRACT'], 'MISMATCH')
                self.fixture['containers'][self.ids[0]][field] = original

    def test_inventory_absence_does_not_inspect_missing(self):
        self.fixture['inventory'] = '\n'.join(self.fixture['inventory'].splitlines()[1:]) + '\n'
        _, report, calls = self.run_audit()
        self.assertIn('NO_AT_INVENTORY', report.values())
        self.assertFalse(any(self.ids[0] == arg for call in calls for arg in call))
        self.assertEqual(report['OPERATIONAL_CONTRACT'], 'MISMATCH')

    def test_daemon_failure_never_reports_absence(self):
        self.fixture['mode'] = 'daemon_failure'
        code, report, calls = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')
        self.assertNotIn('NO_AT_INVENTORY', report.values())
        self.assertEqual(len(calls), 1)

    def test_inspect_failure_not_absence(self):
        self.fixture['mode'] = 'inspect_failure'
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertNotIn('NO_AT_INVENTORY', report.values())
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_malformed_inventory(self):
        original = self.fixture['inventory']
        for data in ['SENSITIVE_SENTINEL\n', original * 2,
                     'x' * 513, '1' * 64 + '\tbad\x1bname\tproject\tservice\n']:
            with self.subTest(length=len(data)):
                self.fixture['inventory'] = data
                self.log.unlink(missing_ok=True)
                code, report, _ = self.run_audit()
                self.assertNotEqual(code, 0)
                self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_numeric_protocol_rejected(self):
        for value in [True, -1, 2**64, 'SENSITIVE_SENTINEL']:
            with self.subTest(value_type=type(value).__name__):
                self.fixture['containers'][self.ids[0]]['RestartCount'] = value
                self.log.unlink(missing_ok=True)
                code, report, _ = self.run_audit()
                self.assertNotEqual(code, 0)
                self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_unvalidated_fields_never_emitted(self):
        for field in ('State', 'Health', 'Image'):
            with self.subTest(field=field):
                original = self.fixture['containers'][self.ids[0]][field]
                self.fixture['containers'][self.ids[0]][field] = 'SENSITIVE_SENTINEL'
                self.log.unlink(missing_ok=True)
                _, report, _ = self.run_audit()
                self.assertNotEqual(report['OPERATIONAL_CONTRACT'], 'PASS')
                self.fixture['containers'][self.ids[0]][field] = original

    def test_volume_metadata_is_not_echoed(self):
        self.fixture['volume'] = 'eventsales-prod_postgres_data|SENSITIVE_SENTINEL|local'
        _, report, _ = self.run_audit()
        self.assertNotEqual(report['OPERATIONAL_CONTRACT'], 'PASS')

    def test_bounded_subprocess_failures(self):
        for mode in ('stdout_flood', 'stderr_flood', 'hang', 'malformed_json'):
            with self.subTest(mode=mode):
                self.fixture['mode'] = mode
                self.log.unlink(missing_ok=True)
                code, report, _ = self.run_audit()
                self.assertNotEqual(code, 0)
                self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_global_deadline(self):
        self.fixture['mode'] = 'slow'
        code, report, calls = self.run_audit(patches={'WORK_SECONDS': 0.4, 'TOTAL_SECONDS': 2})
        self.assertNotEqual(code, 0)
        self.assertLess(len(calls), 10)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_unknown_inventory_record_is_counted_not_printed(self):
        self.fixture['inventory'] += 'd' * 64 + '\teventsales-prod-extra-1\teventsales-prod\textra\n'
        code, report, _ = self.run_audit()
        self.assertEqual(code, 0)
        self.assertEqual(report['UNEXPECTED_MATCHING_CONTAINER_COUNT'], '1')
        self.assertEqual(report['OPERATIONAL_CONTRACT'], 'MISMATCH')
        self.assertNotIn('eventsales-prod-extra-1', '\n'.join(report.values()))

    def test_lookalike_name_is_not_an_expected_container(self):
        self.fixture['inventory'] = self.fixture['inventory'].replace(
            'eventsales-prod-postgres-1', 'eventsales-prod-proof-postgres-1')
        _, report, calls = self.run_audit()
        self.assertEqual(report['UNEXPECTED_MATCHING_CONTAINER_COUNT'], '1')
        self.assertEqual(report['PROD_POSTGRES_PRESENT'], 'NO_AT_INVENTORY')
        self.assertFalse(any(self.ids[0] == arg for call in calls for arg in call))

    def test_valid_marker_and_stage_metadata(self):
        marker = self.prod / '.v4-pgbouncer-redis-start-consumed'
        marker.mkdir(mode=0o700)
        stage = self.prod / 'staged' / 'c9ce0f9239123a6e58f66fde0b5a1e60238bb107'
        stage.mkdir(parents=True, mode=0o555)
        stage.parent.chmod(0o700)
        _, report, _ = self.run_audit()
        self.assertEqual(report['MARKER_V4_PGBOUNCER_REDIS_START_CONSUMED_STATE'], 'SAFE')
        self.assertEqual(report['STAGE_C9CE0F9239123A6E58F66FDE0B5A1E60238BB107_STATE'], 'SAFE')
        self.assertTrue(any(k.endswith('_MTIME_UTC') for k in report))

    def test_exact_command_allowlist_and_count(self):
        module = {'__name__': 'audit_unit'}
        source = WRAPPER.read_text().split("<<'PY'", 1)[1].rsplit('\nPY', 1)[0]
        exec(compile(source, 'audit-collector', 'exec'), module)
        module['DOCKER'] = str(self.fake)
        allowed = module['allowed_command']
        for args in (['exec', 'container', 'anything'], ['network', 'rm', 'network'],
                     ['inspect', '--format', '{{json .Config.Env}}', '1' * 64],
                     ['ps', '-a'], ['volume', 'inspect', '--format', module['VOLUME_FORMAT'], 'unrelated']):
            self.assertFalse(allowed(args))
        module['command_count'] = 10
        valid = ['volume', 'inspect', '--format', module['VOLUME_FORMAT'], module['PROD_VOLUME']]
        # The limit is checked before Popen; no external executable is reached.
        with self.assertRaises(module['AuditError']) as caught:
            module['run_docker'](valid)
        self.assertEqual(caught.exception.code, 'DOCKER_COMMAND_LIMIT')

    def test_unconfirmed_reap_has_fixed_failure_code(self):
        module = {'__name__': 'audit_unit'}
        source = WRAPPER.read_text().split("<<'PY'", 1)[1].rsplit('\nPY', 1)[0]
        exec(compile(source, 'audit-collector', 'exec'), module)
        signals = []
        module['os'] = types.SimpleNamespace(killpg=lambda pid, sig: signals.append(sig))
        module['deadline'] = time.monotonic() + 1
        module['TERM_SECONDS'] = 0
        class UnreapableFixture:
            pid = 123
            def wait(self, timeout):
                raise subprocess.TimeoutExpired('fixture', timeout)
        with self.assertRaises(module['AuditError']) as caught:
            module['cleanup'](UnreapableFixture())
        self.assertEqual(caught.exception.code, 'CLEANUP_UNRESOLVED')
        self.assertEqual(signals, [15, 9])

    def test_inventory_record_count_limit(self):
        self.fixture['inventory'] = ''.join(str(i % 10) * 64 + '\teventsales-prod-extra-' + str(i) + '\teventsales-prod\textra\n' for i in range(13))
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_invalid_network_result(self):
        self.fixture['networks']['eventsales-prod_eventsales_data'] = 'SENSITIVE_SENTINEL'
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_wrong_container_network_membership(self):
        self.fixture['containers'][self.ids[0]]['Networks'] = {'unapproved': 'c' * 64}
        code, report, _ = self.run_audit()
        self.assertEqual(code, 0)
        self.assertEqual(report['OPERATIONAL_CONTRACT'], 'MISMATCH')

    def test_inspect_identity_changed(self):
        self.fixture['containers'][self.ids[0]]['ID'] = 'f' * 64
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')

    def test_volume_query_failure_not_absence(self):
        self.fixture['mode'] = 'volume_failure'
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertNotIn('ABSENT', report.values())

    def test_network_query_failure_not_absence(self):
        self.fixture['mode'] = 'network_failure'
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')
        self.assertNotIn('NO_AT_INVENTORY', report.values())

    def test_metadata_permission_denied(self):
        _, report, _ = self.run_audit(patches={'_TEST_PERMISSION_DENIED': True})
        self.assertTrue(any(v in ('UNSAFE', 'UNVERIFIED') for k, v in report.items()
                            if k.startswith(('MARKER_', 'STAGE_'))))

    def test_metadata_symlink_ancestor(self):
        link = self.base / 'linked-root'
        link.symlink_to(self.prod.parent)
        _, report, _ = self.run_audit(patches={'MARKER_ROOT': str(link / 'eventsales-prod')})
        self.assertTrue(any(v in ('UNSAFE', 'UNVERIFIED') for k, v in report.items()
                            if k.startswith(('MARKER_', 'STAGE_'))))

    def test_symlink_trusted_root(self):
        link = self.base / 'linked-root'
        link.symlink_to(self.prod.parent)
        _, report, _ = self.run_audit(patches={'TRUSTED_ROOT': str(link),
                                              'MARKER_ROOT': str(link / 'eventsales-prod')})
        self.assertTrue(any(v in ('UNSAFE', 'UNVERIFIED') for k, v in report.items()
                            if k.startswith(('MARKER_', 'STAGE_'))))

    def test_descendant_cleanup(self):
        self.fixture['mode'] = 'descendant'
        code, report, _ = self.run_audit()
        self.assertNotEqual(code, 0)
        self.assertEqual(report['COLLECTION_RESULT'], 'FAILED')
        pid = int((self.base / 'descendant.pid').read_text())
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            try:
                state = pathlib.Path('/proc/' + str(pid) + '/stat').read_text().split(') ')[1].split()[0]
            except FileNotFoundError:
                return
            if state == 'Z':
                return  # A terminated orphan may await the workstation's init reaper.
            time.sleep(0.02)
        os.kill(pid, 9)  # Contain the fixture if the safety property fails, then STOP.
        self.fail('STOP=R5_UNCONTROLLED_DESCENDANT')

    def test_no_unexpected_files_written(self):
        self.run_audit()
        expected = {'root', 'calls', 'state.json', 'docker', 'runner.py'}
        self.assertEqual({p.name for p in self.base.iterdir()}, expected,
                         'STOP=R5_UNEXPECTED_FILESYSTEM_WRITE')

    def test_blocked_report_consumer_has_a_deadline(self):
        self.state.write_text(json.dumps(self.fixture))
        config = {'DOCKER': str(self.fake), 'ROOT_UID': os.getuid(), 'ROOT_GID': os.getgid(),
                  'MARKER_ROOT': str(self.prod), 'TRUSTED_ROOT': str(self.base),
                  'PER_COMMAND_SECONDS': 0.3, 'WORK_SECONDS': 2, 'TOTAL_SECONDS': 3,
                  'TERM_SECONDS': 0.1, 'REAP_SECONDS': 0.2}
        reader, writer = os.pipe()
        try:
            fcntl.fcntl(writer, fcntl.F_SETFL, os.O_NONBLOCK)
            while True:
                try:
                    os.write(writer, b'x' * 4096)
                except BlockingIOError:
                    break
            proc = subprocess.Popen([sys.executable, '-I', '-S', '-B', str(self.runner),
                                     str(WRAPPER), json.dumps(config)], stdout=writer, stderr=writer)
            proc.wait(timeout=5)
            self.assertNotEqual(proc.returncode, 0)
        finally:
            os.close(reader)
            os.close(writer)

    def test_post_popen_setup_failure_cleans_child(self):
        self.fixture['mode'] = 'hang'
        code, report, _ = self.run_audit(patches={'_TEST_SELECTOR_FAILURE': True})
        self.assertNotEqual(code, 0)
        self.assertEqual(report['FAILURE_REASON'], 'DOCKER_COLLECTION_FAILED')
        pid = int((self.base / 'setup-child.pid').read_text())
        self.assertFalse(pathlib.Path('/proc/' + str(pid)).exists(),
                         'STOP=R5_UNCONTROLLED_CHILD_AFTER_SETUP_FAILURE')

    def test_cancellation_cleans_active_process(self):
        self.fixture['mode'] = 'hang'
        self.state.write_text(json.dumps(self.fixture))
        config = {'DOCKER': str(self.fake), 'ROOT_UID': os.getuid(), 'ROOT_GID': os.getgid(),
                  'MARKER_ROOT': str(self.prod), 'TRUSTED_ROOT': str(self.base),
                  'PER_COMMAND_SECONDS': 2, 'WORK_SECONDS': 3, 'TOTAL_SECONDS': 5,
                  'TERM_SECONDS': 0.1, 'REAP_SECONDS': 0.2,
                  '_TEST_CAPTURE_CHILD': True}
        proc = subprocess.Popen([sys.executable, '-I', '-S', '-B', str(self.runner),
                                 str(WRAPPER), json.dumps(config)], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        ready = self.base / 'setup-child.pid'
        until = time.monotonic() + 2
        while not ready.exists() and time.monotonic() < until:
            time.sleep(0.01)
        self.assertTrue(ready.exists())
        proc.terminate()
        stdout, stderr = proc.communicate(timeout=3)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn(b'FAILURE_REASON=CANCELLED', stdout)
        self.assertNotIn(b'Traceback', stdout + stderr)
        pid = int(ready.read_text())
        self.assertFalse(pathlib.Path('/proc/' + str(pid)).exists(),
                         'STOP=R5_UNCONTROLLED_CHILD_AFTER_CANCELLATION')

    def test_marker_regular_file_is_not_a_valid_directory_marker(self):
        (self.prod / '.v4-pgbouncer-redis-start-consumed').write_text('SENSITIVE_SENTINEL')
        _, report, _ = self.run_audit()
        self.assertIn('UNSAFE', report.values())

    def test_metadata_symlink(self):
        (self.prod / '.v4-pgbouncer-redis-start-consumed').symlink_to(self.base)
        _, report, _ = self.run_audit()
        self.assertIn('UNSAFE', report.values())

    def test_untrusted_metadata_permissions(self):
        self.prod.chmod(0o777)
        _, report, _ = self.run_audit()
        self.assertIn('UNSAFE', report.values())


FAKE_DOCKER = r'''import json, os, pathlib, signal, subprocess, sys, time
base = pathlib.Path(__file__).parent
state = json.loads((base / 'state.json').read_text())
args = sys.argv[1:]
with (base / 'calls').open('a') as stream:
    stream.write(json.dumps(args) + '\n')
mode = state['mode']
if mode == 'daemon_failure':
    sys.stderr.write('SENSITIVE_SENTINEL')
    sys.exit(1)
if mode == 'stdout_flood':
    sys.stdout.write('SENSITIVE_SENTINEL' * 10000)
    sys.stdout.flush()
    sys.exit(0)
if mode == 'stderr_flood':
    sys.stderr.write('SENSITIVE_SENTINEL' * 10000)
    sys.stderr.flush()
    sys.exit(1)
if mode == 'hang':
    time.sleep(10)
if mode == 'descendant':
    child = subprocess.Popen([sys.executable, '-I', '-S', '-B', '-c',
                              'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(20)'])
    (base / 'descendant.pid').write_text(str(child.pid))
    time.sleep(0.05)
    sys.exit(0)  # Descendant retains the pipes after the leader exits.
if mode == 'slow':
    time.sleep(0.2)
assert args[:2] == ['--host', 'unix:///var/run/docker.sock']
if args[2] == 'ps':
    assert args[3:7] == ['-a', '--no-trunc', '--filter', 'name=^/?eventsales-(prod|d0-proof)-']
    print(state['inventory'], end='')
elif args[2] == 'network':
    assert args[3] == 'inspect'
    if mode == 'network_failure':
        sys.stderr.write('SENSITIVE_SENTINEL')
        sys.exit(1)
    print(state['networks'][args[-1]])
elif args[2] == 'volume':
    assert args[3] == 'inspect'
    if mode == 'volume_failure':
        sys.stderr.write('SENSITIVE_SENTINEL')
        sys.exit(1)
    print(state['volume'])
elif args[2] == 'inspect':
    if mode == 'inspect_failure':
        sys.stderr.write('SENSITIVE_SENTINEL')
        sys.exit(1)
    if mode == 'malformed_json':
        print('SENSITIVE_SENTINEL')
    else:
        value = state['containers'][args[-1]]
        columns = [json.dumps(value[k]) for k in
                   ('ID', 'State', 'Health', 'RestartCount', 'OOMKilled', 'Image', 'Memory', 'NanoCPUs', 'PidsLimit')]
        expected_net = ('eventsales-prod' if args[-1][0] in '123' else 'eventsales-d0-proof') + '_eventsales_data'
        columns += [str(len(value['Networks'])), json.dumps(value['Networks'].get(expected_net, '')),
                    'x' * value['PortBindings'], json.dumps(value['PostgresVolume'])]
        print('|'.join(columns))
else:
    raise RuntimeError('forbidden fake Docker command')
'''

RUNNER = r'''import json, pathlib, sys, types
source = pathlib.Path(sys.argv[1]).read_text().split("<<'PY'", 1)[1].rsplit('\nPY', 1)[0]
module = types.ModuleType('audit_under_test')
exec(compile(source, 'audit-collector', 'exec'), module.__dict__)
config = json.loads(sys.argv[2])
deny = config.pop('_TEST_PERMISSION_DENIED', False)
setup_failure = config.pop('_TEST_SELECTOR_FAILURE', False)
capture_child = config.pop('_TEST_CAPTURE_CHILD', False)
for key, value in config.items():
    setattr(module, key, value)
if deny:
    original_open = module.os.open
    def denied_open(path, *args, **kwargs):
        if path == 'eventsales-prod':
            raise PermissionError('SENSITIVE_SENTINEL')
        return original_open(path, *args, **kwargs)
    module.os.open = denied_open
if setup_failure or capture_child:
    original_popen = module.subprocess.Popen
    def capture_popen(*args, **kwargs):
        proc = original_popen(*args, **kwargs)
        pathlib.Path(__file__).with_name('setup-child.pid').write_text(str(proc.pid))
        return proc
    module.subprocess.Popen = capture_popen
if setup_failure:
    original_selector = module.selectors.DefaultSelector
    failed = False
    class FailFirstRegister(original_selector):
        def register(self, *args, **kwargs):
            global failed
            if not failed:
                failed = True
                raise OSError('SENSITIVE_SENTINEL')
            return super().register(*args, **kwargs)
    module.selectors.DefaultSelector = FailFirstRegister
sys.exit(module.main())
'''


unittest.main(argv=['r5-audit-tests'], verbosity=2)
PY
