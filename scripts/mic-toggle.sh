#!/usr/bin/env bash
# Toggle the default audio source and report the resulting state as a
# notification. Bound to CTRL+SHIFT+M and XF86AudioMicMute in hyprland.lua.
#
# x-rd-hotkey marks this as feedback for a key the user just pressed rather than
# an interruption: the bar shows it even under do-not-disturb, and labels it with
# the current DND state -- see isHotkey() in Services/Notifications.qml.
#
# The previous notification is CLOSED and a fresh one posted, rather than reusing
# replaces-id. Replacing updates the existing notification silently, so once its
# toast had timed out a later toggle changed the text without showing anything.
# Closing first keeps the panel to a single entry AND guarantees a toast per press.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/mic-notify-id"

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
    MSG="Microphone muted"
else
    MSG="Microphone unmuted"
fi

ID=$(cat "$STATE" 2>/dev/null || echo 0)
if [ "${ID:-0}" != "0" ]; then
    busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
        org.freedesktop.Notifications CloseNotification u "$ID" >/dev/null 2>&1 || true
fi

NEW=$(notify-send -p -a Microphone -u low -h boolean:x-rd-hotkey:true "$MSG")
printf '%s' "$NEW" > "$STATE"
