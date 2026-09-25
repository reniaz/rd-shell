#!/bin/sh
# Resolves the wallpaper to apply and hands it to matugen and to quickshell.
#
#   wallpaper-apply.sh <abs image path>   -- from the switcher overlay
#   wallpaper-apply.sh --restore          -- from Hyprland's own startup
#
# quickshell now owns the desktop surface itself (Wallpaper.qml, on its own
# wlr-layer-shell background layer) and draws the swap animation, so this
# script no longer launches a wallpaper daemon. Its job is just: resolve,
# verify, sample colours, and write the state file -- FileView in
# Services/Wallpapers.qml watches that file, and its write is the signal
# quickshell is waiting on to start the transition. It must therefore happen
# LAST, after everything else that can fail has had its chance to.
#
# The restore path runs before anything else on the desktop is up, so PATH
# cannot be assumed to hold anything beyond what init gives a login shell --
# every binary below is called by its full path for that reason, not out of
# style.
set -euf

PGREP=/usr/bin/pgrep
MATUGEN=/usr/bin/matugen
BARMG="$HOME/.config/quickshell/rd-shell/matugen/bar.toml"
JQ=/usr/bin/jq
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell"
STATE="$CACHE/wallpaper"
FALLBACK="$HOME/Pictures/wall/LainOS-wallpapers/rd.png"
# Hoisted up here rather than left local to apply_border the way it used to
# be: the scheme/mode block near the matugen call below needs it too, and
# that block runs before apply_border is ever called.
CAELUS="$HOME/.config/quickshell/rd-shell/Config/Caelus.qml"
SCRIPTS="$HOME/.config/quickshell/rd-shell/scripts"
# Settings.qml (§7.6) writes here once it exists. matugen's scheme reads it
# first and falls back to Caelus.qml's own default -- the same precedence
# Config/Caelus.qml itself reads `scheme` with, so the bar and this script
# never disagree about which one is live.
SETTINGS="$HOME/.config/quickshell/rd-shell/settings.json"
mkdir -p "$CACHE" 2>/dev/null || true

apply_border() {
    # Hyprland's window borders, on the same switch as the bar. Config/Caelus.qml
    # is the single place the mode lives -- a second toggle could be set the other
    # way and leave an orange border framing a blue bar, which is the one outcome
    # worth engineering against here.
    #
    # Applied with `hyprctl eval`, never by rewriting hyprland.lua. `hyprctl
    # keyword` is the obvious call and it does not work here -- this config is
    # Lua, and keyword answers "can't work with non-legacy parsers. Use eval."
    # `eval` takes a Lua string, so the call below is the same hl.config the
    # config file itself makes, with two of its values replaced. The caelus
    # literals stay in that file untouched, so they are what a fresh Hyprland
    # start gives you and the static branch below is a real restore rather than
    # one more piece of state to keep in sync. The cost is that the borders
    # follow on the next wallpaper change or login rather than the moment the
    # switch is flipped.
    HYPRCTL=/usr/bin/hyprctl
    MJSON="$CACHE/matugen.json"

    if [ -x "$HYPRCTL" ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        # Anchored at end-of-line rather than matched right after the colon:
        # Config/Caelus.qml's `dynamicColour` now reads Settings.dynamicColour
        # through a typeof-guarded ternary (§7.2), so the token right after
        # "dynamicColour:" is "typeof", not true/false -- the real fallback
        # value is the ternary's last branch, at the end of the line.
        mode=$(sed -n '/dynamicColour:/ s/.*:[[:space:]]*\(true\|false\)[[:space:]]*$/\1/p' \
            "$CAELUS" 2>/dev/null || true)
    
        if [ "$mode" = true ] && [ -f "$MJSON" ]; then
            # Two stops rather than one. hyprland.lua's active border names a
            # single colour with a 45deg angle, which draws a flat edge -- an
            # angle needs something to travel between. primary to secondary is
            # the gradient matugen already computed.
            p=$(sed -n 's/.*"primary":[[:space:]]*"#\([0-9a-fA-F]*\)".*/\1/p' "$MJSON")
            c=$(sed -n 's/.*"secondary":[[:space:]]*"#\([0-9a-fA-F]*\)".*/\1/p' "$MJSON")
            o=$(sed -n 's/.*"outline":[[:space:]]*"#\([0-9a-fA-F]*\)".*/\1/p' "$MJSON")
    
            # Grouped windows' borders and group bar in the same eval, so a
            # tab group never shows last wallpaper's colours next to this one's.
            if [ -n "$p" ] && [ -n "$c" ]; then
                "$HYPRCTL" eval "hl.config({ general = { col = {\
     active_border = { colors = {'rgb($p)','rgb($c)'}, angle = 45 },\
     inactive_border = 'rgba(${o:-595959}66)' } },\
     group = { col = {\
     border_active = { colors = {'rgb($p)','rgb($c)'}, angle = 45 },\
     border_inactive = 'rgba(${o:-595959}66)' },\
     groupbar = { col = { active = 'rgb($p)', inactive = 'rgba(${o:-595959}66)' } } } })" >/dev/null 2>&1 || true
            fi
        else
            # The literals from hyprland.lua's general and group blocks, verbatim.
            "$HYPRCTL" eval "hl.config({ general = { col = {\
     active_border = { colors = {'rgb(b86e38)'}, angle = 45 },\
     inactive_border = 'rgba(595959aa)' } },\
     group = { col = {\
     border_active = { colors = {'rgb(b86e38)'}, angle = 45 },\
     border_inactive = 'rgba(595959aa)' },\
     groupbar = { col = { active = 'rgb(b86e38)', inactive = 'rgba(595959aa)' } } } })" >/dev/null 2>&1 || true
        fi
    fi
}

# The lock screen, on the same switch as the bar and the window borders.
# hyprlock.conf used to hardcode the static caelus palette, so turning dynamic
# colour on made the lock screen the one surface left behind -- the flagship
# feature actively made it worse, because every other surface moved and it did
# not. Rather than rewriting the hand-maintained hyprlock.conf on every
# wallpaper switch, this writes only the seven colour variables to a generated
# file that hyprlock.conf sources. The layout, fonts and pill shapes stay under
# hand control; only the palette is machine-written.
#
# Chrome follows the wallpaper; state colours do not. `$ok`, `$fail` and the
# auth states mean the same thing at every hour of the day and are read under
# stress, so they stay put for the same reason the bar keeps its microphone red.
apply_lock() {
    LOCKCOLORS="$HOME/.config/hypr/hyprlock-colors.conf"
    MJSON="$CACHE/matugen.json"

    bg=111318; accent=b86e38; fg=f8f5f2; muted=746863; err=f16e65

    mode=$(sed -n '/dynamicColour:/ s/.*:[[:space:]]*\(true\|false\)[[:space:]]*$/\1/p' \
        "$CAELUS" 2>/dev/null || true)

    if [ "$mode" = true ] && [ -f "$MJSON" ]; then
        role() { sed -n "s/.*\"$1\":[[:space:]]*\"#\([0-9a-fA-F]*\)\".*/\1/p" "$MJSON"; }
        bg=$(role surface);            bg=${bg:-111318}
        accent=$(role primary);        accent=${accent:-b86e38}
        fg=$(role onSurface);          fg=${fg:-f8f5f2}
        muted=$(role onSurfaceVariant); muted=${muted:-746863}
        err=$(role error);             err=${err:-f16e65}
    fi

    # Written through a temp file and moved into place: hyprlock may be started
    # by hypridle at any moment, and a half-written config is a lock screen that
    # refuses to draw.
    tmp="$LOCKCOLORS.tmp.$$"
    cat >"$tmp" <<EOF
# Generated by scripts/wallpaper-apply.sh on every wallpaper switch.
# Do not edit -- edits are overwritten. Layout lives in hyprlock.conf.
\$bg     = rgb($bg)
\$accent = rgb($accent)
\$fg     = rgb($fg)
\$muted  = rgb($muted)
\$ok     = rgb(7ec97e)
\$error  = rgb($err)
\$fail   = rgb(e74c40)
EOF
    mv -f "$tmp" "$LOCKCOLORS" 2>/dev/null || rm -f "$tmp"
}

# `--border` re-applies just the window borders and exits. `hyprctl reload`
# re-reads hyprland.lua and with it the caelus literals, which silently undoes
# the dynamic border every time the config is reloaded -- by hyprpm, by a
# keybind, by an edit. Hyprland's `exec` (unlike `exec-once`) runs on every
# reload, so one line in the config pointed at this flag makes the border
# survive them, without re-running matugen and the lock-screen resize for a
# reload that changed no wallpaper.
if [ "${1:-}" = "--border" ]; then
    apply_border
    exit 0
fi

# `--lock` regenerates just the lock screen palette and exits, for the same
# reason `--border` exists: something other than a wallpaper switch wants the
# colours refreshed without paying for matugen and the lock-screen resize.
if [ "${1:-}" = "--lock" ]; then
    apply_lock
    exit 0
fi

if [ "${1:-}" = "--restore" ]; then
    img=$(cat "$STATE" 2>/dev/null || true)
    [ -n "$img" ] && [ -f "$img" ] || img=$FALLBACK
else
    img=${1:?wallpaper-apply.sh: need an image path or --restore}
fi

[ -f "$img" ] || exit 1

# Belt and braces for whatever session still has swaybg running from before
# quickshell took the desktop layer over -- it would otherwise sit on top of
# quickshell's own background surface and cover the transition entirely. Safe
# to delete once no session anyone uses still has a stale swaybg alive; every
# fresh restore after this change never starts one to begin with.
old=$("$PGREP" -x swaybg 2>/dev/null || true)
if [ -n "$old" ]; then
    for pid in $old; do
        kill "$pid" 2>/dev/null || true
    done
fi

# matugen is what dynamic colour runs on. Failure is not fatal: a machine
# without matugen should still change its wallpaper, just without the bar
# following it.
#
# scheme and mode (§7.2). settings.json is read first and Config/Caelus.qml's
# own default second -- the same precedence Caelus.qml itself reads `scheme`
# with, so the bar and this script never disagree about which one is live.
# Mode has no settings.json field yet, so it only ever reads Caelus.qml.
# Both are whitelisted against a case statement rather than passed straight
# through: an unrecognised value would reach matugen as a bad --type/--mode
# and, since the call below is not fatal to the script, would just silently
# stop the bar following the wallpaper at all.
# Resolved by scripts/matugen-scheme.sh, which the switcher's preview also
# calls. Two scripts deciding this separately is how a preview ends up showing
# colours the apply would not produce, so there is one implementation and both
# read it. The fallbacks below only matter if that script is missing.
mgscheme=tonal-spot
mgmode=dark            # <- hand-edit for a quick stopgap with no QML
                       # involved; Config/Caelus.qml's `colorMode` is the
                       # persistent, QML-visible place to set it instead.
# Read into one string and split with parameter expansion rather than `set --`:
# this script's own positional parameters are still the arguments it was
# invoked with, and overwriting them here would quietly change what the rest
# of the file sees.
mgpair=$("$SCRIPTS/matugen-scheme.sh" 2>/dev/null || true)
if [ -n "$mgpair" ]; then
    mgscheme=${mgpair%% *}
    mgmode=${mgpair##* }
fi

# `--prefer saturation` is required, not cosmetic. Where an image offers more
# than one candidate source colour matugen asks the user to choose, and with
# no terminal attached -- which is always the case here, since this script is
# spawned detached from the shell -- it refuses and exits instead. Picking the
# most saturated candidate is also the right answer for a bar accent, which
# wants the colour the wallpaper is *about* rather than its average.
#
# --mode is never left off this call. matugen's own default is dark
# (`matugen --help`), but leaning on that default rather than passing the
# flag is exactly how this bar went light without anyone asking it to --
# whatever matugen happens to pick when the flag is absent is not something
# this script gets to be surprised by again.
#
# Two runs, the bar's own first: matugen/bar.toml holds only the bar's
# template, and ~/.config/matugen/config.toml the apps' (terminal, btop, cava,
# yazi, Vesktop, Spotify). One run stops at the first template that fails, in
# an order that changes every run, so sharing one would let any broken app
# theme sometimes keep the bar on the old colours. A run costs ~50 ms.
if [ -x "$MATUGEN" ]; then
    "$MATUGEN" image "$img" --prefer saturation --type "scheme-$mgscheme" \
        --mode "$mgmode" -c "$BARMG" -q >/dev/null 2>&1 || true
    "$MATUGEN" image "$img" --prefer saturation --type "scheme-$mgscheme" \
        --mode "$mgmode" -q >/dev/null 2>&1 || true
fi


apply_border
apply_lock

printf '%s' "$img" > "$STATE"

# --- lock screen and login screen -------------------------------------------
#
# Both want one path that never changes while the image behind it does, and
# neither can be handed the live file: the collection is a mix of jpg, jpeg,
# gif and png, and hyprlock's `path` and plasmalogin's `Image=` are both fixed
# strings with a fixed extension. So the chosen image is re-encoded to a PNG
# of a known name instead of linked.
#
# This runs AFTER the state write on purpose. That write is the signal
# quickshell waits on to start the swap animation, and a re-encode is a third
# of a second the transition should not be made to wait for. Nothing below is
# fatal -- a switch whose export fails still changes the desktop, and the lock
# screen simply keeps the previous image until the next switch.
MAGICK=/usr/bin/magick
LOCK="$CACHE/lock.png"

# Only ever shrink (the `>` flag). The larger monitor is 2560x1440; carrying a
# 4K or 8K original through to a blurred, dimmed backdrop costs decode time at
# unlock for detail that is blurred away two passes later.
if [ -x "$MAGICK" ]; then
    # [0] takes the first frame and only the first frame. The collection has a
    # gif in it, and a multi-frame input makes magick write lock.png.tmp.N-0,
    # -1, -2 ... instead of the single file named here, which would leave the
    # move below with nothing to move and the lock screen on a stale image.
    if "$MAGICK" "$img[0]" -auto-orient -strip -resize '2560x1440>' "$LOCK.tmp.$$" 2>/dev/null; then
        mv -f "$LOCK.tmp.$$" "$LOCK"
    else
        rm -f "$LOCK.tmp.$$"
    fi
fi

# plasmalogin's greeter runs as its own user and cannot read anything under
# this home directory (0700). The image therefore has to be published to a
# world-readable path, which only exists if the one-time root setup that also
# points /etc/plasmalogin.conf at it has been done:
#
#   sudo install -d -o "$USER" -g "$USER" -m 755 /usr/share/backgrounds/rd-shell
#
# Absent that directory this is a no-op, so a machine without the setup is
# simply a machine whose login screen does not follow the wallpaper.
GREETER=/usr/share/backgrounds/rd-shell
if [ -w "$GREETER" ] && [ -f "$LOCK" ]; then
    if cp -f "$LOCK" "$GREETER/current.png.tmp.$$" 2>/dev/null; then
        chmod 644 "$GREETER/current.png.tmp.$$" 2>/dev/null || true
        mv -f "$GREETER/current.png.tmp.$$" "$GREETER/current.png" 2>/dev/null \
            || rm -f "$GREETER/current.png.tmp.$$"
    fi
fi
