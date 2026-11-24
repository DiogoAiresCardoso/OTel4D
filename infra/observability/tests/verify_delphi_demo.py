"""Check the four traces produced by the Delphi demo and their logs and metrics."""

import argparse
from collections import Counter
from math import isfinite
import re
import sys
import time

from smoke import grafana_query, same_id, string_attribute


SERVICE = "otel4d-delphi-demo"
ROOT = "demo.order.preview"
CALCULATE = ("demo.order.calculate", "INTERNAL", "OK", "order.total.calculated")
SEVERITIES = {"TRACE": 1, "DEBUG": 5, "INFO": 9, "WARN": 13, "ERROR": 17, "FATAL": 21}
SCENARIOS = {
    "success": (-3, "OK", [("demo.inventory.reserve", "CLIENT", "OK", "inventory.attempt.succeeded",
                            "DEBUG", "Inventory reserved")]),
    "retry": (3, "OK", [("demo.inventory.restock", "CLIENT", "ERROR", "inventory.attempt.failed",
                         "WARN", "Inventory restock timed out"),
                        ("demo.inventory.restock", "CLIENT", "OK", "inventory.attempt.succeeded",
                         "DEBUG", "Inventory restocked on retry")]),
    "rejected": (0, "ERROR", [("demo.order.validate", "INTERNAL", "ERROR", "order.rejected",
                               "ERROR", "Order quantity exceeds the demo limit")]),
    "unavailable": (0, "ERROR", [("demo.inventory.reserve", "CLIENT", "ERROR", "inventory.attempt.failed",
                                  "FATAL", "Inventory dependency unavailable")]),
}


def verify_trace(trace_id, scenario):
    _, root_status, steps = SCENARIOS[scenario]
    trace = grafana_query("tempo", f"/api/traces/{trace_id}")
    spans = [span for batch in trace.get("batches", trace.get("resourceSpans", []))
             if string_attribute("service.name", SERVICE) in batch["resource"]["attributes"]
             for scope in batch["scopeSpans"] for span in scope["spans"]]
    roots = [span for span in spans if span["name"] == ROOT and not span.get("parentSpanId")]
    if len(roots) != 1 or len(spans) != 2 + len(steps):
        raise ValueError(f"{scenario}: unexpected root or span count")
    root = roots[0]
    if (root["status"]["code"] != f"STATUS_CODE_{root_status}"
            or string_attribute("demo.scenario", scenario) not in root["attributes"]):
        raise ValueError(f"{scenario}: unexpected root status or scenario attribute")
    if scenario == "retry" and not any(event["name"] == "inventory.retry.scheduled" for event in root["events"]):
        raise ValueError("retry: expected the root retry event")
    if not all(same_id(span["traceId"], trace_id) for span in spans):
        raise ValueError(f"{scenario}: unexpected trace ID on a span")

    children = [span for span in spans if span is not root]
    expected_logs = [("TRACE", "Order processing started", root["spanId"]),
                     ("DEBUG", "Order total calculated", root["spanId"])]
    if root_status == "OK":
        expected_logs.append(("INFO", "Demo order processed", root["spanId"]))
    for name, kind, status, event, *log in [CALCULATE, *steps]:
        matches = [span for span in children if span["name"] == name
                   and span["kind"] == f"SPAN_KIND_{kind}"
                   and span["status"]["code"] == f"STATUS_CODE_{status}"
                   and span.get("parentSpanId") == root["spanId"]
                   and any(item["name"] == event for item in span.get("events", []))]
        if len(matches) != 1:
            raise ValueError(f"{scenario}: expected one {name} span with status {status} and event {event}")
        if log:
            expected_logs.append((*log, matches[0]["spanId"]))
    return expected_logs


def verify_logs(trace_id, scenario, expected):
    end = time.time_ns()
    reply = grafana_query("loki", "/loki/api/v1/query_range", {
        "query": f'{{service_name="{SERVICE}"}} | trace_id = "{trace_id}"',
        "start": end - 15 * 60 * 10**9, "end": end, "limit": 50,
    })
    actual = [(stream["stream"], value[1]) for stream in reply["data"]["result"] for value in stream["values"]]
    if reply["status"] != "success" or Counter(body for _, body in actual) != Counter(body for _, body, _ in expected):
        raise ValueError(f"{scenario}: unexpected log count or body")
    for level, body, span_id in expected:
        attrs = next(labels for labels, message in actual if message == body)
        if (attrs.get("severity_text") != level or int(attrs["severity_number"]) != SEVERITIES[level]
                or attrs.get("demo_scenario") != scenario or attrs.get("demo_simulated") != "true"
                or not same_id(span_id, attrs.get("span_id"))):
            raise ValueError(f"{scenario}: wrong severity, attributes or span correlation for {body!r}")


def metric(name, scenario):
    query = f'last_over_time({name}{{service_name="{SERVICE}",demo_scenario="{scenario}"}}[15m])'
    reply = grafana_query("prometheus", "/api/v1/query", {"query": query})
    series = reply["data"]["result"]
    if reply["status"] != "success" or len(series) != 1:
        raise ValueError(f"{scenario}: expected one series for {name}")
    return float(series[0]["value"][1])


def verify_metrics(scenario):
    runs = metric("otel4d_demo_operations_total", scenario)
    inventory = metric("otel4d_demo_inventory_adjustment", scenario)
    duration = "otel4d_demo_operation_duration_seconds"
    observations = metric(duration + "_count", scenario)
    duration_sum = metric(duration + "_sum", scenario)
    if (not runs.is_integer() or runs < 1 or observations != runs
            or inventory != SCENARIOS[scenario][0] * runs or not isfinite(duration_sum) or duration_sum < 0):
        raise ValueError(f"{scenario}: inconsistent run count, inventory adjustment or duration histogram")
    return f"runs={runs:g}, observations={observations:g}, inventory={inventory:+g}, duration sum={duration_sum:g}s"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for scenario in SCENARIOS:
        parser.add_argument(scenario, metavar=f"{scenario.upper()}_TRACE_ID")
    trace_ids = vars(parser.parse_args())
    if (len(set(trace_ids.values())) != len(SCENARIOS)
            or any(not re.fullmatch(r"[0-9a-f]{32}", value) or int(value, 16) == 0 for value in trace_ids.values())):
        parser.error("provide four distinct, nonzero, lowercase trace IDs")
    try:
        for scenario, trace_id in trace_ids.items():
            expected_logs = verify_trace(trace_id, scenario)
            verify_logs(trace_id, scenario, expected_logs)
            metrics = verify_metrics(scenario)
            print(f"PASS {scenario}: {trace_id}, logs={len(expected_logs)}, {metrics}")
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
