---
name: backend-craft-audit
description: Read-only craft audit for .NET backends - code cleanliness, idiomatic library use, performance, and cross-service consistency. Use when the question is "is this senior-level code", not "is this correct".
---
# Backend Craft Audit

Audit only. Do not modify code unless explicitly asked.
This is not `backend-audit`: that one asks "is it correct and safe", this one asks "is it clean, idiomatic, fast and consistent". Do not re-report correctness or security bugs here.

## Three axes, never merged

Report each axis separately and end with the worst finding **per axis**. A file can be immaculate on one axis and bad on another; a single merged verdict hides that.

1. **Conventions** - does this match *this* repository.
2. **Library idiom** - is each library used the way its own design intends.
3. **Craft** - structure, smells, and performance.

## The repo always overrides

Before judging anything, read the repo's own standards and treat them as binding: `.pi/project/conventions.md`, `.pi/project/canonical-examples.md`, ADRs under `docs/adr/`, `.editorconfig`, analyzer/StyleCop config, `Directory.Build.props`.
A deviation from a generic style guide is not a finding. A deviation from the repo is.
When the repo is silent, say so explicitly and fall back to the baseline below.

## Axis 1: Conventions

- The same job done two different ways in two places - pick the canonical example and name the divergent one.
- Naming that disagrees with its neighbours (suffixes, folder layout, file-per-type).
- Comment language drift where the repo has settled on one.
- Public surface shaped unlike its siblings (return types, error envelopes, validation placement, DTO vs entity).
- Cross-service structural drift: when a pattern is copied N times, the odd copy out is the finding.

## Axis 2: Library idiom

Check that the library is used as designed, not merely made to work. Apply only the bullets for libraries this repository actually uses; not using one of them is not a finding.

- **EF Core**: `AsNoTracking` on read-only paths; composition kept in `IQueryable` rather than materialised early; `ExecuteUpdate`/`ExecuteDelete` instead of load-then-save for set operations; split queries for multiple collection includes; no hand-edited migrations.
- **Dapper**: parameters never interpolated; `CommandDefinition` carrying the cancellation token; no unbounded buffered reads.
- **ASP.NET Core**: binding and validation via the framework, not hand-parsed; `IOptions<T>` with `ValidateOnStart` instead of `IConfiguration[...]` reads scattered through code; cancellation tokens plumbed to every real I/O call; middleware ordering deliberate.
- **FluentValidation**: `.When()` applies to the whole preceding chain - a guard on a different property silently drops the rules before it. Check every `.When()` guards the property it is scoping.
- **Serilog**: message templates with named holes. String interpolation into a log message destroys structured logging - it is the single most common idiom break in .NET.
- **OpenTelemetry**: standard activity/metric naming rather than ad-hoc parallel telemetry.
- **Kafka clients**: explicit commit semantics, consumer disposal, no silent offset advance on failure.
- **Testcontainers/xUnit**: container reuse through a shared fixture, not one per test; `IAsyncLifetime` over constructor side effects.

## Axis 3: Craft

Name the smell, then the move. A finding without a named move is a complaint, not a finding.
Use Fowler's vocabulary (Refactoring ch. 3) so findings are checkable: Mysterious Name, Duplicated Code, Long Function, Long Parameter List, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Speculative Generality, Message Chains, Middle Man.

Performance, only where it is on a hot path and only with evidence:
- allocation in loops, `string` concatenation in loops, non-static/non-compiled regex;
- multiple enumeration of `IEnumerable`;
- sync-over-async and blocking calls on request paths;
- per-request rebuilding of graphs that could be cached or singleton;
- work done eagerly that the caller usually discards.

Do not report speculative micro-optimisation. If throughput is not plausibly affected, it is Axis 3 style, not performance.

## Findings

Every finding must cite one of:
- a repo rule plus the file it comes from;
- a smell name plus the quoted hunk;
- a library's intended usage plus the call site.

A finding without a citation is not reportable.
Include severity, confidence, evidence, impact, the named move, and a verification step when uncertain.
Findings are hypotheses. Say which ones you verified and how.
