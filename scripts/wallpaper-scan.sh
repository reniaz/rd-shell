#!/bin/sh
# Lists one directory of the wallpaper tree for the switcher overlay: the
# entry to go back up, the subfolders, then the images, in that order and
# each alphabetical -- the order Wallpapers.qml renders cards in, so no
# sorting happens on the QML side. Refreshed on every launch (thumbnails
# included) so a wallpaper dropped in five minutes ago already has a card.
#
# Printed on stdout is exactly one JSON object and nothing else, because the
# QML side feeds this straight to JSON.parse: a stray warning on stdout would
# fail every scan silently.
# -f as well as -eu: $EXPR below is expanded unquoted so that find sees it as
# separate arguments, which also exposes its `*.png` patterns to pathname
# expansion against whatever directory the caller happens to be sitting in.
# Quickshell runs from $HOME, and a single loose .jpg there was enough to
# rewrite the find expression and drop every image from the listing. Nothing
# in this script wants globbing, so it is off for the whole file.
set -euf

ROOT="$HOME/Pictures/wall"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell/thumbs"
mkdir -p "$THUMBS" 2>/dev/null || true

EXPR='( -iname *.png -o -iname *.jpg -o -iname *.jpeg -o -iname *.webp -o -iname *.gif )'

# realpath -m tolerates a path that does not exist yet rather than erroring,
# which matters here only in that it also collapses the "/.." and symlink
# tricks a caller could otherwise use to walk out of $ROOT -- resolved before
# the prefix check below ever runs, not after.
dir=$(realpath -m -- "${1:-$ROOT}" 2>/dev/null) || exit 1
root=$(realpath -m -- "$ROOT" 2>/dev/null) || exit 1

case "$dir" in
    "$root") atRoot=true ;;
    "$root"/*) atRoot=false ;;
    *) exit 1 ;;   # outside $ROOT entirely -- refuse rather than guess
esac

[ -d "$dir" ] || exit 1

# How many images a folder holds, recursively, skipping dot-directories along
# the way: LainOS-wallpapers/.git must never be walked into, let alone counted.
count_images() {
    find "$1" \( -type d -name '.*' -prune \) -o -type f $EXPR -print 2>/dev/null | wc -l
}

LINES=$(mktemp)
PAIRS=$(mktemp)
trap 'rm -f "$LINES" "$PAIRS"' EXIT INT TERM

if [ "$atRoot" = false ]; then
    parent=$(dirname -- "$dir")
    jq -n --arg path "$parent" '{kind:"back",name:"..",path:$path}' >> "$LINES"
fi

find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '.*' 2>/dev/null | sort -f | \
while IFS= read -r folder; do
    n=$(count_images "$folder")

    # A folder card shows the first wallpaper underneath it, however deep that
    # is. A folder whose contents are themselves folders otherwise came up as
    # a blank card with a glyph on it, and there was no way to tell from the
    # strip whether there was anything worth opening -- the count said so in
    # words, but the card beside it was a photograph and this one was not.
    # The same cache and the same queue as the image thumbnails below: a cover
    # is just one more thumbnail, and usually one that is already on disk
    # because the folder has been opened before.
    # Null-delimited the whole way. A newline in a filename would otherwise be
    # read as the end of the path, and the truncated result names a file that
    # does not exist -- which is not an error anyone sees, it is a cover that
    # silently never appears and a conversion re-queued on every single scan.
    cover=$(find "$folder" \( -type d -name '.*' -prune \) -o -type f $EXPR -print0 2>/dev/null \
        | sort -zf | head -zn 1 | tr -d '\0')
    cthumb=""
    if [ -n "$cover" ]; then
        chash=$(printf '%s' "$cover" | sha1sum | cut -d' ' -f1)
        cthumb="$THUMBS/$chash.jpg"
        if [ ! -e "$cthumb" ] || [ "$cover" -nt "$cthumb" ]; then
            printf '%s\0%s\0' "$cover" "$cthumb" >> "$PAIRS"
        fi
    fi

    jq -n --arg name "$(basename -- "$folder")" --arg path "$folder" --argjson count "$n" \
        --arg thumb "$cthumb" \
        '{kind:"folder",name:$name,path:$path,count:$count,thumb:$thumb}' >> "$LINES"
done

# Same pass decides which thumbnails are stale and queues them, so a folder
# full of already-cached images costs one stat per file and nothing else.
find "$dir" -mindepth 1 -maxdepth 1 -type f $EXPR -not -name '.*' 2>/dev/null | sort -f | \
while IFS= read -r img; do
    hash=$(printf '%s' "$img" | sha1sum | cut -d' ' -f1)
    thumb="$THUMBS/$hash.jpg"
    jq -n --arg name "$(basename -- "$img")" --arg path "$img" --arg thumb "$thumb" \
        '{kind:"image",name:$name,path:$path,thumb:$thumb}' >> "$LINES"
    if [ ! -e "$thumb" ] || [ "$img" -nt "$thumb" ]; then
        printf '%s\0%s\0' "$img" "$thumb" >> "$PAIRS"
    fi
done

# Regenerated in parallel and waited on before the JSON is printed -- a card
# whose thumbnail is still mid-convert would otherwise flash blank once and
# never be told to retry.
if [ -s "$PAIRS" ]; then
    jobs=$(nproc 2>/dev/null || echo 4)

    # Two guards, and both matter.
    #
    # `|| :` on the xargs keeps one unreadable file from taking the entire
    # listing with it. xargs exits nonzero if any job did, `set -e` aborts on
    # that, and the abort happens before the `jq -s` below ever runs -- so the
    # script printed nothing at all and the switcher came up empty. Not just
    # the broken file: every folder and every wallpaper, gone. That blast
    # radius grew with the folder covers, which reach into every subtree under
    # every visible folder rather than only the directory being looked at.
    #
    # The empty file on failure is what stops the retry loop. A conversion
    # that cannot succeed would otherwise be queued again on every scan for as
    # long as the file is on disk, because the only thing marking a thumbnail
    # as done is the thumbnail existing. An empty one fails to load, which
    # leaves the card on its flat background -- the same thing you get while a
    # real one is still converting.
    xargs -0 -n 2 -P "$jobs" sh -c '
        magick "$1" -auto-orient -resize 440x680^ -gravity center -extent 440x680 -quality 82 "$2.tmp.$$" \
            && mv -f "$2.tmp.$$" "$2" \
            || { rm -f "$2.tmp.$$"; : > "$2"; }
    ' _ < "$PAIRS" || :
fi

jq -s -c --arg dir "$dir" --argjson atRoot "$atRoot" '{dir:$dir,atRoot:$atRoot,entries:.}' "$LINES"
