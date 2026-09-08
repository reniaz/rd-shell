#!/bin/sh
# Emits ONE JSON object describing every Claude Code session this account has
# ever recorded -- lifetime spend, per-project and per-model breakdowns, a daily
# series, tool and time-of-day histograms, and the most expensive sessions.
#
# claude-status.sh answers "what is happening now" from small state files.
# This answers "what has happened, ever", and the only source for that is
# ~/.claude/projects/**/*.jsonl -- 211MB and 495 files on this machine. A full
# parse costs seconds, so the work is cached per FILE and keyed on (mtime,size):
# a refresh after one active session re-reads one transcript, not the corpus.
#
# Cost is taken from the CLI's own accounting where it exists. Every transcript
# carries periodic {"type":"cost-state"} lines whose totalCostUSD is exactly the
# figure /cost prints; the last one in the file is the session's final bill.
# Only ~11% of transcripts have them (older CLI releases wrote none), so the
# per-day and per-model breakdowns are always derived from token counts and
# published prices, and then scaled so they sum to the authoritative total
# wherever there is one. One code path, exact totals, consistent parts.
#
# Same contract as its siblings: always exit 0, always print one valid object
# with every field present.

CDIR="${CLAUDE_HOME:-$HOME/.claude}"
PROJ="$CDIR/projects"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qs-bar"
INDEX="$CACHE_DIR/claude-global-index.json"

EMPTY='{"generatedAt":"","scanned":0,"files":0,"totals":{"cost":0,"exactCost":0,"derivedCost":0,"exactSessions":0,"sessions":0,"projects":0,"turns":0,"tools":0,"prompts":0,"input":0,"output":0,"thinking":0,"cacheRead":0,"cacheWrite":0,"tokens":0,"linesAdded":0,"linesRemoved":0,"apiMs":0,"toolMs":0,"wallMs":0,"subagents":0,"subagentCost":0,"webSearches":0,"firstDay":"","lastDay":"","activeDays":0},"projects":[],"models":[],"days":[],"hours":[],"weekdays":[],"tools":[],"sessions":[]}'

command -v jq >/dev/null 2>&1 || { printf '%s\n' "$EMPTY"; exit 0; }
[ -d "$PROJ" ] || { printf '%s\n' "$EMPTY"; exit 0; }
mkdir -p "$CACHE_DIR" 2>/dev/null || { printf '%s\n' "$EMPTY"; exit 0; }

# Local rather than UTC: an hour-of-day histogram drawn in UTC answers a
# question nobody asked. Seconds east of Greenwich, so a line's local wall
# clock is (epoch + $TZOFF).
tzs=$(date +%z 2>/dev/null)
case "$tzs" in
    [-+][0-9][0-9][0-9][0-9])
        th=$(printf '%s' "$tzs" | cut -c2-3)
        tm=$(printf '%s' "$tzs" | cut -c4-5)
        TZOFF=$(( (${th#0} * 3600) + (${tm#0} * 60) ))
        [ "${tzs%????}" = "-" ] && TZOFF=$(( -TZOFF ))
        ;;
    *) TZOFF=0 ;;
esac

# --- what is on disk ---------------------------------------------------------
# One find, emitting the identity of every transcript: its path, and the
# (mtime,size) pair that says whether the cached parse of it is still good.
# Subagent sidechains live under <transcript>/subagents/ and are picked up by
# the same glob, then attributed back to the session that spawned them.
# Both of these are megabytes on a corpus this size, so they travel through
# files. Passing them as --argjson strings overruns the exec argument limit and
# jq is never reached at all -- which fails silently, since the merge that would
# have consumed them is the thing that did not run.
WANTF="$CACHE_DIR/.want.$$"
NEWF="$CACHE_DIR/.new.$$"
trap 'rm -f "$WANTF" "$NEWF" "$INDEX.$$"' EXIT INT TERM

find "$PROJ" -name '*.jsonl' -type f -printf '{"path":"%p","mtime":%T@,"size":%s}\n' 2>/dev/null \
    | jq -s -c 'map(.mtime |= floor)' > "$WANTF" 2>/dev/null
[ -s "$WANTF" ] || printf '[]' > "$WANTF"

# A truncated or corrupt index would make every later pass fail identically, so
# it is validated once and thrown away rather than nursed.
jq -e 'type == "object"' "$INDEX" >/dev/null 2>&1 || printf '{}' > "$INDEX" 2>/dev/null

# --- which of them the cache no longer describes ------------------------------
STALE=$(jq -r --slurpfile want "$WANTF" '
    . as $idx
    | $want[0][]
    | select(($idx[.path].mtime // -1) != .mtime or ($idx[.path].size // -1) != .size)
    | .path' "$INDEX" 2>/dev/null)

scanned=0
if [ -n "$STALE" ]; then
    scanned=$(printf '%s\n' "$STALE" | wc -l)

    # Everything stale is parsed by ONE jq, attributing each line to the file it
    # arrived from. Per-file rather than per-session because that is the unit
    # the mtime test works on: a session whose subagent wrote one line must not
    # drag its 22MB parent transcript back through the parser.
    #
    # Prices are dollars per million tokens, matching claude-session.sh. Cache
    # reads bill at a tenth of input, five-minute writes at 1.25x and one-hour
    # writes at 2x, which is how the published table reads.
    SCANQ='
        def num: if type == "number" then . else 0 end;
        def clip($n): if type == "string"
                then (if length > $n then .[0:$n] + "…" else . end) else "" end;
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
        # fromdateiso8601 rejects the fractional second every transcript writes.
        def epoch:
            if type == "string" and . != ""
            then (try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0)
            else 0 end;

        reduce inputs as $l ({};
            # $fname is set only on the per-file retry below, which feeds jq
            # through a pipe -- input_filename is null there and every record
            # would collapse onto one null key.
            (if $fname != "" then $fname else input_filename end) as $f
            | if $l.type == "assistant" then
                  ($l.message.usage // {}) as $u
                | (($l.message.model // "") | sub("\\[1m\\]$"; "")) as $m
                | rate($l.message.model // "") as $r
                | spend($u; $r) as $c
                | (($l.timestamp // "") | epoch) as $t
                | (if $t > 0 then (($t + $tz) | strftime("%Y-%m-%d")) else "" end) as $day
                | (if $t > 0 then (($t + $tz) | strftime("%H") | tonumber) else -1 end) as $hr
                | (if $t > 0 then (($t + $tz) | strftime("%w") | tonumber) else -1 end) as $wd
                | (($u.input_tokens | num) + ($u.output_tokens | num)
                   + ($u.cache_read_input_tokens | num)
                   + ($u.cache_creation_input_tokens | num)) as $tok
                | .[$f].turns   = ((.[$f].turns // 0) + 1)
                | .[$f].cost    = ((.[$f].cost // 0) + $c)
                | .[$f].input   = ((.[$f].input // 0) + ($u.input_tokens | num))
                | .[$f].output  = ((.[$f].output // 0) + ($u.output_tokens | num))
                | .[$f].think   = ((.[$f].think // 0) + ($u.output_tokens_details.thinking_tokens | num))
                | .[$f].cr      = ((.[$f].cr // 0) + ($u.cache_read_input_tokens | num))
                | .[$f].cw      = ((.[$f].cw // 0) + ($u.cache_creation_input_tokens | num))
                | .[$f].web     = ((.[$f].web // 0) + ($u.server_tool_use.web_search_requests | num))
                | .[$f].model   = (if $m != "" and $m != "<synthetic>" then $m else (.[$f].model // "") end)
                | (if $m != "" and $m != "<synthetic>" then
                       .[$f].models[$m].cost   = ((.[$f].models[$m].cost // 0) + $c)
                     | .[$f].models[$m].turns  = ((.[$f].models[$m].turns // 0) + 1)
                     | .[$f].models[$m].input  = ((.[$f].models[$m].input // 0) + ($u.input_tokens | num))
                     | .[$f].models[$m].output = ((.[$f].models[$m].output // 0) + ($u.output_tokens | num))
                     | .[$f].models[$m].think  = ((.[$f].models[$m].think // 0) + ($u.output_tokens_details.thinking_tokens | num))
                     | .[$f].models[$m].cr     = ((.[$f].models[$m].cr // 0) + ($u.cache_read_input_tokens | num))
                     | .[$f].models[$m].cw     = ((.[$f].models[$m].cw // 0) + ($u.cache_creation_input_tokens | num))
                   else . end)
                | (if $day != "" then
                       .[$f].days[$day].cost   = ((.[$f].days[$day].cost // 0) + $c)
                     | .[$f].days[$day].turns  = ((.[$f].days[$day].turns // 0) + 1)
                     | .[$f].days[$day].tokens = ((.[$f].days[$day].tokens // 0) + $tok)
                     | .[$f].days[$day].output = ((.[$f].days[$day].output // 0) + ($u.output_tokens | num))
                   else . end)
                | (if $hr >= 0 then
                       .[$f].hours[$hr | tostring].turns = ((.[$f].hours[$hr | tostring].turns // 0) + 1)
                     | .[$f].hours[$hr | tostring].cost  = ((.[$f].hours[$hr | tostring].cost // 0) + $c)
                   else . end)
                | (if $wd >= 0 then
                       .[$f].wdays[$wd | tostring].turns = ((.[$f].wdays[$wd | tostring].turns // 0) + 1)
                     | .[$f].wdays[$wd | tostring].cost  = ((.[$f].wdays[$wd | tostring].cost // 0) + $c)
                   else . end)
                | (if $t > 0 then
                       .[$f].start = (if (.[$f].start // 0) == 0 then $t else ([.[$f].start, $t] | min) end)
                     | .[$f].end   = ([(.[$f].end // 0), $t] | max)
                   else . end)
                | (if ($l.agentId // "") != ""
                   then .[$f].agents[$l.agentId] = 1 | .[$f].sidechain = true
                   else . end)
                # message.content is a bare string on text-only turns, so every
                # walk into it is type-guarded: an unguarded index aborts the
                # whole reduce and the file would contribute nothing at all.
                | (if ($l.message.content | type) == "array" then
                      reduce ($l.message.content[] | select(.type == "tool_use")) as $x (.;
                          (($x.name // "") | tostring) as $n
                        | .[$f].tools = ((.[$f].tools // 0) + 1)
                        | if $n == "" then . else .[$f].byTool[$n] = ((.[$f].byTool[$n] // 0) + 1) end)
                   else . end)
              elif $l.type == "cost-state" then
                  # The CLI'"'"'s own ledger. Written repeatedly and monotonically,
                  # so the last one seen is the session'"'"'s final bill.
                    .[$f].exact  = ($l.totalCostUSD | num)
                  | .[$f].added  = ($l.totalLinesAdded | num)
                  | .[$f].removed = ($l.totalLinesRemoved | num)
                  | .[$f].apiMs  = ($l.totalAPIDuration | num)
                  | .[$f].toolMs = ($l.totalToolDuration | num)
                  | .[$f].wallMs = ($l.totalDuration | num)
              elif $l.type == "ai-title" then .[$f].title = (($l.aiTitle // "") | clip(70))
              elif $l.type == "last-prompt" then .[$f].prompts = ((.[$f].prompts // 0) + 1)
              elif $l.type == "user" then
                    .[$f].cwd = ($l.cwd // .[$f].cwd)
                  | (if ($l.agentId // "") != "" then .[$f].sidechain = true else . end)
              else . end)
        | to_entries
        | map({
            path: .key,
            turns: (.value.turns | num), tools: (.value.tools | num),
            prompts: (.value.prompts | num),
            cost: (.value.cost | num),
            exact: (.value.exact | num), hasExact: ((.value.exact // null) != null),
            input: (.value.input | num), output: (.value.output | num),
            think: (.value.think | num), cr: (.value.cr | num), cw: (.value.cw | num),
            web: (.value.web | num),
            added: (.value.added | num), removed: (.value.removed | num),
            apiMs: (.value.apiMs | num), toolMs: (.value.toolMs | num),
            wallMs: (.value.wallMs | num),
            agents: ((.value.agents // {}) | length),
            sidechain: (.value.sidechain // false),
            start: (.value.start | num), end: (.value.end | num),
            model: (.value.model // ""), title: (.value.title // ""),
            cwd: (.value.cwd // ""),
            models: (.value.models // {}), days: (.value.days // {}),
            hours: (.value.hours // {}), wdays: (.value.wdays // {}),
            byTool: (.value.byTool // {})
          })
        | map({(.path): .}) | add // {}'

    # xargs splits an over-long argument list into several jq runs, each of which
    # prints its own object, so the result is always slurped and added.
    printf '%s\n' "$STALE" | tr '\n' '\0' \
        | xargs -0 -r jq -n -c --argjson tz "$TZOFF" --arg fname '' "$SCANQ" 2>/dev/null \
        | jq -s -c 'add // {}' > "$NEWF" 2>/dev/null

    # A transcript whose final line is half written -- the normal state of any
    # session that is running right now -- makes jq abort, and one such file in
    # the batch would otherwise cost every other file in it. The retry pays one
    # process per file to lose only the file that is genuinely unreadable, and
    # even that one gets a second chance without its last line.
    if [ ! -s "$NEWF" ] || [ "$(cat "$NEWF")" = "{}" ]; then
        : > "$NEWF.parts"
        printf '%s\n' "$STALE" | while IFS= read -r f; do
            [ -n "$f" ] || continue
            jq -n -c --argjson tz "$TZOFF" --arg fname '' "$SCANQ" -- "$f" >> "$NEWF.parts" 2>/dev/null \
                || sed '$d' -- "$f" 2>/dev/null \
                   | jq -n -c --argjson tz "$TZOFF" --arg fname "$f" "$SCANQ" >> "$NEWF.parts" 2>/dev/null \
                || true
        done
        jq -s -c 'add // {}' "$NEWF.parts" > "$NEWF" 2>/dev/null
        rm -f "$NEWF.parts" 2>/dev/null
    fi
    [ -s "$NEWF" ] || printf '{}' > "$NEWF"

    # Files that vanished drop out here rather than lingering in the index for
    # ever: the merge is rebuilt from `want`, not from the old index'"'"'s keys.
    tmp="$INDEX.$$"
    jq -c --slurpfile want "$WANTF" --slurpfile new "$NEWF" '
        . as $old
        | ($new | add // {}) as $n
        | reduce $want[0][] as $w ({};
            .[$w.path] = (($n[$w.path] // $old[$w.path] // {})
                          + {mtime: $w.mtime, size: $w.size}))' "$INDEX" > "$tmp" 2>/dev/null \
        && [ -s "$tmp" ] && mv -f "$tmp" "$INDEX"
    rm -f "$tmp" 2>/dev/null
fi

# --- aggregate ---------------------------------------------------------------
# Everything below reads the index only, so a refresh with nothing stale costs
# one jq pass over a few hundred small records.
jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson scanned "$scanned" '
    def num: if type == "number" then . else 0 end;
    def r2: ((. | num) * 100 | round) / 100;
    def r4: ((. | num) * 10000 | round) / 10000;
    def addmaps: reduce .[] as $m ({}; reduce ($m | to_entries[]) as $e (.;
        .[$e.key] = ((.[$e.key] // 0) + ($e.value | num))));
    # Two-level maps (model or day keyed, each holding several counters).
    def addmaps2: reduce .[] as $m ({}; reduce ($m | to_entries[]) as $e (.;
        .[$e.key] = reduce ($e.value | to_entries[]) as $f ((.[$e.key] // {});
            .[$f.key] = ((.[$f.key] // 0) + ($f.value | num)))));

    to_entries
    | map(.value + {path: .key})
    | map(select((.turns | num) > 0 or (.hasExact // false)))

    # A sidechain belongs to the session that spawned it: its transcript sits at
    # <project>/<sessionId>/subagents/agent-*.jsonl, so the owning id is two
    # path components up. Main transcripts key on their own file name.
    | map(. + {
        sid: (if (.sidechain // false)
              then (.path | split("/") | .[-3])
              else (.path | split("/") | last | sub("\\.jsonl$"; "")) end),
        proj: (if (.sidechain // false)
               then (.path | split("/") | .[-4])
               else (.path | split("/") | .[-2]) end)
      })
    | . as $files

    # One record per session: the main transcript plus every sidechain it owns.
    | ($files | group_by(.sid) | map(
        . as $g
        | ($g | map(select((.sidechain // false) | not)) | first) as $main
        | ($g | map(.cost | num) | add // 0) as $derived
        | (($main.exact // 0) | num) as $exact
        | (($main.hasExact // false) and $exact > 0) as $isExact
        | (if $isExact and $derived > 0 then ($exact / $derived) else 1 end) as $k
        | {
            sid: $g[0].sid,
            project: ($main.proj // $g[0].proj),
            cwd: (($g | map(.cwd // "") | map(select(. != "")) | first) // ""),
            title: ($main.title // ""),
            model: ($main.model // ($g[0].model // "")),
            exact: $isExact,
            cost: (if $isExact then $exact else $derived end),
            scale: $k,
            derived: $derived,
            subagentCost: (($g | map(select(.sidechain // false) | .cost | num) | add // 0) * $k),
            subagents: ($g | map(.agents | num) | add // 0),
            turns: ($g | map(.turns | num) | add // 0),
            tools: ($g | map(.tools | num) | add // 0),
            prompts: ($g | map(.prompts | num) | add // 0),
            input: ($g | map(.input | num) | add // 0),
            output: ($g | map(.output | num) | add // 0),
            think: ($g | map(.think | num) | add // 0),
            cr: ($g | map(.cr | num) | add // 0),
            cw: ($g | map(.cw | num) | add // 0),
            web: ($g | map(.web | num) | add // 0),
            added: (($main.added // 0) | num),
            removed: (($main.removed // 0) | num),
            apiMs: (($main.apiMs // 0) | num),
            toolMs: (($main.toolMs // 0) | num),
            wallMs: (($main.wallMs // 0) | num),
            start: ($g | map(.start | num) | map(select(. > 0)) | min // 0),
            end: ($g | map(.end | num) | max // 0),
            byTool: ($g | map(.byTool // {}) | addmaps),
            hours: ($g | map(.hours // {}) | addmaps2),
            wdays: ($g | map(.wdays // {}) | addmaps2),
            # Every derived money figure is scaled onto the authoritative total,
            # so the parts of a session always sum to the whole it is billed at.
            models: ($g | map(.models // {}) | addmaps2
                     | with_entries(.value.cost = ((.value.cost | num) * $k))),
            days: ($g | map(.days // {}) | addmaps2
                   | with_entries(.value.cost = ((.value.cost | num) * $k)))
          })) as $sess

    | ($sess | map(.days | to_entries[]) | group_by(.key) | map({
          date: .[0].key,
          cost: (map(.value.cost | num) | add // 0),
          turns: (map(.value.turns | num) | add // 0),
          tokens: (map(.value.tokens | num) | add // 0),
          output: (map(.value.output | num) | add // 0),
          sessions: length
        }) | sort_by(.date)) as $days

    | ($sess | map(.models | to_entries[]) | group_by(.key) | map({
          name: .[0].key,
          cost: (map(.value.cost | num) | add // 0),
          turns: (map(.value.turns | num) | add // 0),
          input: (map(.value.input | num) | add // 0),
          output: (map(.value.output | num) | add // 0),
          think: (map(.value.think | num) | add // 0),
          cacheRead: (map(.value.cr | num) | add // 0),
          cacheWrite: (map(.value.cw | num) | add // 0)
        })
        | map(. + {tokens: (.input + .output + .cacheRead + .cacheWrite)})
        | sort_by(.cost) | reverse) as $models

    | ($sess | map(.byTool | to_entries[]) | group_by(.key)
        | map({name: .[0].key, count: (map(.value | num) | add // 0)})
        | sort_by(.count) | reverse) as $tools

    | ($sess | group_by(.project) | map({
          # Named from the cwd where one was recorded, because splitting the
          # flattened directory on "-" turns coding/stac-ks into "ks".
          name: ((map(select((.cwd // "") != "")) | first | .cwd | split("/") | last)
                 // (.[0].project | ltrimstr("-") | split("-") | last)),
          dir: .[0].project,
          path: ((map(select((.cwd // "") != "")) | first | .cwd) // ""),
          cost: (map(.cost | num) | add // 0),
          sessions: length,
          turns: (map(.turns | num) | add // 0),
          tools: (map(.tools | num) | add // 0),
          prompts: (map(.prompts | num) | add // 0),
          output: (map(.output | num) | add // 0),
          tokens: (map((.input + .output + .cr + .cw) | num) | add // 0),
          subagents: (map(.subagents | num) | add // 0),
          subagentCost: (map(.subagentCost | num) | add // 0),
          added: (map(.added | num) | add // 0),
          removed: (map(.removed | num) | add // 0),
          wallMs: (map(.wallMs | num) | add // 0),
          start: (map(.start | num) | map(select(. > 0)) | min // 0),
          end: (map(.end | num) | max // 0)
        })
        | sort_by(.cost) | reverse) as $projects

    | ([range(0; 24)] | map(. as $h
        | {hour: $h,
           turns: ($sess | map(.hours[$h | tostring].turns | num) | add // 0),
           cost:  ($sess | map(.hours[$h | tostring].cost  | num) | add // 0)})) as $hours

    | ([range(0; 7)] | map(. as $d
        | {day: $d,
           turns: ($sess | map(.wdays[$d | tostring].turns | num) | add // 0),
           cost:  ($sess | map(.wdays[$d | tostring].cost  | num) | add // 0)})) as $wdays

    | ($sess | map(.cost | num) | add // 0) as $total

    | {
        generatedAt: $now,
        scanned: $scanned,
        files: ($files | length),
        totals: {
          cost: ($total | r2),
          exactCost: (($sess | map(select(.exact) | .cost | num) | add // 0) | r2),
          derivedCost: (($sess | map(select(.exact | not) | .cost | num) | add // 0) | r2),
          exactSessions: ($sess | map(select(.exact)) | length),
          sessions: ($sess | length),
          projects: ($projects | length),
          turns: ($sess | map(.turns | num) | add // 0),
          tools: ($sess | map(.tools | num) | add // 0),
          prompts: ($sess | map(.prompts | num) | add // 0),
          input: ($sess | map(.input | num) | add // 0),
          output: ($sess | map(.output | num) | add // 0),
          thinking: ($sess | map(.think | num) | add // 0),
          cacheRead: ($sess | map(.cr | num) | add // 0),
          cacheWrite: ($sess | map(.cw | num) | add // 0),
          tokens: ($sess | map((.input + .output + .cr + .cw) | num) | add // 0),
          linesAdded: ($sess | map(.added | num) | add // 0),
          linesRemoved: ($sess | map(.removed | num) | add // 0),
          apiMs: ($sess | map(.apiMs | num) | add // 0),
          toolMs: ($sess | map(.toolMs | num) | add // 0),
          wallMs: ($sess | map(.wallMs | num) | add // 0),
          subagents: ($sess | map(.subagents | num) | add // 0),
          subagentCost: (($sess | map(.subagentCost | num) | add // 0) | r2),
          webSearches: ($sess | map(.web | num) | add // 0),
          firstDay: (($days | first | .date) // ""),
          lastDay: (($days | last | .date) // ""),
          activeDays: ($days | length)
        },
        projects: ($projects | map({
            name, dir, path, sessions, turns, tools, prompts, subagents,
            added, removed, tokens, output, wallMs, start, end,
            cost: (.cost | r2),
            subagentCost: (.subagentCost | r2),
            share: (if $total > 0 then ((.cost / $total) | r4) else 0 end)
          })),
        models: ($models | map(. + {
            cost: (.cost | r2),
            share: (if $total > 0 then ((.cost / $total) | r4) else 0 end)
          })),
        days: ($days | map({date, turns, tokens, output, sessions, cost: (.cost | r2)})),
        hours: ($hours | map({hour, turns, cost: (.cost | r2)})),
        weekdays: ($wdays | map({day, turns, cost: (.cost | r2)})),
        tools: ($tools | map(. + {
            share: (($tools | map(.count) | add // 0) as $t
                    | if $t > 0 then ((.count / $t) | r4) else 0 end)
          })),
        sessions: ($sess | sort_by(.cost) | reverse | .[0:40] | map({
            id: .sid,
            project: (if (.cwd // "") != "" then (.cwd | split("/") | last)
                      else (.project | ltrimstr("-") | split("-") | last) end),
            title, model,
            exact, turns, tools, prompts, subagents, start, end,
            added, removed,
            cost: (.cost | r2),
            subagentCost: (.subagentCost | r2),
            tokens: ((.input + .output + .cr + .cw) | num),
            output: (.output | num),
            durationMs: (if .wallMs > 0 then .wallMs
                         else (if .end > .start then ((.end - .start) * 1000) else 0 end) end)
          }))
      }' "$INDEX" 2>/dev/null || printf '%s\n' "$EMPTY"
