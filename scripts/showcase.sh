#!/usr/bin/env bash
# Build the r/unixporn "busy screenshot" layout: fetchit, btop and cava tiled
# on a fresh workspace, then switch there. Bound to SUPER+SHIFT+S in
# hyprland.lua. No options, no teardown -- close the windows by hand when done.
set -euo pipefail

# This Hyprland is the hyprland-lua fork: `hyprctl dispatch <expr>` runs <expr>
# as Lua (wrapped in `hl.dispatch(...)`), not the classic dispatcher-string
# syntax -- the old `[workspace N silent] cmd` exec form is a plain hyprctl-ism
# and no longer applies. `hl.dsp.exec_raw(name, args)` is this fork's escape
# hatch to any raw dispatcher (see hyprland.lua's hyprexpo comment for the same
# trick), which is what layoutmsg/closewindow go through below.
dispatch() { hyprctl dispatch "$1" >/dev/null; }

# A silently-placed window never starts its command: ghostty defers spawning
# the surface's process until the compositor actually renders it, and neither
# a `special:` workspace nor an ordinary one that is not the visible workspace
# on its monitor ever gets a frame -- verified by hand, `[workspace N silent]`
# ghostty windows sit there with no shell child at all, running or not. So
# there is no way to prepare this off-screen and reveal it once built; the
# workspace switch below happens FIRST and the four panes are built live on
# top of it, in view. That is also just what "switches there" asks for.
FOCUSED_MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
WS_JSON=$(hyprctl workspaces -j)
TARGET=$(jq -r --arg mon "$FOCUSED_MON" \
    '[.[] | select(.monitor == $mon and .windows == 0)] | sort_by(.id) | .[0].id // empty' \
    <<<"$WS_JSON")
if [ -z "$TARGET" ]; then
    # Nothing empty is pinned to this monitor -- every persistent workspace
    # already has a window on it. A brand new id has no workspace_rule, so
    # Hyprland hands it to whichever monitor is focused when it is first
    # touched, i.e. this one.
    TARGET=$(($(jq -r '[.[].id] | max' <<<"$WS_JSON") + 1))
fi
dispatch "hl.dsp.focus({workspace=$TARGET})"

# Smaller than the desktop default (20), but not by much -- btop's pane is now
# the full-height left column, not a quarter tile, so it can stay close to
# size. Measured by hand (`stty size` inside a probe pane of the same pixel
# geometry): on the smaller of the two monitors here (DP-2, 1920x1080) the
# half-width pane gives 18pt only 79 columns -- one short of btop's 80x24
# floor -- while 17pt gives 86x35. 17 is the largest size that still clears
# 80x24 on whichever monitor the layout lands on.
FONT=17
CONFIRM='--confirm-close-surface=false' # so the verify/cleanup close below never blocks on a "process is running" prompt
MARKER_DIR="$HOME/.local/state/ghostty/new-window" # same cwd the SUPER+Q terminal bind uses; ~/.bashrc fetchit's a window that lands here

# Wait for a new ghostty window with the given title to map, then print its
# address. Title, not class -- `--class` on a plain (non `+new-window`) launch
# gets ignored and every window keeps the default com.mitchellh.ghostty id.
wait_for_window() {
    local title="$1" tries=0
    while [ "$tries" -lt 50 ]; do
        addr=$(hyprctl clients -j | jq -r --arg t "$title" \
            '.[] | select(.title == $t) | .address' | head -n1)
        [ -n "$addr" ] && { echo "$addr"; return 0; }
        sleep 0.1
        tries=$((tries + 1))
    done
    echo "showcase.sh: $title never mapped" >&2
    return 1
}

# btop first, full height on the left -- it is the widget that wants the most
# cells, so it gets the whole left column instead of a quarter tile. `-e` runs
# the command directly as the surface's process instead of a shell, so
# ~/.bashrc (and its fetchit marker check) never runs for it.
dispatch "hl.dsp.exec_cmd(\"ghostty --title=ShowcaseBtop --font-size=$FONT $CONFIRM -e btop\")"
wait_for_window ShowcaseBtop >/dev/null

# fetchit to the right of btop: default shell, opened in the marker cwd so
# ~/.bashrc runs fetchit for it exactly the way SUPER+Q's terminal does, then
# cd's home and drops into the normal interactive shell -- fetchit prints once
# and the pane stays open, it never execs into anything that would exit.
dispatch 'hl.dsp.exec_raw("layoutmsg", "preselect r")'
dispatch "hl.dsp.exec_cmd(\"ghostty --title=ShowcaseFetchit --font-size=$FONT $CONFIRM --working-directory=$MARKER_DIR\")"
FETCHIT=$(wait_for_window ShowcaseFetchit)

# cava under fetchit -- the right column becomes fetchit over cava, giving a
# two-column layout: btop | fetchit-over-cava.
#
# A plain `cava` picks up every playback stream WirePlumber can link it to,
# wayvibes (the keyboard-click sound pack) included -- so this one gets its
# own PipeWire node name with autoconnect off, and Services/Cava.qml's
# ignoredStreams linker (the bar's own cava sink) feeds it everything except
# wayvibes instead, matching any node named rd-cava*, not just the bar's.
dispatch "hl.dsp.focus({window=\"address:$FETCHIT\"})"
dispatch 'hl.dsp.exec_raw("layoutmsg", "preselect d")'
dispatch "hl.dsp.exec_cmd(\"ghostty --title=ShowcaseCava --font-size=$FONT $CONFIRM -e env PULSE_PROP='node.name=rd-cava-showcase node.autoconnect=false' cava\")"
wait_for_window ShowcaseCava >/dev/null
