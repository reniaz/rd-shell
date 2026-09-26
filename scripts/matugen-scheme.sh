#!/bin/sh
# usage: matugen-scheme.sh [image]
#        matugen-scheme.sh --hue [image]
#
# Default form prints "<scheme> <mode>" -- the matugen --type suffix and
# --mode this shell is currently configured for. The optional image argument
# is the wallpaper the scheme is being resolved for -- only used to tell an
# achromatic wallpaper apart from a colourful one when the wallpaper-colours
# toggle is on (see below); leave it off and that check is simply skipped.
#
# `--hue` prints the scheme scripts/wallpaper-apply.sh's third pass
# (matugen/hue.toml -- nvim's and bat's own syntax highlighting) should
# render with instead: the same resolution as the default form, except that
# a `monochrome` result is swapped for the fixed Caelus scheme whenever
# settings.json's "keepAppColours" is true (missing key = true) -- so those
# two templates stay hued on an achromatic wallpaper while everything else
# (rendered from the unswapped default form) goes grey. Toggle off, or a
# colourful wallpaper, resolves to the same scheme either form would give,
# so this only ever changes the monochrome case.
#
# Three callers need this answer and none may disagree: wallpaper-apply.sh's
# chrome pass and its hue pass, and wallpaper-preview.sh, which renders a
# throwaway swatch for the switcher. A preview computed with a different
# scheme than the apply would use is worse than no preview at all -- it
# would show the user colours they are not about to get.
set -eu

CAELUS="${CAELUS:-$HOME/.config/quickshell/rd-shell/Config/Caelus.qml}"
# Same path wallpaper-apply.sh reads, and overridable the same way CAELUS is
# above -- so this can be pointed at a scratch copy for testing without
# touching the real file.
SETTINGS="${SETTINGS:-$HOME/.config/quickshell/rd-shell/settings.json}"
JQ=/usr/bin/jq
MAGICK=/usr/bin/magick

hue=false
if [ "${1:-}" = "--hue" ]; then
    hue=true
    shift
fi
img=${1:-}

# Reads one boolean key out of settings.json, jq first with a sed fallback
# for a machine without jq -- the same two-step lookup both wallpaperColours
# and keepAppColours need, done once here rather than copied per key.
# Missing jq, a missing settings.json, or a missing/unparsable key all fall
# through to the given default.
setting() {  # setting <key> <default: true|false>
    key=$1 default=$2
    val=$default
    if [ -f "$SETTINGS" ]; then
        if [ -x "$JQ" ]; then
            # Not `.key // default` -- jq's `//` falls through on `false`
            # the same as it does on a missing key, which would silently
            # turn an explicit "keepAppColours": false back into its
            # true default. `== null` only matches an actually-missing key.
            val=$("$JQ" -r "if .$key == null then $default else .$key end" \
                "$SETTINGS" 2>/dev/null || true)
        else
            val=$(sed -n \
                "s/.*\"$key\"[[:space:]]*:[[:space:]]*\\(true\\|false\\).*/\\1/p" \
                "$SETTINGS" 2>/dev/null | head -n 1 || true)
        fi
    fi
    case "$val" in
        true|false) ;;
        *) val=$default ;;
    esac
    printf '%s' "$val"
}

# Config/Caelus.qml's fixed scheme -- read once, since both "the toggle is
# off" below and "--hue wants the hued fallback for a monochrome result"
# need the exact same string, and repeating the sed would risk the two
# copies drifting.
base_scheme=$(sed -n \
    '/property string scheme:/ s/.*:[[:space:]]*"\([a-zA-Z-]*\)"[[:space:]]*$/\1/p' \
    "$CAELUS" 2>/dev/null || true)
[ -n "$base_scheme" ] || base_scheme=tonal-spot

# The settings popup's "Wallpaper colours" toggle (Settings.wallpaperColours).
# On, it overrides Config/Caelus.qml's fixed scheme with `content`, the one
# that keeps a wallpaper's own colours instead of inventing a secondary/
# tertiary hue.
wallpaperColours=$(setting wallpaperColours false)

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
    # Fixed at tonal-spot (or whatever Config/Caelus.qml's `scheme` property
    # says) -- the one place it's written down, so the shell and matugen
    # cannot disagree about which scheme the colours came from.
    scheme=$base_scheme
fi

# `--hue`: an achromatic wallpaper has no hue for chrome to keep either, and
# that's the right call there -- but nvim's and bat's own syntax highlighting
# (matugen/hue.toml) need several hues to stay legible at all, so "keep app
# colours" (default on) swaps the fixed, always-hued scheme back in for just
# this pass rather than following chrome into monochrome. A
# non-monochrome result (toggle off, or a colourful wallpaper) is left
# exactly as resolved above -- this only ever changes the monochrome case.
if [ "$hue" = true ] && [ "$scheme" = monochrome ]; then
    keepAppColours=$(setting keepAppColours true)
    [ "$keepAppColours" = true ] && scheme=$base_scheme
fi

mode=$(sed -n \
    '/property string colorMode:/ s/.*colorMode:[[:space:]]*"\([a-z]*\)".*/\1/p' \
    "$CAELUS" 2>/dev/null || true)
case "$mode" in
    light|dark|smart) ;;
    *) mode=dark ;;
esac

printf '%s %s\n' "$scheme" "$mode"
