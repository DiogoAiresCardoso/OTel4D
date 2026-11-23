# Reuse before implementation

1. Find the public entry point, its callers and tests. Search for domain terms, behavior and alternate names with rg, including configuration, fixtures, services, validators and adapters.
2. Check existing packages and the installed RTL for a compatible implementation. Verify the specific version, supported targets, ownership and license before relying on it.
3. Compare the contracts. Reuse or extend an existing component when the rule and ownership match. If similar code represents different domain rules, explain why independent implementations are appropriate.
4. Record the candidate and decision in the implementation or review summary. Put a newly shared rule in the unit that owns it and make it discoverable through its public API or documentation.

For OTel4D, search for an existing ID encoder or endpoint resolver before adding one to a second signal. Test the existing caller when consolidating implementations.
