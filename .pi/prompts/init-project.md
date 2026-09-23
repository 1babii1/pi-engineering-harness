# Init Project

Use the `project-discovery` skill.

Inspect this repository with a strict context budget. Do not modify product code.

Create or refresh `.pi/project/overview.md`, `architecture.md`, `commands.md`, `conventions.md`, and `canonical-examples.md`.

Requirements:
- Ground non-obvious claims in file/config evidence.
- Add High/Medium/Low confidence where interpretation is required.
- Record exact build/test/lint/run commands only after finding them in project files, scripts, docs, or CI.
- Prefer paths to canonical examples over pasted code.
- Do not document formatting rules already enforced by tools.
- Do not overwrite nested `AGENTS.md` files.
- If the repository has a clearly separated top-level area (a backend, a frontend, an infra/deploy
  tree) with no `AGENTS.md` of its own yet, offer to seed one there from the matching starter in
  `.harness/templates/nested/` (`backend.AGENTS.md`, `frontend.AGENTS.md`, `infra.AGENTS.md`),
  edited to name the repository's actual layers and commands rather than left generic. Do this only
  on request or when the boundary is unambiguous - a single-area repository does not need one.
- If existing context disagrees with the repository, update it and mention the stale assumption.
