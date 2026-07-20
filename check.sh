#!/usr/bin/env bash
#
# check.sh — quick pre-publish check of everything the marketplace form needs.
#
# Validates the repo against the Agents Market "New agent" constraints and prints
# recommendations for anything missing, invalid, or still template-placeholder.
# Read-only; needs nothing beyond bash/awk/grep.
#
#   ./check.sh        exit 0 = ready to publish, 1 = errors, only warnings still exit 0

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ERRORS=0
WARNINGS=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$1"; ERRORS=$((ERRORS+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARNINGS=$((WARNINGS+1)); }

# Read a scalar from agent.yaml: first match of "key: value", comments stripped.
yaml() { awk -F': *' -v k="$1" '$1==k {sub(/[ \t]*#.*/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' agent.yaml; }
is_number() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; }
is_int()    { [[ "$1" =~ ^[0-9]+$ ]]; }
# __SET_ME__ (any case) marks a template value that must be replaced before publishing.
is_todo()   { [[ "$1" == *__SET_ME__* || "$1" == *__set_me__* ]]; }

echo "── Listing (agent.yaml) ─────────────────────────────────"
if [ ! -f agent.yaml ]; then
  err "agent.yaml is missing — it is the source for every short form field"
else
  name="$(yaml name)"; handle="$(yaml handle)"; role="$(yaml role)"
  category="$(yaml category)"; tagline="$(yaml tagline)"

  if [ -z "$name" ]; then err "name is empty — shown on every listing card"
  elif is_todo "$name"; then err "name is still __SET_ME__ — give the agent a name"
  else ok "name: $name"; fi

  if [ -z "$handle" ]; then err "handle is empty — public, used in URLs and signatures"
  elif is_todo "$handle"; then err "handle is still __set_me__ — pick a public handle"
  elif ! [[ "$handle" =~ ^[a-z0-9_]{3,30}$ ]]; then err "handle '$handle' invalid — need 3-30 lowercase letters/digits/underscore"
  else ok "handle: @$handle"; fi

  if [ -z "$role" ]; then err "role is empty — 1-3 word tag next to the name"
  elif is_todo "$role"; then err "role is still __SET_ME__ — 1-3 word label, e.g. 'Venue Finder'"
  elif [ "$(echo "$role" | wc -w)" -gt 3 ]; then err "role '$role' is over 3 words"
  else ok "role: $role"; fi

  if [ -z "$category" ]; then err "category is empty — top-level grouping on Discover"
  elif is_todo "$category"; then err "category is still __SET_ME__ — pick a Discover category, e.g. 'Automation'"
  else ok "category: $category"; fi

  if [ -z "$tagline" ]; then err "tagline is empty — one sentence shown on every listing card"
  elif is_todo "$tagline"; then err "tagline is still __SET_ME__ — one sentence, max 90 chars"
  elif [ "${#tagline}" -gt 90 ]; then err "tagline is ${#tagline} chars — max 90"
  else ok "tagline: ${#tagline}/90 chars"; fi

  echo
  echo "── Pricing & runtime (agent.yaml) ───────────────────────"
  price="$(yaml starter_price_usd)"; sla="$(yaml delivery_sla_hours)"
  cap="$(yaml spend_cap_usd_per_hire)"
  fmt="$(yaml output_format)"; rounds="$(yaml max_tool_rounds)"
  dispatch="$(yaml max_dispatch_time_sec)"; hires="$(yaml max_concurrent_hires)"
  sub="$(yaml sub_hires)"

  if [ -z "$price" ]; then warn "starter_price_usd not set — optional, but without it no default per-call plan is created"
  elif ! is_number "$price"; then err "starter_price_usd '$price' is not a number"
  else ok "starter price: \$$price per call"; fi

  if [ -z "$sla" ]; then warn "delivery_sla_hours not set — buyers see the SLA on every bid; past it an undelivered job can be cancelled with a full refund"
  elif ! is_int "$sla" || [ "$sla" -lt 1 ]; then err "delivery_sla_hours '$sla' must be a positive integer (hours)"
  else ok "delivery SLA: ${sla}h per job"; fi

  if [ -z "$cap" ]; then err "spend_cap_usd_per_hire is missing — REQUIRED by the form"
  elif ! is_number "$cap"; then err "spend_cap_usd_per_hire '$cap' is not a number"
  else ok "spend cap: \$$cap per hire"; fi

  if [ -z "$fmt" ]; then warn "output_format not set — pick the deliverable shape (e.g. markdown)"
  else ok "output format: $fmt"; fi

  if [ -z "$rounds" ]; then warn "max_tool_rounds not set — platform default is 8"
  elif ! is_int "$rounds" || [ "$rounds" -lt 1 ] || [ "$rounds" -gt 64 ]; then err "max_tool_rounds '$rounds' out of range 1-64"
  else ok "max tool rounds: $rounds"; fi

  if [ -z "$dispatch" ]; then warn "max_dispatch_time_sec not set — platform default is 900"
  elif ! is_int "$dispatch" || [ "$dispatch" -lt 1 ] || [ "$dispatch" -gt 3600 ]; then err "max_dispatch_time_sec '$dispatch' out of range 1-3600"
  else ok "max dispatch time: ${dispatch}s"; fi

  if [ -z "$hires" ]; then warn "max_concurrent_hires not set — match your slowest downstream dependency's session limit"
  elif ! is_int "$hires" || [ "$hires" -lt 1 ] || [ "$hires" -gt 64 ]; then err "max_concurrent_hires '$hires' out of range 1-64"
  else ok "max concurrent hires: $hires"; fi

  case "$sub" in
    true|false) ok "sub-hires: $sub" ;;
    "") warn "sub_hires not set — off by default on the platform" ;;
    *) err "sub_hires '$sub' must be true or false" ;;
  esac

  echo
  echo "── Private MCP servers (agent.yaml) ─────────────────────"
  # One line per entry: name|url|auth. Tokens live on the platform, never here.
  mcp="$(awk -F': *' '
    /^private_mcp_servers:/ {f=1; next}
    f && /^[^ ]/ {f=0}
    f {
      sub(/[ \t]*#.*$/,"")
      key=$1; gsub(/^[ \t-]+/,"",key)
      val=$0; sub(/^[^:]*: */,"",val); gsub(/^[ \t]+|[ \t]+$/,"",val)
      if (key=="name")      { if (n!="") print n"|"u"|"a; n=val; u=a="" }
      else if (key=="url")  u=val
      else if (key=="auth") a=val
      else if (key=="token" || key=="api_key" || key=="secret") print "SECRET||"
    }
    END { if (n!="") print n"|"u"|"a }
  ' agent.yaml)"
  if [ -z "$mcp" ]; then
    warn "no private_mcp_servers listed — fine only if the agent needs no connectors"
  else
    while IFS='|' read -r n u a; do
      if [ "$n" = "SECRET" ]; then err "private_mcp_servers holds a token/api_key/secret — tokens belong on the platform ONLY"
      elif [ -z "$u" ]; then err "MCP server '$n' has no url"
      elif ! [[ "$u" =~ ^https:// ]]; then err "MCP server '$n' url '$u' is not https"
      elif [ -n "$a" ] && [ "$a" != "static_token" ] && [ "$a" != "oauth" ]; then err "MCP server '$n' auth '$a' must be static_token or oauth"
      else ok "MCP server '$n' → $u${a:+ ($a)}"; fi
    done <<< "$mcp"
  fi
fi

echo
echo "── System prompt (agent/SYSTEM_PROMPT.md) ───────────────"
if [ ! -f agent/SYSTEM_PROMPT.md ]; then
  err "agent/SYSTEM_PROMPT.md is missing — REQUIRED by the form"
else
  bytes=$(wc -c < agent/SYSTEM_PROMPT.md | tr -d ' ')
  if grep -q '__SET_ME__' agent/SYSTEM_PROMPT.md; then
    err "system prompt is still __SET_ME__ — write the real prompt"
  elif [ "$bytes" -eq 0 ]; then err "system prompt is empty"
  elif [ "$bytes" -gt 4096 ]; then err "system prompt is $bytes bytes — max 4096 ($((bytes-4096)) over)"
  else ok "system prompt: $bytes/4096 bytes"; fi
  grep -q '__SET_ME__' agent/SYSTEM_PROMPT.md \
    || { grep -qi 'MARKET_SUBMIT_DELIVERABLE' agent/SYSTEM_PROMPT.md \
      && ok "mentions MARKET_SUBMIT_DELIVERABLE" \
      || warn "prompt never mentions MARKET_SUBMIT_DELIVERABLE — the form suggests telling the agent to submit its result via it"; }
fi

echo
echo "── Description (DESCRIPTION.md) ─────────────────────────"
if [ ! -f DESCRIPTION.md ]; then
  warn "DESCRIPTION.md is missing — the agent page will have no description"
else
  body="$(sed '/<!--/,/-->/d' DESCRIPTION.md | grep -v '^[[:space:]]*$' || true)"
  if [ -z "$body" ]; then warn "DESCRIPTION.md has no content beyond comments"
  elif echo "$body" | grep -q '__SET_ME__'; then err "DESCRIPTION.md is still __SET_ME__ — write the listing description"
  else ok "description present ($(echo "$body" | wc -l | tr -d ' ') non-empty lines)"; fi
fi

echo
echo "── Skills (agent/skills/) ───────────────────────────────"
found=0
for d in agent/skills/*/; do
  [ -d "$d" ] || continue
  found=1
  s="$(basename "$d")"
  if [ ! -f "$d/SKILL.md" ]; then
    err "skill dir '$s' has no SKILL.md — nothing to upload"
  elif ! head -1 "$d/SKILL.md" | grep -q '^---$'; then
    warn "skill '$s': SKILL.md has no YAML frontmatter (name/description expected)"
  else
    ok "skill '$s' (SKILL.md with frontmatter)"
  fi
done
[ "$found" -eq 0 ] && warn "no skills under agent/skills/ — fine if the prompt alone is enough"

echo
echo "── Workbench wiring ─────────────────────────────────────"
[ -f agent/CLAUDE.md ] && grep -q '@SYSTEM_PROMPT.md' agent/CLAUDE.md \
  && ok "agent/CLAUDE.md imports @SYSTEM_PROMPT.md" \
  || warn "agent/CLAUDE.md missing or doesn't import @SYSTEM_PROMPT.md — 'cd agent && claude' won't adopt the prompt"
[ -L agent/.claude/skills ] && [ "$(readlink agent/.claude/skills)" = "../skills" ] \
  && ok "agent/.claude/skills symlink → ../skills" \
  || warn "agent/.claude/skills is not a symlink to ../skills — Claude Code won't auto-load the skills"

echo
if [ "$ERRORS" -gt 0 ]; then
  printf '\033[31m✗ %d error(s)\033[0m, %d warning(s) — fix errors before publishing.\n' "$ERRORS" "$WARNINGS"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  printf '\033[33m! Ready-ish:\033[0m 0 errors, %d warning(s) — review the recommendations above.\n' "$WARNINGS"
else
  echo "✓ All checks passed — ready to copy into the marketplace form."
fi
