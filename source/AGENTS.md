# Delphi runtime changes

Use the [Delphi development skill](../.agents/skills/develop-delphi/SKILL.md) when implementing units and components. It covers Embarcadero conventions, Tokyo compatibility and ownership at the application boundary.

Start with the [root instructions](../AGENTS.md) and [MVC decision](../docs/adr/0001-library-mvc-and-otlp-http.md). Inspect the actual package and supported compiler before using an RTL or FireDAC member. Tokyo Win32 is the baseline. Use syntax available there and state the targets actually compiled.

Keep domain state independent of UI, OTLP encoding and network code. Capture immutable span data before queuing it, restore contexts in finally blocks on the owning execution path, preserve application exceptions and keep HTTP off the business thread. Check encoding and line endings before touching existing Pascal or project files. Exclude per-user IDE files from commits.
