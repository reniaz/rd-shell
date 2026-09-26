# starship

Not a linked dotfile like the rest of this section — `~/.config/starship.toml`
is pure matugen render output, regenerated on every wallpaper switch from
`dotfiles/matugen/templates/starship.toml` via `[templates.starship]` in
`dotfiles/matugen/config.toml`. Starship reads it fresh on every prompt draw,
so there's no reload/signal step the way ghostty's theme needs.

## The prompt

Single line, the same shape as the stock Fedora prompt with git state added:

```
[user@host ~/path] main* ⇡1 $
```

`git_status` (`*` unstaged, `+` staged, `!` conflict) and `git_branch` sit
right after the bracketed `[user@host dir]`; ahead/behind arrows follow when
the branch has an upstream; a command that ran over 2s prints its duration
before the prompt character.

## Palette

Same harmonized-hue convention as the ghostty ANSI mapping and the
bat/GTK templates: username/hostname/directory/outline all key off
`primary`, and git state is split across the six fixed hues (red for
conflicts, yellow for unstaged/staged, magenta for the branch name, …) so a
dirty prompt and a language badge never read as the same colour.

## Install

`install.sh` offers to install `starship` itself from the official
`starship.rs` installer (no Fedora package or COPR carries it) — no sudo,
pinned to `~/.local/bin`. It then appends a guarded, idempotent
`eval "$(starship init bash)"` to `~/.bashrc` (backed up first) if starship
is present and not already wired in. Skips both steps cleanly if starship
isn't installed, leaving the shell prompt as bash's own default.
