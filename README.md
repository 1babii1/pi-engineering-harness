# Pi Engineering Harness

A compact, production-oriented engineering harness for Pi and compatible coding agents.

The goal is not maximum prompt size or maximum agent count. The goal is better engineering decisions with controlled context and deterministic verification.

## Core philosophy

- Small always-loaded rules.
- Detailed skills loaded only when relevant.
- Project-specific discovery instead of generic assumptions.
- Scope before large changes.
- Deterministic verification before completion.
- Evals for the harness itself.
- Durable learnings only when they earn permanent context.
- Independent verification only for high-risk work.

> Production-grade does not mean maximum complexity.
> Prefer simple -> observable -> reliable -> scalable.

## Main modes

- BUILD — implement the smallest correct change.
- DESIGN — compare options and trade-offs before implementation.
- DEBUG — reproduce, find root cause, fix, verify.
- REVIEW — inspect a change/diff.
- AUDIT — inspect a system without changing it.
- VERIFY — run deterministic evidence-based checks.
- INIT PROJECT — build compact project context.

## Profiles

- `backend`
- `frontend`
- `fullstack`
- `production`
- `kubernetes`
- `distributed`
- `audit`
- `project-discovery`
- `verification`

## Install

```bash
TARGET=/path/to/project ./install.sh fullstack production
```

The installer copies only selected skills plus shared prompts/references/templates/scripts.

## Project context

Run the `init-project` prompt after installation. It creates/refreshes compact files under `.pi/project/`:

- `overview.md`
- `architecture.md`
- `commands.md`
- `conventions.md`
- `canonical-examples.md`

## Task scope and ADRs

Use `templates/scope-contract.md` for non-trivial task boundaries. Use `templates/adr.md` only for durable architectural decisions.

## Verification

Portable scripts live in `scripts/`; project-specific verified commands belong in `.pi/project/commands.md` (and optional repository-owned `commands.env` for executable overrides).

## Evals

`evals/` contains portable cases that test harness behavior. Prefer deterministic graders and compare harness variants against a baseline. Do not claim benchmark improvements without repeated controlled runs.

## Cross-agent adapters

`AGENTS.md` is the source of truth. `adapters/` documents how to reuse the same rules with Pi, Codex, Claude Code, and Cursor without maintaining separate hand-edited copies.
