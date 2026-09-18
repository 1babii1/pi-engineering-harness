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
- If existing context disagrees with the repository, update it and mention the stale assumption.
