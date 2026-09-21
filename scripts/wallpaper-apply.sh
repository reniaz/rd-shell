#!/bin/sh
# Resolves the wallpaper to apply and hands it to pywal and to quickshell.
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
WAL="$HOME/.local/bin/wal"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell"
STATE="$CACHE/wallpaper"
FALLBACK="$HOME/Pictures/wall/LainOS-wallpapers/rd.png"
mkdir -p "$CACHE" 2>/dev/null || true

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

# Failure is not fatal -- a machine with a stale ~/.cache/wal or no pywal
# installed should still get its wallpaper changed, just without the bar
# following it.
"$WAL" -i "$img" -n -s -t -q >/dev/null 2>&1 || true

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
