"""Verify FireDAC behavior and the three signals through a Delphi consumer."""
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

import verify_telemetry as telemetry

from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import ExportTraceServiceRequest


class FireDACTest(unittest.TestCase):
    exercise = telemetry.TelemetryTest.exercise

    @staticmethod
    def spans(payloads):
        for payload in payloads:
            for resource in ExportTraceServiceRequest.FromString(payload).resource_spans:
                for scope in resource.scope_spans:
                    yield from scope.spans

    def test_sqlite_concurrency_streaming_and_preserved_errors(self):
        requests, output = self.exercise()
        self.assertIn("database operations passed, delivered=1", output)
        spans = list(self.spans(requests["/tenant/v1/traces"]))
        roots = {span.span_id: span for span in spans if not span.parent_span_id}
        self.assertEqual({span.name for span in roots.values()}, {"orders.first", "orders.second"})
        self.assertEqual(len({span.trace_id for span in roots.values()}), 2)
        children = [span for span in spans if span.parent_span_id]
        self.assertEqual(len(children), 6)
        for parent, root in roots.items():
            group = [span for span in children if span.parent_span_id == parent]
            self.assertEqual(len(group), 3)
            self.assertTrue(all(span.trace_id == root.trace_id and span.kind == 3 for span in group))
            self.assertEqual(sum(span.status.code == 2 for span in group), 1)
        logs = list(telemetry.TelemetryTest.log_records(requests["/tenant/v1/logs"]))
        self.assertEqual({log.span_id for log in logs}, set(roots))
        points = list(telemetry.TelemetryTest.metric_points(requests["/tenant/v1/metrics"]))
        self.assertEqual({m.name for _, _, m, _, _ in points}, {"db.client.operation.duration"})
        self.assertEqual(sum(point.count for _, _, _, _, point in points), 8)
        failed = [point for _, _, _, _, point in points if any(a.key == "error.type" for a in point.attributes)]
        self.assertEqual(sum(point.count for point in failed), 2)
        self.assertAlmostEqual(sum(point.sum for point in failed), sum(
            (span.end_time_unix_nano - span.start_time_unix_nano) / 1e9
            for span in children if span.status.code == 2), places=10)
        for bodies in requests.values():
            for body in bodies:
                self.assertNotIn(b"sensitive-", body)
                self.assertNotIn(b"select amount from fixture", body)

    def test_disabled_and_unavailable_receiver_preserve_business_operations(self):
        requests, output = self.exercise(configs={"OTEL_SDK_DISABLED": "true"})
        self.assertEqual(requests, {})
        self.assertIn("database operations passed, delivered=1", output)
        responses = {f"/tenant/v1/{signal}": [(503, b"", {"Retry-After": "30"})]
                     for signal in ("traces", "logs", "metrics")}
        _, output = self.exercise(responses=responses, configs={"OTEL_EXPORTER_OTLP_TIMEOUT": "1000"})
        self.assertIn("database operations passed, delivered=0", output)
        with socket.socket() as refused:
            refused.bind(("127.0.0.1", 0))
            endpoint = f"http://127.0.0.1:{refused.getsockname()[1]}"
            requests, output = self.exercise(configs={
                "OTEL_EXPORTER_OTLP_ENDPOINT": endpoint, "OTEL_EXPORTER_OTLP_TIMEOUT": "350",
            })
        self.assertEqual(requests, {})
        self.assertIn("database operations passed, delivered=0", output)

    @unittest.skipUnless(os.getenv("OTEL4D_TEST_FIREBIRD"), "Set the path to a Win32 Firebird client with embedded support.")
    def test_firebird_stored_procedure(self):
        with tempfile.TemporaryDirectory(prefix="otel4d-firebird-") as temp:
            args = ["firebird", str(Path(temp) / "fixture.fdb"), os.environ["OTEL4D_TEST_FIREBIRD"]]
            requests, output = self.exercise(args)
        self.assertIn("database operations passed, delivered=1", output)
        span, = self.spans(requests["/tenant/v1/traces"])
        self.assertEqual((span.kind, span.status.code), (3, 0))
        tags = {item.key: item.value.string_value for item in span.attributes}
        self.assertEqual(tags, {"db.system.name": "firebirdsql", "db.operation.name": "CALL"})
        point, = [point for _, _, _, _, point in telemetry.TelemetryTest.metric_points(requests["/tenant/v1/metrics"])]
        self.assertEqual(point.count, 1)
        self.assertAlmostEqual(point.sum, (span.end_time_unix_nano - span.start_time_unix_nano) / 1e9, places=10)

    @unittest.skipUnless(os.getenv("OTEL4D_TEST_COLLECTOR"), "Set the official Collector executable path.")
    def test_official_collector_receives_all_signals(self):
        with tempfile.TemporaryDirectory(prefix="otel4d-collector-") as temp:
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", 0))
                port = probe.getsockname()[1]
            config = Path(__file__).resolve().parents[1] / "examples" / "collector.yaml"
            local_config = Path(temp) / "collector.yaml"
            local_config.write_text(config.read_text().replace("127.0.0.1:4318", f"127.0.0.1:{port}"))
            env = {key: value for key, value in os.environ.items() if not key.upper().startswith("OTEL_")}
            env.update(OTEL_SERVICE_NAME="otel4d.fire-dac-fixture", OTEL_EXPORTER_OTLP_ENDPOINT=f"http://127.0.0.1:{port}")
            log = Path(temp) / "collector.log"
            with log.open("wb") as sink:
                collector = subprocess.Popen([os.environ["OTEL4D_TEST_COLLECTOR"], "--config=" + str(local_config)],
                                             stdout=sink, stderr=subprocess.STDOUT, env=env)
                try:
                    for _ in range(100):
                        if collector.poll() is not None:
                            self.fail(log.read_text(encoding="utf-8"))
                        try:
                            with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                                break
                        except OSError:
                            time.sleep(0.05)
                    else:
                        self.fail("The Collector did not bind its HTTP port.")
                    result = subprocess.run([str(self.executable)], env=env, capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("database operations passed, delivered=1", result.stdout)
                    output = log.read_text(encoding="utf-8")
                    for expected in ("otel4d.fire-dac-fixture", "orders.first", "orders.second",
                                     "database workflow completed", "db.client.operation.duration"):
                        self.assertIn(expected, output)
                finally:
                    collector.terminate()
                    collector.wait(timeout=10)


if __name__ == "__main__":
    FireDACTest.executable = Path(sys.argv.pop()).resolve(strict=True)
    unittest.main(verbosity=2)
