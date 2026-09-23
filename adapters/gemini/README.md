# Gemini CLI Adapter

Gemini CLI loads `GEMINI.md` (global, then project up to the git root, then subdirectories) and
supports importing other files with `@./file.md`. The installer writes a `GEMINI.md` that only
imports `AGENTS.md`, so the rules are maintained in one place. Alternative without any extra file:
set `"context": { "fileName": ["AGENTS.md", "GEMINI.md"] }` in Gemini's `settings.json`.

An existing, different `GEMINI.md` (for example one written by another tool) is kept unless you pass
`--overwrite-entry`; then add `@./AGENTS.md` to it by hand.
