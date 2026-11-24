"""Send correlated OTLP JSON fixtures and query them through Grafana."""

import argparse
import base64
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import json
import os
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener
from uuid import uuid4


OTLP = os.environ.get("OTLP_ENDPOINT", "http://lgtm:4318").rstrip("/")
GRAFANA = os.environ.get("GRAFANA_ENDPOINT", "http://lgtm:3000").rstrip("/")
SERVICE = os.environ.get("OTEL_SERVICE_NAME", "dac-otel-smoke")
GAUGE = "dac_otel_smoke"
SPAN_NAME = "smoke.test"
LOG_BODY = "OpenTelemetry smoke test"
RETRYABLE = {429, 502, 503, 504}
REQUEST_TIMEOUT = 5
QUERY_TIMEOUT = 90


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


HTTP = build_opener(ProxyHandler({}), NoRedirect())


def string_attribute(key, value):
    return {"key": key, "value": {"stringValue": value}}


def fixtures(trace_id, span_id):
    now = time.time_ns()
    timestamp = str(now)
    resource = {"attributes": [
        string_attribute("service.name", SERVICE),
        string_attribute("deployment.environment.name", "test"),
    ]}
    scope = {"name": "otel-lgtm.smoke"}
    correlation = {"traceId": trace_id, "spanId": span_id, "flags": 1}
    span = {
        **correlation, "name": SPAN_NAME, "kind": 1,
        "startTimeUnixNano": str(now - 5_000_000), "endTimeUnixNano": timestamp,
    }
    metric = {"name": GAUGE, "gauge": {"dataPoints": [{
        "attributes": [string_attribute("smoke_run_id", trace_id)],
        "timeUnixNano": timestamp, "asInt": "1",
    }]}}
    log = {
        **correlation, "timeUnixNano": timestamp, "observedTimeUnixNano": timestamp,
        "severityNumber": 9, "severityText": "INFO", "body": {"stringValue": LOG_BODY},
    }
    return {
        "traces": {"resourceSpans": [{"resource": resource, "scopeSpans": [{"scope": scope, "spans": [span]}]}]},
        "metrics": {"resourceMetrics": [{"resource": resource, "scopeMetrics": [{"scope": scope, "metrics": [metric]}]}]},
        "logs": {"resourceLogs": [{"resource": resource, "scopeLogs": [{"scope": scope, "logRecords": [log]}]}]},
    }


def read_json(request, timeout=REQUEST_TIMEOUT, check_media=False):
    with HTTP.open(request, timeout=timeout) as response:
        if response.status != 200:
            raise ValueError(f"Expected HTTP 200, received HTTP {response.status}")
        if check_media and response.headers.get_content_type() != "application/json":
            raise ValueError("Expected an OTLP JSON acknowledgement")
        return json.load(response)


def retry_delay(header, fallback):
    if not header:
        return fallback
    try:
        delay = int(header)
    except ValueError:
        try:
            until = parsedate_to_datetime(header)
            if until.tzinfo is None:
                until = until.replace(tzinfo=timezone.utc)
            delay = (until - datetime.now(timezone.utc)).total_seconds()
        except (ValueError, TypeError, OverflowError):
            return fallback
    return max(fallback, delay)


def send(signal, payload):
    rejected_field = {"traces": "rejectedSpans", "metrics": "rejectedDataPoints", "logs": "rejectedLogRecords"}[signal]
    request = Request(f"{OTLP}/v1/{signal}", data=json.dumps(payload).encode("utf-8"),
                      headers={"Content-Type": "application/json", "Accept": "application/json"})
    deadline = time.monotonic() + 30
    for attempt in range(5):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError(f"{signal} export deadline elapsed")
        backoff = min(2 ** attempt, 4)
        try:
            reply = read_json(request, timeout=min(REQUEST_TIMEOUT, remaining), check_media=True)
        except HTTPError as error:
            with error:
                if error.code not in RETRYABLE:
                    raise ValueError(f"{signal} export failed with HTTP {error.code}") from error
                delay = retry_delay(error.headers.get("Retry-After"), backoff)
                failure = f"HTTP {error.code}"
        except (URLError, TimeoutError, ConnectionError) as error:
            delay = backoff
            failure = str(error)
        else:
            if not isinstance(reply, dict):
                raise ValueError(f"{signal} acknowledgement must be a JSON object")
            partial = reply.get("partialSuccess", {})
            if not isinstance(partial, dict):
                raise ValueError(f"{signal} partialSuccess must be a JSON object")
            rejected = partial.get(rejected_field, "0")
            if type(rejected) not in (str, int) or not re.fullmatch(r"\d+", str(rejected)):
                raise ValueError(f"{signal} acknowledgement returned an invalid rejection count")
            if int(rejected):
                raise ValueError(f"{signal} acknowledged with {rejected} rejected items")
            warning = " (receiver warning)" if partial.get("errorMessage") else ""
            print(f"PASS OTLP {signal}: HTTP 200, zero rejected{warning}")
            return
        if attempt == 4 or delay >= deadline - time.monotonic():
            raise ValueError(f"{signal} export did not succeed: {failure}")
        time.sleep(delay)


def grafana_query(source, path, params=None):
    query = "?" + urlencode(params) if params else ""
    request = Request(f"{GRAFANA}/api/datasources/proxy/uid/{source}{path}{query}",
                      headers={"Accept": "application/json"})
    return read_json(request)


def same_id(wire_value, expected):
    if wire_value == expected:
        return True
    try:
        return base64.b64decode(wire_value, validate=True).hex() == expected
    except (ValueError, TypeError):
        return False


def tempo_contains(trace_id, span_id):
    trace = grafana_query("tempo", f"/api/traces/{trace_id}")
    for batch in trace.get("batches", trace.get("resourceSpans", [])):
        attributes = batch.get("resource", {}).get("attributes", [])
        if string_attribute("service.name", SERVICE) not in attributes:
            continue
        for group in batch.get("scopeSpans", []):
            for span in group.get("spans", []):
                if (span["name"] == SPAN_NAME and same_id(span["traceId"], trace_id)
                        and same_id(span["spanId"], span_id)):
                    return True
    return False


def prometheus_contains(trace_id):
    selector = f'{GAUGE}{{smoke_run_id="{trace_id}"}}'
    reply = grafana_query("prometheus", "/api/v1/query", {"query": selector})
    return reply.get("status") == "success" and any(
        sample["metric"].get("smoke_run_id") == trace_id and float(sample["value"][1]) == 1
        for sample in reply.get("data", {}).get("result", [])
    )


def loki_contains(trace_id, span_id):
    query = (f'{{service_name={json.dumps(SERVICE)}}} |= {json.dumps(LOG_BODY)} '
             f'| trace_id = "{trace_id}" | span_id = "{span_id}" | severity_text = "INFO"')
    end = time.time_ns()
    reply = grafana_query("loki", "/loki/api/v1/query_range", {
        "query": query, "start": end - 15 * 60 * 10**9, "end": end, "limit": 10,
    })
    return reply.get("status") == "success" and any(
        entry[1] == LOG_BODY for stream in reply.get("data", {}).get("result", [])
        for entry in stream["values"]
    )


def verify_storage(trace_id, span_id):
    pending = {
        "Tempo": (lambda: tempo_contains(trace_id, span_id), f"{SPAN_NAME} with matching TraceID and SpanID"),
        "Prometheus": (lambda: prometheus_contains(trace_id), f"{GAUGE}=1 for this run"),
        "Loki": (lambda: loki_contains(trace_id, span_id), "INFO message with matching TraceID and SpanID"),
    }
    last_failures = {}
    deadline = time.monotonic() + QUERY_TIMEOUT
    while pending:
        for source, (check, description) in list(pending.items()):
            try:
                if check():
                    print(f"PASS Grafana / {source}: {description}")
                    del pending[source]
                    continue
                last_failures[source] = "the fixture was not found"
            except HTTPError as error:
                with error:
                    if error.code not in RETRYABLE | {404, 500}:
                        raise ValueError(f"{source} query failed with HTTP {error.code}") from error
                    last_failures[source] = f"HTTP {error.code}"
            except (URLError, TimeoutError, ConnectionError) as error:
                last_failures[source] = str(error)
        if not pending:
            return
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError("; ".join(f"{source}: {last_failures[source]}" for source in pending))
        time.sleep(min(2, remaining))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", nargs=2, metavar=("TRACE_ID", "SPAN_ID"),
                        help="query an existing fixture without submitting new data")
    args = parser.parse_args()
    trace_id, span_id = args.verify_only or (uuid4().hex, uuid4().hex[:16])
    for value, digits in ((trace_id, 32), (span_id, 16)):
        if not re.fullmatch(rf"[0-9a-f]{{{digits}}}", value) or int(value, 16) == 0:
            parser.error(f"expected a nonzero lowercase hexadecimal identifier with {digits} digits")
    print(f"service.name={SERVICE}  trace_id={trace_id}  span_id={span_id}  gauge={GAUGE}")
    try:
        if not args.verify_only:
            for signal, payload in fixtures(trace_id, span_id).items():
                send(signal, payload)
        verify_storage(trace_id, span_id)
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
