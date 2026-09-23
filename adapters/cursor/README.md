# Cursor Adapter

Cursor reads `AGENTS.md` from the project root and applies nested `AGENTS.md` files to the areas they
sit in (it documents AGENTS.md as the simple alternative to `.cursor/rules`). The installer also
writes one always-on `.cursor/rules/engineering-harness.mdc` that only points at `AGENTS.md`, as a
fallback for Cursor versions or settings that ignore AGENTS.md. Do not copy rule text into
`.cursor/rules`; if you need path-scoped rules, generate them from nested `AGENTS.md` files.
