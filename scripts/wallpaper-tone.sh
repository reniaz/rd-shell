#!/bin/sh
# The colour the desktop actually is: the single most common pixel of the
# wallpaper pywal last read. The bar paints itself this so that it disappears
# into the desktop and only shows against windows.
#
# pywal's own background is deliberately not this colour. generic_adjust() in
# pywal tests the first hex digit of each channel, and where all three are the
# character "0" -- every colour darker than #101010 -- it decides the colour is
# not saturated enough, lightens it 3% and saturates it 40%. So the image is
# asked directly instead.
set -euf

wal_file="${XDG_CACHE_HOME:-$HOME/.cache}/wal/wal"
# Checked before the cat, not after: on a machine with no pywal run yet this
# file does not exist, and set -e would otherwise exit right there, on the
# cat's own "No such file" going to stderr, before reaching the deliberate
# exit below. Same end state, no stray noise from a failure this script
# already expects.
[ -f "$wal_file" ] || exit 1
wallpaper=$(cat "$wal_file")
[ -f "$wallpaper" ] || exit 1

# A tenth of the picture: the tone that covers a wallpaper does not hide in the
# pixels a downscale drops, and it keeps the read to a third of a second.
magick "$wallpaper" -resize 10% -format %c -depth 8 histogram:info:- \
    | sort -rn \
    | head -1 \
    | grep -o '#[0-9A-Fa-f]\{6\}'
