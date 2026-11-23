---
name: develop-delphi
description: Implement or change Delphi units, components and sample applications in OTel4D using Embarcadero Object Pascal conventions and the Delphi 10.2 Tokyo Win32 toolchain.
---

## Choose where the change belongs

Trace the requested behavior from its caller. For a library feature, keep the public API independent of the host application's framework. For a sample, call that API from the host's existing startup, event and shutdown paths. OTel4D owns OTLP/HTTP delivery. Its MVC View encodes telemetry. A VCL form belongs to the host or sample. [OTel4D architecture decision](../../../docs/adr/0001-library-mvc-and-otlp-http.md)

When adding a component for the IDE palette, put its implementation in the runtime package. Put palette registration and property editors in a design-time package that requires the runtime package. Opening a form in the designer must leave telemetry delivery inactive. [Embarcadero design-time packages](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Design-time_Packages)

## Write Object Pascal for the target

- Use descriptive PascalCase identifiers, lowercase keywords and two spaces per indentation level. For example, a class might be named `TSpanBuffer`, an interface `ISpanBuffer`, an exception `ESpanBufferError` and a field `FCapacity`. Keep existing public and designer-streamed names stable. [Embarcadero Object Pascal Style Guide](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Delphi%E2%80%99s_Object_Pascal_Style_Guide)
- Match a new unit's filename to its declared name and follow the project's unit namespace. Put dependencies needed for public declarations in the interface `uses` clause. Move implementation-only dependencies to the implementation section. [Embarcadero unit structure](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Source_Code_Files_Units_and_Their_Structure)
- Check RTL and framework signatures against the installed Tokyo sources or compiler. Declare local variables in a `var` block before `begin`. Inline declarations, including `for var`, arrived in Delphi 10.3. [Embarcadero language version note](https://blogs.embarcadero.com/introducing-inline-variables-in-the-delphi-language/)

## Manage ownership at the application boundary

For a locally owned object, construct it before entering `try` and release it in `finally`. With an owner-managed `TComponent`, identify which owner will destroy it. For a reference-counted implementation such as `TInterfacedObject`, keep a strong interface reference for as long as the object is needed. Record ownership when a public method returns or retains an object. [Component ownership](https://docwiki.embarcadero.com/Libraries/Alexandria/en/System.Classes.TComponent.Owner) · [Interface reference counting](https://docwiki.embarcadero.com/RADStudio/Florence/en/Using_Reference_Counting)

For a form or data module, keep the Pascal declaration, streamed resource and event handlers consistent. Keep VCL control access on the main thread. Hand workers a snapshot of telemetry data they own. A dynamic-array assignment shares its storage, so copy mutable bytes before queuing if the producer may reuse the buffer. If a worker reports progress to a form, detach or invalidate pending UI callbacks before the form is destroyed. [Project coding standard](../../../docs/engineering/CODING_STANDARDS.md)

## Verify through the caller

Build the affected package or application for Tokyo Win32. Exercise the changed entry point through a representative caller. For example, when changing buffer ownership, queue a batch, mutate the caller's original bytes and check what the receiver observes. For a form change, open and close the form with work pending. Report the compiler, target and observed result. [Build verification skill](../verify-delphi-build/SKILL.md)
