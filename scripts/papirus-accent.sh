#!/bin/sh
# Recolours Papirus-Dark's folder icons to track the wallpaper's matugen accent.
#
# Triggered by matugen's post_hook on templates.papirus-accent
# (dotfiles/matugen/templates/papirus-accent.txt), in the apps' matugen run
# (dotfiles/matugen/config.toml) that scripts/wallpaper-apply.sh starts second --
# by the time that run's post_hooks fire, the bar's own matugen pass (run first,
# see matugen/bar.toml) has already written $CACHE/matugen.json. This script
# reads that file directly rather than trust the template's own render: one
# source for the primary hex, the same one wallpaper-apply.sh's apply_border and
# apply_lock already trust, instead of two that could disagree.
#
# Fast, silent, and never fails the caller: every exit path is 0 (matugen's
# post_hook ignores the exit code anyway, but a script that hangs or spews
# would still be a bad neighbour on a path that runs on every wallpaper
# switch), and every step that can fail is guarded so a missing Papirus
# install, a missing papirus-folders, or a malformed cache file just leaves
# the folders on whatever colour they already have.
#
# The actual `papirus-folders -C` call -- and the gtk-update-icon-cache
# rebuild it does for Papirus-Dark, measured at several seconds -- is fired
# with setsid, detached, rather than run inline. This post_hook runs inside
# matugen's *second* pass (dotfiles/matugen/config.toml), which
# wallpaper-apply.sh runs before it writes $STATE -- the write that is the
# signal Services/Wallpapers.qml is waiting on to start the swap animation.
# Blocking here would delay that animation by however long the icon cache
# rebuild takes, on every switch that lands in a new hue bucket. Detached, the
# folders update a moment after the wallpaper does instead of before it.
#
# No PATH assumptions -- called from a matugen post_hook, which is not a login
# shell -- so every binary below is invoked by its full path.
set -euf

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell"
MJSON="$CACHE/matugen.json"
LAST="$CACHE/papirus-accent-color"
PF="$HOME/.local/bin/papirus-folders"
PYTHON3=/usr/bin/python3
THEME=Papirus-Dark

[ -f "$MJSON" ] || exit 0
[ -x "$PF" ] || exit 0
[ -x "$PYTHON3" ] || exit 0

primary=$(sed -n 's/.*"primary":[[:space:]]*"#\([0-9a-fA-F]*\)".*/\1/p' "$MJSON")
[ -n "$primary" ] || exit 0

# Nearest papirus-folders colour by hue (circular distance) plus saturation,
# both taken from the actual fills inside Papirus-Dark's own
# folder-<name>.svg icons (measured once, hardcoded below) rather than
# guessed -- the icon set's colours don't sit evenly on a wheel (several
# blues, no plain "amber"), so a table built from what Papirus actually draws
# tracks it better than assumed hue positions would.
#
# Below the saturation floor the hue is noise (a near-grey wallpaper accent
# has no hue worth matching), so that case short-circuits to grey without
# going through the hue table at all.
color=$("$PYTHON3" - "$primary" <<'PYEOF' 2>/dev/null || true
import sys, colorsys

hexv = sys.argv[1].lstrip('#')
if len(hexv) != 6:
    sys.exit(1)
r, g, b = (int(hexv[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
h, s, v = colorsys.rgb_to_hsv(r, g, b)
h *= 360.0

SAT_FLOOR = 0.12
if s < SAT_FLOOR:
    print("grey")
    sys.exit(0)

# name: (hue degrees, saturation), from folder-<name>.svg's non-white fills.
ANCHORS = {
    "red":        (0.0,   0.62),
    "carmine":    (359.1, 1.00),
    "deeporange": (15.6,  0.81),
    "orange":     (27.1,  0.77),
    "brown":      (31.1,  0.41),
    "yellow":     (42.0,  0.90),
    "green":      (95.3,  0.49),
    "teal":       (168.1, 0.86),
    "cyan":       (186.9, 1.00),
    "blue":       (212.8, 0.62),
    "indigo":     (230.9, 0.59),
    "violet":     (262.0, 0.59),
    "magenta":    (292.4, 0.50),
    "pink":       (339.7, 0.66),
}

best, best_d = "blue", None
for name, (ah, asat) in ANCHORS.items():
    dh = min(abs(h - ah), 360.0 - abs(h - ah)) / 180.0   # 0..1
    ds = abs(s - asat)
    d = 0.8 * dh + 0.2 * ds
    if best_d is None or d < best_d:
        best, best_d = name, d
print(best)
PYEOF
)
[ -n "$color" ] || exit 0

last=$(cat "$LAST" 2>/dev/null || true)
[ "$color" = "$last" ] && exit 0

# Written before the detached call, not after: the call below outlives this
# script (that is the point of setsid -f), so there is nothing to wait on to
# confirm success. Worst case on a rare papirus-folders failure is the state
# file claims a colour the folders don't actually have yet, which the next
# real colour change (not the next no-op run) will correct either way.
tmp="$LAST.tmp.$$"
printf '%s' "$color" > "$tmp" 2>/dev/null && mv -f "$tmp" "$LAST" 2>/dev/null || rm -f "$tmp"

SETSID=/usr/bin/setsid
if [ -x "$SETSID" ]; then
    "$SETSID" -f "$PF" -t "$THEME" -C "$color" >/dev/null 2>&1 &
else
    "$PF" -t "$THEME" -C "$color" >/dev/null 2>&1 &
fi

exit 0
