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

## Hooks and the verifier subagent

`install.sh --agent claude` also installs enforcement that plain rule text cannot give:

- `.harness/hooks/guard-secrets.py` (PreToolUse on Read/Edit/Write/MultiEdit/Grep/Glob/Bash/
  NotebookEdit) blocks `.env*` (except `.env.example`), SOPS vaults, age/SSH/TLS private keys and
  shell env dumps (`env`, `printenv`, `export -p`, `/proc/*/environ`). Extend it with one regex per
  line in `.pi/project/secret-patterns.txt` (project-owned, never overwritten).
  **It is defense in depth, not a sandbox**: it reads a command line with regexes, so shell
  indirection (`$(...)`, variable concatenation, base64), partial globs (`.e*`) and a directory-wide
  Grep over an un-gitignored `.env` get through. Keep real permissions/sandboxing underneath it.
- `.harness/hooks/verify-on-stop.sh` (Stop) runs `verify.sh quick` before a turn that changed files
  may end, and blocks it with the log tail on FAIL. Off by default; enable per project with
  `export HARNESS_VERIFY_ON_STOP=1` in `.pi/project/commands.sh` (optional
  `HARNESS_VERIFY_ON_STOP_TIMEOUT`, default 300s). NOT RUN and timeouts warn but never block, and
  `stop_hook_active` prevents a retry loop.
- `.claude/agents/independent-verifier.md`: the high-risk verifier as a real subagent (fresh
  context, read-only on the working tree). Its body is generated from
  `.pi/skills/workflow/independent-verifier/SKILL.md` at install time, so the procedure has one
  source. Invoke it with the scope contract, final diff and verification results only.

`.claude/settings.json` is merged, not replaced: only `hooks` is touched, your own hooks and
`permissions` survive, reinstalling never duplicates an entry, and an unparseable file is left as it
is with a warning. Needs `python3` (already required by `eval.sh`).
