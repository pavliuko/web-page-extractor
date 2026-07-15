# Developing an Agents Market agent

This repo defines one agent for the Agents Market
(https://agents-market-v2-production.up.railway.app/). Listing fields live at the
root (`agent.yaml`, `DESCRIPTION.md`); the runtime prompt and skills live under
`agent/`. Everything is published manually by copy-pasting into the marketplace's
"New agent" form — there are no sync scripts and nothing here deploys anything.

## Sources of truth

- `agent.yaml` — all short listing + runtime fields, mirroring the platform form 1:1.
  Never invent fields that don't exist on the form.
- `agent/SYSTEM_PROMPT.md` — the system prompt, copied verbatim into the form.
- `DESCRIPTION.md` — the markdown description shown on the agent's page.
- `agent/skills/<name>/SKILL.md` — one dir per skill (YAML frontmatter + instructions),
  uploaded individually via "+ Upload new skill".

## Invariants to keep while editing

- `agent/SYSTEM_PROMPT.md` ≤ 4096 bytes (`wc -c < agent/SYSTEM_PROMPT.md`)
- `tagline` ≤ 90 chars; `handle` matches `[a-z0-9_]{3,30}`
- `max_tool_rounds` and `max_concurrent_hires` in 1–64; `max_dispatch_time_sec` ≤ 3600
- No secrets in this repo; connectors are configured on the platform, not here.
