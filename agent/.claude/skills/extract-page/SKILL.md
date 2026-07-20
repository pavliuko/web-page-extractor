---
# Claude Code wrapper — LOCAL DEV ONLY, never published. Keep Claude-specific frontmatter
# here so it never pollutes the portable agent-skill frontmatter under agent/skills/.
name: extract-page
description: Fetches a URL with the Anchor Browser MCP tools and returns clean, structured JSON extracted from the page — titles, prices, contacts, tables, metadata — in the buyer's requested shape. ALWAYS invoke this skill when the user gives a link to `extract` or `scrape`, asks to pull product/article/listing/company fields from a web page, or supplies a field list or JSON schema to populate from a URL. Do not fetch the page with any other tool or answer from prior knowledge — use this skill first.
# Claude Code-only fields (safe here — never shipped to the marketplace):
disable-model-invocation: true
---

@../../../skills/extract-page/SKILL.md

<!--
  Local wrapper for the `extract-page` skill. The published skill (portable frontmatter +
  body) lives at agent/skills/extract-page/SKILL.md — that is the ONLY file uploaded to
  the marketplace. This wrapper is never published; it carries the Claude-only
  `disable-model-invocation: true` so the skill fires only when the system prompt routes
  to it, not on model whim.

  NOTE: Claude Code does not auto-expand `@` inside a SKILL.md (that is a CLAUDE.md-only
  feature), so the line above is a pointer, not an injection — open the referenced file
  to read/run the real body.
-->
