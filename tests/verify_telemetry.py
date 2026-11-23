"""Decode a real Delphi consumer's OTLP/HTTP payloads with the official bindings."""
import os
import re
import subprocess
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from opentelemetry.proto.collector.logs.v1.logs_service_pb2 import (
    ExportLogsServiceRequest, ExportLogsServiceResponse,
)
from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import ExportTraceServiceRequest

MEDIA = "application/x-protobuf"


class Receiver(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with self.server.lock:
            requests = self.server.requests.setdefault(self.path, [])
            requests.append(body)
            index = len(requests) - 1
        status, response, headers = self.server.responses.get(self.path, [(200, b"", {})])[min(
            index, len(self.server.responses.get(self.path, [(200, b"", {})])) - 1)]
        if self.server.slow_path == self.path:
            self.server.release.wait(5)
        self.send_response(status)
        self.send_header("Content-Type", MEDIA)
        self.send_header("Content-Length", str(len(response)))
        for key, value in headers.items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, *_):
        pass


class TelemetryTest(unittest.TestCase):
    def exercise(self, mode="", configs=None, responses=None, slow_path=""):
        with ThreadingHTTPServer(("127.0.0.1", 0), Receiver) as server:
            server.requests = {}
            server.responses = responses or {}
            server.lock = threading.Lock()
            server.slow_path = slow_path
            server.release = threading.Event()
            worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
            worker.start()
            base = f"http://127.0.0.1:{server.server_port}"
            env = {key: value for key, value in os.environ.items() if not key.upper().startswith("OTEL_")}
            env.update(OTEL_SERVICE_NAME="test.multisignal", OTEL_EXPORTER_OTLP_ENDPOINT=base + "/tenant")
            for key, value in (configs or {}).items():
                env[key] = value.replace("{base}", base)
            try:
                with subprocess.Popen([str(self.executable), mode], env=env, stdout=subprocess.PIPE,
                                      stderr=subprocess.STDOUT, text=True) as app:
                    if slow_path:
                        marker = app.stdout.readline()
                        server.release.set()
                        self.assertEqual(marker.strip(), "release receiver")
                    output, _ = app.communicate(timeout=35)
                    self.assertEqual(app.returncode, 0, output)
            finally:
                server.release.set()
                server.shutdown()
                worker.join()
            return server.requests, output

    @staticmethod
    def log_records(requests):
        for body in requests:
            for resource in ExportLogsServiceRequest.FromString(body).resource_logs:
                for scope in resource.scope_logs:
                    yield from scope.log_records

    def test_log_fields_and_correlation(self):
        path = "/exact/logs?tenant=a"
        requests, output = self.exercise(configs={"OTEL_EXPORTER_OTLP_LOGS_ENDPOINT": "{base}" + path})
        self.assertIn("flush=1 logs_dropped=0 logs_rejected=0 logs_warnings=0", output)
        payload, = requests[path]
        resource, = ExportLogsServiceRequest.FromString(payload).resource_logs
        self.assertEqual(resource.resource.attributes[0].value.string_value, "test.multisignal")
        scope, = resource.scope_logs
        self.assertEqual((scope.scope.name, scope.scope.version), ("orders.logger", "2"))
        records = {record.body.string_value: record for record in scope.log_records}
        self.assertEqual(set(records), {"sampled", "unsampled", "outside"})
        trace = ExportTraceServiceRequest.FromString(requests["/tenant/v1/traces"][0])
        span, = trace.resource_spans[0].scope_spans[0].spans
        log = records["sampled"]
        self.assertEqual((log.trace_id, log.span_id, log.flags), (span.trace_id, span.span_id, 1))
        self.assertEqual((log.severity_number, log.time_unix_nano), (9, 1700000000000000001))
        self.assertGreater(log.observed_time_unix_nano, log.time_unix_nano)
        expected = {"count": ("int_value", -3000000000), "cache": ("bool_value", True),
                    "ratio": ("double_value", 0.5), "message": ("string_value", "café")}
        actual = {a.key: (a.value.WhichOneof("value"), getattr(a.value, a.value.WhichOneof("value")))
                  for a in log.attributes}
        self.assertEqual(actual, expected)
        self.assertEqual(records["unsampled"].span_id.hex(), "0123456789abcdef")
        self.assertEqual((records["unsampled"].flags, records["unsampled"].severity_number), (0, 13))
        self.assertEqual((records["outside"].trace_id, records["outside"].span_id), (b"", b""))

    def test_log_acknowledgements(self):
        path = "/tenant/v1/logs"
        partial = ExportLogsServiceResponse()
        partial.partial_success.rejected_log_records = 1
        partial.partial_success.error_message = "fixture"
        for response, count, rejected, warnings in [
            ([(503, b"", {"Retry-After": "0"}), (200, b"", {})], 2, 0, 0),
            ([(400, b"", {})], 1, 3, 0),
            ([(200, partial.SerializeToString(), {})], 1, 1, 1),
        ]:
            with self.subTest(rejected=rejected):
                requests, output = self.exercise(responses={path: response})
                self.assertEqual(len(requests[path]), count)
                self.assertEqual(len(set(requests[path])), 1)
                self.assertIn(f"logs_rejected={rejected} logs_warnings={warnings}", output)
                self.assertEqual(len(requests["/tenant/v1/traces"]), 1)

    def test_log_queue_is_bounded(self):
        path = "/tenant/v1/logs"
        requests, output = self.exercise(mode="pressure", slow_path=path)
        dropped = int(re.search(r"logs_dropped=(\d+)", output)[1])
        self.assertGreater(dropped, 0)
        self.assertIn("logs_rejected=0", output)
        self.assertEqual(sum(1 for _ in self.log_records(requests[path])) + dropped, 3000)

    def test_log_disable_is_independent(self):
        requests, _ = self.exercise(configs={"OTEL_LOGS_EXPORTER": "none", "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL": "grpc"})
        self.assertEqual(set(requests), {"/tenant/v1/traces"})
        requests, _ = self.exercise(configs={"OTEL_SDK_DISABLED": "true"})
        self.assertEqual(requests, {})


if __name__ == "__main__":
    TelemetryTest.executable = Path(sys.argv.pop()).resolve(strict=True)
    unittest.main(verbosity=2)
