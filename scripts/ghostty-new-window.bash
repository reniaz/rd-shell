# Sourced from ~/.bashrc (install.sh adds the line).
#
# fetchit on every new Ghostty window, never on a split. Ghostty spawns windows
# and splits identically -- same process, same env, same cgroup shape -- so the
# only marker is the cwd: Super+Q in hypr/hyprland.lua opens windows in the
# state dir below, while a split inherits the parent surface's cwd, which never
# is it. The window then starts in ~, not in that marker dir.
if [[ $- == *i* && -n $GHOSTTY_RESOURCES_DIR && $PWD == "$HOME/.local/state/ghostty/new-window" ]]; then
    cd "$HOME" || true
    command -v fetchit >/dev/null && fetchit
fi
