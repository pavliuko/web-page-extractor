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

## Building skills

A skill is one `agent/skills/<name>/SKILL.md`: a YAML frontmatter block, then the
markdown body (the instructions). Only **`name`** and **`description`** are read by Claude
Code and the Agents Market — every other field below is **IronClaw Reborn-specific**:
ignored by Claude Code and the marketplace, but valid to include so the same file stays
portable to IronClaw. The body must be ≤ 64 KiB.

Source of truth for the fields below: `crates/ironclaw_skills/src/types.rs` in
`nearai/ironclaw` (do not invent fields — reconcile with that file if it changes).

### Writing `description:` (directive-description pattern)

`description:` is the single strongest signal for whether a skill fires — Claude Code
routes on it in the workbench, IronClaw scores activation on it, and the marketplace shows
it. Write it in three slots:

```
<factual lead>. ALWAYS invoke this skill when <trigger clauses>. Do not <direct action it replaces> — use this skill first.
```

- **Lead** — one third-person sentence starting with a verb. No "I"/"you", no marketing.
  This is the half a marketplace buyer reads, so keep it clean and accurate.
- **Trigger clauses** — 3–6 concrete user-intent phrases. Routers keyword-match, so mix
  natural language with the backticked CLI/API/file names the skill touches; include
  common casual forms and typos. Don't claim trigger phrases that belong to another skill.
- **Negative constraint** — name the exact shortcut the model would otherwise take (the
  command, file, or artifact this skill owns). This is the half that actually changes
  behavior. Skip it only when there's no obvious direct action to replace (rare), and skip
  the whole pattern when `disable-model-invocation: true`.

Keep it third person, under 1024 chars, no time-sensitive wording. Before finalizing, scan
sibling descriptions (`agent/skills/*/SKILL.md` and `agent/.claude/skills/*/SKILL.md`) and
resolve any trigger overlap — only one skill fires per prompt. Keep a skill's wrapper
`description` in sync with its published `description` so workbench routing matches
production.

### Top-level fields (`SkillManifest`)

| Field | Type | Default | Notes |
|---|---|---|---|
| `name` | string | — (required) | Skill identifier. Our invariant: lowercase-kebab slug matching the directory name. |
| `description` | string | `""` | One-line summary; drives activation/selection. |
| `version` | string | `"0.0.0"` | Freeform version. |
| `auto_activate` | bool | `true` | `false` = never auto-selected; only force-activated via an explicit `$name` / `/name` mention. |
| `activation` | map | empty | Matching criteria — see below. |
| `requires` | map | empty | Gating prerequisites — see below. |
| `credentials` | list | empty | HTTP credential specs — see below. Values live in the platform/secrets store, never in this repo or the LLM context. |

### `activation:`

| Field | Type | Default | Notes |
|---|---|---|---|
| `keywords` | string[] | `[]` | Exact + substring match (lowercased). Each must be ≥ 3 chars (shorter dropped); **cap 20**. |
| `exclude_keywords` | string[] | `[]` | Veto: if any matches, the skill scores 0. Same ≥ 3-char rule; cap 20. |
| `patterns` | string[] | `[]` | Regex (Rust `regex`). **Cap 5**; each compiled with a 64 KiB size limit (ReDoS guard); invalid patterns are skipped. |
| `tags` | string[] | `[]` | Broad-category match. Each ≥ 3 chars; **cap 10**. |
| `max_context_tokens` | int | `2000` | Budget hint for how much of the prompt this skill should consume. |
| `setup_marker` | string | unset | Workspace-relative path; when it exists the skill is treated as "setup done" and excluded from selection. ≤ 256 bytes, must not contain `..` (else dropped). For one-time `*-setup` skills. |

### `requires:` (`GatingRequirements`)

| Field | Type | Behavior |
|---|---|---|
| `bins` | string[] | Binaries that must be on `PATH`; **gating** — skill is skipped if missing. |
| `env` | string[] | Env vars that must be set; **gating**. |
| `config` | string[] | Config file paths that must exist; **gating**. |
| `skills` | string[] | Companion skills to chain-load. **Advisory only** — missing companions do NOT block loading. **Cap 10**. |

Only this top-level `requires:` shape is parsed. The legacy nested
`metadata.openclaw.requires` is ignored — migrate old skills.

### `credentials:` (list of `SkillCredentialSpec`)

Each entry declares how to inject a secret into outbound HTTP; the secret value itself is
never in the repo or context.

| Field | Type | Default | Notes |
|---|---|---|---|
| `name` | string | — (required) | Secret name in the secrets store (e.g. `google_oauth_token`). |
| `provider` | string | — (required) | Provider hint (e.g. `google`, `github`, `slack`). |
| `location` | map | — (required) | Where to inject — tagged by `type` (see below). |
| `hosts` | string[] | — (required) | Glob host patterns this credential applies to (e.g. `*.googleapis.com`). |
| `path_patterns` | string[] | `[]` | Literal path prefixes to scope the credential to specific endpoints. |
| `oauth` | map | unset | OAuth config — see below. |
| `setup_instructions` | string | unset | Shown to the user when the credential is missing. |

**`location.type`** (one of):
- `bearer` → `Authorization: Bearer {secret}`
- `basic_auth` + `username` → `Authorization: Basic base64(username:secret)`
- `header` + `name` (+ optional `prefix`) → custom header, e.g. `X-API-Key: Token {secret}`
- `query_param` + `name` → `?{name}={secret}`

**`oauth:` (`SkillOAuthConfig`)**

| Field | Type | Default | Notes |
|---|---|---|---|
| `authorization_url` | string | — (required) | OAuth authorize endpoint. |
| `token_url` | string | — (required) | Token exchange endpoint. |
| `client_id` / `client_id_env` | string | unset | Literal client id, or env var to read it from. |
| `client_secret` / `client_secret_env` | string | unset | Literal client secret, or env var to read it from. |
| `scopes` | string[] | `[]` | OAuth scopes. |
| `use_pkce` | bool | `false` | Enable PKCE. |
| `extra_params` | map<string,string> | `{}` | Extra auth params (e.g. `access_type: offline`, `prompt: consent`). |
| `test_url` | string | unset | Endpoint to validate the token after exchange. |
| `refresh` | map | `{strategy: standard}` | Refresh behavior — `strategy:` is `standard` (OAuth2 refresh_token), `reauthorize_only` (no refresh; re-auth when expired), or `custom` + `refresh_url` (+ optional `extra_params`). |

### Caps & validation (enforced by IronClaw at load)

- Keywords/exclude-keywords ≤ 3 chars are silently dropped; caps: keywords 20,
  patterns 5, tags 10, `requires.skills` 10 — extras beyond a cap are silently truncated.
- `setup_marker` > 256 bytes or containing `..` is dropped.
- SKILL.md ≤ 64 KiB.
- Trust: skills placed by the user (workspace/`~/.ironclaw/skills/`) are **trusted** (all
  tools); registry/URL-installed skills are **read-only** (no shell/write/HTTP).

### Full example

```yaml
---
name: gmail-triage
description: Triage and label Gmail threads via the Gmail API.
version: 1.0.0
auto_activate: true
activation:
  keywords: [email, gmail, inbox, triage]
  exclude_keywords: [calendar]
  patterns: ['(?i)\b(label|archive)\b.*\bthread\b']
  tags: [productivity]
  max_context_tokens: 2000
requires:
  bins: []
  env: []
  config: []
  skills: []
credentials:
  - name: google_oauth_token
    provider: google
    location:
      type: bearer
    hosts: ["*.googleapis.com"]
    path_patterns: ["/gmail/"]
    setup_instructions: "Authorize Google under Building → Connectors."
    oauth:
      authorization_url: "https://accounts.google.com/o/oauth2/v2/auth"
      token_url: "https://oauth2.googleapis.com/token"
      scopes: ["https://www.googleapis.com/auth/gmail.modify"]
      use_pkce: true
      extra_params:
        access_type: offline
        prompt: consent
      test_url: "https://www.googleapis.com/oauth2/v1/userinfo"
      refresh:
        strategy: standard
---

# Gmail triage

Body instructions go here…
```
