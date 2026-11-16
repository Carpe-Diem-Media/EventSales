#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
python3 -I -S -B - "$root" <<'PY'
import json
import os
import pathlib
import socketserver
import sys
import tempfile
import threading
import time
import types
import unittest

ROOT = pathlib.Path(sys.argv[1])
COLLECTOR = ROOT / "deploy/vps/operator/agent-vps-d0-current-state-inspect"
COLLECTOR_EXISTS = COLLECTOR.is_file()
MODULE = None
if COLLECTOR_EXISTS:
    source_text = COLLECTOR.read_text()
    source = source_text.split("<<'PY'", 1)[1].rsplit("\nPY", 1)[0]
    MODULE = types.ModuleType("d0_current_state_inspect")
    exec(compile(source, str(COLLECTOR), "exec"), MODULE.__dict__)

SENTINEL = "protected-d0-path-sentinel"
IDS = {
    "postgres": "1" * 64,
    "pgbouncer": "2" * 64,
    "redis": "3" * 64,
}
NETWORK_IDS = {
    "eventsales-d0-proof_eventsales_data": "a" * 64,
    "eventsales-d0-proof_eventsales_edge": "b" * 64,
}
ENDPOINT_IDS = {
    "postgres": "c" * 64,
    "pgbouncer": "d" * 64,
    "redis": "e" * 64,
}
IMAGE_IDS = {
    "postgres": "sha256:" + "4" * 64,
    "pgbouncer": "sha256:" + "5" * 64,
    "redis": "sha256:" + "6" * 64,
}


def labels_for(service):
    return {
        "com.docker.compose.project": "eventsales-d0-proof",
        "com.docker.compose.service": service,
    }


def container_row(service):
    return {
        "Id": IDS[service],
        "Names": ["/eventsales-d0-proof-" + service + "-1"],
        "Labels": labels_for(service),
    }


def network_row(name, internal):
    prefix = "eventsales-d0-proof_"
    logical_name = name[len(prefix):] if name.startswith(prefix) else ""
    return {
        "Name": name,
        "Id": NETWORK_IDS.get(name, "9" * 64),
        "Created": "2026-11-01T00:00:00.000000000Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": False,
        "Internal": internal,
        "Attachable": False,
        "Ingress": False,
        "ConfigFrom": {"Network": ""},
        "ConfigOnly": False,
        "IPAM": {"Driver": "default", "Options": None, "Config": []},
        "Options": None,
        "Labels": {
            "com.docker.compose.project": "eventsales-d0-proof",
            "com.docker.compose.network": logical_name,
        },
    }


def volume_row():
    return {
        "Name": "eventsales-d0-proof_postgres_data",
        "Driver": "local",
        "Mountpoint": "/var/lib/docker/volumes/eventsales-d0-proof_postgres_data/_data",
        "Labels": {
            "com.docker.compose.project": "eventsales-d0-proof",
            "com.docker.compose.volume": "postgres_data",
        },
        "Scope": "local",
        "Options": None,
    }


def volume_inspect():
    return {
        **volume_row(),
        "CreatedAt": "2026-11-01T00:00:00Z",
        "Status": {},
    }


def network_attachment(service, mode):
    index = {"postgres": 2, "pgbouncer": 3, "redis": 4}[service]
    endpoint_id = (
        ENDPOINT_IDS[service]
        if mode in ("cross_checked_membership", "wrong_network_endpoint")
        or mode in ("missing_container_network_addresses", "conflicting_network_address")
        or (mode == "endpoint_not_in_network_map" and service == "postgres")
        else ""
    )
    network_id = "" if mode == "missing_container_network_id" and service == "postgres" else NETWORK_IDS[
        "eventsales-d0-proof_eventsales_data"
    ]
    attachment = {
        "NetworkID": network_id,
        "EndpointID": endpoint_id,
        "Gateway": "",
        "IPAddress": "",
        "IPPrefixLen": 0,
        "IPv6Gateway": "",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "MacAddress": "",
        "Aliases": ["eventsales-d0-proof-" + service + "-1"],
        "DriverOpts": None,
    }
    if mode in (
        "cross_checked_membership",
        "missing_container_network_addresses",
        "conflicting_network_address",
    ):
        attachment.update({
            "IPAddress": (
                "172.18.0.99"
                if mode == "conflicting_network_address" and service == "postgres"
                else "172.18.0." + str(index)
            ),
            "GlobalIPv6Address": "2001:db8::" + str(index),
            "MacAddress": "02:42:ac:12:00:" + format(index, "02x"),
        })
        if mode == "missing_container_network_addresses":
            attachment.update({"IPAddress": "", "GlobalIPv6Address": "", "MacAddress": ""})
    if mode == "null_network_aliases" and service == "postgres":
        attachment["Aliases"] = None
    elif mode == "missing_network_aliases" and service == "postgres":
        del attachment["Aliases"]
    elif mode == "malformed_network_aliases" and service == "postgres":
        attachment["Aliases"] = "eventsales-d0-proof-postgres-1"
    return attachment


def container_inspect(service, second_read, mode):
    mountpoint = volume_row()["Mountpoint"]
    mounts = []
    if service == "postgres":
        mounts.append({
            "Type": "volume",
            "Name": volume_row()["Name"],
            "Source": mountpoint,
            "Destination": "/var/lib/postgresql",
            "Driver": "local",
            "Mode": "",
            "RW": True,
            "Propagation": "",
        })
    elif service == "pgbouncer":
        mounts.append({
            "Type": "tmpfs",
            "Source": "",
            "Destination": "/tmp",
            "Mode": "",
            "RW": True,
            "Propagation": "",
        })
        if mode == "valid_bind_mount" or (mode == "changed_mounts" and second_read):
            mounts.append({
                "Type": "bind",
                "Source": "/srv/config" if mode == "valid_bind_mount" else "/srv/" + SENTINEL,
                "Destination": "/etc/service" if mode == "valid_bind_mount" else "/unexpected",
                "Mode": "ro",
                "RW": False,
                "Propagation": "rprivate",
            })
    if service == "postgres" and mode == "missing_volume_mount_name":
        del mounts[0]["Name"]
    if service == "postgres" and mode == "missing_volume_mount_driver":
        del mounts[0]["Driver"]

    state = {
        "Status": "exited",
        "Running": False,
        "Restarting": False,
        "ExitCode": 0,
        "OOMKilled": False,
        "StartedAt": "2026-11-01T00:00:00Z",
        "FinishedAt": "2026-11-10T00:00:00Z",
    }
    if mode == "nonzero_exit_oom" and service == "redis":
        state["ExitCode"] = 137
        state["OOMKilled"] = True
    if mode == "missing_exit_code" and service == "postgres":
        del state["ExitCode"]
    if mode == "missing_oom" and service == "postgres":
        del state["OOMKilled"]
    if mode in (
        "cross_checked_membership",
        "wrong_network_endpoint",
        "missing_container_network_addresses",
        "conflicting_network_address",
    ):
        state.update({"Status": "running", "Running": True, "FinishedAt": ""})

    networks = {
        "eventsales-d0-proof_eventsales_data": network_attachment(service, mode),
    }
    if mode == "extra_configured_network" and service == "redis":
        networks["eventsales-d0-proof_eventsales_edge"] = {
            **network_attachment(service, mode),
            "NetworkID": NETWORK_IDS["eventsales-d0-proof_eventsales_edge"],
        }

    image_ref = {
        "postgres": "dhi.io/postgres:18.6-alpine3.24@sha256:d33bd884995daddfb515d0ce9aec23b74d20d72e03ca42b72c4abf617c76bb19",
        "pgbouncer": "dhi.io/pgbouncer:1.26.1-debian13@sha256:78fe21ad5b7c1ab497e9828eea9b951f9d6a58eb638946ddc61ef1f99737f1b1",
        "redis": "dhi.io/redis:8.10.2-debian13@sha256:953ca2c2ab4ff7a93f8abac31339ba4d913ec0914861453ab4faa29d154115a0",
    }[service]
    if mode == "wrong_image" and service == "redis":
        image_ref = "dhi.io/redis:wrong"

    result = {
        "Id": IDS[service],
        "Name": "/eventsales-d0-proof-" + service + "-1",
        "Image": IMAGE_IDS[service],
        "Config": {
            "Image": image_ref,
            "Labels": labels_for(service),
        },
        "HostConfig": {
            "RestartPolicy": {"Name": "no", "MaximumRetryCount": 0},
        },
        "State": state,
        "RestartCount": 0,
        "NetworkSettings": {"Networks": networks},
        "Mounts": mounts,
    }
    if mode == "missing_mounts" and service == "postgres":
        del result["Mounts"]
    return result


if MODULE is not None:
    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            data = b""
            while b"\r\n\r\n" not in data:
                chunk = self.request.recv(4096)
                if not chunk:
                    return
                data += chunk
            request_line = data.split(b"\r\n", 1)[0].decode("ascii")
            method, path, _ = request_line.split(" ", 2)
            self.server.requests.append((method, path))
            mode = self.server.mode
            if mode == "timeout" and path == MODULE.CONTAINERS_PATH:
                time.sleep(0.2)
            if mode == "bad_status" and path == "/version":
                self.send(b"HTTP/1.1 500 Error\r\nContent-Length: 0\r\n\r\n")
                return
            if method != "GET":
                self.send(b"HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n")
                return
            if path == "/version":
                payload = {"ApiVersion": "1.55", "MinAPIVersion": "1.24"}
                if mode == "missing_version":
                    del payload["MinAPIVersion"]
                body = json.dumps(payload).encode()
            elif path == MODULE.CONTAINERS_PATH:
                body = self.container_list(mode)
            elif path == MODULE.NETWORKS_PATH:
                body = self.network_list(mode)
            elif path.startswith(MODULE.API + "/networks/"):
                ident = path.rsplit("/", 1)[-1]
                name = next((key for key, value in NETWORK_IDS.items() if value == ident), None)
                if name is None:
                    self.send(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
                    return
                second_read = sum(1 for method, seen in self.server.requests
                                  if method == "GET" and seen == path) > 1
                body = self.network_inspect(name, mode, second_read)
            elif path == MODULE.VOLUMES_PATH:
                body = self.volume_list(mode)
            elif path == MODULE.VOLUME_INSPECT_PATH:
                payload = volume_inspect()
                if mode == "missing_volume_mountpoint":
                    del payload["Mountpoint"]
                body = json.dumps(payload).encode()
            elif path.startswith(MODULE.API + "/containers/") and path.endswith("/json"):
                ident = path.split("/")[-2]
                service = next((key for key, value in IDS.items() if value == ident), None)
                if service is None:
                    self.send(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
                    return
                second_read = sum(1 for method, seen in self.server.requests
                                  if method == "GET" and seen == path) > 1
                payload = container_inspect(service, second_read, mode)
                if mode == "wrong_label" and service == "redis":
                    payload["Config"]["Labels"]["com.docker.compose.project"] = "wrong"
                if mode == "wrong_id" and service == "postgres":
                    payload["Id"] = "9" * 64
                body = json.dumps(payload).encode()
            else:
                self.send(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
                return
            if mode == "malformed_json" and path == "/version":
                body = b"{"
            if mode == "duplicate_json_key" and path == "/version":
                body = b'{"ApiVersion":"1.55","ApiVersion":"1.55","MinAPIVersion":"1.24"}'
            if mode == "oversized_body" and path == "/version":
                body = b" " * (MODULE.MAX_BODY_BYTES + 1)
            content_type = b"application/jsonp" if mode == "bad_content_type" else b"application/json"
            self.send(
                b"HTTP/1.1 200 OK\r\nContent-Type: " + content_type + b"\r\nContent-Length: "
                + str(len(body)).encode()
                + b"\r\nConnection: close\r\n\r\n"
                + body
            )

        def container_list(self, mode):
            rows = [container_row(service) for service in ("postgres", "pgbouncer", "redis")]
            if mode == "extra_container":
                rows.append({
                    "Id": "9" * 64,
                    "Names": ["/unexpected"],
                    "Labels": {
                        "com.docker.compose.project": "eventsales-d0-proof",
                        "com.docker.compose.service": "extra",
                    },
                })
            if mode == "bad_container_id":
                rows[0]["Id"] = "bad"
            return json.dumps(rows).encode()

        def network_list(self, mode):
            rows = [
                network_row("eventsales-d0-proof_eventsales_data", True),
                network_row("eventsales-d0-proof_eventsales_edge", False),
            ]
            if mode == "extra_network":
                rows.append(network_row("eventsales-d0-proof_unexpected", False))
            if mode == "wrong_network_id":
                rows[0]["Id"] = "bad"
            return json.dumps(rows).encode()

        def network_inspect(self, name, mode, second_read):
            result = network_row(name, name == "eventsales-d0-proof_eventsales_data")
            members = {}
            if name == "eventsales-d0-proof_eventsales_data" and (
                mode == "cross_checked_membership"
                or mode in ("missing_container_network_addresses", "conflicting_network_address")
                or (mode == "changed_network_membership" and second_read)
            ):
                services = (
                    ("postgres", "pgbouncer", "redis")
                    if mode in (
                        "cross_checked_membership",
                        "missing_container_network_addresses",
                        "conflicting_network_address",
                    )
                    else ("postgres",)
                )
                for index, service in enumerate(services, start=2):
                    members[IDS[service]] = {
                        "Name": "eventsales-d0-proof-" + service + "-1",
                        "EndpointID": ENDPOINT_IDS[service],
                        "MacAddress": "02:42:ac:12:00:" + format(index, "02x"),
                        "IPv4Address": "172.18.0." + str(index) + "/16",
                        "IPv6Address": "2001:db8::" + str(index),
                    }
            if mode == "unknown_network_member" and name == "eventsales-d0-proof_eventsales_data":
                members["9" * 64] = {
                    "Name": "unexpected",
                    "EndpointID": "f" * 64,
                    "MacAddress": "",
                    "IPv4Address": "",
                    "IPv6Address": "",
                }
            if mode == "wrong_network_endpoint" and name == "eventsales-d0-proof_eventsales_data":
                members[IDS["postgres"]] = {
                    "Name": "eventsales-d0-proof-postgres-1",
                    "EndpointID": "f" * 64,
                    "MacAddress": "",
                    "IPv4Address": "",
                    "IPv6Address": "",
                }
            result["Containers"] = members
            if mode == "wrong_network_inspect_id" and name == "eventsales-d0-proof_eventsales_data":
                result["Id"] = "9" * 64
            if mode == "missing_network_inspect_members" and name == "eventsales-d0-proof_eventsales_data":
                del result["Containers"]
            if mode == "null_network_inspect_members":
                result["Containers"] = None
            return json.dumps(result).encode()

        def volume_list(self, mode):
            rows = [volume_row()]
            if mode == "extra_volume":
                rows.append({**volume_row(), "Name": "unexpected"})
            return json.dumps({"Volumes": rows, "Warnings": []}).encode()

        def send(self, response):
            try:
                self.request.sendall(response)
            except (BrokenPipeError, ConnectionResetError):
                pass

    class QuietUnixServer(socketserver.ThreadingUnixStreamServer):
        def handle_error(self, request, client_address):
            pass


class CollectorTests(unittest.TestCase):
    def test_collector_exists(self):
        self.assertTrue(COLLECTOR_EXISTS, "new D0 inspection collector is missing")

    def setUp(self):
        if MODULE is None:
            return
        self.temp = tempfile.TemporaryDirectory(prefix="d0-inspect-test-")
        MODULE.SOCKET_PATH = os.path.join(self.temp.name, "docker.sock")
        MODULE.TRUSTED_PARENT = self.temp.name
        MODULE.EXPECTED_SOCKET_UID = os.getuid()
        MODULE.EXPECTED_PEER_UID = os.getuid()
        MODULE.REQUEST_SECONDS = 3.0
        MODULE.TOTAL_SECONDS = 40.0
        self.server = QuietUnixServer(MODULE.SOCKET_PATH, Handler)
        self.server.mode = "good"
        self.server.requests = []
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        if getattr(self, "server", None):
            self.server.shutdown()
            self.server.server_close()
            self.thread.join(timeout=2)
            self.temp.cleanup()

    def collect(self):
        read_fd, write_fd = os.pipe()
        saved_stdout = os.dup(1)
        was_blocking = os.get_blocking(1)
        try:
            os.dup2(write_fd, 1)
            os.close(write_fd)
            code = MODULE.main()
        finally:
            os.dup2(saved_stdout, 1)
            os.close(saved_stdout)
            os.set_blocking(1, was_blocking)
        output = os.read(read_fd, 1 << 20)
        os.close(read_fd)
        return code, output

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_records_complete_prospective_observation_without_accepting_it(self):
        code, output = self.collect()
        self.assertEqual(code, 0, f"valid synthetic observation should complete: {output!r}")
        report = json.loads(output)
        self.assertEqual(report["collection_result"], "COMPLETE")
        self.assertEqual(report["collection_atomic"], "NO")
        self.assertEqual(report["historical_continuity"], "UNVERIFIED")
        self.assertEqual(report["d0_current_baseline"], "NOT_ACCEPTED")
        self.assertEqual(report["volume_immutable_id"], "UNAVAILABLE")
        self.assertEqual(report["image_content_identity"], "DOCKER_REPORTED_IMAGE_ID_ONLY")
        self.assertTrue(report["all_containers_stopped_state_match"])
        self.assertEqual(len(report["objects"]["containers"]), 3)
        self.assertEqual(len(report["objects"]["networks"]), 2)
        self.assertEqual(len(report["objects"]["volumes"]), 1)
        containers = {row["service"]: row for row in report["objects"]["containers"]}
        self.assertEqual({service: row["id"] for service, row in containers.items()}, IDS)
        networks = {row["name"]: row for row in report["objects"]["networks"]}
        self.assertEqual(
            {name: row["id"] for name, row in networks.items()},
            NETWORK_IDS,
        )
        self.assertNotIn("Containers", network_row("eventsales-d0-proof_eventsales_data", True))
        data_network = networks["eventsales-d0-proof_eventsales_data"]
        edge_network = networks["eventsales-d0-proof_eventsales_edge"]
        self.assertEqual(data_network["members"], [])
        self.assertEqual(data_network["membership_status"], "STOPPED_ENDPOINTS_UNAVAILABLE")
        self.assertEqual(
            {row["id"] for row in data_network["unavailable_stopped_members"]},
            set(IDS.values()),
        )
        self.assertEqual(edge_network["members"], [])
        self.assertEqual(edge_network["membership_status"], "OBSERVED_EMPTY")
        volume = report["objects"]["volumes"][0]
        self.assertEqual(volume["name"], "eventsales-d0-proof_postgres_data")
        self.assertEqual(volume["created_at"], "2026-11-01T00:00:00Z")
        self.assertEqual(
            volume["mountpoint"],
            "/var/lib/docker/volumes/eventsales-d0-proof_postgres_data/_data",
        )
        postgres = containers["postgres"]
        self.assertEqual(postgres["state"]["exit_code"], 0)
        self.assertFalse(postgres["state"]["oom_killed"])
        self.assertEqual(postgres["network_configuration_status"], "PARTIALLY_AVAILABLE")
        postgres_network = postgres["configured_networks"]["eventsales-d0-proof_eventsales_data"]
        self.assertEqual(postgres_network["network_id_status"], "VERIFIED")
        self.assertEqual(postgres_network["endpoint_id_status"], "UNAVAILABLE")
        self.assertEqual(postgres["image_id"], IMAGE_IDS["postgres"])
        self.assertTrue(postgres["mounts"])
        attachment = postgres["postgres_volume_attachment"]
        self.assertEqual(attachment["volume_name"], volume["name"])
        self.assertEqual(attachment["source"], volume["mountpoint"])
        self.assertEqual(attachment["destination"], "/var/lib/postgresql")
        self.assertTrue(attachment["rw"])
        self.assertEqual(containers["pgbouncer"]["mounts"][0]["type"], "tmpfs")
        self.assertEqual(containers["redis"]["mounts"], [])
        self.assertTrue(report["started_at_utc"].endswith("Z"))
        self.assertTrue(report["finished_at_utc"].endswith("Z"))
        self.assertTrue(all(method == "GET" for method, _ in self.server.requests))
        self.assertEqual(len(self.server.requests), MODULE.MAX_REQUESTS)
        allowed = {
            "/version",
            MODULE.CONTAINERS_PATH,
            MODULE.NETWORKS_PATH,
            MODULE.VOLUMES_PATH,
            MODULE.VOLUME_INSPECT_PATH,
        }
        network_inspect_paths = {
            MODULE.API + "/networks/" + ident for ident in NETWORK_IDS.values()
        }
        self.assertTrue(all(
            path in allowed
            or path in network_inspect_paths
            or (
                path.startswith(MODULE.API + "/containers/")
                and path.endswith("/json")
                and path.split("/")[-2] in IDS.values()
            )
            for _, path in self.server.requests
        ), "collector requested an unapproved API path")
        self.assertTrue(
            SENTINEL not in output.decode("utf-8", "replace"),
            "synthetic protected mount sentinel unexpectedly appeared",
        )

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_nonzero_exit_and_oom_are_recorded_but_not_accepted(self):
        self.server.mode = "nonzero_exit_oom"
        code, output = self.collect()
        self.assertTrue(output.startswith(b"{"), f"expected JSON observation: {output!r}")
        report = json.loads(output)
        redis = next(row for row in report["objects"]["containers"]
                     if row["service"] == "redis")
        self.assertNotEqual(code, 0)
        self.assertFalse(report["all_containers_stopped_state_match"])
        self.assertEqual(redis["state"]["exit_code"], 137)
        self.assertTrue(redis["state"]["oom_killed"])
        self.assertEqual(report["d0_current_baseline"], "NOT_ACCEPTED")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_malformed_responses(self):
        self.server.mode = "malformed_json"
        code, output = self.collect()
        self.assertNotEqual(code, 0)
        self.assertIn(b"STOP=", output)
        self.assertTrue(
            SENTINEL.encode() not in output,
            "failure output exposed a protected identifier",
        )

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_wrong_identity_and_unexpected_objects(self):
        for mode in (
            "bad_container_id",
            "wrong_id",
            "wrong_label",
            "wrong_image",
            "wrong_network_id",
            "extra_container",
            "extra_network",
            "extra_volume",
        ):
            with self.subTest(mode=mode):
                self.server.mode = mode
                self.server.requests = []
                code, output = self.collect()
                self.assertNotEqual(code, 0)
                self.assertIn(b"STOP=", output)

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_invalid_network_inspection_membership(self):
        for mode in (
            "unknown_network_member",
            "wrong_network_inspect_id",
            "wrong_network_endpoint",
            "changed_network_membership",
            "endpoint_not_in_network_map",
        ):
            with self.subTest(mode=mode):
                self.server.mode = mode
                self.server.requests = []
                code, output = self.collect()
                self.assertNotEqual(code, 0)
                self.assertIn(b"STOP=", output)

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_marks_unavailable_network_inspection_membership_without_claiming_empty(self):
        for mode in ("missing_network_inspect_members", "null_network_inspect_members"):
            with self.subTest(mode=mode):
                self.server.mode = mode
                self.server.requests = []
                code, output = self.collect()
                self.assertEqual(code, 0, f"stopped endpoint absence is reported as unavailable: {output!r}")
                report = json.loads(output)
                networks = {row["name"]: row for row in report["objects"]["networks"]}
                data_network = networks["eventsales-d0-proof_eventsales_data"]
                edge_network = networks["eventsales-d0-proof_eventsales_edge"]
                self.assertEqual(data_network["membership_status"], "STOPPED_ENDPOINTS_UNAVAILABLE")
                self.assertEqual({row["id"] for row in data_network["unavailable_stopped_members"]}, set(IDS.values()))
                self.assertFalse(data_network["membership_data_available"])
                expected_edge_status = "OBSERVED_EMPTY" if mode == "missing_network_inspect_members" else "MEMBERSHIP_UNAVAILABLE"
                self.assertEqual(edge_network["membership_status"], expected_edge_status)
                self.assertEqual(edge_network["members"], [])

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_does_not_treat_blank_container_network_id_as_verified(self):
        self.server.mode = "missing_container_network_id"
        code, output = self.collect()
        self.assertEqual(code, 0, f"stopped container network identity is recorded as unavailable: {output!r}")
        report = json.loads(output)
        postgres = next(row for row in report["objects"]["containers"]
                        if row["service"] == "postgres")
        data_network = next(row for row in report["objects"]["networks"]
                            if row["name"] == "eventsales-d0-proof_eventsales_data")
        configured = postgres["configured_networks"]["eventsales-d0-proof_eventsales_data"]
        self.assertEqual(configured["network_id"], "")
        self.assertEqual(configured["network_id_status"], "UNAVAILABLE")
        self.assertEqual(postgres["network_configuration_status"], "PARTIALLY_AVAILABLE")
        self.assertIn(IDS["postgres"], {
            row["id"] for row in data_network["unavailable_stopped_members"]
        })

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_cross_checks_network_inspection_membership_with_container_settings(self):
        self.server.mode = "cross_checked_membership"
        code, output = self.collect()
        self.assertNotEqual(code, 0, "running containers must not match the stopped-state profile")
        report = json.loads(output)
        networks = {row["name"]: row for row in report["objects"]["networks"]}
        data_network = networks["eventsales-d0-proof_eventsales_data"]
        self.assertEqual(data_network["membership_status"], "OBSERVED")
        self.assertEqual({row["id"] for row in data_network["members"]}, set(IDS.values()))
        for member in data_network["members"]:
            self.assertEqual(member["cross_check"]["network_id"], "MATCH")
            self.assertEqual(member["cross_check"]["endpoint_id"], "MATCH")
            self.assertEqual(member["cross_check"]["mac_address"], "MATCH")
            self.assertEqual(member["cross_check"]["ipv4_address"], "MATCH")
            self.assertEqual(member["cross_check"]["ipv6_address"], "MATCH")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_accepts_null_or_missing_aliases_as_unavailable(self):
        for mode in ("null_network_aliases", "missing_network_aliases"):
            with self.subTest(mode=mode):
                self.server.mode = mode
                code, output = self.collect()
                self.assertEqual(code, 0, f"optional aliases should not reject the inspection: {output!r}")
                report = json.loads(output)
                postgres = next(row for row in report["objects"]["containers"]
                                if row["service"] == "postgres")
                aliases = postgres["configured_networks"]["eventsales-d0-proof_eventsales_data"]
                self.assertIsNone(aliases["aliases"])
                self.assertEqual(aliases["aliases_status"], "UNAVAILABLE")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_malformed_aliases(self):
        self.server.mode = "malformed_network_aliases"
        code, output = self.collect()
        self.assertNotEqual(code, 0)
        self.assertEqual(output, b"D0_INSPECTION=INCOMPLETE STOP=CONTAINER_NETWORKS\n")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_marks_missing_network_addresses_unavailable_and_partial(self):
        self.server.mode = "missing_container_network_addresses"
        code, output = self.collect()
        self.assertNotEqual(code, 0, "running containers must not match the stopped-state profile")
        report = json.loads(output)
        data_network = next(row for row in report["objects"]["networks"]
                            if row["name"] == "eventsales-d0-proof_eventsales_data")
        self.assertEqual(data_network["membership_status"], "OBSERVED_WITH_PARTIAL_CONTAINER_CROSS_CHECK")
        for member in data_network["members"]:
            self.assertEqual(member["cross_check"]["mac_address"], "UNAVAILABLE")
            self.assertEqual(member["cross_check"]["ipv4_address"], "UNAVAILABLE")
            self.assertEqual(member["cross_check"]["ipv6_address"], "UNAVAILABLE")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_conflicting_network_addresses(self):
        self.server.mode = "conflicting_network_address"
        code, output = self.collect()
        self.assertNotEqual(code, 0)
        self.assertEqual(output, b"D0_INSPECTION=INCOMPLETE STOP=NETWORK_ADDRESS_MISMATCH\n")

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_accepts_docker_shaped_bind_and_tmpfs_mounts(self):
        self.server.mode = "valid_bind_mount"
        code, output = self.collect()
        self.assertEqual(code, 0, f"Docker-shaped bind/tmpfs mounts should be accepted: {output!r}")
        report = json.loads(output)
        pgbouncer = next(row for row in report["objects"]["containers"]
                         if row["service"] == "pgbouncer")
        mounts = {mount["type"]: mount for mount in pgbouncer["mounts"]}
        self.assertEqual(mounts["tmpfs"]["source"], "")
        self.assertNotIn("name", mounts["tmpfs"])
        self.assertNotIn("driver", mounts["tmpfs"])
        self.assertEqual(mounts["bind"]["source"], "/srv/config")
        self.assertEqual(mounts["bind"]["destination"], "/etc/service")
        self.assertNotIn("name", mounts["bind"])
        self.assertNotIn("driver", mounts["bind"])

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_changed_mounts_during_collection(self):
        self.server.mode = "changed_mounts"
        code, output = self.collect()
        self.assertNotEqual(code, 0)
        self.assertIn(b"STOP=", output)
        self.assertTrue(
            SENTINEL.encode() not in output,
            "failure output exposed a protected mount path",
        )

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_timeouts(self):
        self.server.mode = "timeout"
        MODULE.REQUEST_SECONDS = 0.05
        code, output = self.collect()
        self.assertNotEqual(code, 0)
        self.assertIn(b"STOP=", output)

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_missing_required_fields(self):
        for mode in (
            "missing_version",
            "missing_exit_code",
            "missing_oom",
            "missing_mounts",
            "missing_volume_mountpoint",
            "missing_volume_mount_name",
            "missing_volume_mount_driver",
        ):
            with self.subTest(mode=mode):
                self.server.mode = mode
                self.server.requests = []
                code, output = self.collect()
                self.assertNotEqual(code, 0)
                self.assertIn(b"STOP=", output)

    @unittest.skipUnless(COLLECTOR_EXISTS, "collector has not been implemented")
    def test_rejects_unsupported_http_and_oversized_body(self):
        for mode in (
            "bad_status",
            "bad_content_type",
            "duplicate_json_key",
            "oversized_body",
        ):
            with self.subTest(mode=mode):
                self.server.mode = mode
                self.server.requests = []
                code, output = self.collect()
                self.assertNotEqual(code, 0)
                self.assertIn(b"STOP=", output)


unittest.main(argv=["d0-current-state-inspect-tests"], verbosity=2)
PY
