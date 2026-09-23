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

- `backend`, `frontend`, `fullstack` - everyday coding stacks (`backend`/`fullstack` include `services/auth`)
- `production`, `kubernetes`, `distributed` - operating and designing running systems
- `high-risk` - the high-risk categories in `.pi/laws/signals.md` (auth, payments, migrations, concurrency, ...): scope contract, reasoning, independent verifier
- `audit` - read-only audits, including the `backend-craft` / `frontend-craft` "is this senior-level code" audits
- `project-discovery`, `verification` - minimal

Skills not in any profile (`services/payments`, `services/notifications`, `services/api-gateway`,
`services/background-jobs`, `infrastructure/aspire`) are installed by name - deliberately: most
repositories have zero or one of these, so bundling all of them into `backend`/`fullstack` would load
context for services the project does not have. `./install.sh backend services/payments`.

## Install

```bash
TARGET=/path/to/project ./install.sh fullstack production
TARGET=/path/to/project ./install.sh --dry-run fullstack   # show what would change, write nothing
```

Ownership model (safe to re-run to upgrade):

| Kind | Files | Behaviour |
|---|---|---|
| harness-owned | `.pi/prompts`, `.pi/laws`, `.pi/references`, `.harness/*`, the selected `.pi/skills/*` | refreshed; anything that differs is **backed up first** to `.harness/backup/<timestamp>/`, never silently destroyed |
| project-owned | `AGENTS.md`, `CLAUDE.md`, the Cursor rule | created if absent; if present and different they are **kept** unless `--overwrite-entry` (then backed up) |
| project data | `.pi/project/*`, `.pi/learnings/inbox.md` | created only if absent, never touched |

Skills you did not select are never touched, so project-local skills survive. The installer refuses
to install into the harness itself and validates every requested skill before writing anything.
If you improved a harness skill inside a project, move that improvement back into this repository
before reinstalling - otherwise the reinstall replaces it (the old copy stays in the backup).
Add `.harness/backup/` to the project's `.gitignore`.
Upgrading an existing project: `--overwrite-entry` is needed once to receive the new `AGENTS.md` (the old one is backed up).

## Project context

Run the `init-project` prompt after installation. It creates/refreshes compact files under `.pi/project/`:

- `overview.md`
- `architecture.md`
- `commands.md`
- `conventions.md`
- `canonical-examples.md`

## Task scope and ADRs

Use `templates/scope-contract.md` for non-trivial task boundaries. Use `templates/adr.md` only for durable architectural decisions. `templates/nested/*.AGENTS.md` are starters `init-project` can seed into a repository's clearly separated backend/frontend/infra areas - never applied automatically.

## Verification

`.harness/scripts/verify.sh [quick|standard|full] [--all]` verifies what changed (tracked diff,
staged, **and new untracked files**), finds the project directory for each affected area, runs the
matching script, and prints a PASS / FAIL / NOT RUN report (exit 0 / 1 / 2). It will not report a
pass for something it could not run.

- Backend: nearest `.slnx`/`.sln`/`.csproj` from the changed file; if an ancestor solution lists
  that directory it is preferred (per-service solutions often omit test projects, so building only
  them can "pass" with no tests run). Ambiguity (two solutions in one directory) is NOT RUN, not a guess.
- Frontend: nearest `package.json`; runs `typecheck`, `lint`, `test` (and `build` above `quick`)
  with `CI=true`; needs installed dependencies, otherwise NOT RUN.
- Kubernetes: only manifest-looking YAML (under `k8s/` etc., or with `apiVersion:` + `kind:`);
  `docker-compose`, CI workflows and plain config YAML are ignored. Helm charts need rendering: NOT RUN
  unless you configure a command.
- Overrides: repository-owned `.pi/project/commands.sh` may set `BACKEND_VERIFY_CMD`,
  `FRONTEND_VERIFY_CMD`, `K8S_VERIFY_CMD`; they run once from the repository root and any
  non-zero exit is a FAIL. Project-verified commands belong in `.pi/project/commands.md`; a starter is `templates/commands.sh.example`. The override file is deliberately not named `*.env`, which is the name of secret files.

## Evals and tests

```bash
./eval.sh smoke        # structure + eval-case lint + grader self-test (seconds)
./eval.sh regression   # smoke + installer/verify/eval-tooling test suites
./eval.sh grade <case-id> <response-file>
```

`smoke` checks that profiles reference real skills, always-loaded files stay within budget, every
path a rule mentions exists, and that each eval case's deterministic graders accept a known-good
response and reject a known-bad one. `grade` scores an agent's actual response/diff. `benchmark`
(comparing harness variants with a real agent) needs an agent runtime and reports NOT RUN here.
See `evals/README.md`. Each `tests/*.test.sh` can be run on its own.

## Cross-agent adapters

`AGENTS.md` is the source of truth; nothing else duplicates rule text. Codex and Cursor read it
natively; Claude Code gets a `CLAUDE.md` that imports it (`@AGENTS.md`); Gemini CLI gets a `GEMINI.md`
that imports it (`@./AGENTS.md`); Cursor also gets one always-on pointer rule. Install with
`--agent pi|codex|claude|cursor|gemini`. Details and sources: `adapters/*/README.md`.

## Maintaining the harness

- Every rule earns its context: `AGENTS.md` and skill descriptions are always loaded, so
  `./eval.sh smoke` enforces size budgets. Put detail in a skill, not in `AGENTS.md`.
- Add or change a skill/law: run `./eval.sh smoke`; for a behavior you want to keep, add an eval case
  (`evals/cases/`) with a good and a bad fixture, then `./eval.sh regression`.
- Promote a lesson from a project: copy it here generalized (no project paths), check any factual claim
  against a primary source, add the eval case, and note it in `CHANGELOG.md`. A project's
  `.pi/learnings/inbox.md` entry can then be dropped.
- Bump `VERSION` (semver) for every release; the installer stamps it into `.harness/VERSION` and
  prints `old -> new` on upgrade.
- Shell and Python tooling here has no third-party dependencies, and every behavior in `install.sh`,
  `scripts/` and `evals/run.py` has a test that fails when the behavior is removed.
