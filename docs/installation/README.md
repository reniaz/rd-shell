# Installation

`install.sh` is the one installer for the whole rice: Hyprland and its
dotfiles, rd-shell itself, and every app config the two shell out to. It is
meant to reproduce this machine's setup on a fresh Fedora box, or to lay the
same config over an existing one without losing what is already there.

```bash
git clone https://github.com/reniaz/rd-shell ~/coding/qs-bar
cd ~/coding/qs-bar
./install.sh
```

Pass `-y` (or `--yes`) to assume yes to every prompt instead of asking one at a
time.

Pick the page that matches your situation:

- [Requirements](requirements.md) — what has to be true before you run it.
- [Fresh install](fresh-install.md) — a Fedora box with a Hyprland session
  just started and nothing of this rice on it yet.
- [Installing over an existing config](existing-config.md) — you already have
  your own hypr/ghostty/nvim/etc. configs.
- [What install.sh does](what-install-does.md) — a step-by-step walkthrough of
  the script, in order.
- [Updating / re-running](updating.md) — pulling changes and re-running it.
- [Uninstall / revert](uninstall.md) — undoing what it did.

{% hint style="warning" %}
`install.sh` only checks the config files next to itself in the repo — it
never downloads them. Copying the script out on its own and running it
installs every package and links nothing, which looks like it worked but
leaves the bar unconfigured. Always run it from inside a clone of the repo.
{% endhint %}
