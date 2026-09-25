#!/usr/bin/env bash
# Capture a screenshot, put it on the clipboard AND on disk, then offer to open
# it. Bound to CTRL+ALT+up in hyprland.lua; the optional argument is the target
# (area|active|output|screen) and defaults to a region selection.
#
# The capture happens BEFORE anything else is on screen, and the region is then
# cropped out of those pixels rather than grabbed live. That ordering is the
# whole point. grimblast -f put hyprpicker's frozen layer up first and ran slurp
# on top of it, then captured the result -- so the crosshair slurp installs as a
# client cursor surface, which Hyprland composites into the scene rather than
# onto the hardware cursor plane, ended up baked into the saved PNG at whichever
# corner the drag finished on. Capturing first makes that impossible: the pixels
# are already on disk before either of them exists.
#
# The screen is still frozen while the region is dragged out, by the same
# hyprpicker overlay grimblast used. The difference is that the overlay is now
# only something to look at -- nothing is ever captured from it -- so whatever
# it does with the cursor cannot reach the file.
set -eu

TARGET="${1:-area}"
DIR="$HOME/Pictures/screens"
FILE="$DIR/$(date +'%Y%m%d_%H%M%S').png"
COLORS="$HOME/.cache/rd-shell/matugen.json"

mkdir -p "$DIR"

TMP=$(mktemp --suffix=.png -p "${XDG_RUNTIME_DIR:-/tmp}" shot.XXXXXX)
trap 'rm -f "$TMP"' EXIT

# Whole layout in one frame. No -c, and nothing of ours is drawn over it yet.
grim "$TMP"

# slurp is themed from the live wallpaper palette so the selector matches the
# shell instead of being stock grey-on-black. Roles are the same ones Colors.qml
# reads; the fallbacks are the static Caelus palette.
role() { jq -r --arg k "$1" '.[$k] // empty' "$COLORS" 2>/dev/null || true; }
accent=$(role primary); accent=${accent:-#b86e38}
surface=$(role surface); surface=${surface:-#111318}

# How hard everything outside the selection is dimmed, as the alpha byte slurp
# takes on the end of its colours. The dim is what makes the region being
# dragged read as lit rather than merely outlined, so it wants to be heavy --
# but it is laid over the frozen screen, not over the saved pixels, so pushing
# it further costs the screenshot nothing. Lower it toward 80 for a lighter
# scrim, raise it toward cc to black the rest of the screen out.
DIM=b3

# Geometry as "X,Y WxH" in layout coordinates. Empty means the whole layout.
case "$TARGET" in
screen) geo="" ;;
output) geo=$(hyprctl monitors -j | jq -r '.[]|select(.focused)|"\(.x),\(.y) \(.width)x\(.height)"') ;;
active) geo=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
area)
    # Freeze the screen to drag against. -r renders the inactive displays too so
    # a multi-monitor selection is frozen everywhere, and -z drops the colour
    # picker's zoom lens, which is the only part of hyprpicker we do not want.
    # It is killed on every exit path, including a cancelled selection.
    if command -v hyprpicker >/dev/null 2>&1; then
        hyprpicker -r -z >/dev/null 2>&1 &
        picker=$!
        trap 'kill "$picker" 2>/dev/null || true; rm -f "$TMP"' EXIT
    fi

    # Cancelling slurp exits non-zero, and a deliberate cancel does not deserve
    # a failure toast, so it leaves quietly.
    # -b dims everything outside the selection, -s leaves the selection itself
    # completely clear so the frozen screen shows through it undimmed, and -c
    # outlines it in the wallpaper's own accent. That is the spotlight look:
    # the region is not highlighted, everything else is taken away.
    geo=$(slurp -d -w 2 \
        -b "${surface}${DIM}" \
        -s "#00000000" \
        -c "${accent}ff" \
        -F "$(fc-match -f '%{family}' caelusevka 2>/dev/null || echo sans)") || exit 0
    ;;
*) echo "usage: screenshot.sh [area|active|output|screen]" >&2; exit 2 ;;
esac

if [ -z "$geo" ]; then
    cp "$TMP" "$FILE"
else
    # Every monitor here sits at scale 1 with no transform and the layout origin
    # is 0,0, so layout coordinates and image pixels are the same number. -crop
    # clips anything that runs past the edge of the frame, which is what should
    # happen for a window hanging off screen.
    pos=${geo%% *}
    size=${geo##* }
    magick "$TMP" -crop "${size}+${pos%,*}+${pos#*,}" +repage "$FILE"
fi

wl-copy --type image/png <"$FILE"

# notify-send -A prints the invoked action id and blocks until the notification
# is actioned or closed, so it has to run detached -- hyprland's exec_cmd would
# otherwise sit on it for as long as the toast lives. timeout bounds that wait:
# a notification nobody ever touches would leave this process alive for the rest
# of the session. x-rd-hotkey marks it as hotkey feedback, so the bar shows it
# even under do-not-disturb -- see isHotkey() in Services/Notifications.qml.
(
    [ "$(timeout 300 notify-send -a Screenshot -i "$FILE" \
        -h "string:image-path:file://$FILE" \
        -h boolean:x-rd-hotkey:true \
        -A "default=Open" \
        "Screenshot saved" "$(basename "$FILE")")" = default ] &&
        xdg-open "$FILE"
) >/dev/null 2>&1 &
