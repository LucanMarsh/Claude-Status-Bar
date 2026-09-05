#!/usr/bin/env bash
# ~/.claude/statusline.sh — Claude Code session status line (aesthetic edition)
#
# 三行輸出：
#   第一行：◆ 模型 │ 漸層進度條 百分比 │ 費用 │ 時間 │ 速率限制
#   第二行：+增/-減 │ 目錄
#   第三行：❯ 提示符（顏色跟上下文用量連動）
#
# 環境變數：
#   CLAUDE_STATUSLINE_ASCII=1     退回純 ASCII
#   CLAUDE_STATUSLINE_NERDFONT=1  啟用 Nerd Font 圖示
#   CLAUDE_STATUSLINE_POWERLINE=1 啟用 Powerline 分隔符（預設跟隨 NERDFONT）
#   COLORTERM=truecolor|24bit     系統自動設定，啟用真彩色漸層

set -uo pipefail

# ═══════════════════════════════════════════════════════════════
# 環境偵測
# ═══════════════════════════════════════════════════════════════

USE_ASCII="${CLAUDE_STATUSLINE_ASCII:-0}"
USE_NERDFONT="${CLAUDE_STATUSLINE_NERDFONT:-0}"
USE_POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$USE_NERDFONT}"
USE_TRUECOLOR=0
if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
  USE_TRUECOLOR=1
fi

# ═══════════════════════════════════════════════════════════════
# 色彩與符號
# ═══════════════════════════════════════════════════════════════

RST='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'
GRAY='\033[90m'
DIM='\033[2m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
MAGENTA='\033[35m'

# Anthropic 品牌紫 (#7266EA)
if (( USE_TRUECOLOR )); then
  PURPLE='\033[38;2;114;102;234m'
else
  PURPLE='\033[35m'
fi

# Claude 品牌橘 (#D97757)
if (( USE_TRUECOLOR )); then
  CLAUDE_ORANGE='\033[38;2;217;119;87m'
else
  CLAUDE_ORANGE='\033[38;5;208m'
fi

# 符號集
if [[ "$USE_ASCII" == "1" ]]; then
  S_BRAND="<>"
  S_WARN="!"
  S_PROMPT=">"
  S_TIME=""
  S_COST=""
  S_RESET="in "
  S_AGENT="agents:"
  SEP=" | "
elif [[ "$USE_NERDFONT" == "1" ]]; then
  S_BRAND="◆"
  S_WARN=" 󰀦"
  S_PROMPT="❯"
  S_TIME="󰔟 "
  S_COST=" "
  S_RESET="󰥔 "
  S_AGENT=" "
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
else
  S_BRAND="◆"
  S_WARN=" ⚠"
  S_PROMPT="❯"
  S_TIME=""
  S_COST=""
  S_RESET="⟳"
  S_AGENT="#"
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 降級輸出
# ═══════════════════════════════════════════════════════════════

fallback_prompt() {
  printf '%b' "${GRAY}${1:-─}${RST}"
  exit 0
}

command -v jq &>/dev/null || fallback_prompt "─ │ jq not found"

# ═══════════════════════════════════════════════════════════════
# 讀取 JSON（單次 jq）
# ═══════════════════════════════════════════════════════════════

input=$(cat)

parsed=$(echo "$input" | jq -r '
  (.model.display_name // ""),
  (.context_window.used_percentage // 0 | tostring),
  (.cost.total_cost_usd // 0 | tostring),
  (.workspace.current_dir // "." | split("/") | last),
  (.rate_limits.five_hour.used_percentage // -1 | tostring),
  (.rate_limits.seven_day.used_percentage // -1 | tostring),
  (.agent.name // ""),
  (.workspace.current_dir // "."),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.context_window.context_window_size // 0 | tostring),
  (.context_window.total_input_tokens // 0 | tostring),
  (.worktree.name // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.resets_at // ""),
  (.transcript_path // ""),
  (.session_id // ""),
  (.effort.level // ""),
  "END"
' 2>/dev/null) || fallback_prompt "─ │ parse error"

{
  IFS= read -r model_name
  IFS= read -r ctx_pct
  IFS= read -r cost
  IFS= read -r dir
  IFS= read -r rate5h
  IFS= read -r rate7d
  IFS= read -r agent_name
  IFS= read -r cwd_full
  IFS= read -r lines_add
  IFS= read -r lines_rm
  IFS= read -r duration_ms
  IFS= read -r ctx_size
  IFS= read -r ctx_used_tokens
  IFS= read -r wt_name
  IFS= read -r reset5h_at
  IFS= read -r reset7d_at
  IFS= read -r transcript_path
  IFS= read -r session_id
  IFS= read -r effort_level
  IFS= read -r _sentinel
} <<< "$parsed"

# ═══════════════════════════════════════════════════════════════
# 模型
# ═══════════════════════════════════════════════════════════════

model="${model_name:-─}"

# ═══════════════════════════════════════════════════════════════
# 上下文進度條
# ═══════════════════════════════════════════════════════════════

pct_int=${ctx_pct%.*}
pct_int=${pct_int:-0}
if (( pct_int < 0 )); then pct_int=0; fi
if (( pct_int > 100 )); then pct_int=100; fi

bar_filled=$(( pct_int / 10 ))
if (( bar_filled > 10 )); then bar_filled=10; fi

# 漸層色（真彩色）：綠 → 黃 → 橘 → 紅
GRAD_R=(46 116 186 241 239 236 233 231 211 192)
GRAD_G=(204 195 186 196 161 126 101 76 66 57)
GRAD_B=(113 89 64 15 24 34 44 60 50 43)

bar=""
if [[ "$USE_ASCII" == "1" ]]; then
  # ASCII 模式
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="#"; else bar+="-"; fi
  done
elif (( USE_TRUECOLOR )); then
  # 真彩色漸層：每格獨立上色
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then
      bar+="\\033[38;2;${GRAD_R[$i]};${GRAD_G[$i]};${GRAD_B[$i]}m█"
    else
      bar+="\\033[38;2;60;60;60m░"
    fi
  done
  bar+="${RST}"
else
  # ANSI 退回：依整體百分比選色
  if (( pct_int >= 90 )); then bar_color="$RED"
  elif (( pct_int >= 70 )); then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi

  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="█"; else bar+="░"; fi
  done
  bar="${bar_color}${bar}${RST}"
fi

# 百分比文字顏色（跟進度條整體色一致）
if (( pct_int >= 90 )); then pct_color="$RED"
elif (( pct_int >= 70 )); then pct_color="$YELLOW"
else pct_color="$GREEN"; fi

# 警告符號
ctx_warn=""
if (( pct_int >= 90 )); then ctx_warn="${RED}${S_WARN}${RST}"; fi

# 上下文視窗大小（僅在 model display_name 不包含 context 資訊時才顯示）
format_tokens() {
  local n="${1:-0}"
  if (( n >= 1000000 )); then
    local whole=$(( n / 1000000 ))
    local frac=$(( (n % 1000000) / 100000 ))
    if (( frac > 0 )); then printf '%d.%dM' "$whole" "$frac"; else printf '%dM' "$whole"; fi
  elif (( n >= 1000 )); then
    printf '%dk' "$(( n / 1000 ))"
  else
    printf '%d' "$n"
  fi
}

ctx_size_int=${ctx_size:-0}
ctx_used_int=${ctx_used_tokens:-0}
ctx_label=""
if [[ "$model" != *context* && "$model" != *Context* ]]; then
  if (( ctx_size_int >= 1000000 )); then ctx_label=" ${GRAY}$(format_tokens "$ctx_used_int")/1M${RST}"
  elif (( ctx_size_int >= 200000 )); then ctx_label=" ${GRAY}$(format_tokens "$ctx_used_int")/200k${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 經過時間（零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════

dur_ms=${duration_ms:-0}
dur_section=""
if (( dur_ms > 0 )); then
  dur_sec=$((dur_ms / 1000))
  dur_hr=$((dur_sec / 3600))
  dur_min=$(((dur_sec % 3600) / 60))
  dur_s=$((dur_sec % 60))
  # 格式化後仍為 0s 就不顯示（session 啟動初期 dur_ms 可能是幾百毫秒）
  if (( dur_hr > 0 )); then
    dur_fmt="${dur_hr}h${dur_min}m"
  elif (( dur_min > 0 )); then
    dur_fmt="${dur_min}m${dur_s}s"
  elif (( dur_s > 0 )); then
    dur_fmt="${dur_s}s"
  else
    dur_fmt=""
  fi
  if [[ -n "$dur_fmt" ]]; then
    dur_section="${SEP}${GRAY}${S_TIME}${dur_fmt}${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 行數增減（零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════

lines_add=${lines_add:-0}
lines_rm=${lines_rm:-0}
lines_section=""
if (( lines_add > 0 || lines_rm > 0 )); then
  lines_section="${GREEN}+${lines_add}${RST}/${RED}-${lines_rm}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# 速率限制（條件顯示）+ reset countdown
# ═══════════════════════════════════════════════════════════════

# Format an ISO-8601 resets_at timestamp as a short countdown ("2h15m", "3d4h", "45m").
# Empty string if missing/unparseable/already past.
format_reset_countdown() {
  local iso="$1"
  [[ -z "$iso" || "$iso" == "null" ]] && return
  local reset_epoch=""
  if [[ "$iso" =~ ^[0-9]+$ ]]; then
    # already unix epoch seconds
    reset_epoch="$iso"
  else
    local clean="${iso%.*}"
    clean="${clean%Z}"
    reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null) \
      || reset_epoch=$(date -u -d "${clean}Z" +%s 2>/dev/null) \
      || return
  fi
  local now_epoch diff
  now_epoch=$(date +%s)
  diff=$(( reset_epoch - now_epoch ))
  (( diff <= 0 )) && return
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if (( days > 0 )); then printf '%dd%dh' "$days" "$hours"
  elif (( hours > 0 )); then printf '%dh%dm' "$hours" "$mins"
  else printf '%dm' "$mins"; fi
}

reset5h_str=$(format_reset_countdown "$reset5h_at")
reset7d_str=$(format_reset_countdown "$reset7d_at")

rate_section=""
rate5h_int=${rate5h%.*}; rate5h_int=${rate5h_int:-0}
rate7d_int=${rate7d%.*}; rate7d_int=${rate7d_int:-0}

rate_parts=""
if (( rate5h_int >= 0 )); then
  if (( rate5h_int >= 80 )); then rate_parts+="${RED}5h:${rate5h_int}%${RST}"
  else rate_parts+="${GRAY}5h:${rate5h_int}%${RST}"; fi
  if [[ -n "$reset5h_str" ]]; then rate_parts+="${DIM}${S_RESET}${reset5h_str}${RST}"; fi
fi
if (( rate7d_int >= 0 )); then
  if [[ -n "$rate_parts" ]]; then rate_parts+=" "; fi
  if (( rate7d_int >= 80 )); then rate_parts+="${RED}7d:${rate7d_int}%${RST}"
  else rate_parts+="${GRAY}7d:${rate7d_int}%${RST}"; fi
  if [[ -n "$reset7d_str" ]]; then rate_parts+="${DIM}${S_RESET}${reset7d_str}${RST}"; fi
fi
if [[ -n "$rate_parts" ]]; then
  rate_section="${SEP}${rate_parts}"
fi

# ═══════════════════════════════════════════════════════════════
# Running subagent count (heuristic — # of Task-tool children still active)
# ═══════════════════════════════════════════════════════════════

agent_running=0
if [[ -n "$transcript_path" && -n "$session_id" ]]; then
  subagents_dir="$(dirname "$transcript_path")/$session_id/subagents"
  if [[ -d "$subagents_dir" ]]; then
    for f in "$subagents_dir"/agent-*.jsonl; do
      [[ -e "$f" ]] || continue
      last_line=$(tail -c 16384 "$f" 2>/dev/null | tail -n 1)
      finished=$(printf '%s' "$last_line" | jq -r '
        if .type == "assistant"
           and (.message.stop_reason == "end_turn" or .message.stop_reason == "stop_sequence")
           and ((.message.content // []) | map(select(.type == "tool_use")) | length) == 0
        then "yes" else "no" end
      ' 2>/dev/null)
      [[ "$finished" != "yes" ]] && agent_running=$(( agent_running + 1 ))
    done
  fi
fi

agent_badge=""
if (( agent_running > 0 )); then
  agent_badge="${SEP}${CLAUDE_ORANGE}${S_AGENT}${agent_running}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# Reasoning effort 等級
# ═══════════════════════════════════════════════════════════════

effort_badge=""
if [[ -n "${effort_level:-}" ]]; then
  case "$effort_level" in
    low)              effort_color="$GREEN" ;;
    medium)           effort_color="$YELLOW" ;;
    high|xhigh|max)   effort_color="$RED" ;;
    *)                effort_color="$GRAY" ;;
  esac
  effort_badge="${SEP}${effort_color}${effort_level}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# 動態提示符（顏色跟上下文用量連動）
# ═══════════════════════════════════════════════════════════════

if (( pct_int >= 90 )); then prompt_color="$RED"
elif (( pct_int >= 70 )); then prompt_color="$YELLOW"
else prompt_color="$GREEN"; fi

# ═══════════════════════════════════════════════════════════════
# 組裝第一行
# ═══════════════════════════════════════════════════════════════

line1="${PURPLE}${S_BRAND}${RST} ${CYAN}${model}${RST}"
line1+="${SEP}${bar} ${pct_color}${pct_int}%${RST}${ctx_warn}${ctx_label}"
line1+="${dur_section}"
line1+="${rate_section}"
line1+="${effort_badge}"
line1+="${agent_badge}"

# ═══════════════════════════════════════════════════════════════
# 目錄路徑（顯示最後幾層，而非只有當前目錄名稱）
# ═══════════════════════════════════════════════════════════════

PATH_DEPTH="${CLAUDE_STATUSLINE_PATH_DEPTH:-3}"

path_display="${cwd_full:-$dir}"
if [[ -n "${HOME:-}" && "$path_display" == "$HOME"* ]]; then
  path_display="~${path_display#$HOME}"
fi

IFS='/' read -ra _path_parts <<< "$path_display"
_path_nonempty=()
for _p in "${_path_parts[@]}"; do
  [[ -n "$_p" ]] && _path_nonempty+=("$_p")
done
_path_total=${#_path_nonempty[@]}

if (( _path_total <= PATH_DEPTH )); then
  dir=$(IFS=/; echo "${_path_nonempty[*]}")
  [[ "$path_display" == /* ]] && dir="/${dir}"
else
  _start=$(( _path_total - PATH_DEPTH ))
  _last_parts=("${_path_nonempty[@]:$_start:$PATH_DEPTH}")
  dir=".../$(IFS=/; echo "${_last_parts[*]}")"
fi

# ═══════════════════════════════════════════════════════════════
# 組裝第二行
# ═══════════════════════════════════════════════════════════════

parts=()
if [[ -n "$lines_section" ]]; then
  parts+=("${lines_section}")
fi
parts+=("${BLUE}${dir}${RST}")

# Agent / Worktree 指示器（僅在非主 session 時顯示）
if [[ -n "${wt_name:-}" ]]; then
  parts+=("${YELLOW}⚙ worktree:${wt_name}${RST}")
elif [[ -n "${agent_name:-}" ]]; then
  parts+=("${YELLOW}⚙ ${agent_name}${RST}")
fi

line2=""
for i in "${!parts[@]}"; do
  if (( i > 0 )); then
    line2+="${SEP}"
  fi
  line2+="${parts[$i]}"
done

# ═══════════════════════════════════════════════════════════════
# 輸出
# ═══════════════════════════════════════════════════════════════

# 只輸出兩行（Claude Code 有自己的輸入提示符，不需要我們的 ❯）
printf '%b\n%b' "$line1" "$line2"
