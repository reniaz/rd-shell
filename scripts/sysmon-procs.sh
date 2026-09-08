#!/usr/bin/env bash
# The two "what is eating this machine" lists, as one JSON line:
#   {"cpu":[{pid,name,cpu,rss}...],"mem":[...]}
#
# top and not ps because ps prints a process's CPU share averaged over its
# whole life, which for anything long-running is a number about last week. Two
# iterations 0.2s apart make the second one a live reading; both lists come out
# of that same run, so the popup pays for one sample and not two.
set -u

rows=${1:-9}

top -b -n 2 -d 0.2 -w 512 -e k 2>/dev/null | awk -v rows="$rows" '
    # Subscripts, not counters: an unset n indexes the arrays under "" and
    # leaves a hole at 0 that sorts in as a phantom process.
    BEGIN { n = 0 }

    # Everything before the second header belongs to the throwaway first pass.
    /^ *PID +USER/ { pass++; next }
    pass < 2 || NF < 12 { next }
    # The summary block that top prints between passes ("%Cpu(s): ...") is
    # wide enough to look like a task row; a numeric PID tells them apart.
    $1 !~ /^[0-9]+$/ { next }

    {
        pid[n] = $1
        cpu[n] = $9 + 0
        rss[n] = $6 + 0          # -e k pins this to KiB, suffix-free
        # COMMAND is the last field and top prints comm, not the full command
        # line, so it never contains a space to re-join.
        name[n] = $NF
        n++
    }

    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }

    function emit(order, count,   i, out) {
        out = ""
        for (i = 0; i < count && i < n; i++) {
            j = order[i]
            out = out sprintf("%s{\"pid\":%d,\"name\":\"%s\",\"cpu\":%.1f,\"rss\":%d}",
                              (i ? "," : ""), pid[j], esc(name[j]), cpu[j], rss[j] * 1024)
        }
        return out
    }

    # Selection sort over the top `rows` only: the table is ~1500 processes and
    # nine of them are wanted, so a full sort would be the expensive part of
    # this script.
    function top_by(values, out, count,   i, k, best, taken) {
        for (i = 0; i < count && i < n; i++) {
            best = -1
            for (k = 0; k < n; k++)
                if (!(k in taken) && (best < 0 || values[k] > values[best])) best = k
            if (best < 0) break
            taken[best] = 1
            out[i] = best
        }
    }

    END {
        top_by(cpu, byCpu, rows)
        top_by(rss, byMem, rows)
        printf "{\"cpu\":[%s],\"mem\":[%s]}\n", emit(byCpu, rows), emit(byMem, rows)
    }
'
