# Developing an Agents Market agent

## What this agent is

**Web Page Extractor** — given a URL, the agent fetches the page and returns
structured data pulled from it (e.g. titles, prices, contacts, tables, metadata),
in the shape the buyer asks for. Every listing field, prompt, and skill in this
repo should serve that single job: URL in → clean structured data out.

## Repo layout

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
- `agent/skills/<name>/SKILL.md` — the PUBLISHED skill: one self-contained file, YAML
  frontmatter + markdown body, uploaded as-is via "+ Upload new skill". Frontmatter is a
  superset kept portable across Claude Code and IronClaw (`nearai/ironclaw`): `name` +
  `description` (required by both), plus optional IronClaw fields (`version`, `activation`,
  `requires`). No Claude-only fields here.
- `agent/.claude/skills/<name>/SKILL.md` — the LOCAL wrapper Claude Code loads. Holds
  Claude-only frontmatter (`allowed-tools`, `disable-model-invocation`, `argument-hint`, …)
  so those never leak into the published frontmatter, then a single
  `@../../../skills/<name>/SKILL.md` reference to the agent skill. Never published.
- To add a skill, create the pair by hand: `agent/skills/<name>/SKILL.md` (published) and
  `agent/.claude/skills/<name>/SKILL.md` (wrapper). `_`-prefixed dirs are treated as
  scaffolds (checked but never published) if you ever want one.

## Invariants to keep while editing

- `agent/SYSTEM_PROMPT.md` ≤ 4096 bytes (`wc -c < agent/SYSTEM_PROMPT.md`)
- `tagline` ≤ 90 chars; `handle` matches `[a-z0-9_]{3,30}`
- `max_tool_rounds` and `max_concurrent_hires` in 1–64; `max_dispatch_time_sec` ≤ 3600
- every `agent/skills/<name>/SKILL.md` is one self-contained file: frontmatter (`name`
  matching `<name>` + `description`, optional IronClaw fields) then a non-empty markdown
  body — and has a matching wrapper at `agent/.claude/skills/<name>/SKILL.md` whose `name`
  matches and which references `@../../../skills/<name>/SKILL.md`. `agent/.claude/skills`
  is a real directory of wrappers, not a symlink. `check.sh` enforces both.
- `private_mcp_servers` in `agent.yaml` mirrors the form's "Private MCP servers"
  section: which connectors to tick, plus the name/url/auth needed to re-create
  each one under Building → Connectors. Tokens are entered on the platform only.
- No secrets in this repo; connector tokens are configured on the platform, not here.
  Local-dev exception: `agent/.mcp.json` wires the Anchor Browser MCP
  (https://api.anchorbrowser.io/mcp) into the workbench so `cd agent && claude`
  gets real browser tools. The file is gitignored and holds the API key
  locally (header `anchor-api-key`) — keep it out of git and never copy the
  key into any tracked file.
