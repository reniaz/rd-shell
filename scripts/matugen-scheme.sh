#!/bin/sh
# Prints "<scheme> <mode>" -- the matugen --type suffix and --mode this shell
# is currently configured for.
#
# Two callers need this answer and they must never disagree: wallpaper-apply.sh,
# which renders the live theme, and wallpaper-preview.sh, which renders a
# throwaway one for the switcher's swatches. A preview computed with a
# different scheme than the apply would use is worse than no preview at all --
# it would show the user colours they are not about to get.
set -eu

CAELUS="${CAELUS:-$HOME/.config/quickshell/rd-shell/Config/Caelus.qml}"

# Fixed at tonal-spot. Config/Caelus.qml is the single place it is written
# down; this reads it from there rather than repeating the string, so the shell
# and matugen cannot disagree about which scheme the colours came from.
scheme=$(sed -n \
    '/property string scheme:/ s/.*:[[:space:]]*"\([a-zA-Z-]*\)"[[:space:]]*$/\1/p' \
    "$CAELUS" 2>/dev/null || true)
[ -n "$scheme" ] || scheme=tonal-spot

mode=$(sed -n \
    '/property string colorMode:/ s/.*colorMode:[[:space:]]*"\([a-z]*\)".*/\1/p' \
    "$CAELUS" 2>/dev/null || true)
case "$mode" in
    light|dark|smart) ;;
    *) mode=dark ;;
esac

printf '%s %s\n' "$scheme" "$mode"
