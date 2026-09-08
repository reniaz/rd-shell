#!/bin/sh
# Reads and writes the two files that decide what a Claude Code session costs:
# ~/.claude/settings.json and ~/.claude/CLAUDE.md. Every rule it knows about is
# detected from disk on every call and never remembered, so the panel cannot
# drift out of step with a file the user edited by hand.
#
# The script never calls sudo itself. It reports whether it *could* write, and
# the caller decides whether to re-run it under sudo -- which is why every path
# below is taken from CLAUDE_HOME rather than HOME: sudo hands us /root.
set -eu

CLAUDE_HOME="${CLAUDE_HOME:-$HOME}"
SETTINGS="$CLAUDE_HOME/.claude/settings.json"
RULES="$CLAUDE_HOME/.claude/CLAUDE.md"
BACKUPS="$CLAUDE_HOME/.claude/backups"

ERR=""

# Anything that leaves this script has to be parseable JSON, because the caller
# swaps its whole model out for whatever lands on stdout.
EMPTY='{"generatedAt":"","needsSudo":false,"settingsPath":"","rulesPath":"","appliedCount":0,"totalCount":0,"error":"","rules":[]}'

command -v jq >/dev/null 2>&1 || { printf '%s\n' "$EMPTY"; exit 0; }

# ── the catalogue ─────────────────────────────────────────────────────────
# The single source of truth for what the panel offers. `kind` decides both how
# a rule is detected and how it is written:
#   env  -- a string under .env in settings.json
#   bool -- a top-level boolean in settings.json
#   md   -- a marked block in CLAUDE.md
# Every env name here was checked against the installed claude binary; none of
# them is guessed, and nothing is added to this list that was not.
CATALOGUE=$(cat <<'JSON'
[
  {
    "id": "subagent-model",
    "section": "settings",
    "kind": "env",
    "key": "CLAUDE_CODE_SUBAGENT_MODEL",
    "val": "claude-sonnet-5",
    "title": "Route subagents to Sonnet",
    "detail": "Every subagent inherits the main model unless this names another one. Sonnet 5 bills $2 in and $10 out per million tokens against Opus 5 at $5 and $25, and delegated work is mostly reading and searching.",
    "saves": "cost",
    "target": "settings.json · env",
    "value": "CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-5",
    "risk": "Delegated answers are less capable. Revert if a subagent starts coming back wrong."
  },
  {
    "id": "mcp-output-cap",
    "section": "settings",
    "kind": "env",
    "key": "MAX_MCP_OUTPUT_TOKENS",
    "val": "10000",
    "title": "Cap MCP tool output",
    "detail": "An MCP result lands in the transcript and is re-sent as input on every later turn. The default ceiling is 25000 tokens per result; 10000 still carries a full page.",
    "saves": "input",
    "target": "settings.json · env",
    "value": "MAX_MCP_OUTPUT_TOKENS=10000",
    "risk": "A very large MCP result is truncated rather than trimmed by the server itself."
  },
  {
    "id": "bash-output-cap",
    "section": "settings",
    "kind": "env",
    "key": "BASH_MAX_OUTPUT_LENGTH",
    "val": "20000",
    "title": "Cap bash output",
    "detail": "Limits how much command output is pasted into the conversation. One unbounded log dump is paid for again in the input of every turn that follows it.",
    "saves": "input",
    "target": "settings.json · env",
    "value": "BASH_MAX_OUTPUT_LENGTH=20000",
    "risk": "Long build logs are cut off. Re-run through grep or tail when that happens."
  },
  {
    "id": "thinking-cap",
    "section": "settings",
    "kind": "env",
    "key": "MAX_THINKING_TOKENS",
    "val": "8000",
    "title": "Cap the thinking budget",
    "detail": "A ceiling on the reasoning a turn may spend before answering. Thinking is billed as output, and on a routine edit almost none of it is ever read.",
    "saves": "output",
    "target": "settings.json · env",
    "value": "MAX_THINKING_TOKENS=8000",
    "risk": "Hard problems get less room to reason. Remove it again for design work."
  },
  {
    "id": "no-interleaved-thinking",
    "section": "settings",
    "kind": "env",
    "key": "DISABLE_INTERLEAVED_THINKING",
    "val": "1",
    "title": "Stop thinking between tool calls",
    "detail": "Drops the extra reasoning block emitted between one tool call and the next. On a long tool chain that block is spent dozens of times in a single turn.",
    "saves": "output",
    "target": "settings.json · env",
    "value": "DISABLE_INTERLEAVED_THINKING=1",
    "risk": "Long tool sequences are planned less carefully as they go."
  },
  {
    "id": "nonessential-traffic",
    "section": "settings",
    "kind": "env",
    "key": "DISABLE_NONESSENTIAL_TRAFFIC",
    "val": "1",
    "title": "Drop non-essential calls",
    "detail": "Turns off the background requests the CLI makes for convenience rather than for your turn, along with its telemetry and update pings.",
    "saves": "calls",
    "target": "settings.json · env",
    "value": "DISABLE_NONESSENTIAL_TRAFFIC=1",
    "risk": "Conveniences that depend on those calls go quiet."
  },
  {
    "id": "tool-search",
    "section": "settings",
    "kind": "env",
    "key": "ENABLE_TOOL_SEARCH",
    "val": "auto",
    "title": "Defer tool schemas until needed",
    "detail": "Holds tool definitions back until a tool is actually wanted instead of sending all of them in every request. With several MCP servers connected that prefix is thousands of input tokens per turn.",
    "saves": "input",
    "target": "settings.json · env",
    "value": "ENABLE_TOOL_SEARCH=auto",
    "risk": ""
  },
  {
    "id": "no-always-thinking",
    "section": "settings",
    "kind": "bool",
    "key": "alwaysThinkingEnabled",
    "val": false,
    "title": "Think only when it is worth it",
    "detail": "Lets the model decide per turn whether to reason first, instead of thinking ahead of every reply including the trivial ones.",
    "saves": "output",
    "target": "settings.json",
    "value": "alwaysThinkingEnabled = false",
    "risk": ""
  },
  {
    "id": "auto-compact",
    "section": "settings",
    "kind": "bool",
    "key": "autoCompactEnabled",
    "val": true,
    "title": "Keep auto-compact on",
    "detail": "Summarises the conversation as it approaches the context limit. Without it a long session re-sends its whole history as input on every turn until it hits the wall.",
    "saves": "input",
    "target": "settings.json",
    "value": "autoCompactEnabled = true",
    "risk": ""
  },
  {
    "id": "terse-output",
    "section": "rules",
    "kind": "md",
    "key": "",
    "val": "",
    "title": "Answer without preamble",
    "detail": "Preamble and closing recaps are pure output tokens that repeat what the answer already said.",
    "saves": "output",
    "target": "CLAUDE.md",
    "value": "Answer with the result, not a recap. No preamble, no restatement of the request, no closing summary of what was just said in full above.",
    "risk": ""
  },
  {
    "id": "targeted-reads",
    "section": "rules",
    "kind": "md",
    "key": "",
    "val": "",
    "title": "Read ranges, not whole files",
    "detail": "A whole-file read is billed once when it happens and again inside the input of every turn after it.",
    "saves": "input",
    "target": "CLAUDE.md",
    "value": "Read only the part of a file the task needs -- a line range, or a grep. Never re-read a file to confirm an edit that the edit tool already reported as applied.",
    "risk": ""
  },
  {
    "id": "batch-calls",
    "section": "rules",
    "kind": "md",
    "key": "",
    "val": "",
    "title": "Batch independent tool calls",
    "detail": "Each turn re-sends the entire conversation as input, so two turns cost roughly twice what one turn carrying both calls costs.",
    "saves": "input",
    "target": "CLAUDE.md",
    "value": "Issue independent tool calls together in one message. Every extra turn re-sends the whole conversation as input.",
    "risk": ""
  },
  {
    "id": "delegate-search",
    "section": "rules",
    "kind": "md",
    "key": "",
    "val": "",
    "title": "Delegate wide searches",
    "detail": "A subagent's file dumps stay in the subagent. Only its conclusion is ever paid for in the main thread.",
    "saves": "input",
    "target": "CLAUDE.md",
    "value": "Send broad multi-file searches to a subagent and keep only its conclusion. A file dump read in the main thread is paid for again on every later turn.",
    "risk": ""
  },
  {
    "id": "cache-stable-prefix",
    "section": "rules",
    "kind": "md",
    "key": "",
    "val": "",
    "title": "Keep the cached prefix stable",
    "detail": "The prompt prefix is cached by exact bytes and read back at about a tenth of the input price. One changed byte re-bills the whole prefix at full rate.",
    "saves": "cache",
    "target": "CLAUDE.md",
    "value": "Do not edit CLAUDE.md, memory files or settings mid-session unless the task is about them: the prompt prefix is cached by exact bytes, and one changed byte re-bills the whole prefix.",
    "risk": ""
  }
]
JSON
)

# ── writability ───────────────────────────────────────────────────────────
# A target that does not exist yet is writable when its directory is: that is
# the case where the panel creates settings.json for the first time.
writable() {
    if [ -e "$1" ]; then
        [ -w "$1" ]
    else
        [ -w "$(dirname "$1")" ]
    fi
}

needs_sudo() {
    if writable "$SETTINGS" && writable "$RULES"; then
        printf 'false'
    else
        printf 'true'
    fi
}

# ── writes ────────────────────────────────────────────────────────────────
# One backup per invocation per file, so pressing Apply twelve times does not
# leave twelve identical copies of the same settings file.
backed_up=""

backup_once() {
    case " $backed_up " in
        *" $1 "*) return 0 ;;
    esac
    backed_up="$backed_up $1"
    [ -e "$1" ] || return 0
    mkdir -p "$BACKUPS"
    cp -p "$1" "$BACKUPS/$(basename "$1").qsbar.$(date +%s).bak"
}

# Moves a staged file over its target while keeping the target's identity. The
# chown is the whole reason this is a function: run under sudo without it, an
# apply hands the user's settings.json to root and Claude Code can never write
# it again.
replace() {
    target=$1
    staged=$2

    if [ -e "$target" ]; then
        owner=$(stat -c %u:%g "$target")
        mode=$(stat -c %a "$target")
    else
        owner=$(stat -c %u:%g "$(dirname "$target")")
        mode=600
    fi

    chmod "$mode" "$staged"
    chown "$owner" "$staged" 2>/dev/null || true
    mv -f "$staged" "$target"
}

settings_json() {
    if [ -f "$SETTINGS" ]; then
        jq -c . "$SETTINGS" 2>/dev/null || printf '{}'
    else
        printf '{}'
    fi
}

# Both settings writers stage through jq and go through replace(), so a jq that
# fails leaves the original file untouched rather than truncated.
write_settings() {
    backup_once "$SETTINGS"
    staged="$SETTINGS.qsbar.$$"
    settings_json | jq "$@" > "$staged" || { rm -f "$staged"; return 1; }
    replace "$SETTINGS" "$staged"
}

# ── CLAUDE.md blocks ──────────────────────────────────────────────────────
# Each rule owns a marked block inside one managed section. Detection is the
# presence of the opening marker, which means a user who deletes the block by
# hand simply turns the rule off.
md_has() {
    [ -f "$RULES" ] || return 1
    grep -qxF "<!-- qs-bar:optimize:$1 -->" "$RULES"
}

md_applied_ids() {
    if [ ! -f "$RULES" ]; then
        printf '[]'
        return 0
    fi
    ids=$(sed -n 's/^<!-- qs-bar:optimize:\([a-z0-9-]*\) -->$/\1/p' "$RULES" \
          | grep -vxE 'start|end' || true)
    printf '%s' "$ids" | jq -R . | jq -s -c .
}

md_apply() {
    id=$1
    text=$2
    if md_has "$id"; then return 0; fi

    backup_once "$RULES"
    staged="$RULES.qsbar.$$"
    block="<!-- qs-bar:optimize:$id -->
- $text
<!-- /qs-bar:optimize:$id -->"

    if [ -f "$RULES" ] && grep -qxF '<!-- qs-bar:optimize:end -->' "$RULES"; then
        awk -v b="$block" '
            $0 == "<!-- qs-bar:optimize:end -->" { print b; print ""; print; next }
            { print }
        ' "$RULES" > "$staged"
    else
        {
            if [ -f "$RULES" ]; then cat "$RULES"; fi
            printf '\n<!-- qs-bar:optimize:start -->\n'
            printf '## Token budget (managed by qs-bar -- edit in the Claude panel)\n\n'
            printf '%s\n\n' "$block"
            printf '<!-- qs-bar:optimize:end -->\n'
        } > "$staged"
    fi

    replace "$RULES" "$staged"
}

# Drops the rule's own block, then drops the whole managed section once the last
# block in it is gone -- including the blank line the section was appended
# after, so a CLAUDE.md that has had every rule reverted is byte-identical to
# the one qs-bar first found.
md_revert() {
    id=$1
    md_has "$id" || return 0

    backup_once "$RULES"
    staged="$RULES.qsbar.$$"

    awk -v id="$id" '
        $0 == "<!-- qs-bar:optimize:" id " -->"  { skip = 1; next }
        $0 == "<!-- /qs-bar:optimize:" id " -->" { skip = 0; eat = 1; next }
        skip { next }
        eat && $0 == "" { eat = 0; next }
        { eat = 0; print }
    ' "$RULES" > "$staged"

    if ! sed -n 's/^<!-- qs-bar:optimize:\([a-z0-9-]*\) -->$/\1/p' "$staged" \
         | grep -qvxE 'start|end'; then
        awk '
            /^<!-- qs-bar:optimize:start -->$/ { skip = 1; hold = 0; next }
            /^<!-- qs-bar:optimize:end -->$/   { skip = 0; next }
            skip { next }
            {
                if (hold) { print held; hold = 0 }
                if ($0 == "") { held = $0; hold = 1 } else print
            }
            END { if (hold) print held }
        ' "$staged" > "$staged.2"
        mv -f "$staged.2" "$staged"
    fi

    replace "$RULES" "$staged"
}

# ── one rule ──────────────────────────────────────────────────────────────
rule_field() {
    printf '%s' "$CATALOGUE" | jq -r --arg id "$1" --arg f "$2" \
        '(.[] | select(.id == $id) | .[$f]) // empty'
}

rule_exists() {
    [ -n "$(printf '%s' "$CATALOGUE" | jq -r --arg id "$1" '.[] | select(.id == $id) | .id')" ]
}

do_apply() {
    id=$1
    kind=$(rule_field "$id" kind)
    key=$(rule_field "$id" key)

    case "$kind" in
        env)
            val=$(rule_field "$id" val)
            write_settings --arg k "$key" --arg v "$val" \
                '.env = ((.env // {}) + {($k): $v})'
            ;;
        bool)
            val=$(printf '%s' "$CATALOGUE" | jq -c --arg id "$id" \
                  '.[] | select(.id == $id) | .val')
            write_settings --arg k "$key" --argjson v "$val" '.[$k] = $v'
            ;;
        md)
            md_apply "$id" "$(rule_field "$id" value)"
            ;;
    esac
}

do_revert() {
    id=$1
    kind=$(rule_field "$id" kind)
    key=$(rule_field "$id" key)

    case "$kind" in
        # Deleting rather than writing the opposite value: the rule was never
        # the CLI's default, so removing the key is what "off" actually means.
        env)
            [ -f "$SETTINGS" ] || return 0
            write_settings --arg k "$key" \
                'if .env then (.env |= del(.[$k])) else . end
                 | if .env == {} then del(.env) else . end'
            ;;
        bool)
            [ -f "$SETTINGS" ] || return 0
            write_settings --arg k "$key" 'del(.[$k])'
            ;;
        md)
            md_revert "$id"
            ;;
    esac
}

# ── status ────────────────────────────────────────────────────────────────
status() {
    jq -n \
        --argjson cat "$CATALOGUE" \
        --argjson set "$(settings_json)" \
        --argjson md "$(md_applied_ids)" \
        --argjson sudo "$(needs_sudo)" \
        --arg gen "$(date -Iseconds)" \
        --arg sp "$SETTINGS" \
        --arg rp "$RULES" \
        --arg err "$ERR" '
        [ $cat[]
          # Bound to $r before the detection expression: inside index() the
          # input is $md, so a bare .id there reads the array, not the rule.
          | . as $r
          | $r + { applied:
              # has(), not the // operator: `false // null` is null, so an
               # applied `alwaysThinkingEnabled: false` would read as absent.
               (if $r.kind == "env" then
                    (($set.env // {}) | has($r.key)) and ($set.env[$r.key] == $r.val)
                elif $r.kind == "bool" then
                    ($set | has($r.key)) and ($set[$r.key] == $r.val)
                else ($md | index($r.id)) != null end) }
          | { id, section, title, detail, saves, target, value, applied, risk }
        ] as $rules
        | { generatedAt: $gen,
            needsSudo: $sudo,
            settingsPath: $sp,
            rulesPath: $rp,
            appliedCount: ([$rules[] | select(.applied)] | length),
            totalCount: ($rules | length),
            error: $err,
            rules: $rules }'
}

verb=${1:-status}
id=${2:-}

case "$verb" in
    status)
        ;;
    apply)
        if ! rule_exists "$id"; then ERR="unknown rule $id"
        elif ! do_apply "$id"; then ERR="could not write $id"; fi
        ;;
    revert)
        if ! rule_exists "$id"; then ERR="unknown rule $id"
        elif ! do_revert "$id"; then ERR="could not write $id"; fi
        ;;
    apply-all)
        for r in $(printf '%s' "$CATALOGUE" | jq -r '.[].id'); do
            do_apply "$r" || ERR="could not write $r"
        done
        ;;
    *)
        ERR="unknown command $verb"
        ;;
esac

status 2>/dev/null || printf '%s\n' "$EMPTY"
