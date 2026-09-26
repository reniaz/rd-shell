#!/usr/bin/env bash
# Decodes `hyprctl binds` into the rows KeybindOverview.qml (SUPER+K) shows.
#
# The list comes from `hyprctl binds`, not from parsing hyprland.lua, so it is
# whatever Hyprland is actually running right now — including the binds the
# workspace loops generate. The Lua config dispatches through `__lua`, whose
# dispatcher name and argument say nothing useful, so each bind carries a
# `description` in hyprland.lua and that is what is shown here.
#
#   keybinds.sh --tsv    the rows, "<combo>\t<action>\t<ref>\t<raw>" -- what
#                        Services/Keybinds.qml reads. <ref> is the bind's Lua
#                        callback (see `ref` below), empty for a bind the
#                        overview cannot run. <raw> is the same chord in
#                        Hyprland's OWN spelling (mods + hyprctl's own `key`
#                        field, not the display glyphs `combo` uses) -- what
#                        hl.bind/hl.unbind take and what keybind-overrides.lua
#                        matches rows against, since that file has to
#                        round-trip through those functions, not through
#                        this script's display column.
set -euo pipefail

# No modes left to switch on -- `--tsv` is accepted (and ignored) only so
# Services/Keybinds.qml's `["sh", ..., "--tsv"]` call needs no update.

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
              elif . == "left"  then "←"
              elif . == "right" then "→"
              elif . == "up"    then "↑"
              elif . == "down"  then "↓"
              # XF86AudioRaiseVolume reads as "Audio Raise Volume".
              elif startswith("XF86") then (ltrimstr("XF86") | gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a) \(.b)"))
              else . end
        end;
    def action:
        if (.description // "") != "" then .description
        else ("\(.dispatcher) \(.arg // "")" | rtrimstr(" ")) end;
    # A bind in this Lua config dispatches through `__lua`, and its arg is the
    # callback'"'"'s slot in the Lua registry -- what lets the overview run it with
    # `hyprctl eval`. Mouse binds (drag to move/resize) have nothing to run
    # without the drag itself, so they get no ref.
    # `.mouse` reads false even for drag binds on 0.56, so mouse keys (drag
    # and scroll -- no keyboard capture can rebind them) are ruled out by name.
    def ref: if .dispatcher == "__lua" and (.mouse | not) and (.key // "" | startswith("mouse") | not) then .arg else "" end;
    # Same as `keyname` but with none of the display translation -- exactly
    # the token hyprland.lua'"'"'s own hl.bind call for this key would have
    # used, which is what rd_bind_registry there is keyed by.
    def rawkey: if (.key // "") == "" then "code:\(.keycode)" else .key end;
    .[] | [ ((mods + [keyname]) | join(" + ")), action, ref, ((mods + [rawkey]) | join(" + ")) ] | @tsv
')

printf '%s\n' "$rows"
