#!/usr/bin/env bash
# rd shell — session launcher. Put this in the compositor's autostart:
#
#     hl.exec_cmd("~/.config/quickshell/rd-shell/launch.sh")   # hyprland.lua
#     exec-once = ~/.config/quickshell/rd-shell/launch.sh      # hyprland.conf
#
# The shell reads the audio graph once at startup and does not reconnect if
# PipeWire appears later, so this waits for a working graph before exec'ing it.
set -uo pipefail

CONFIG=rd-shell
LOG="${XDG_RUNTIME_DIR:-/tmp}/$CONFIG.log"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$1" >>"$LOG"; }

# PipeWire is socket-activated, but a failed unit stays failed: once the service
# has crash-looped past its start limit, systemd refuses to activate it again and
# the whole audio stack is dead for the rest of the session. Clearing the failed
# state and starting it explicitly is idempotent when it is already healthy.
systemctl --user reset-failed pipewire.service pipewire.socket \
    pipewire-pulse.service pipewire-pulse.socket wireplumber.service 2>/dev/null
systemctl --user start pipewire.service wireplumber.service pipewire-pulse.socket 2>/dev/null

# Wait for the graph to actually answer, not just for the unit to be active.
for _ in $(seq 40); do
    wpctl status >/dev/null 2>&1 && break
    sleep 0.25
done

if wpctl status >/dev/null 2>&1; then
    log "audio ready"
else
    log "WARNING: no PipeWire graph after 10s; volume and mic pills will read 0"
fi

# Replace any shell left over from a previous launch, so running this twice
# restarts cleanly instead of drawing two bars. -x anchors the match to the whole
# command line: a plain -f substring match also hits shells and editors that
# merely mention the string, and kills them.
for pid in $(pgrep -U "$(id -u)" -fx "qs -c $CONFIG" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null
done

log "starting quickshell"
exec qs -c "$CONFIG"
