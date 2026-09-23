# Changelog

## 4.7.0
Merged with `main` (PR #1, developed in parallel): kept `coding/generic` for non-.NET backends and
restored the Claude Code skill mirror into `.claude/skills/<name>/` on top of the new backup-aware
installer (with a regression test); the 4.x eval format supersedes PR #1's `checks.forbidden_patterns`.

Two new signals found using the harness on a real foundations review of a live platform:
- New dependency: check for known vulnerabilities (transitive included) before treating a
  successful build as verification - found because adding one SignalR package silently
  pulled in a library with several CVEs, invisible until `dotnet list package --vulnerable`
  was run deliberately.
- Undocumented single-instance assumption: ask explicitly what is currently true only
  because there is exactly one instance running, separate from re-checking documented
  decisions - found a real one (a SignalR hub's in-memory connection groups) that nothing
  in the codebase's otherwise thorough ADRs had ever written down.

## 4.6.0
- `signals.md` Concurrency: added a concrete pitfall found using the harness against a real
  service - a race test seeded against a brand-new aggregate can pass by accident (the
  aggregate's own primary key masks a missing constraint on the row that actually needed
  protecting), so seed the race against an aggregate that already has related rows.

## 4.5.0
Promoted two lessons found while using the reinstalled harness against a real project (dsPorfolio):
- `services/auth` check #1 (enumeration): a framework's own duplicate-account error (ASP.NET
  Identity's DuplicateUserName/DuplicateEmail, code AND message text) is the same enumeration leak
  as a hand-written one if passed through uncaught - found on a real `/auth/register` endpoint via
  the project's own pre-existing test, which asserted the leaking behavior (400 vs 204) as correct.
- Core law #3's smell: an ORM's own "does it exist?" pre-check (e.g. Identity's CreateAsync) is
  itself check-then-act - it closes the gap for sequential callers, but two concurrent callers can
  both pass it before either commits, so the database constraint is what actually stops the second
  one, by throwing rather than returning gracefully. Confirmed by reproducing the exact race with a
  concurrent-registration test (500 Internal Server Error, PostgresException 23505) and mutation-
  testing the fix (disabling the DB-exception catch failed the test 3/6 runs - real, not scripted,
  and not deterministic every single run the way a synchronous test would be).

## 4.4.0
Audited eval coverage against `.pi/laws/signals.md`'s own trigger categories and found three with
zero eval cases despite being core, security-relevant signals: Boundary/trust, Operations/
observability, and half of Performance claims (only "don't add a cache without evidence" was
covered; "verify the improvement after making the change" was not). Added one case each:
`boundary-webhook-payment-notification`, `operations-consumer-readiness`,
`performance-index-verify-after` - 22 cases total. Checked all graders for duplicate/copy-pasted
patterns (none found) and confirmed every new grader rejects both its dedicated bad fixture and a
generic non-committal answer, not just the one bad example it was written against.

## 4.3.0
Fresh-eyes review of the harness's own always-loaded text (AGENTS.md + laws), specifically for the
kind of defect the harness itself teaches to look for.
- Found and fixed: the high-risk category list was copied into four places (AGENTS.md, README,
  `signals.md`, `independent-verifier`'s description) with real textual drift between them
  ("persistence/migrations" vs "migrations", "destructive operations" present in only one) - the
  harness's own text violating its own laws #1 ("state has one authoritative owner") and #10
  ("copies create consistency obligations"). `.pi/laws/signals.md` is now the single canonical
  wording; AGENTS.md and `independent-verifier` are synced to it; README's mention is now
  explicitly non-exhaustive instead of silently dropping items. `evals/run.py structure` now
  extracts and diff-checks this list automatically so it cannot drift again unnoticed.
- Found and fixed: AGENTS.md said independent review "benefits from" high-risk work (optional
  phrasing) while `signals.md`'s own "Require:" list for the same work said it was required - a
  real strength mismatch between the always-loaded file and the signal-activated one. AGENTS.md now
  says "requires".
- Added the "Destructive / irreversible operation" obligation category to `proof-obligations.md` -
  `signals.md`'s own "High risk" trigger list already named "destructive operations" but nothing
  defined what evidence that decision owed. New eval case `destructive-bulk-delete-department`.
- Diversified core law #12's smell examples (was entirely auth-flavored after two sessions of auth
  work) with a non-auth example.

## 4.2.0
- Wired three previously-orphaned pieces back into the harness: `.pi/laws/lifecycle.md` and
  `.pi/references/*.md` (reading-map, system-design-decision-tree, production-service-checklist)
  are now referenced from AGENTS.md, the relevant prompts, signals.md, and skills, instead of being
  installed with nothing ever telling the agent to open them; `templates/nested/*.AGENTS.md` are now
  installed to `.harness/templates/nested/` and `init-project` can seed them into a repository's
  clearly separated backend/frontend/infra areas.
- `coding/react`: added a Next.js App Router section (Server Components by default, `'use client'`
  scope, secrets never passed as client props) verified against Next.js's own docs - the actual gap
  found reviewing this skill against a real Next.js App Router project. Zustand line softened to
  "or the project's existing equivalent", since TanStack Query does not require it.
- `services/api-gateway`: cross-referenced `services/auth` for edge token validation and made
  explicit that the gateway proving identity does not replace each service's own authorization.
- `services/notifications`: added consent/opt-out per channel.
- `evals/run.py structure`: now warns when a `.pi/references/*` or `.pi/laws/*` file is not
  referenced from anywhere else in the harness, so this class of dead-weight file is caught
  automatically instead of found by a manual pass.
- README: documented why `services/*` and `infrastructure/aspire` are name-only, not bundled into
  `backend`/`fullstack` (most repositories have zero or one of these).
- Verified `infrastructure/kubernetes` (probe semantics), `infrastructure/observability` (OTel
  naming), and `infrastructure/aspire` (dev/orchestration scope, not a Kubernetes replacement)
  against their current official docs; no changes needed, kept as-is with evidence.

## 4.1.0
Installer
- Safe upgrades: everything replaced or pruned is backed up under `.harness/backup/<timestamp>/`;
  `AGENTS.md`/`CLAUDE.md`/`GEMINI.md`/Cursor rule are kept unless `--overwrite-entry`; `--dry-run`;
  refuses to install into the harness itself; validates all skills before writing; stamps `VERSION`.
- New `--agent gemini`; adapter docs verified against each tool's documentation.
Verification scripts
- `verify.sh` sees new untracked files, finds the project directory per area, prefers the outermost
  solution that lists a directory (per-service solutions often omit tests), ignores non-manifest YAML,
  and reports PASS / FAIL / NOT RUN with exit 0 / 1 / 2. Overrides live in `.pi/project/commands.sh`.
Laws and skills
- Laws carry violation smells; signals for identity/sessions, concurrency, operations, performance
  claims, frontend state, test evidence, and a real High-risk requirement list.
- New proof obligations: credential change, external identity linking, token/key lifecycle,
  step-up, concurrency, scheduled jobs, performance claims, test evidence.
- `services/auth` rewritten around defects found and verified in a real service (pre-hijacking,
  session revocation, key rotation retention/caches/locking, keys at rest, first-link 2FA).
- Promoted from a project: testing (mutation-checked tests, shared fixtures), database (composite
  index direction, migrations), `audit/backend-craft`, `audit/frontend-craft`.
- Background jobs (multi-instance), payments (atomic transitions), verification (NOT RUN, empirical
  framework claims), code-review (stale comments), AGENTS.md secrets rule.
Evals
- `eval.sh` now runs: structure checks, case lint, grader self-test against good/bad fixtures, and the
  shell test suites; `eval.sh grade` scores a real response. 18 cases with deterministic graders.
Tests
- `tests/*.test.sh`: installer, verify scripts, and eval tooling, each behavior mutation-checked.
