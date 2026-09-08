#!/bin/sh
# Deletes one background job. Removing its directory is the whole of what
# "dismiss" means: claude-status.sh discovers jobs by listing $CDIR/jobs, so a
# job that is not on disk is not on the table.

id="$1"
CDIR="${CLAUDE_HOME:-$HOME/.claude}"

# The id is interpolated into a path, so anything outside the id alphabet is
# rejected rather than escaped -- same rule as claude-session.sh. The two dot
# entries pass that alphabet and would aim the rm at $CDIR itself, so they are
# named separately.
case "$id" in
    ''|.|..|*[!A-Za-z0-9._-]*) exit 0 ;;
esac

[ -f "$CDIR/jobs/$id/state.json" ] || exit 0

rm -rf -- "$CDIR/jobs/$id"
