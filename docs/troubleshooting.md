# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Every icon is a box | Material Symbols Rounded not installed | re-run `install.sh`, or check `fc-match -f '%{family}' 'Material Symbols Rounded'` |
| Icons render as their own name (`queue_music`, …) | another app's font subset wins the family lookup | `install.sh` links `assets/fontconfig/99-rd-shell-symbols.conf` to drop subsets |
| Text looks like the wrong font | caelusevka not installed | re-run `install.sh`; it copies from `assets/fonts/` |
| Volume shows 0%, no mic pill | started `qs` directly instead of `launch.sh` | kill the shell, use `launch.sh`; check `$XDG_RUNTIME_DIR/rd-shell.log` |
| No notifications at all | swaync/dunst/mako still owns the D-Bus name | `install.sh` masks all three — check none re-enabled itself (`systemctl --user is-enabled swaync.service` etc.) |
| No audio, PipeWire keeps failing | Iriun's PipeWire drop-in aborts the whole context | `install.sh` patches `iriunaudio.conf` if present |
| Claude panel is empty | no `claude` CLI, or nothing in `~/.claude` | install `claude` yourself — `install.sh` deliberately doesn't |
| Graphics tab shows only the Radeon card | no `libnvidia-ml.so.1` (NVIDIA driver not installed) | expected; the NVIDIA card's rows stay hidden without it |
| Network card reads `--` right after opening | a byte counter needs a predecessor before it's a speed | expected, fills in next sample |
| Edited QML, nothing changed | old `qs` process still running | restart with `launch.sh` |
| Firefox colours didn't change | chrome/content CSS loads once, at startup | restart Firefox |
| System popup stays empty | `python3` missing, or the sampler crashed | install `python3`; check the shell log (below) |
| Wallpaper switch doesn't recolour anything | matugen missing, or hasn't rendered yet | `command -v matugen`; re-run `scripts/wallpaper-apply.sh --restore` by hand and watch its output |
| Window borders still show the static orange after a switch | `hyprctl reload` re-read the static literals from `hyprland.lua` since the last switch | run `scripts/wallpaper-apply.sh --border`, or switch wallpaper again — see [Theming](theming/README.md) |
| Bar/GTK/Qt agree but the lock screen doesn't | `hyprlock-colors.conf` not regenerated yet | `scripts/wallpaper-apply.sh --lock` |
| Discord call banner never shows | XSOverlay plugin off, Vesktop not restarted since it was turned on, port 42070 already taken, or another real XSOverlay app is running | enable/check the plugin (Vencord → Plugins → XSOverlay) and restart Vesktop; `ss -ltnp '( sport = :42070 )'` shows what's holding the port — a real XSOverlay VR overlay app wants it too, so only run one at a time; see [Notifications](the-shell/notifications.md) and [vesktop](dotfiles/vesktop.md#call-banner-xsoverlay-plugin) |
| Sticky note key does nothing | the focused workspace isn't empty | `Super+S` only creates a note over an empty workspace, by design |
| `git pull` refuses with "local changes... would be overwritten by merge", or `install.sh` refuses with conflict markers | `hyprland.lua`/the ghostty config were edited through their `~/.config` symlink, so the edit landed in this tracked clone | see [Updating / re-running](installation/updating.md) |

## Reading the shell's own log

```bash
qs log -i $(qs list --all | awk '/^Instance/{print $2; exit}' | tr -d :)
```

This finds the running `rd-shell` Quickshell instance and tails its log —
the same place `$XDG_RUNTIME_DIR/rd-shell.log` points at. Use it for QML
errors, a crashed `scripts/sysmon.py`, or anything the symptom table above
doesn't cover.

## Still stuck

Check the relevant wiki page first — [Installation](installation/README.md)
for anything install-time, [Theming](theming/README.md) for anything
colour/wallpaper-related, [Dotfiles](dotfiles/README.md) for a specific app.
