#!/bin/sh
# Emits ONE JSON object describing a SINGLE Claude Code session in depth:
# recent tool calls, spawned subagents, prompt queue, token economics, edited
# files and git state.
#
# Unlike claude-status.sh this reads the whole transcript, so it is only run on
# demand while a row is expanded, refreshed every ~5s. A full scan of the
# largest transcript on this machine (22MB / 5127 lines) costs ~0.2s, which is
# cheap enough that no incremental-offset cache is worth its own bug surface.
#
# Same contract as the status script: always exit 0, always print one valid
# object with every field present, and never derive anything from the current
# clock -- only instants are emitted, so an unchanged session serialises
# identically on every refresh and the consumer can skip the rebuild.

sid="$1"
CDIR="${CLAUDE_HOME:-$HOME/.claude}"

# The id is interpolated into a path, so anything outside the uuid alphabet is
# rejected rather than escaped.
case "$sid" in
    ''|*[!A-Za-z0-9._-]*) sid='' ;;
esac

EMPTY=$(printf '{"sessionId":"%s","activity":[],"subagents":[],"prompt":{"last":"","queue":[]},"economics":{"input":0,"output":0,"thinking":0,"cacheRead":0,"cacheWrite5m":0,"cacheWrite1h":0,"turns":0,"tools":0,"cost":0,"subagentCost":0,"growthPerTurn":0,"turnsToLimit":0},"files":[],"git":{"repo":false,"branch":"","dirty":0,"ahead":0,"behind":0}}' "$sid")

[ -n "$sid" ] || { printf '%s\n' "$EMPTY"; exit 0; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' "$EMPTY"; exit 0; }

TR=''
for d in "$CDIR"/projects/*/; do
    [ -f "$d$sid.jsonl" ] || continue
    TR="$d$sid.jsonl"
    break
done
[ -n "$TR" ] || { printf '%s\n' "$EMPTY"; exit 0; }

# Shared helpers. fromdateiso8601 rejects fractional seconds, so the fraction is
# stripped for the seconds part and re-added as milliseconds -- tool durations
# are routinely under a second, and rounding them all to 0s would make the
# activity feed useless.
PRE='def num: if type == "number" then . else 0 end;
def clip($n): if type == "string"
        then (if length > $n then .[0:$n] + "…" else . end) else "" end;
def epochms:
    if type == "string" and . != "" then
        (try (((sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) * 1000)
              + (try (capture("\\.(?<f>[0-9]{3})Z$") | .f | tonumber) catch 0))
         catch 0)
    else 0 end;
def rate($m):
    ($m | sub("\\[1m\\]$"; "")) as $k
    | if   ($k | test("fable"))      then {i: 10, o: 50}
      elif ($k | test("opus"))       then {i: 5,  o: 25}
      elif ($k | test("sonnet-4-6")) then {i: 3,  o: 15}
      elif ($k | test("sonnet"))     then {i: 2,  o: 10}
      elif ($k | test("haiku"))      then {i: 1,  o: 5}
      else {i: 5, o: 25} end;
def spend($u; $r):
    ((($u.input_tokens | num) * $r.i
      + ($u.output_tokens | num) * $r.o
      + ($u.cache_read_input_tokens | num) * $r.i * 0.1
      + ($u.cache_creation.ephemeral_5m_input_tokens | num) * $r.i * 1.25
      + ($u.cache_creation.ephemeral_1h_input_tokens | num) * $r.i * 2) / 1000000);
def r2: (. * 100 | round) / 100;
'

# --- main transcript ---------------------------------------------------------
# One reduce collects everything: usage totals, the tool_use/tool_result pairing
# that yields durations, edited files, the prompt queue and a rolling window of
# context sizes for the growth estimate. message.content is a bare string on
# text-only turns, so every walk into it is type-guarded -- an unguarded index
# aborts the whole reduce and the panel would show nothing at all.
SCAN=$(jq -n -c "$PRE"'
    reduce inputs as $l (
        { inp: 0, out: 0, think: 0, cr: 0, cw5: 0, cw1: 0, turns: 0, tools: 0,
          cost: 0, tu: {}, ord: [], files: {}, queue: [], prompt: "",
          model: "", cwd: "", ctx: [] };
        if $l.type == "assistant" then
              ($l.message.usage // {}) as $u
            | rate($l.message.model // "") as $r
            | .turns += 1
            | .model = ($l.message.model // .model)
            | .cwd = ($l.cwd // .cwd)
            | .inp   += ($u.input_tokens | num)
            | .out   += ($u.output_tokens | num)
            | .think += ($u.output_tokens_details.thinking_tokens | num)
            | .cr    += ($u.cache_read_input_tokens | num)
            | .cw5   += ($u.cache_creation.ephemeral_5m_input_tokens | num)
            | .cw1   += ($u.cache_creation.ephemeral_1h_input_tokens | num)
            | .cost  += spend($u; $r)
            | .ctx = ((.ctx + [(($u.input_tokens | num)
                                + ($u.cache_creation_input_tokens | num)
                                + ($u.cache_read_input_tokens | num))])[-11:])
            | (if ($l.message.content | type) == "array" then
                  reduce ($l.message.content[] | select(.type == "tool_use")) as $t (.;
                      (if (($t.input // null) | type) == "object" then $t.input else {} end) as $i
                    | .tools += 1
                    | .ord += [$t.id]
                    | .tu[$t.id] = {
                        name: ($t.name // ""),
                        target: (($i.description // $i.file_path // $i.command
                                  // $i.pattern // $i.url // $i.query
                                  // $i.prompt // "") | clip(70)),
                        at: ($l.timestamp // ""),
                        done: ""
                      }
                    | (if (($t.name // "") | IN("Edit", "Write", "NotebookEdit", "MultiEdit"))
                       then (($i.file_path // $i.notebook_path // "") | tostring) as $fp
                            | if $fp == "" then .
                              else .files[$fp] = {
                                     n: (((.files[$fp].n) // 0) + 1),
                                     at: ($l.timestamp // "")
                                   }
                              end
                       else . end))
               else . end)
        elif $l.type == "user" then
              .cwd = ($l.cwd // .cwd)
            | (if ($l.message.content | type) == "array" then
                  reduce ($l.message.content[] | select(.type == "tool_result")) as $t (.;
                      ($t.tool_use_id // "") as $k
                    | if $k != "" and (.tu | has($k))
                      then .tu[$k].done = ($l.timestamp // "") else . end)
               else . end)
        elif $l.type == "last-prompt" then .prompt = ($l.lastPrompt | clip(400))
        elif $l.type == "queue-operation" then
              (($l.content // "") | tostring) as $c
            # Task notifications are enqueued through the same channel as real
            # user prompts; they are the agent framework talking to itself and
            # have no business showing up as a backlog item.
            | if $l.operation == "enqueue" then
                  (if ($c | startswith("<task-notification>")) then .
                   else .queue += [{content: ($c | clip(200)), at: ($l.timestamp // "")}] end)
              elif $l.operation == "remove" then
                  .queue = (.queue | map(select(.content != ($c | clip(200)))))
              elif $l.operation == "dequeue" then .queue = (.queue[1:])
              else . end
        else . end)
    | . as $a
    | ($a.ctx | length) as $cn
    | (if $cn > 2 then ((($a.ctx[-1] - $a.ctx[0]) / ($cn - 1)) | floor) else 0 end) as $g
    | (($a.ctx[-1] // 0)) as $cur
    | (if ($a.model | test("\\[1m\\]")) or $cur > 200000 then 1000000 else 200000 end) as $lim
    | {
        cwd: $a.cwd,
        activity: ($a.ord[-8:] | reverse
          | map($a.tu[.]) | map(select(. != null))
          | map({
              name, target, at,
              durationMs: (if .done != "" and .at != ""
                           then ((.done | epochms) - (.at | epochms)) else 0 end),
              running: (.done == "")
            })),
        prompt: { last: $a.prompt, queue: $a.queue },
        economics: {
          input: $a.inp, output: $a.out, thinking: $a.think,
          cacheRead: $a.cr, cacheWrite5m: $a.cw5, cacheWrite1h: $a.cw1,
          turns: $a.turns, tools: $a.tools,
          cost: ($a.cost | r2),
          subagentCost: 0,
          growthPerTurn: (if $g > 0 then $g else 0 end),
          turnsToLimit: (if $g > 0 and $lim > $cur then (($lim - $cur) / $g | floor) else 0 end)
        },
        files: ($a.files | to_entries
          | map({path: .key, edits: (.value.n | num), at: (.value.at // "")})
          | sort_by(.at) | reverse | .[0:10] | map({path, edits}))
      }' -- "$TR" 2>/dev/null) || SCAN=''
[ -n "$SCAN" ] || SCAN='null'

# --- subagents ---------------------------------------------------------------
# A background agent's tool_result lands immediately ("Async agent launched
# successfully"), so a pending tool_use is NOT a liveness test. The parent
# transcript only mentions <task-id>ID</task-id> once the agent has reported
# back, which makes the id's absence the running test.
SUBS='[]'
sdir="${TR%.jsonl}/subagents"
if [ -d "$sdir" ]; then
    set --
    for mf in "$sdir"/agent-*.meta.json; do
        [ -f "$mf" ] && set -- "$@" "$mf"
    done
    if [ "$#" -gt 0 ]; then
        # The meta files carry no id of their own -- it is only in the filename,
        # hence input_filename. They are a few hundred bytes each, so slurping
        # all of them is free; their transcripts are not and are handled below.
        META=$(jq -n -c '
            reduce inputs as $m ({};
                (input_filename | split("/") | last
                 | ltrimstr("agent-") | rtrimstr(".meta.json")) as $id
                | .[$id] = {
                    agentType: ($m.agentType // ""),
                    description: ($m.description // ""),
                    spawnDepth: (if ($m.spawnDepth | type) == "number" then $m.spawnDepth else 0 end)
                  })' -- "$@" 2>/dev/null) || META='{}'
        [ -n "$META" ] || META='{}'

        fin=$(grep -oE '<task-id>[A-Za-z0-9_-]+</task-id>' -- "$TR" 2>/dev/null \
              | sed 's/<task-id>//; s|</task-id>||' | sort -u \
              | jq -R -s -c 'split("\n") | map(select(. != ""))' 2>/dev/null)
        [ -n "$fin" ] || fin='[]'

        # An agent orphaned by a crashed session is never mentioned in a task
        # notification, so the id test alone would call it running forever. A
        # transcript untouched for fifteen minutes is treated as abandoned:
        # long enough that a genuinely slow agent -- a build, a wide search --
        # is never mistaken for dead, short enough that a ghost row does not
        # outlive the session that spawned it.
        now=$(date +%s)
        stale=""
        for jf in "$sdir"/agent-*.jsonl; do
            [ -f "$jf" ] || continue
            mt=$(stat -c %Y -- "$jf" 2>/dev/null) || continue
            case "$mt" in ''|*[!0-9]*) continue ;; esac
            [ "$((now - mt))" -gt 900 ] || continue
            b=${jf##*/}
            b=${b#agent-}
            stale="$stale${b%.jsonl}
"
        done
        STALE=$(printf '%s' "$stale" | jq -R -s -c 'split("\n") | map(select(. != ""))' 2>/dev/null)
        [ -n "$STALE" ] || STALE='[]'

        # One busy session accumulated 73 agents / 61MB of sidechain transcript,
        # where a plain jq pass costs ~0.4s on its own. Every line an agent
        # writes carries .agentId, so grep can throw away the ~65% of bytes that
        # are tool_result envelopes before jq parses anything, and the usage
        # totals still come out exact. lastAt is therefore the agent's last
        # model turn rather than its last line -- at most one tool call stale,
        # which is invisible next to a 5s refresh.
        set --
        for jf in "$sdir"/agent-*.jsonl; do
            [ -f "$jf" ] && set -- "$@" "$jf"
        done
        if [ "$#" -gt 0 ]; then
            AGSCAN=$(grep -h '"type":"assistant"' -- "$@" 2>/dev/null \
                | jq -n -c "$PRE"'
                reduce inputs as $l ({};
                    ($l.agentId // "") as $id
                    | if $id == "" then .
                      else
                          ($l.message.usage // {}) as $u
                        | rate($l.message.model // "") as $r
                        | .[$id].model = (($l.message.model // "") | sub("\\[1m\\]$"; ""))
                        | .[$id].outputTokens = ((.[$id].outputTokens // 0) + ($u.output_tokens | num))
                        | .[$id].cost = ((.[$id].cost // 0) + spend($u; $r))
                        | .[$id].startedAt = (.[$id].startedAt // ($l.timestamp // ""))
                        | .[$id].lastAt = ($l.timestamp // (.[$id].lastAt // ""))
                        | .[$id].tools = ((.[$id].tools // 0)
                            + (if ($l.message.content | type) == "array"
                               then ([$l.message.content[] | select(.type == "tool_use")] | length)
                               else 0 end))
                      end)' 2>/dev/null) || AGSCAN='{}'
            [ -n "$AGSCAN" ] || AGSCAN='{}'
        else
            AGSCAN='{}'
        fi

        SUBS=$(jq -n -c --argjson meta "$META" --argjson scan "$AGSCAN" \
            --argjson fin "$fin" --argjson stale "$STALE" '
            def num: if type == "number" then . else 0 end;
            def r2: (. * 100 | round) / 100;
            $meta | to_entries
            | map(.key as $id | ($scan[$id] // {}) as $s | {
                id: $id,
                agentType: .value.agentType,
                description: .value.description,
                model: ($s.model // ""),
                spawnDepth: (.value.spawnDepth | num),
                running: ((([$id] - $fin) | length) == 1
                          and (([$id] - $stale) | length) == 1),
                startedAt: ($s.startedAt // ""),
                lastAt: ($s.lastAt // ""),
                tools: ($s.tools | num),
                outputTokens: ($s.outputTokens | num),
                cost: (($s.cost | num) | r2)
              })
            # Running agents first because they are the reason to look at this
            # section at all; within each group newest last-activity wins.
            | (map(select(.running))       | sort_by(.lastAt) | reverse)
            + (map(select(.running | not)) | sort_by(.lastAt) | reverse)' 2>/dev/null) || SUBS='[]'
        [ -n "$SUBS" ] || SUBS='[]'
    fi
fi

# --- git ---------------------------------------------------------------------
GIT='{"repo":false,"branch":"","dirty":0,"ahead":0,"behind":0}'
cwd=$(printf '%s' "$SCAN" | jq -r 'if type == "object" then (.cwd // "") else "" end' 2>/dev/null)
if [ -n "$cwd" ] && [ -d "$cwd" ] && command -v git >/dev/null 2>&1 \
   && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    br=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l)
    # No upstream (a fresh branch) is normal, not an error -- both counts stay 0.
    ab=$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
    behind=$(printf '%s' "$ab" | awk '{ print $1 + 0; exit } END { }')
    ahead=$(printf '%s' "$ab" | awk '{ print $2 + 0; exit } END { }')
    GIT=$(jq -n -c --arg b "$br" --argjson d "${dirty:-0}" \
        --argjson a "${ahead:-0}" --argjson e "${behind:-0}" \
        '{repo: true, branch: $b, dirty: $d, ahead: $a, behind: $e}' 2>/dev/null) \
        || GIT='{"repo":true,"branch":"","dirty":0,"ahead":0,"behind":0}'
fi

# --- assemble ----------------------------------------------------------------
jq -n -c --arg sid "$sid" --argjson scan "$SCAN" --argjson subs "$SUBS" \
    --argjson git "$GIT" '
    def num: if type == "number" then . else 0 end;
    def r2: (. * 100 | round) / 100;
    ($scan // {}) as $s
    | {
        sessionId: $sid,
        activity: ($s.activity // []),
        subagents: $subs,
        prompt: ($s.prompt // {last: "", queue: []}),
        economics: (($s.economics // {
            input: 0, output: 0, thinking: 0, cacheRead: 0, cacheWrite5m: 0,
            cacheWrite1h: 0, turns: 0, tools: 0, cost: 0, subagentCost: 0,
            growthPerTurn: 0, turnsToLimit: 0
          }) + { subagentCost: (($subs | map(.cost | num) | add // 0) | r2) }),
        files: ($s.files // []),
        git: $git
      }' 2>/dev/null || printf '%s\n' "$EMPTY"
