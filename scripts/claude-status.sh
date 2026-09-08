#!/bin/sh
# Emits ONE compact JSON object describing every live Claude Code session,
# background job and the account's rate limits.
#
# Historical usage is deliberately NOT here. It used to be, read out of
# stats-cache.json and out of ~/.claude.json's per-project last*-family keys,
# and both were wrong for the question the panel was asking them: the first
# counts messages for one day, and the second describes only each project's
# most recent session. scripts/claude-global.sh answers it properly, from the
# transcripts, on a timer of its own.
#
# The bar polls this every 2s, so it reads ~/.claude state files directly:
# shelling out to the `claude` binary costs ~300ms and ~250MB RSS per poll,
# and `claude --print` would additionally cost tokens.
#
# Every section degrades to an empty array / zeroed object rather than failing,
# and the script always exits 0 -- a poller that sometimes emits nothing would
# make the widget blank out mid-glance. Every field is always present, so the
# QML side only ever has to test for emptiness, never for existence.
#
# Nothing here is derived from the current clock -- only instants are emitted
# (startedAt, statusUpdatedAt, lastActivity). An "elapsed" number computed here
# would differ on every poll, so the consumer could not tell a real change from
# the passage of time and would rebuild its session list twice a second.

CDIR="${CLAUDE_HOME:-$HOME/.claude}"
SDIR="$CDIR/sessions"
JDIR="$CDIR/jobs"
PDIR="$CDIR/plans"
SETTINGS="$CDIR/settings.json"
GLOBALF="$HOME/.claude.json"
# Written by claude-usage.sh, which polls the endpoint /usage reads. Same shape
# as .cachedUsageUtilization in $GLOBALF, and normally much fresher than it.
USAGEF="${XDG_CACHE_HOME:-$HOME/.cache}/qs-bar/claude-usage.json"

EMPTY='{"sessions":[],"jobs":[],"limits":null}'

command -v jq >/dev/null 2>&1 || { printf '%s\n' "$EMPTY"; exit 0; }

SESS='[]'
EXT='{}'
WIN='{}'
AGENTS='{}'
SPLAN='{}'

# --- live sessions -----------------------------------------------------------
# A session file is never removed when claude crashes, so /proc is the only
# reliable liveness test. Sibling <pid>.<sha256>.key files are IPC auth keys;
# the *.json glob already excludes them.
live=""
for f in "$SDIR"/*.json; do
    [ -f "$f" ] || continue
    b=${f##*/}
    pid=${b%.json}
    case "$pid" in *[!0-9]*) continue ;; esac
    [ -d "/proc/$pid" ] || continue
    live="$live $f"
done

if [ -n "$live" ]; then
    # entrypoint == "cli" is load-bearing: SDK observers (claude-mem and friends)
    # write session files too and are usually the newest one on disk, so without
    # this filter the widget tracks a transient robot instead of your terminal.
    #
    # waitingFor is the whole point of the attention sort -- a session frozen on
    # a permission prompt is indistinguishable from one thinking hard without it.
    SESS=$(jq -s -c --arg home "$HOME" 'map(
        select(.entrypoint == "cli") | {
            pid, sessionId, cwd,
            name: (.name // ""),
            status: (.status // ""),
            waitingFor: (.waitingFor // ""),
            kind: (.kind // ""),
            startedAt: (.startedAt // 0),
            updatedAt: (.updatedAt // 0),
            statusUpdatedAt: (.statusUpdatedAt // .updatedAt // 0),
            version: (.version // ""),
            project: (.cwd | split("/") | last),
            transcript: ($home + "/.claude/projects/"
                + (.cwd | gsub("[/._ ]"; "-")) + "/" + .sessionId + ".jsonl")
        })' $live 2>/dev/null) || SESS='[]'
    [ -n "$SESS" ] || SESS='[]'
fi

# "<sessionId>|<pid>|<transcript path>" per session. Neither field can contain
# "|" or a space: the project directory name has every space mangled to "-".
pairs=$(printf '%s' "$SESS" | jq -r '.[] | .sessionId + "|" + (.pid|tostring) + "|" + .transcript' 2>/dev/null)

paths=""
for pair in $pairs; do
    p=${pair##*|}
    [ -f "$p" ] && paths="$paths $p"
done

if [ -n "$paths" ]; then
    # Transcripts reach 22MB, so only the tail is ever touched. Every line
    # carries .sessionId, which is what lets one jq pass fan the merged tails
    # back out per session.
    extract='def clip($n): if type == "string"
            then (if length > $n then .[0:$n] + "…" else . end) else "" end;
        reduce inputs as $l ({};
        ($l.sessionId // "") as $s
        | if $s == "" then .
          else
            (if ($l.timestamp // null) != null and $l.timestamp > (.[$s].ts // "")
             then .[$s].ts = $l.timestamp else . end)
            | (if $l.type == "assistant" then
                  .[$s].model  = ($l.message.model // .[$s].model)
                | .[$s].usage  = ($l.message.usage // .[$s].usage)
                | .[$s].branch = ($l.gitBranch // .[$s].branch)
                | .[$s].effort = ($l.effort // .[$s].effort)
                # message.content is a bare string on text-only turns, so the
                # walk below has to be type-guarded: an unguarded index would
                # abort the whole reduce and blank every session this poll.
                | (if ($l.message.content | type) == "array" then
                      ([$l.message.content[] | select(.type == "tool_use")] | last) as $t
                      | if $t == null then .
                        else
                          (if (($t.input // null) | type) == "object"
                           then $t.input else {} end) as $i
                          | .[$s].tool = {
                              name: ($t.name // ""),
                              target: (($i.description // $i.file_path // $i.command
                                        // $i.pattern // $i.url // $i.query
                                        // $i.prompt // "") | clip(60))
                            }
                        end
                   else . end)
               else . end)
            | (if $l.type == "ai-title" then .[$s].title = $l.aiTitle else . end)
            # The permission mode moved line types between CLI releases: 2.1.260
            # writes {"type":"permission-mode","permissionMode":...} while 2.1.259
            # writes {"type":"mode","mode":...}. Both are collected here and the
            # newer one wins at assembly, otherwise older sessions render blank.
            | (if $l.type == "permission-mode" then .[$s].pmode = $l.permissionMode else . end)
            | (if $l.type == "mode" then .[$s].lmode = $l.mode else . end)
            # last-prompt is written once per turn and is far more reliable than
            # scraping user lines, which are mostly tool_result envelopes.
            | (if $l.type == "last-prompt" then .[$s].prompt = ($l.lastPrompt | clip(120)) else . end)
          end)'
    # A half-written final line aborts the whole reduce, so retry once without
    # it rather than dropping every session's detail for that poll.
    EXT=$(tail -q -n 200 $paths 2>/dev/null | jq -n -c "$extract" 2>/dev/null) \
        || EXT=$(tail -q -n 200 $paths 2>/dev/null | sed '$d' | jq -n -c "$extract" 2>/dev/null) \
        || EXT='{}'
    [ -n "$EXT" ] || EXT='{}'
fi

# --- terminal window addresses -----------------------------------------------
# Every terminal here is one Ghostty process owning several windows, so matching
# a hyprland client by pid is ambiguous. Claude Code keeps the terminal title in
# sync with the session's ai-title, which makes the title the reliable key and
# the /proc parent chain only a fallback for sessions with no title yet.
if [ -n "$pairs" ] && command -v hyprctl >/dev/null 2>&1; then
    chains=""
    for pair in $pairs; do
        sid=${pair%%|*}
        rest=${pair#*|}
        p=${rest%%|*}
        chain=" "
        hops=0
        while [ "$hops" -lt 12 ]; do
            case "$p" in ''|*[!0-9]*) break ;; esac
            [ "$p" -gt 1 ] || break
            chain="$chain$p "
            p=$(awk '/^PPid:/ { print $2; exit }' "/proc/$p/status" 2>/dev/null)
            hops=$((hops + 1))
        done
        chains="$chains$(printf '{"sid":"%s","ch":"%s"}' "$sid" "$chain")
"
    done
    CH=$(printf '%s\n' "$chains" | jq -n -c \
        'reduce inputs as $c ({}; .[$c.sid] = $c.ch)' 2>/dev/null) || CH='{}'
    [ -n "$CH" ] || CH='{}'
    # Two passes, and a window is claimed by at most one session. A terminal
    # emulator that draws every window from one process -- ghostty, kitty
    # single-instance, foot server -- reports the same pid for all of them, so
    # the parent chain alone matches every one of its windows equally and the
    # old single pass handed the same address to every session running in that
    # terminal. Title is the only per-window key there is, so titled sessions
    # claim first and the chain then only has to choose among what is left:
    # with one untitled session and one unclaimed window the answer is forced.
    WIN=$(hyprctl clients -j 2>/dev/null | jq -c \
        --argjson sess "$SESS" --argjson ext "$EXT" --argjson chains "$CH" '
        . as $cl
        | ($sess | map({
              sid: .sessionId,
              # Claude Code keeps the terminal title in sync with the session
              # ai-title, so that is the reliable key; .name is what the title
              # would be for a session too young to have one, and matches the
              # terminal only if the user set it themselves.
              t: (if (($ext[.sessionId].title // "") != "") then $ext[.sessionId].title
                  else .name end),
              chain: ($chains[.sessionId] // "")
          })) as $ss

        | def claim($st; $x; $hit):
            if $hit == null then $st
            else {win:   ($st.win   + {($x.sid): $hit.address}),
                  taken: ($st.taken + {($hit.address): true})}
            end;

          reduce $ss[] as $x ({win: {}, taken: {}};
            . as $st
            | claim($st; $x;
                ([ $cl[] | select($x.t != ""
                                  and ((.title // "") | contains($x.t))
                                  and (($st.taken[.address] // false) | not)) ]
                 | first)))
        # `|` inside select() rebinds `.`, so every client field must be bound
        # before the first pipe: select($x.chain | contains(" " + (.pid|tostring)
        # + " ")) reads .pid off a string and aborts the whole pass.
        | reduce $ss[] as $x (.;
            . as $st
            | if ($st.win[$x.sid] // "") != "" then $st
              else claim($st; $x;
                ([ $cl[] | (.address) as $a
                         | (" " + (.pid | tostring) + " ") as $p
                         | select(($x.chain | contains($p))
                                  and (($st.taken[$a] // false) | not)) ]
                 | first))
              end)
        | .win
        | . as $w
        | reduce $ss[] as $x ({}; .[$x.sid] = ($w[$x.sid] // ""))' 2>/dev/null) || WIN='{}'
    [ -n "$WIN" ] || WIN='{}'
fi

# --- plans, subagents --------------------------------------------------------
# The eight most recent plans are the candidate set; a session owns whichever of
# them its transcript mentions last. One fixed-string grep per transcript covers
# every candidate at once (70ms on the largest transcript on disk).
pfiles=$(ls -t "$PDIR"/*.md 2>/dev/null | head -8)
pnames=""
for pf in $pfiles; do
    b=${pf##*/}
    pnames="$pnames -e ${b%.md}"
done

agn_nd=""
pln_nd=""
for pair in $pairs; do
    sid=${pair%%|*}
    tp=${pair##*|}
    [ -f "$tp" ] || continue

    if [ -n "$pnames" ]; then
        pn=$(grep -oF $pnames -- "$tp" 2>/dev/null | tail -1)
        [ -n "$pn" ] && pln_nd="$pln_nd$(printf '{"sid":"%s","plan":"%s"}' "$sid" "$pn")
"
    fi

    # A background agent's tool_result lands immediately ("Async agent launched
    # successfully"), so a pending tool_use says nothing about liveness. The
    # parent transcript only mentions <task-id>ID</task-id> once that agent has
    # reported back, which makes the id's ABSENCE the running test. One grep
    # collects every finished id, then the meta files are matched against it.
    sdir="${tp%.jsonl}/subagents"
    [ -d "$sdir" ] || continue
    fin=$(grep -oE '<task-id>[A-Za-z0-9_-]+</task-id>' -- "$tp" 2>/dev/null | sort -u)
    n=0
    for mf in "$sdir"/agent-*.meta.json; do
        [ -f "$mf" ] || continue
        b=${mf##*/}
        b=${b#agent-}
        aid=${b%.meta.json}
        case "$fin" in
            *"<task-id>$aid</task-id>"*) ;;
            *) n=$((n + 1)) ;;
        esac
    done
    agn_nd="$agn_nd$(printf '{"sid":"%s","n":%d}' "$sid" "$n")
"
done
if [ -n "$agn_nd" ]; then
    AGENTS=$(printf '%s\n' "$agn_nd" | jq -n -c \
        'reduce inputs as $a ({}; .[$a.sid] = $a.n)' 2>/dev/null) || AGENTS='{}'
    [ -n "$AGENTS" ] || AGENTS='{}'
fi
if [ -n "$pln_nd" ]; then
    SPLAN=$(printf '%s\n' "$pln_nd" | jq -n -c \
        'reduce inputs as $a ({}; .[$a.sid] = $a.plan)' 2>/dev/null) || SPLAN='{}'
    [ -n "$SPLAN" ] || SPLAN='{}'
fi

# --- background jobs ---------------------------------------------------------
# Each job contributes a tag line, its state.json and the newest timeline entry;
# one jq pass then stitches the three back together in order. timeline.jsonl
# lines carry no job id of their own, hence the tag.
JOBS='[]'
jnd=""
jcount=0
for d in "$JDIR"/*/; do
    [ -f "$d/state.json" ] || continue
    jcount=$((jcount + 1))
    [ "$jcount" -gt 8 ] && break
    id=${d%/}
    id=${id##*/}
    jnd="$jnd$(printf '{"__job":"%s"}' "$id")
$(cat "$d/state.json" 2>/dev/null)
$(tail -n 1 "$d/timeline.jsonl" 2>/dev/null)
"
done
if [ -n "$jnd" ]; then
    # .at is tested before .state because timeline entries carry both.
    JOBS=$(printf '%s\n' "$jnd" | jq -n -c '
        reduce inputs as $l ({o: [], m: {}};
            if ($l.__job // null) != null then (.cur = $l.__job | .o += [$l.__job])
            elif ($l.at // null) != null then (.m[.cur] = ((.m[.cur] // {}) + {at: $l.at}))
            elif ($l.state // null) != null then (.m[.cur] = ((.m[.cur] // {}) + {
                state: $l.state,
                detail: ($l.detail // ""),
                tempo: ($l.tempo // ""),
                tasks: ($l.inFlight.tasks // 0),
                queued: ($l.inFlight.queued // 0),
                tokens: ($l.tokens // 0)
            }))
            else . end)
        | . as $a
        | [ $a.o[] | select(($a.m[.].state // null) != null)
            | {id: .} + $a.m[.] + {at: ($a.m[.].at // "")} ]' 2>/dev/null) || JOBS='[]'
    [ -n "$JOBS" ] || JOBS='[]'
fi

# --- assemble ----------------------------------------------------------------
# --slurpfile on a missing file aborts jq, so absent inputs become /dev/null,
# which slurps to [] and falls through every // default below.
[ -f "$GLOBALF" ]  || GLOBALF=/dev/null
[ -f "$SETTINGS" ] || SETTINGS=/dev/null
[ -f "$USAGEF" ]   || USAGEF=/dev/null

{
    # stat emits the record skeleton, awk adds the checkbox tallies, and the jq
    # below merges the two streams by path. A plan with no checkboxes never
    # reaches awk's output at all and simply keeps its 0/0.
    if [ -n "$pfiles" ]; then
        stat -c '{"path":"%n","mtime":%Y}' $pfiles 2>/dev/null
        awk '
            /^[[:space:]]*[-*][[:space:]]+\[[xX]\]/ { d[FILENAME]++; next }
            /^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\]/ { o[FILENAME]++; next }
            END {
                for (f in d) printf "{\"path\":\"%s\",\"done\":%d}\n", f, d[f]
                for (f in o) printf "{\"path\":\"%s\",\"open\":%d}\n", f, o[f]
            }' $pfiles 2>/dev/null
    fi
} | jq -n -c \
    --argjson sess "$SESS" \
    --argjson ext "$EXT" \
    --argjson win "$WIN" \
    --argjson agn "$AGENTS" \
    --argjson spl "$SPLAN" \
    --argjson jobs "$JOBS" \
    --slurpfile cj "$GLOBALF" \
    --slurpfile cfg "$SETTINGS" \
    --slurpfile uc "$USAGEF" '
    def num: if type == "number" then . else 0 end;
    def r2: (. * 100 | round) / 100;

    # A model id suffixed "[1m]" is the 1M-context variant. Observed usage above
    # the 200k ceiling proves the same for a session whose model differs from
    # the global setting.
    (if (($cfg[0].model // "") | test("\\[1m\\]$")) then 1000000 else 200000 end) as $baseLimit |

    # Two writers, one field. The CLI only refreshes its copy when you open
    # /usage, so it is usually the stale one -- but it is the only copy that
    # survives an expired OAuth token, which is exactly when claude-usage.sh
    # stops updating. Keeping whichever was fetched later is correct for both.
    ([$cj[0].cachedUsageUtilization, $uc[0]]
      | map(select(.utilization != null))
      | sort_by(.fetchedAtMs | num) | last // null) as $u |

    # Plans are keyed by name so a session can claim the one its transcript
    # named; a plan nobody named is simply never emitted.
    ([inputs] | group_by(.path) | map(add)
      | map({
          name: (.path | split("/") | last | sub("\\.md$"; "")),
          mtime: (.mtime | num),
          done: (.done | num),
          open: (.open | num)
        })
      | map({(.name): .}) | add // {}) as $plans |

    {
      sessions: ($sess | map(
        . as $x
        | ($ext[$x.sessionId] // {}) as $e
        | (($e.usage.input_tokens | num)
           + ($e.usage.cache_creation_input_tokens | num)
           + ($e.usage.cache_read_input_tokens | num)) as $ctx
        | {
            pid: ($x.pid | num),
            sessionId: $x.sessionId,
            name: (if ($x.name // "") != "" then $x.name else $x.project end),
            project: $x.project,
            cwd: $x.cwd,
            status: $x.status,
            waitingFor: $x.waitingFor,
            kind: $x.kind,
            startedAt: ($x.startedAt | num),
            # The instant the current status began. Deliberately taken from the
            # session file rather than hunted for in the transcript: a tool-heavy
            # turn easily outruns the 200-line tail, while this is exact, free,
            # and stable enough not to churn the consumer'"'"'s change detection.
            statusUpdatedAt: (if ($x.statusUpdatedAt | num) > 0
                              then ($x.statusUpdatedAt | num)
                              else ($x.startedAt | num) end),
            version: $x.version,
            branch: ($e.branch // ""),
            model: ($e.model // ""),
            title: ($e.title // ""),
            mode: (if ($e.pmode // "") != "" then $e.pmode else ($e.lmode // "") end),
            effort: ($e.effort // ""),
            contextTokens: $ctx,
            contextLimit: (if $ctx > 200000 then 1000000 else $baseLimit end),
            lastActivity: ($e.ts // (if ($x.updatedAt | num) > 0
                then (($x.updatedAt | num) / 1000 | todate) else "" end)),
            lastPrompt: ($e.prompt // ""),
            # The tail always holds some last tool_use, so it is only meaningful
            # while the session is actually working -- an idle session would
            # otherwise keep advertising whatever it did last.
            tool: (if $x.status == "" then {name: "", target: ""}
                   else ($e.tool // {name: "", target: ""}) end),
            window: ($win[$x.sessionId] // ""),
            subagents: ($agn[$x.sessionId] | num),
            plan: ($plans[($spl[$x.sessionId] // "")] // null)
          })
        | . as $all
        # Ordering is settled here so every consumer agrees and none re-sorts.
        # Blocked and busy rows sort by startedAt, NOT lastActivity: that field
        # moves on every poll for a working session, so rows would swap places
        # under the cursor twice a second. Idle rows are safe to sort by it
        # precisely because it has stopped moving.
        | ($all | map(select(.waitingFor != "")) | sort_by(.startedAt))
        + ($all | map(select(.waitingFor == "" and .status == "busy")) | sort_by(.startedAt))
        + ($all | map(select(.waitingFor == "" and .status != "busy"))
                | sort_by(.lastActivity) | reverse)),

      jobs: $jobs,

      limits: (if $u == null then null else ($u.utilization) as $z | {
        fiveHour: ($z.five_hour.utilization | num),
        fiveHourResets: ($z.five_hour.resets_at // ""),
        sevenDay: ($z.seven_day.utilization | num),
        sevenDayResets: ($z.seven_day.resets_at // ""),
        spend: ($z.spend.percent | num),
        spendEnabled: ($z.spend.enabled // false),
        # Money is minor units plus an exponent, never a float, so it is
        # resolved here rather than in four places in QML.
        spendUsed: ((($z.spend.used.amount_minor | num)
                     / pow(10; ($z.spend.used.exponent // 2))) ),
        spendLimit: ((($z.spend.limit.amount_minor | num)
                      / pow(10; ($z.spend.limit.exponent // 2))) ),
        spendCurrency: ($z.spend.used.currency // ""),
        # Pay-as-you-go credits, which are a separate ceiling from the plan
        # limits above and silently zero for accounts that never enabled them.
        extraEnabled: ($z.extra_usage.is_enabled // false),
        extraUsed: ($z.extra_usage.used_credits | num),
        extraLimit: ($z.extra_usage.monthly_limit | num),
        extraCurrency: ($z.extra_usage.currency // ""),
        # Every ceiling the account is actually subject to, including the
        # per-model weekly ones that only appear once a model is scoped. The
        # two named fields above stay because the pill and the header read
        # them directly; this is the full list for the Usage tab.
        buckets: (($z.limits // []) | map({
            kind: (.kind // ""),
            group: (.group // ""),
            percent: (.percent | num),
            severity: (.severity // ""),
            resets: (.resets_at // ""),
            active: (.is_active // false),
            model: (.scope.model.display_name // "")
          })),
        fetchedAtMs: ($u.fetchedAtMs | num)
      } end),

    }' 2>/dev/null || printf '%s\n' "$EMPTY"
