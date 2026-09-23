---
name: engineering-reasoning
description: Use for non-trivial design or implementation decisions. Activate relevant engineering laws from task signals, derive proof obligations, and keep reasoning proportional to risk.
---
# Engineering Reasoning

Use `.pi/laws/core.md` as the compact law set.

For non-trivial work:
1. Detect task signals using `.pi/laws/signals.md` (the Architecture/complexity signal there points to
   `.pi/references/system-design-decision-tree.md` and `reading-map.md` for deeper justification).
2. Activate only relevant laws and specialized skills.
3. Identify the simplest viable decision.
4. Derive proof obligations for material decisions.
5. Implement the smallest complete change.
6. Verify obligations with matching evidence.
7. State material properties that remain unverified.

Do not:
- recite all laws on every task;
- load every skill for routine work;
- turn conditional guidance into universal syntax bans;
- add architecture because a pattern is fashionable;
- claim properties the performed checks do not prove.

When a decision rests on how a framework or library behaves, treat that as a claim needing
evidence: read the installed version's source or docs, or run a small experiment, before building
on it. Record the observation where the next reader will see it (a test or a comment naming the
evidence), not just the conclusion.
