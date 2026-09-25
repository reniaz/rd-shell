# fetchit

[fetchit](https://codeberg.org/nzuum/fetchit) is a Lua-scriptable system-info
tool (the `neofetch`/`fastfetch` family), built from source by `install.sh`'s
"fetchit (source build)" step since it has no Fedora package — see
[What install.sh does](../installation/what-install-does.md#4-fetchit-and-wayvibes-source-builds).

## `dotfiles/fetchit/init.lua`

Two-column layout: `logos/logo.txt` (a small ASCII glyph, 7 lines) on the
left, a coloured info block on the right.

| Setting | Value | Notes |
|---|---|---|
| `column_padding` | `2` | space between the art column and the info column |
| `art.source` | `"./logos/logo.txt"` | resolved relative to `init.lua`'s own directory |
| line 1 | `user.name .. "@" .. host.name` | fetchit's own `user`/`host` APIs, runtime-detected |
| `os:` | `user.name .. " os \| 'fedora linux 44'"` | the login-name half reads your own account at runtime the same way the line above does (an earlier version of this file hardcoded a specific username here instead); the `fedora linux 44` half is still a fixed string |
| `kernel:` | `"fedora " .. kernel.release` | `kernel.release` is fetchit's runtime API; the `"fedora "` label is a fixed prefix |
| `cpu:` | `string.lower(cpu.name)` | fetchit's own `cpu` API, runtime-detected |
| `gpu:` | `"nvidia geforce rtx 5070"` | fixed string, hand-typed for the machine this rice was built on — fetchit has no runtime GPU API, so this is the one line `install.sh`'s end-of-run summary calls out to edit for your own card |
| `ram:` | `memory.used_gb`/`total_gb`/`percent` | fetchit's own `memory` API, runtime-detected |
| `uptime:` | `uptime.pretty` | fetchit's own `uptime` API, runtime-detected |

## Colours: matugen via the terminal, not a fetchit template

fetchit itself has no matugen template of its own (`color.red(...)` etc. just
emit standard ANSI escape codes) — the colours you actually see come from
whichever 16-colour ANSI palette the terminal fetchit runs in is currently
showing. In ghostty (this rice's terminal), that's the same
matugen-rendered, wallpaper-following palette described in
[ghostty](ghostty.md) and [The matugen pipeline](../theming/matugen-pipeline.md):
`color.red`/`green`/`yellow`/`blue`/`magenta`/`cyan` resolve to the six
harmonized custom hues defined once in `dotfiles/matugen/config.toml`'s
`[config.custom_colors]` (`red`, `green`, `yellow`, `blue`, `magenta`,
`cyan`, each `blend`ed toward the wallpaper's source colour so they read as
one theme without collapsing to a single hue on a tonal-spot wallpaper). Run
fetchit in a different terminal with its own ANSI palette and you'll get
that terminal's colours instead — there's nothing fetchit-specific to
re-theme.

## Changing the logo or the lines

- **Logo**: replace `dotfiles/fetchit/logos/logo.txt` with any plain-text
  ASCII art (or point `art.source` at a different file). No sizing/scaling —
  what's in the file is what's drawn, so keep line widths reasonable for a
  terminal column.
- **Lines**: edit the `columns` table in `init.lua` directly — each entry is
  a `color.<name>("label") .. value` string; see fetchit's own docs for the
  full `cpu`/`memory`/`host`/`user`/`kernel`/`uptime`/… API surface if you
  want to swap a fixed string for a runtime one.
