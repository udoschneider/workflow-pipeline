---
description: "Audit completed workflow docs for pruning readiness — checks test coverage, code rationale, lessons extraction. Invoke with /prune-completed."
---

Follow the `prune-completed` skill.

Read `skills/prune-completed/SKILL.md` — it sits in this package's skills directory, wherever your agent installed it — and follow it exactly. Do not work from this file, and do not reconstruct the procedure from memory.

This file exists only so the skill is reachable as a slash command. Agents that discover skills directly invoke it without going through here; agents that expose only commands need this to reach the same behaviour. It deliberately contains no procedure of its own — one skill, one source of truth, whichever route you arrive by.
