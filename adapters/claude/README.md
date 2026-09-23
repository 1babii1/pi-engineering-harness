# Claude Code Adapter

Claude Code reads `CLAUDE.md`, not `AGENTS.md`, so the installer writes a `CLAUDE.md` whose first
line is `@AGENTS.md` (the import syntax) and nothing else that duplicates rules.

Skills are different from the other adapters. Claude Code discovers skills natively from
`.claude/skills/<name>/SKILL.md` and loads each one on demand, at runtime, based on its own
frontmatter `description` - it never reads `.pi/skills/`. `install.sh --agent claude`
mirrors the profile's selected skills into `.claude/skills/` (named from each skill's own
`name:` frontmatter) so they're actually reachable, in addition to the normal `.pi/skills/`
copy every agent gets.

The profile you pass still narrows *what's installed* - `install.sh --agent claude backend`
only mirrors the `backend` profile's skills. Which of those installed skills gets *loaded*
for a given task is then Claude Code's own relevance matching, not this harness's - that's
strictly additive to (not a replacement for) picking a narrower or broader profile.
