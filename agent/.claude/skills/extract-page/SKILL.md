---
# Claude Code wrapper — LOCAL DEV ONLY, never published. Keep Claude-specific frontmatter
# here so it never pollutes the portable agent-skill frontmatter under agent/skills/.
name: extract-page
description: Given a URL (plus an optional field list or JSON schema), fetch the page with the Anchor Browser MCP tools and return clean, structured JSON extracted from it. Use this for every extraction job — it is the agent's core workflow.
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
