#!/usr/bin/env bash
#
# publish.sh — step-by-step clipboard wizard for the marketplace "New agent" form.
#
# Walks every form field in the order the form presents them, copies each value
# to the clipboard, and waits for Enter so you can paste it before moving on.
# Sources: agent.yaml (short fields), agent/SYSTEM_PROMPT.md, DESCRIPTION.md.
# Skills are uploaded as files, so those steps just print the path to pick.
#
#   ./publish.sh          walk all fields
#   ./publish.sh tagline  jump straight to one field (any step name from --list)
#   ./publish.sh --list   show step names and exit
#
# Keys at each step: Enter = next, r = copy again, s = skip, q = quit.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# ── Clipboard ────────────────────────────────────────────────────────────────
if command -v pbcopy >/dev/null 2>&1; then clip() { pbcopy; }
elif command -v wl-copy >/dev/null 2>&1; then clip() { wl-copy; }
elif command -v xclip  >/dev/null 2>&1; then clip() { xclip -selection clipboard; }
else
  echo "No clipboard tool found (pbcopy / wl-copy / xclip)." >&2
  exit 1
fi

# Read a scalar from agent.yaml: first match of "key: value", comments stripped.
yaml() { awk -F': *' -v k="$1" '$1==k {sub(/[ \t]*#.*/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' agent.yaml; }

# Read a scalar from a SKILL.md YAML frontmatter block: fm <file> <key>
fm() {
  awk -F': *' -v k="$2" '
    NR==1 && $0=="---" {f=1; next}
    f && $0=="---" {exit}
    f && $1==k { val=$0; sub(/^[^:]*: */,"",val); gsub(/^[ \t]+|[ \t]+$/,"",val); print val; exit }
  ' "$1"
}

# Private MCP servers from agent.yaml, one per line: name|url|auth|auth_header
mcp_servers() {
  awk -F': *' '
    /^private_mcp_servers:/ {f=1; next}
    f && /^[^ ]/ {f=0}
    f {
      sub(/[ \t]*#.*$/,"")
      key=$1; gsub(/^[ \t-]+/,"",key)
      val=$0; sub(/^[^:]*: */,"",val); gsub(/^[ \t]+|[ \t]+$/,"",val)
      if (key=="name")             { if (n!="") print n"|"u"|"a"|"h; n=val; u=a=h="" }
      else if (key=="url")         u=val
      else if (key=="auth")        a=val
      else if (key=="auth_header") h=val
    }
    END { if (n!="") print n"|"u"|"a"|"h }
  ' agent.yaml
}

bold()  { printf '\033[1m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }

STEP_N=0
TOTAL=0

# prompt_keys <copy-cmd> — copy, then handle Enter/r/s/q. copy-cmd re-runs on 'r'.
prompt_keys() {
  "$1"
  printf '  %s ' "$(dim 'Enter=next  r=copy again  s=skip  q=quit →')"
  while true; do
    IFS= read -r key
    case "$key" in
      q|Q) echo; echo "Stopped."; exit 0 ;;
      r|R) "$1"; printf '  %s copied again ' "$(green '✓')" ;;
      s|S|"") echo; return 0 ;;
      *) printf '  %s ' "$(dim '(Enter/r/s/q) →')" ;;
    esac
  done
}

# step <name> <form label> <kind:value|file|note> <payload>
step() {
  local name="$1" label="$2" kind="$3" payload="$4"
  STEP_N=$((STEP_N+1))
  [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && return 0

  echo
  printf '%s %s\n' "$(bold "[$STEP_N/$TOTAL]")" "$(bold "$label")"

  case "$kind" in
    value)
      if [ -z "$payload" ]; then
        printf '  %s\n' "$(dim '(empty in agent.yaml — skipping)')"
        return 0
      fi
      printf '  %s\n' "$payload"
      copy_it() { printf '%s' "$payload" | clip; }
      prompt_keys copy_it
      ;;
    file)
      if [ ! -f "$payload" ]; then
        printf '  %s\n' "$(dim "($payload missing — skipping)")"
        return 0
      fi
      printf '  %s %s\n' "$(dim 'file:')" "$payload $(dim "($(wc -c < "$payload" | tr -d ' ') bytes)")"
      copy_it() { clip < "$payload"; }
      prompt_keys copy_it
      ;;
    note)
      printf '  %s\n' "$payload"
      printf '  %s ' "$(dim 'Enter=next  q=quit →')"
      IFS= read -r key || key=""
      case "$key" in q|Q) echo "Stopped."; exit 0 ;; esac
      ;;
  esac
}

# ── Step list (form order). Each entry: name|label|kind|payload ──────────────
build_steps() {
  step name          "Name"                       value "$(yaml name)"
  step handle        "Handle"                     value "$(yaml handle)"
  step role          "Role"                       value "$(yaml role)"
  step category      "Category"                   value "$(yaml category)"
  step tagline       "Tagline"                    value "$(yaml tagline)"
  step description   "Description (markdown)"     file  "DESCRIPTION.md"
  while IFS='|' read -r n u a h; do
    [ -n "$n" ] || continue
    step "mcp_$n" "Private MCP server: $n" note \
      "Tick '$n' ($u). If it's not listed yet, add it under Building → Connectors: auth=$a${h:+, auth header '$h'}, token from your vault — never from this repo."
  done < <(mcp_servers)
  step price         "Starter price (USD)"        value "$(yaml starter_price_usd)"
  step delivery_sla  "Delivery SLA (hours)"       value "$(yaml delivery_sla_hours)"
  step system_prompt "System prompt"              file  "agent/SYSTEM_PROMPT.md"
  step spend_cap     "Spend cap per hire (USD)"   value "$(yaml spend_cap_usd_per_hire)"
  step output_format "Output format"              value "$(yaml output_format)"
  step tool_rounds   "Max tool rounds"            value "$(yaml max_tool_rounds)"
  step dispatch_time "Max dispatch time (sec)"    value "$(yaml max_dispatch_time_sec)"
  step concurrent    "Max concurrent hires"       value "$(yaml max_concurrent_hires)"
  step sub_hires     "Sub-hires (toggle)"         value "$(yaml sub_hires)"
  for d in agent/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    s="$(basename "$d")"
    step "skill_${s}_title" "Skill '$s': title"       value "$(fm "$d/SKILL.md" name)"
    step "skill_${s}_desc"  "Skill '$s': description" value "$(fm "$d/SKILL.md" description)"
    step "skill_$s" "Skill '$s': upload" note \
      "Upload via '+ Upload new skill' → pick $(pwd)/${d}SKILL.md"
  done
}

case "${1:-}" in
  --list)
    ONLY="__none__"; TOTAL=0
    # Re-run step() in list mode by printing names instead: cheap approach —
    # names are stable, so just document them here.
    cat <<'EOF'
name handle role category tagline description mcp_<server> price delivery_sla
system_prompt spend_cap output_format tool_rounds dispatch_time concurrent
sub_hires skill_<dir>_title skill_<dir>_desc skill_<dir>
EOF
    exit 0 ;;
  *) ONLY="${1:-}" ;;
esac

# Count steps for the [n/N] header:
# 15 fixed + one per private MCP server + three per skill with a SKILL.md
# (title, description, upload).
TOTAL=15
TOTAL=$((TOTAL + $(mcp_servers | wc -l | tr -d ' ')))
for d in agent/skills/*/; do [ -f "$d/SKILL.md" ] && TOTAL=$((TOTAL+3)); done

echo "$(bold 'Agents Market publish wizard') — copies each form value to your clipboard."
[ -n "$ONLY" ] && echo "$(dim "Single step: $ONLY")"
build_steps

echo
green '✓'; echo " Done — all values walked. Run ./check.sh if you haven't yet."
