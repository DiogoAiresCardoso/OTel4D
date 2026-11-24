---
name: verify-delphi-build
description: Build OTel4D for a specific Delphi compiler and platform and distinguish compiler, package and runtime evidence.
---

Check the project file, package requires/contains clauses, installed compiler and target libraries. Verify the source is present in the revision under review. Follow [the build instructions](../../../tests/AGENTS.md) and run the relevant target on a licensed machine. Preserve the developer's source and IDE settings; put generated outputs in a disposable working copy if build events or resource generation would touch the checkout.

Report compiler version, configuration, target, command and exit status. For a runtime claim, run a representative consumer or test through its normal entry point. A Win32 compilation is evidence for Win32 only. An unavailable target remains unverified.
