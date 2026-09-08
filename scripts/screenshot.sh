#!/usr/bin/env bash
# Capture a screenshot, put it on the clipboard AND on disk, then offer to open
# it. Bound to CTRL+ALT+up in hyprland.lua; the optional argument is grimblast's
# target (area|active|output|screen) and defaults to a region selection.
#
# copysave rather than a separate grim + wl-copy: one capture feeds both the
# clipboard and the file, so the two can never drift apart.
set -eu

TARGET="${1:-area}"
DIR="$HOME/Pictures/screens"
FILE="$DIR/$(date +'%Y%m%d_%H%M%S').png"

mkdir -p "$DIR"

# -f freezes the screen while the region is dragged out. Cancelling slurp also
# exits non-zero, and a deliberate cancel does not deserve a failure toast, so
# every non-zero exit is silent. grimblast's own -n is left off: the notification
# below carries a thumbnail and an action, which -n does not. x-rd-hotkey marks
# it as hotkey feedback, so the bar shows it even under do-not-disturb and labels
# it with the DND state -- see isHotkey() in Services/Notifications.qml.
grimblast -f copysave "$TARGET" "$FILE" || exit 0
[ -f "$FILE" ] || exit 0

# notify-send -A prints the invoked action id and blocks until the notification
# is actioned or closed, so it has to run detached -- hyprland's exec_cmd would
# otherwise sit on it for as long as the toast lives. timeout bounds that wait:
# a notification nobody ever touches would leave this process alive for the rest
# of the session.
(
    [ "$(timeout 300 notify-send -a Screenshot -i "$FILE" \
        -h "string:image-path:file://$FILE" \
        -h boolean:x-rd-hotkey:true \
        -A "default=Open" \
        "Screenshot saved" "$(basename "$FILE")")" = default ] &&
        xdg-open "$FILE"
) >/dev/null 2>&1 &
