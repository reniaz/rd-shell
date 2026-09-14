#!/usr/bin/env bash
# A cheat sheet of every Hyprland bind, in rofi, themed like the launcher.
#
# The list comes from `hyprctl binds`, not from parsing hyprland.lua, so it is
# whatever Hyprland is actually running right now — including the binds the
# workspace loops generate. The Lua config dispatches through `__lua`, whose
# dispatcher name and argument say nothing useful, so each bind carries a
# `description` in hyprland.lua and that is what is shown here.
set -euo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rofi-keybinds.pid"

# Second press closes the sheet instead of stacking another copy on top of it.
# rofi removes the file on a clean exit; a killed one leaves it behind, so the
# pid is only believed when it still belongs to a rofi.
if [ -s "$PIDFILE" ] && [ "$(cat "/proc/$(cat "$PIDFILE")/comm" 2>/dev/null)" = "rofi" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    exit 0
fi

rows=$(hyprctl -j binds | jq -r '
    def bit($b): ((.modmask / $b) | floor) % 2 == 1;
    def mods: [ (if bit(64) then "SUPER" else empty end),
                (if bit(4)  then "CTRL"  else empty end),
                (if bit(8)  then "ALT"   else empty end),
                (if bit(1)  then "SHIFT" else empty end) ];
    def keyname:
        if (.key // "") == "" then "code:\(.keycode)"
        else .key
            | if   . == "mouse:272"  then "LMB"
              elif . == "mouse:273"  then "RMB"
              elif . == "mouse:274"  then "MMB"
              elif . == "mouse_down" then "Scroll down"
              elif . == "mouse_up"   then "Scroll up"
              elif . == "left"  then "\u2190"
              elif . == "right" then "\u2192"
              elif . == "up"    then "\u2191"
              elif . == "down"  then "\u2193"
              # XF86AudioRaiseVolume reads as "Audio Raise Volume".
              elif startswith("XF86") then (ltrimstr("XF86") | gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a) \(.b)"))
              else . end
        end;
    def action:
        if (.description // "") != "" then .description
        else ("\(.dispatcher) \(.arg // "")" | rtrimstr(" ")) end;
    .[] | [ ((mods + [keyname]) | join(" + ")), action ] | @tsv
')

# Both columns are padded to the widest bind, which lines up because caelusevka
# is monospaced. Pango markup means the text has to be escaped first.
printf '%s\n' "$rows" | awk -F'\t' '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
    { key[NR] = $1; act[NR] = $2; if (length($1) > w) w = length($1) }
    END {
        for (i = 1; i <= NR; i++)
            printf "<span foreground=\"#b86e38\">%-*s</span>  %s\n", w, esc(key[i]), esc(act[i])
    }' |
    rofi -dmenu -i -markup-rows -no-custom \
         -p "keybinds" \
         -mesg "$(printf '%s\n' "$rows" | wc -l) binds — type to filter" \
         -theme "$HOME/.config/rofi/keybinds.rasi" \
         -pid "$PIDFILE" >/dev/null || true
