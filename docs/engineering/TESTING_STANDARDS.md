# Testing standard

Write the expected behavior and choose the smallest test that distinguishes the correct change from the old behavior. Cover normal use, invalid input, limits, error propagation and regressions. Use isolated Arrange–Act–Assert tests. TDD, scenario-driven examples, property tests and mutation tests are useful when they expose a concrete risk.

Use deterministic test IDs and clocks. Test two roots with the same tracer, concurrent tasks with different parents, a child ending after its parent, repeated shutdown and a saturated queue. Verify preservation of the business exception during telemetry failure. Use a loopback receiver to check paths, headers, deadlines and the actual payload. Decode emitted bytes independently of the encoder under test. A test double belongs in test code.

Test integration points on the supported platform, then use a configured backend for end-to-end ingest when authorized. Identify exactly which layers were exercised. Fix incorrect behavior in the implementation. Change a previously correct expectation only when the verified contract itself changes. Consult [the gates](QUALITY_GATES.md) for reporting and compiler setup.
