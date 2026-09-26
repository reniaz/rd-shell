#!/bin/sh
# usage: matugen-scheme.sh [image]
#
# Prints "<scheme> <mode>" -- the matugen --type suffix and --mode this shell
# is currently configured for. The optional image argument is the wallpaper
# the scheme is being resolved for -- only used to tell an achromatic
# wallpaper apart from a colourful one when the wallpaper-colours toggle is
# on (see below); leave it off and that check is simply skipped.
#
# Two callers need this answer and they must never disagree: wallpaper-apply.sh,
# which renders the live theme, and wallpaper-preview.sh, which renders a
# throwaway one for the switcher's swatches. A preview computed with a
# different scheme than the apply would use is worse than no preview at all --
# it would show the user colours they are not about to get.
set -eu

CAELUS="${CAELUS:-$HOME/.config/quickshell/rd-shell/Config/Caelus.qml}"
# Same path wallpaper-apply.sh reads, and overridable the same way CAELUS is
# above -- so this can be pointed at a scratch copy for testing without
# touching the real file.
SETTINGS="${SETTINGS:-$HOME/.config/quickshell/rd-shell/settings.json}"
JQ=/usr/bin/jq
MAGICK=/usr/bin/magick
img=${1:-}

# The settings popup's "Wallpaper colours" toggle (Settings.wallpaperColours).
# On, it overrides Config/Caelus.qml's fixed scheme with `content`, the one
# that keeps a wallpaper's own colours instead of inventing a secondary/
# tertiary hue. Missing jq, a missing settings.json, or a missing/unparsable
# key all fall through to "false", which is exactly today's behaviour:
# nothing here is load-bearing for a machine that has never had this key
# written.
wallpaperColours=false
if [ -f "$SETTINGS" ]; then
    if [ -x "$JQ" ]; then
        wallpaperColours=$("$JQ" -r '.wallpaperColours // false' "$SETTINGS" 2>/dev/null || true)
    else
        wallpaperColours=$(sed -n \
            's/.*"wallpaperColours"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' \
            "$SETTINGS" 2>/dev/null | head -n 1 || true)
    fi
fi
[ "$wallpaperColours" = true ] || wallpaperColours=false

if [ "$wallpaperColours" = true ]; then
    # Default to content -- matugen's scheme that keeps a wallpaper's own
    # colours instead of inventing a secondary/tertiary hue. But an
    # achromatic wallpaper has no colours of its own for matugen to keep:
    # it can't find a source colour with real chroma, so both content and
    # tonal-spot fall back to the same invented blue (matugen's own
    # default, #4285f4) regardless of scheme -- the toggle's whole point,
    # "only the wallpaper's colours", would silently produce a colour that
    # isn't in the wallpaper at all. scheme-monochrome is matugen's answer
    # for exactly that case: white/grey, no invented hue.
    #
    # Chroma fraction via ImageMagick's HCL colourspace (H/C/L are the
    # three channels; -channel G -separate isolates chroma). Resized to
    # 128x128 first since only the proportion of colourful pixels matters,
    # not their exact positions -- a cheap check by design, one that never
    # blocks matugen's own render if it goes wrong.
    #
    # Threshold tuned against real wallpapers, not assumed: a pixel counts
    # as "colourful" past 2% chroma (not the 8% a first guess used -- that
    # cut two legitimately-coloured wallpapers with a small accent, e.g. a
    # BSD daemon's rust-red on cream, under the line). Below 1% of pixels
    # colourful mirrors the proportion Material's own dynamic colour spec
    # uses before it gives up on a source colour and falls back -- which
    # matches what matugen actually did on the wallpapers tested: truly
    # achromatic ones (0% here) got matugen's exact #4285f4 fallback,
    # every wallpaper measured at 1.2% or above got a real, non-fallback
    # palette out of matugen instead.
    scheme=content
    if [ -n "$img" ] && [ -f "$img" ] && [ -x "$MAGICK" ]; then
        frac=$("$MAGICK" "$img[0]" -resize 128x128! -colorspace HCL \
            -channel G -separate -threshold 2% -format '%[fx:mean]' info: \
            2>/dev/null || true)
        case "$frac" in
            ''|*[!0-9.]*) ;;
            *)
                if awk -v f="$frac" 'BEGIN { exit !(f < 0.01) }' 2>/dev/null; then
                    scheme=monochrome
                fi
                ;;
        esac
    fi
else
    # Fixed at tonal-spot. Config/Caelus.qml is the single place it is written
    # down; this reads it from there rather than repeating the string, so the
    # shell and matugen cannot disagree about which scheme the colours came
    # from.
    scheme=$(sed -n \
        '/property string scheme:/ s/.*:[[:space:]]*"\([a-zA-Z-]*\)"[[:space:]]*$/\1/p' \
        "$CAELUS" 2>/dev/null || true)
    [ -n "$scheme" ] || scheme=tonal-spot
fi

mode=$(sed -n \
    '/property string colorMode:/ s/.*colorMode:[[:space:]]*"\([a-z]*\)".*/\1/p' \
    "$CAELUS" 2>/dev/null || true)
case "$mode" in
    light|dark|smart) ;;
    *) mode=dark ;;
esac

printf '%s %s\n' "$scheme" "$mode"
