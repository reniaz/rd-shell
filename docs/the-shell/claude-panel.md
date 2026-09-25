# Claude panel

`ClaudePanel.qml`, opened from its bar pill. No bind by default — bind
`qs ipc -c rd-shell call claude toggle` yourself if you want one.

Four tabs, all reading state off disk — none of them start a `claude` process
just to answer a question:

- **Session table** (`ClaudeSessionList.qml`/`ClaudeSessionDetail.qml`,
  `ClaudeSessionRow.qml`) — what's running, context fill, plan, subagents.
- **Lifetime spend** — aggregated from every transcript ever written.
- **Spend/usage charts** (`ClaudeAreaChart.qml`, `ClaudeBarChart.qml`,
  `ClaudeDonutChart.qml`, `ClaudeHeatmap.qml`, `ClaudeColumns.qml`,
  `ClaudeLegend.qml`).
- **Optimize** (`ClaudeOptimizeTab.qml`, `ClaudeRuleRow.qml`) — token-budget
  rules applied from `settings.json`/`CLAUDE.md`.

Backing services: `Services/ClaudeSession.qml`, `Services/ClaudeDetail.qml`,
`Services/ClaudeGlobal.qml`, `Services/ClaudeOptimize.qml`. On disk, this
reads the same transcript/session files Claude Code itself writes and (per
`scripts/claude-global.sh`) caches a summary under `~/.cache/qs-bar/`.

If the panel is empty: no `claude` CLI is installed, or `~/.claude` has
nothing in it yet. `install.sh` deliberately doesn't install `claude` itself
— see [Troubleshooting](../troubleshooting.md).
