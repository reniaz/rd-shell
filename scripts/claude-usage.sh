#!/bin/sh
# Refreshes the account-wide rate-limit figures, and nothing else.
#
# Claude Code writes .cachedUsageUtilization into ~/.claude.json only when you
# open /usage, so a bar reading that file alone reports whatever your last
# manual check said -- routinely hours stale, and stuck at the old number for
# the whole of the next five-hour window. This asks the endpoint /usage itself
# asks, with the same OAuth credentials, and leaves the answer in a cache file
# that claude-status.sh reads alongside the CLI's copy.
#
# Run on a slow timer. Unlike claude-status.sh this is a network round trip,
# and the five-hour figure only ever moves in whole percent.
#
# Every failure path leaves the previous cache exactly as it was and exits 0:
# a missed refresh must read as "unchanged", never as "0%" and never as an
# error the poller has to interpret.

CDIR="${CLAUDE_HOME:-$HOME/.claude}"
CREDS="$CDIR/.credentials.json"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qs-bar"
CACHE="$CACHE_DIR/claude-usage.json"

command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
[ -r "$CREDS" ] || exit 0

# expiresAt is checked here only to avoid firing a request that is certain to
# come back 401. Refreshing the token is deliberately not attempted: the refresh
# rotates it, and racing the CLI for that write would log the user out.
now_ms=$(date +%s%3N)
tok=$(jq -r --argjson now "$now_ms" '
    .claudeAiOauth
    | select((.expiresAt // 0) > $now)
    | .accessToken // empty' "$CREDS" 2>/dev/null)
[ -n "$tok" ] || exit 0

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

tmp="$CACHE.$$"
trap 'rm -f "$tmp" "$tmp.out"' EXIT INT TERM

# at_wall=1 asks what the utilization is right now rather than as of the last
# request this account made -- without it a quiet account reports the figure
# from its final message and never moves.
code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 8 \
    "https://api.anthropic.com/api/oauth/usage?at_wall=1" \
    -H "Authorization: Bearer $tok" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || exit 0
[ "$code" = "200" ] || exit 0

# Written in the CLI's own cachedUsageUtilization shape, so claude-status.sh
# reads this file and ~/.claude.json through one expression and simply keeps
# whichever was fetched later.
jq -c --argjson now "$now_ms" '
    select(.five_hour != null)
    | {fetchedAtMs: $now, utilization: .}' "$tmp" > "$tmp.out" 2>/dev/null || exit 0
[ -s "$tmp.out" ] || exit 0

mv -f "$tmp.out" "$CACHE"
