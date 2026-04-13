#!/usr/bin/env bash
# Custom Claude Code statusline — seamless powerline, zero intermediate resets.
# Catppuccin Mocha "Sunset Strip": flamingo → pink → mauve → lavender → blue → sapphire
# Dependencies: jq, bash

input=$(cat)

# ── Extract all fields (newline-delimited to handle spaces in values) ───────
mapfile -t _f < <(echo "$input" | jq -r '
  (.workspace.current_dir // .cwd // ""),
  (if (.model | type) == "object" then (.model.id // "") else (.model // "") end),
  (if (.model | type) == "object" then (.model.display_name // "") else "" end),
  (.context_window.used_percentage // ""),
  (.cost.total_cost_usd // ""),
  (.cost.total_api_duration_ms // ""),
  (.context_window.total_output_tokens // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.transcript_path // "")
' 2>/dev/null)
cwd="${_f[0]}"; model_id="${_f[1]}"; model_disp="${_f[2]}"
used_pct="${_f[3]}"; cost_usd="${_f[4]}"; api_ms="${_f[5]}"
out_tokens="${_f[6]}"; rate5h="${_f[7]}"; transcript_path="${_f[8]}"

# ── Derive values ──────────────────────────────────────────────────────────

# CWD: abbreviate home, keep last 2 segments
home="$HOME"
[[ "$cwd" == "$home"* ]] && cwd="~${cwd#$home}"
cwd_short=$(echo "$cwd" | awk -F'/' '{ if(NF<=2) print $0; else printf "…/%s",$NF }')

# Model: prefer id, strip claude- prefix
model="${model_id:-$model_disp}"
model="${model#claude-}"
model="${model#Claude-}"
# Normalize display_name: "Sonnet 4.6" → "sonnet-4.6"
[[ "$model" == *" "* ]] && model=$(echo "$model" | tr '[:upper:] ' '[:lower:]-')

# Context percentage
ctx=""
[[ -n "$used_pct" ]] && ctx=$(printf "%.0f%%" "$used_pct")

# Cost
cost_str=""
[[ -n "$cost_usd" && "$cost_usd" != "0" ]] && cost_str=$(printf "\$%.2f" "$cost_usd")

# Speed: session-average output t/s
speed_str=""
if [[ -n "$api_ms" && -n "$out_tokens" && "$api_ms" != "0" ]]; then
  speed_str=$(awk "BEGIN { s=$out_tokens/($api_ms/1000); if(s>=1000) printf \"%.1fk t/s\",s/1000; else if(s>=1) printf \"%.0f t/s\",s; }" 2>/dev/null)
fi

# Rate limit (5h block usage)
rate_str=""
[[ -n "$rate5h" ]] && rate_str=$(printf "%.0f%%" "$rate5h")

# Thinking effort: grep transcript backwards for /effort command output
effort=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  effort=$(tac "$transcript_path" 2>/dev/null | grep -o 'Set effort level to \(low\|medium\|high\|max\)' | head -1 | sed 's/Set effort level to //' 2>/dev/null || true)
fi
# Show all effort levels including medium
[[ -z "$effort" ]] && effort="auto"

# Git: fast detection
git_branch=""
git_stat=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_stat=$(git diff --shortstat 2>/dev/null | sed 's/ file.* changed//;s/ insertion.*//;s/ deletion.*//;s/,//g;s/^ //' 2>/dev/null)
fi

# ── Catppuccin Mocha "Sunset Strip" palette ────────────────────────────────
# Format: BG_xxx = background ANSI, FG_xxx = same color as foreground (for arrows)
FG_CRUST=$'\033[38;2;17;17;27m'

BG_FLAMINGO=$'\033[48;2;242;205;205m'; FG_FLAMINGO=$'\033[38;2;242;205;205m'
BG_PINK=$'\033[48;2;245;194;231m';     FG_PINK=$'\033[38;2;245;194;231m'
BG_MAUVE=$'\033[48;2;203;166;247m';    FG_MAUVE=$'\033[38;2;203;166;247m'
BG_LAVENDER=$'\033[48;2;180;190;254m'; FG_LAVENDER=$'\033[38;2;180;190;254m'
BG_BLUE=$'\033[48;2;137;180;250m';     FG_BLUE=$'\033[38;2;137;180;250m'
BG_SAPPHIRE=$'\033[48;2;116;199;236m'; FG_SAPPHIRE=$'\033[38;2;116;199;236m'

BOLD=$'\033[1m'
NOBOLD=$'\033[22m'
RESET=$'\033[0m'
ARROW=$'\xee\x82\xb0'       # U+E0B0
CAP_START=$'\xee\x82\xb6'   # U+E0B6
CAP_END=$'\xee\x82\xb4'     # U+E0B4

# Dynamic context color + emphasis based on usage
BG_CTX="$BG_BLUE"; FG_CTX="$FG_BLUE"; CTX_EMPH=""
if [[ -n "$used_pct" ]]; then
  used_int=$(printf "%.0f" "$used_pct")
  if (( used_int >= 80 )); then
    BG_CTX=$'\033[48;2;243;139;168m'; FG_CTX=$'\033[38;2;243;139;168m'   # red
    CTX_EMPH="$BOLD"
  elif (( used_int >= 60 )); then
    BG_CTX=$'\033[48;2;249;226;175m'; FG_CTX=$'\033[38;2;249;226;175m'   # yellow
  fi
fi

# Dynamic rate limit color + emphasis
BG_RATE="$BG_SAPPHIRE"; FG_RATE="$FG_SAPPHIRE"; RATE_EMPH=""
if [[ -n "$rate5h" ]]; then
  rate_int=$(printf "%.0f" "$rate5h")
  if (( rate_int >= 90 )); then
    BG_RATE=$'\033[48;2;243;139;168m'; FG_RATE=$'\033[38;2;243;139;168m'  # red
    RATE_EMPH="$BOLD"
  elif (( rate_int >= 70 )); then
    BG_RATE=$'\033[48;2;249;226;175m'; FG_RATE=$'\033[38;2;249;226;175m'  # yellow
  fi
fi

# ── Build output — ZERO intermediate resets ────────────────────────────────
out=""

# Track current bg for arrow transitions
prev_fg=""  # fg color matching previous segment's bg (for arrow coloring)

# Start cap: fg=flamingo on default bg
out+="${FG_FLAMINGO}${CAP_START}"

# ── Segment: CWD (flamingo) ────────────────────────────────────────────────
out+="${BG_FLAMINGO}${FG_CRUST}${BOLD} ${cwd_short} ${NOBOLD}"
prev_fg="$FG_FLAMINGO"

# ── Segment: Git (pink) — conditional ──────────────────────────────────────
if [[ -n "$git_branch" ]]; then
  out+="${prev_fg}${BG_PINK}${ARROW}"
  git_text=" ${git_branch}"
  [[ -n "$git_stat" ]] && git_text+=" ${git_stat}"
  git_text+=" "
  out+="${FG_CRUST}${git_text}"
  prev_fg="$FG_PINK"
fi

# ── Segment: Model (mauve) ─────────────────────────────────────────────────
out+="${prev_fg}${BG_MAUVE}${ARROW}"
out+="${FG_CRUST}${BOLD} ${model} ${NOBOLD}"
prev_fg="$FG_MAUVE"

# ── Segment: Thinking (lavender) — conditional ─────────────────────────────
if [[ -n "$effort" ]]; then
  out+="${prev_fg}${BG_LAVENDER}${ARROW}"
  out+="${FG_CRUST} ${effort} "
  prev_fg="$FG_LAVENDER"
fi

# ── Segment: Context % (dynamic color, bold when ≥80%) ─────────────────────
if [[ -n "$ctx" ]]; then
  out+="${prev_fg}${BG_CTX}${ARROW}"
  out+="${FG_CRUST}${CTX_EMPH} ${ctx} ${CTX_EMPH:+$NOBOLD}"
  prev_fg="$FG_CTX"
fi

# ── Segment: Speed (sapphire) ─────────────────────────────────────────────
if [[ -n "$speed_str" ]]; then
  out+="${prev_fg}${BG_SAPPHIRE}${ARROW}"
  out+="${FG_CRUST} ${speed_str} "
  prev_fg="$FG_SAPPHIRE"
fi

# ── Segment: Rate limit (dynamic color, bold when ≥90%) ───────────────────
if [[ -n "$rate_str" ]]; then
  out+="${prev_fg}${BG_RATE}${ARROW}"
  out+="${FG_CRUST}${RATE_EMPH} ${rate_str} ${RATE_EMPH:+$NOBOLD}"
  prev_fg="$FG_RATE"
fi

# ── End cap: fg=last_bg on default bg ──────────────────────────────────────
out+="${RESET}${prev_fg}${CAP_END}${RESET}"

printf "%s\n" "$out"
