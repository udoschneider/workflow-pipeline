---
description: "Triage assistant over the workflow indexes — proposes 2-3 candidates matched to the current effort window and session goal, and surfaces a separate \"what are you avoiding?\" smells section (stale-actives, stale clusters, high-pull raw thoughts, unpromoted promotion-ready). Default-declines when nothing fits. Invoke with /what-next."
---

Follow the `what-next` skill.

Read `skills/what-next/SKILL.md` — it sits in this package's skills directory, wherever your agent installed it — and follow it exactly. Do not work from this file, and do not reconstruct the procedure from memory.

This file exists only so the skill is reachable as a slash command. Agents that discover skills directly invoke it without going through here; agents that expose only commands need this to reach the same behaviour. It deliberately contains no procedure of its own — one skill, one source of truth, whichever route you arrive by.
