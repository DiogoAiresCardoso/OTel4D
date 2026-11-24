"""Exercise the Delphi public API over loopback with the independent OTLP schema."""

import os
import re
import subprocess
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import (
    ExportTraceServiceRequest,
    ExportTraceServiceResponse,
)

PROTOBUF = "application/x-protobuf"


class Receiver(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        self.server.received.append((self.path, self.headers, body))
        if hasattr(self.server, "release"):
            self.server.release.wait(timeout=12)
        responses = self.server.responses
        status, payload, media, headers = responses[min(len(self.server.received), len(responses)) - 1]
        if len(body) > getattr(self.server, "max_bytes", len(body)):
            status, payload, headers = 413, b"", {}
        self.send_response(status)
        self.send_header("Content-Type", media)
        self.send_header("Content-Length", str(len(payload)))
        for key, value in headers.items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


class TraceDelivery(unittest.TestCase):
    @staticmethod
    def environment(endpoint):
        env = {key: value for key, value in os.environ.items() if not key.upper().startswith("OTEL_")}
        env.update(OTEL_SERVICE_NAME="test.orders", OTEL_EXPORTER_OTLP_ENDPOINT=endpoint,
                   OTEL_EXPORTER_OTLP_HEADERS="X-Tag=hello%20world%2B")
        return env

    def exercise(self, responses, rejected=0, warnings=0, settings=None, path="/tenant/v1/traces"):
        with ThreadingHTTPServer(("127.0.0.1", 0), Receiver) as server:
            server.received = []
            server.responses = responses
            worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
            worker.start()
            base = f"http://127.0.0.1:{server.server_port}"
            env = self.environment(base + "/tenant")
            for key, value in (settings or {}).items():
                env[key] = value.replace("{base}", base)
            try:
                command = [str(self.executable)]
                if rejected:
                    command.append("expect-loss")
                run = subprocess.run(command, env=env, capture_output=True, text=True, timeout=25)
            finally:
                server.shutdown()
                worker.join()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertRegex(run.stdout, rf"flush={int(rejected == 0)} dropped=0 rejected={rejected} warnings={warnings}\b")
        self.assertEqual(len(server.received), len(responses))
        first_body = server.received[0][2]
        for target, headers, body in server.received:
            self.assertEqual(target, path)
            self.assertEqual(headers["Content-Type"], PROTOBUF)
            self.assertEqual(headers["Accept"], PROTOBUF)
            self.assertEqual(headers["X-Tag"], "hello world+")
            self.assertEqual(body, first_body)
        message = ExportTraceServiceRequest.FromString(first_body)
        self.assertEqual(len(message.resource_spans), 1)
        resource = message.resource_spans[0]
        self.assertEqual({a.key: a.value.string_value for a in resource.resource.attributes},
                         {"service.name": "test.orders"})
        self.assertEqual(len(resource.scope_spans), 1)
        group = resource.scope_spans[0]
        self.assertEqual((group.scope.name, group.scope.version), ("orders.delphi", "1.0"))
        spans = {s.name: s for s in group.spans}
        self.assertEqual(len(group.spans), 4)
        self.assertEqual(set(spans), {"orders.receive", "orders.query", "orders.root", "orders.other"})
        server_span, child = spans["orders.receive"], spans["orders.query"]
        self.assertEqual(server_span.trace_id.hex(), "0123456789abcdef0123456789abcdef")
        self.assertEqual(server_span.parent_span_id.hex(), "0123456789abcdef")
        self.assertEqual((server_span.flags, server_span.kind), (0x301, 2))
        self.assertEqual((child.trace_id, child.parent_span_id, child.flags, child.kind),
                         (server_span.trace_id, server_span.span_id, 0x101, 3))
        self.assertEqual(child.trace_state, "vendor=upstream")
        self.assertEqual(spans["orders.root"].status.code, 1)
        self.assertEqual(spans["orders.root"].parent_span_id, b"")
        self.assertNotEqual(spans["orders.root"].trace_id, spans["orders.other"].trace_id)
        self.assertEqual(len({s.span_id for s in spans.values()}), 4)
        for span in spans.values():
            self.assertEqual(len(span.trace_id), 16)
            self.assertEqual(len(span.span_id), 8)
            self.assertGreater(span.start_time_unix_nano, 0)
            self.assertGreaterEqual(span.end_time_unix_nano, span.start_time_unix_nano)
        typed = {a.key: (a.value.WhichOneof("value"), getattr(a.value, a.value.WhichOneof("value")))
                 for a in server_span.attributes}
        self.assertEqual(typed, {"order.number": ("int_value", -3000000000), "cached": ("bool_value", True),
                                 "ratio": ("double_value", 0.75), "label": ("string_value", "café")})
        self.assertEqual([e.name for e in server_span.events], ["received"])
        self.assertEqual((child.status.code, child.status.message), (2, "conversion failed"))
        self.assertEqual([e.name for e in child.events], ["exception"])
        self.assertEqual({a.key: a.value.string_value for a in child.events[0].attributes},
                         {"exception.type": "EConvertError"})

    def test_full_success_at_exact_signal_endpoint(self):
        settings = {"OTEL_EXPORTER_OTLP_TRACES_ENDPOINT": "{base}/exact?tenant=east"}
        self.exercise([(200, b"", PROTOBUF, {})], settings=settings, path="/exact?tenant=east")

    def test_retry_preserves_payload(self):
        self.exercise([(503, b"", PROTOBUF, {"Retry-After": "0"}), (200, b"", PROTOBUF, {})])

    def test_retry_after_beyond_specific_timeout(self):
        settings = {"OTEL_EXPORTER_OTLP_TRACES_TIMEOUT": "300", "OTEL_EXPORTER_OTLP_TIMEOUT": "10000"}
        self.exercise([(503, b"", PROTOBUF, {"Retry-After": "2"})], rejected=4, settings=settings)

    def test_partial_success_and_warning(self):
        for rejected in (0, 1):
            reply = ExportTraceServiceResponse()
            reply.partial_success.rejected_spans = rejected
            reply.partial_success.error_message = "synthetic receiver warning"
            with self.subTest(rejected=rejected):
                self.exercise([(200, reply.SerializeToString(), PROTOBUF, {})], rejected=rejected, warnings=1)

    def test_large_batch_is_split_by_encoded_bytes(self):
        with ThreadingHTTPServer(("127.0.0.1", 0), Receiver) as server:
            server.received = []
            server.responses = [(200, b"", PROTOBUF, {})]
            server.max_bytes = 4 * 1024 * 1024
            worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
            worker.start()
            env = self.environment(f"http://127.0.0.1:{server.server_port}/tenant")
            try:
                run = subprocess.run([str(self.executable), "large"], env=env, capture_output=True,
                                     text=True, timeout=25)
            finally:
                server.shutdown()
                worker.join()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn("flush=1 dropped=0 rejected=0", run.stdout)
        self.assertGreater(len(server.received), 1)
        sequence = []
        for target, _, body in server.received:
            self.assertEqual(target, "/tenant/v1/traces")
            self.assertLessEqual(len(body), server.max_bytes)
            request = ExportTraceServiceRequest.FromString(body)
            sequence.extend(
                next(a.value.int_value for a in span.attributes if a.key == "sequence")
                for resource in request.resource_spans for scope in resource.scope_spans for span in scope.spans
            )
        self.assertEqual(sequence, list(range(1, 129)))

    def test_terminal_responses(self):
        for response in [(400, b"", PROTOBUF, {}), (307, b"", PROTOBUF, {"Location": "/unexpected"}),
                         (200, bytes([0x0a, 0xff]), PROTOBUF, {}), (200, b"{}", "application/json", {})]:
            with self.subTest(response=response):
                self.exercise([response], rejected=4)

    def test_flush_deadline_and_queue_pressure(self):
        for mode, submitted in (("delayed", 4), ("pressure", 3000)):
            with self.subTest(mode=mode), ThreadingHTTPServer(("127.0.0.1", 0), Receiver) as server:
                server.received = []
                server.responses = [(200, b"", PROTOBUF, {})]
                server.release = threading.Event()
                worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02})
                worker.start()
                env = self.environment(f"http://127.0.0.1:{server.server_port}")
                lines = []
                try:
                    with subprocess.Popen([str(self.executable), mode], env=env, stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT, text=True) as app:
                        def watch_client():
                            for line in app.stdout:
                                lines.append(line)
                                if line.strip() == "release receiver":
                                    server.release.set()

                        reader = threading.Thread(target=watch_client)
                        reader.start()
                        try:
                            app.wait(timeout=25)
                        finally:
                            if app.poll() is None:
                                app.kill()
                            reader.join(5)
                finally:
                    server.release.set()
                    server.shutdown()
                    worker.join()
                output = "".join(lines)
                self.assertEqual(app.returncode, 0, output)
                self.assertIn("release receiver", output)
                counters = re.search(r"flush=(\d) dropped=(\d+) rejected=0 warnings=0", output)
                self.assertIsNotNone(counters, output)
                success, dropped = map(int, counters.groups())
                self.assertEqual(success, int(mode == "delayed"))
                self.assertEqual(dropped > 0, mode == "pressure")
                ids = []
                for _, _, body in server.received:
                    request = ExportTraceServiceRequest.FromString(body)
                    batch = [s for r in request.resource_spans for scope in r.scope_spans for s in scope.spans]
                    self.assertLessEqual(len(batch), 128)
                    ids.extend(s.span_id for s in batch)
                self.assertEqual(len(set(ids)), len(ids))
                self.assertEqual(len(ids) + dropped, submitted)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python verify_traces.py path/to/TraceSmoke.exe")
    TraceDelivery.executable = Path(sys.argv.pop()).resolve(strict=True)
    unittest.main(verbosity=2)
