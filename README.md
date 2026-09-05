# Claude Status Bar

A custom status line for [Claude Code](https://claude.com/claude-code), rendered as a two-line prompt showing model, context usage, cost, elapsed time, rate limits, reasoning effort, and running subagents.

## Features

- Gradient/ASCII context-window usage bar with warning threshold
- Elapsed session time (auto-hidden when zero)
- Lines added/removed
- 5-hour and 7-day rate limit usage with reset countdowns
- Reasoning effort badge
- Running subagent count
- Truecolor, Nerd Font, and Powerline-aware rendering with ASCII fallback

## Install

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and make it executable:
   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```
2. Add the `statusLine` block from `settings.snippet.json` to your `~/.claude/settings.json`.
3. Requires [`jq`](https://jqlang.org/) to be installed.

## Configuration

Environment variables (set in your shell profile):

| Variable | Effect |
|---|---|
| `CLAUDE_STATUSLINE_ASCII=1` | Force plain ASCII output |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Enable Nerd Font icons |
| `CLAUDE_STATUSLINE_POWERLINE=1` | Enable Powerline separators (defaults to `NERDFONT` value) |
| `CLAUDE_STATUSLINE_PATH_DEPTH=3` | Number of path segments shown for the working directory |

Truecolor gradients are enabled automatically when `COLORTERM=truecolor` or `24bit`.
