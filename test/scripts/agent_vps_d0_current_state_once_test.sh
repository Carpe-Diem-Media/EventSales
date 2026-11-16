#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
/usr/bin/python3 -I -S -B - "$root" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import shlex
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = pathlib.Path(sys.argv[1])
WRAPPER = ROOT / "deploy/vps/operator/agent-vps-d0-current-state-once"
COLLECTOR = ROOT / "deploy/vps/operator/agent-vps-d0-current-state-inspect"
EVIDENCE_NAME = "eventsales-d0-current-state-once"
PINNED_COLLECTOR_SHA256 = "91e7f6adce032f514eeff512998952b623b20232e95d71b3cf00e4fc4c15a124"
SENTINEL_ID = "synthetic-container-id-7a9c"
SENTINEL_MOUNT = "/synthetic/private/mount-7a9c"
SENTINEL_STDERR = "synthetic-stderr-7a9c"


class CaptureWrapperTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="d0-once-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.parent = self.root / "evidence-parent"
        self.parent.mkdir(mode=0o700)
        os.chmod(self.parent, 0o700)
        self.collector = self.root / "synthetic-collector"
        self.collector_body = self.root / "synthetic-collector.py"
        self.wrapper = self.root / "synthetic-wrapper"
        self.counter = self.root / "invocations"
        self.wrapper_source = WRAPPER.read_text()

    def write_collector(self, body):
        self.collector_body.write_text(textwrap.dedent(body))
        os.chmod(self.collector_body, 0o600)
        source = (
            "#!/bin/bash -p\n"
            "exec /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin "
            "LC_ALL=C HOME=/nonexistent "
            "DOCKER_CONFIG=/nonexistent/eventsales-d0-inspect-config "
            "DOCKER_HOST=unix:///run/docker.sock "
            "/usr/bin/python3 -I -S -B "
            + shlex.quote(str(self.collector_body))
            + "\n"
        )
        self.collector.write_text(source)
        os.chmod(self.collector, 0o700)
        return hashlib.sha256(self.collector.read_bytes()).hexdigest()

    def install_wrapper(self, collector_digest=None, runtime=5.0, output_limit=65536, parent_mode=0o700, required_uid=None):
        if not self.collector.exists():
            self.write_collector("import os\nimport sys\n")
        digest = hashlib.sha256(self.collector.read_bytes()).hexdigest()
        if collector_digest is not None:
            digest = collector_digest
        substitutions = {
            'REQUIRED_EUID=0': f'REQUIRED_EUID={os.geteuid() if required_uid is None else required_uid}',
            'REQUIRED_UID = 0': f'REQUIRED_UID = {os.geteuid() if required_uid is None else required_uid}',
            'REQUIRED_GID = 0': f'REQUIRED_GID = {os.getegid()}',
            'EVIDENCE_PARENT = "/root"': f'EVIDENCE_PARENT = {str(self.parent)!r}',
            'EVIDENCE_NAME = "eventsales-d0-current-state-once"': f'EVIDENCE_NAME = {EVIDENCE_NAME!r}',
            'COLLECTOR_PATH = "/usr/local/sbin/agent-vps-d0-current-state-inspect"': f'COLLECTOR_PATH = {str(self.collector)!r}',
            'COLLECTOR_SHA256 = "91e7f6adce032f514eeff512998952b623b20232e95d71b3cf00e4fc4c15a124"': f'COLLECTOR_SHA256 = "{digest}"',
            'MAX_RUNTIME_SECONDS = 55.0': f'MAX_RUNTIME_SECONDS = {runtime!r}',
            'MAX_OUTPUT_BYTES = 65536': f'MAX_OUTPUT_BYTES = {output_limit}',
        }
        source = self.wrapper_source
        for old, new in substitutions.items():
            self.assertIn(old, source, f"test fixture could not find pinned constant: {old}")
            source = source.replace(old, new, 1)
        self.wrapper.write_text(source)
        os.chmod(self.wrapper, 0o700)
        os.chmod(self.parent, parent_mode)
        return digest

    def set_collector_body(self, body):
        source = "\n".join(
            [
                "import os",
                "import sys",
                "import time",
                "import json",
                "from pathlib import Path",
                f"counter = Path({str(self.counter)!r})",
                "with counter.open('a') as handle:",
                "    handle.write('invoked\\n')",
                "    handle.flush()",
                textwrap.dedent(body).strip(),
                "",
            ]
        )
        self.write_collector(source)

    def run_wrapper(self, args=(), env=None, timeout=6):
        return subprocess.run(
            [str(self.wrapper), *args],
            cwd="/",
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )

    @property
    def evidence(self):
        return self.parent / EVIDENCE_NAME

    def metadata(self):
        return json.loads((self.evidence / "metadata.json").read_text())

    def assert_protected_files(self):
        self.assertEqual(stat.S_IMODE(self.evidence.stat().st_mode), 0o700)
        for name in ("collector.stdout", "collector.stderr", "metadata.json"):
            path = self.evidence / name
            info = path.stat()
            self.assertEqual(info.st_uid, os.geteuid())
            self.assertEqual(info.st_gid, os.getegid())
            self.assertEqual(stat.S_IMODE(info.st_mode), 0o600)

    def assert_redacted(self, result):
        terminal = result.stdout + result.stderr
        for value in (SENTINEL_ID, SENTINEL_MOUNT, SENTINEL_STDERR):
            self.assertNotIn(value, terminal)
        self.assertEqual(result.stderr, "")

    def test_production_digest_and_deadline_are_pinned(self):
        self.assertTrue(WRAPPER.is_file())
        observed = hashlib.sha256(COLLECTOR.read_bytes()).hexdigest()
        self.assertEqual(observed, PINNED_COLLECTOR_SHA256)
        self.assertIn(f'COLLECTOR_SHA256 = "{PINNED_COLLECTOR_SHA256}"', self.wrapper_source)
        self.assertIn("REQUIRED_EUID=0", self.wrapper_source)
        self.assertIn("REQUIRED_UID = 0", self.wrapper_source)
        self.assertIn("REQUIRED_GID = 0", self.wrapper_source)
        self.assertIn('EVIDENCE_PARENT = "/root"', self.wrapper_source)
        self.assertIn('EVIDENCE_NAME = "eventsales-d0-current-state-once"', self.wrapper_source)
        self.assertIn('COLLECTOR_PATH = "/usr/local/sbin/agent-vps-d0-current-state-inspect"', self.wrapper_source)
        self.assertNotIn("os.environ", self.wrapper_source)
        self.assertIn('COLLECTOR_SHA256 = "' + PINNED_COLLECTOR_SHA256 + '"', self.wrapper_source)
        match = re.search(r"MAX_RUNTIME_SECONDS = ([0-9]+(?:\.[0-9]+)?)", self.wrapper_source)
        collector_deadline = re.search(r"TOTAL_SECONDS = ([0-9]+(?:\.[0-9]+)?)", COLLECTOR.read_text())
        self.assertIsNotNone(match)
        self.assertIsNotNone(collector_deadline)
        self.assertGreater(float(match.group(1)), float(collector_deadline.group(1)))
        collector_limit = re.search(r"MAX_REPORT_BYTES = ([0-9]+)", COLLECTOR.read_text())
        stdout_limit = re.search(r"MAX_OUTPUT_BYTES = ([0-9]+)", self.wrapper_source)
        self.assertIsNotNone(collector_limit)
        self.assertIsNotNone(stdout_limit)
        self.assertGreaterEqual(int(stdout_limit.group(1)), int(collector_limit.group(1)))

    def test_success_captures_hashes_permissions_and_redacts_terminal(self):
        environment_capture = self.root / "collector-environment.json"
        self.set_collector_body(
            f"""
            os.write(1, {('{"container_id":"' + SENTINEL_ID + '","mount":"' + SENTINEL_MOUNT + '"}').encode()!r} + bytes([10]))
            os.write(2, {SENTINEL_STDERR.encode()!r} + bytes([10]))
            Path({str(environment_capture)!r}).write_text(json.dumps({{
                "PATH": os.environ.get("PATH"),
                "DOCKER_HOST": os.environ.get("DOCKER_HOST"),
                "D0_CAPTURE_TEST": os.environ.get("D0_CAPTURE_TEST"),
                "PYTHONPATH": os.environ.get("PYTHONPATH"),
            }}))
            """
        )
        self.install_wrapper()
        result = self.run_wrapper(env={"PATH": "/tmp/untrusted", "PYTHONPATH": "/tmp/untrusted", "D0_CAPTURE_TEST": "ignored"})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "D0_CAPTURE=COMPLETE\n")
        self.assert_redacted(result)
        self.assert_protected_files()
        stdout = (self.evidence / "collector.stdout").read_bytes()
        stderr = (self.evidence / "collector.stderr").read_bytes()
        self.assertEqual(stdout, ('{"container_id":"' + SENTINEL_ID + '","mount":"' + SENTINEL_MOUNT + '"}\n').encode())
        self.assertIn(SENTINEL_ID.encode(), stdout)
        self.assertIn(SENTINEL_MOUNT.encode(), stdout)
        self.assertEqual(stderr, (SENTINEL_STDERR + "\n").encode())
        metadata = self.metadata()
        self.assertEqual(metadata["result"], "COMPLETE")
        self.assertEqual(metadata["mechanism"], "G47_ONE_SHOT")
        self.assertEqual(metadata["collector_invocation_count"], 1)
        self.assertEqual(metadata["collector_exit_code"], 0)
        self.assertEqual(metadata["collector_observed_sha256"], hashlib.sha256(self.collector.read_bytes()).hexdigest())
        self.assertEqual(metadata["stdout_sha256"], hashlib.sha256(stdout).hexdigest())
        self.assertEqual(metadata["stderr_sha256"], hashlib.sha256(stderr).hexdigest())
        self.assertTrue(metadata["collector_started_at_utc"])
        self.assertTrue(metadata["collector_finished_at_utc"])
        self.assertEqual(json.loads(environment_capture.read_text()), {
            "PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
            "DOCKER_HOST": "unix:///run/docker.sock",
            "D0_CAPTURE_TEST": None,
            "PYTHONPATH": None,
        })
        self.assertEqual(self.counter.read_text(), "invoked\n")

    def test_nonzero_exit_preserves_json_and_never_retries(self):
        self.set_collector_body(
            f"""
            os.write(1, {('{"container_id":"' + SENTINEL_ID + '"}').encode()!r} + bytes([10]))
            os.write(2, {SENTINEL_STDERR.encode()!r} + bytes([10]))
            sys.exit(19)
            """
        )
        self.install_wrapper()
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=COLLECTOR_EXIT\n")
        self.assert_redacted(result)
        stdout = (self.evidence / "collector.stdout").read_bytes()
        stderr = (self.evidence / "collector.stderr").read_bytes()
        metadata = self.metadata()
        self.assertIn(SENTINEL_ID.encode(), stdout)
        self.assertEqual(metadata["stdout_sha256"], hashlib.sha256(stdout).hexdigest())
        self.assertEqual(metadata["stderr_sha256"], hashlib.sha256(stderr).hexdigest())
        self.assertEqual(metadata["collector_exit_code"], 19)
        self.assertEqual(metadata["collector_invocation_count"], 1)
        second = self.run_wrapper()
        self.assertEqual(second.stdout, "D0_CAPTURE=INCOMPLETE STOP=ALREADY_USED\n")
        self.assertEqual(self.counter.read_text(), "invoked\n")

    def test_timeout_kills_and_preserves_partial_output(self):
        self.set_collector_body(
            f"""
            os.write(1, {('{"container_id":"' + SENTINEL_ID + '"}').encode()!r} + bytes([10]))
            time.sleep(5)
            """
        )
        self.install_wrapper(runtime=1.0)
        result = self.run_wrapper(timeout=5)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=TIMEOUT\n")
        self.assert_redacted(result)
        self.assertIn(SENTINEL_ID.encode(), (self.evidence / "collector.stdout").read_bytes())
        metadata = self.metadata()
        self.assertTrue(metadata["collector_timed_out"])
        self.assertEqual(metadata["collector_invocation_count"], 1)

    def test_output_overflow_is_capped_and_terminal_stays_redacted(self):
        self.set_collector_body('os.write(1, b"x" * 4096)')
        self.install_wrapper(output_limit=128)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=OUTPUT_LIMIT\n")
        self.assert_redacted(result)
        self.assertEqual((self.evidence / "collector.stdout").stat().st_size, 128)
        metadata = self.metadata()
        self.assertTrue(metadata["stdout_truncated"])
        self.assertGreater(metadata["stdout_observed_bytes"], 128)

    def test_stderr_overflow_is_capped(self):
        self.set_collector_body('os.write(2, b"y" * 4096)')
        self.install_wrapper(output_limit=128)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=OUTPUT_LIMIT\n")
        self.assert_redacted(result)
        self.assertEqual((self.evidence / "collector.stderr").stat().st_size, 128)
        metadata = self.metadata()
        self.assertTrue(metadata["stderr_truncated"])
        self.assertGreater(metadata["stderr_observed_bytes"], 128)

    def test_incorrect_digest_consumes_attempt_without_invoking_collector(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper(collector_digest="0" * 64)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=COLLECTOR_IDENTITY\n")
        self.assert_redacted(result)
        metadata = self.metadata()
        self.assertEqual(metadata["collector_invocation_count"], 0)
        self.assertIsNone(metadata["collector_exit_code"])
        self.assertEqual(metadata["collector_observed_sha256"], hashlib.sha256(self.collector.read_bytes()).hexdigest())
        self.assertFalse(self.counter.exists())

    def test_existing_evidence_directory_is_terminal_and_untouched(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper()
        self.evidence.mkdir(mode=0o700)
        sentinel = self.evidence / "existing-marker"
        sentinel.write_text("do not modify")
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=ALREADY_USED\n")
        self.assert_redacted(result)
        self.assertEqual(sentinel.read_text(), "do not modify")
        self.assertFalse(self.counter.exists())

    def test_insufficient_privilege_is_rejected_before_consuming_authority(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper(required_uid=os.geteuid() + 1)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 77)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=PRIVILEGE\n")
        self.assertEqual(result.stderr, "")
        self.assertFalse(self.evidence.exists())
        self.assertFalse(self.counter.exists())

    def test_unsafe_evidence_parent_is_rejected(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper(parent_mode=0o777)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=EVIDENCE_PARENT\n")
        self.assertEqual(result.stderr, "")
        self.assertFalse(self.evidence.exists())

    def test_untrusted_collector_permissions_are_rejected_after_consumption(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper()
        os.chmod(self.collector, 0o777)
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=COLLECTOR_IDENTITY\n")
        self.assert_redacted(result)
        self.assertEqual(self.metadata()["collector_invocation_count"], 0)
        self.assertFalse(self.counter.exists())

    def test_argument_is_rejected_without_creating_evidence(self):
        self.set_collector_body("os.write(1, b'\\\"would-run\\\"')")
        self.install_wrapper()
        result = self.run_wrapper(args=("unexpected",))
        self.assertEqual(result.returncode, 64)
        self.assertEqual(result.stdout, "D0_CAPTURE=INCOMPLETE STOP=ARGUMENTS\n")
        self.assertEqual(result.stderr, "")
        self.assertFalse(self.evidence.exists())

    def test_concurrent_attempts_invoke_collector_once(self):
        self.set_collector_body("time.sleep(0.35)\nos.write(1, b'{\\\"synthetic\\\":true}\\n')")
        self.install_wrapper(runtime=5.0)
        processes = [
            subprocess.Popen([str(self.wrapper)], cwd="/", stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            for _ in range(2)
        ]
        results = [process.communicate(timeout=6) + (process.returncode,) for process in processes]
        outputs = sorted(stdout for stdout, _stderr, _code in results)
        self.assertEqual(outputs, [
            "D0_CAPTURE=COMPLETE\n",
            "D0_CAPTURE=INCOMPLETE STOP=ALREADY_USED\n",
        ])
        self.assertTrue(all(stderr == "" for _stdout, stderr, _code in results))
        self.assertTrue(all(code in (0, 1) for _stdout, _stderr, code in results))
        self.assertEqual(self.counter.read_text(), "invoked\n")
        self.assertEqual(self.metadata()["collector_invocation_count"], 1)
        self.assert_protected_files()


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
PY
