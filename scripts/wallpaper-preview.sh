#!/bin/sh
# usage: wallpaper-preview.sh <image>
#
# Prints, on stdout, the same roles JSON the bar reads -- but computed for an
# image that has NOT been applied. The wallpaper switcher calls this for the
# centred card so the accent colours can be seen before committing to them.
#
# Nothing here touches the live theme. matugen is pointed at a per-call config
# in the cache directory whose template output is the cache file, so the real
# ~/.cache/rd-shell/matugen.json is never a side effect of looking at a
# wallpaper. That file being written by an incidental matugen run is exactly
# how this shell once turned itself light mid-session.
set -eu

img=${1:-}
[ -n "$img" ] && [ -f "$img" ] || exit 1

DIR="$HOME/.config/quickshell/rd-shell"
CACHE="$HOME/.cache/rd-shell/preview"
MATUGEN=/usr/bin/matugen
TEMPLATE="$DIR/matugen/colors.json"

pair=$("$DIR/scripts/matugen-scheme.sh" 2>/dev/null || true)
scheme=${pair%% *}
mode=${pair##* }
[ -n "$scheme" ] || scheme=tonal-spot
[ -n "$mode" ] || mode=dark

mkdir -p "$CACHE"

# Keyed on the scheme and mode as well as the path: the same wallpaper gives
# different colours under a different scheme, and a stale hit would show the
# previous one.
key=$(printf '%s\n%s\n%s\n' "$img" "$scheme" "$mode" | sha1sum | cut -d' ' -f1)
out="$CACHE/$key.json"

if [ ! -s "$out" ]; then
    [ -x "$MATUGEN" ] || exit 1
    cfg="$CACHE/$key.toml"
    printf '[config]\n\n[templates.preview]\ninput_path = "%s"\noutput_path = "%s"\n' \
        "$TEMPLATE" "$out" > "$cfg"
    "$MATUGEN" image "$img" --config "$cfg" --prefer saturation \
        --type "scheme-$scheme" --mode "$mode" -q >/dev/null 2>&1 || true
    rm -f "$cfg"
fi

[ -s "$out" ] || exit 1
cat "$out"
