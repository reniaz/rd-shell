# Requirements

- **Fedora 44** (or close to it) with `dnf5`. Package installs elsewhere in
  the script fall back to plain `dnf` if `dnf5` isn't found, but the
  COPR-enabling step specifically needs `dnf5` (`dnf5 copr enable` has no
  `dnf` equivalent here) — without it, you're warned and told to enable the
  COPRs below by hand instead.
- **A running Hyprland session**, or at least the ability to log into one —
  several steps (`hyprctl`, `hyprpm`, the first matugen render) either need a
  live compositor or degrade gracefully without one.
- **sudo access** — package installs, COPR/RPM Fusion enablement, and one
  PipeWire drop-in patch (only if the Iriun Webcam package is present) all use
  it. You're prompted before each `sudo` call unless you pass `-y`.
- **A network connection** — for package installs, two from-source builds
  (`fetchit`, optionally `wayvibes`), the `hyprexpo` plugin build, the
  Material Symbols Rounded font, the Bibata cursor theme, the Papirus icon
  theme, the wallpaper clone, nvim's plugin sync, the Spotify flatpak, and
  `starship` — no Fedora/COPR package carries it, so it comes from its own
  installer at starship.rs into `~/.local/bin`.
- **`flatpak`, with the `flathub` remote reachable** — installed as a
  regular (optional) dependency if missing; the `flathub` remote is added
  `--user` automatically if it isn't already there. Used to install Spotify
  per-user for spicetify. See [spicetify](../dotfiles/spicetify.md).
- **Build tooling for `hyprexpo`** — `cmake`, `meson`, `ninja-build`,
  `pkgconf`, `gcc-c++`, `hyprland-devel`; installed automatically before the
  plugin build.
- **Internet access to four COPRs**: `lionheartp/Hyprland`,
  `errornointernet/quickshell`, `scottames/ghostty`, `lihaohong/yazi`.
  Fedora carries none of Hyprland, hypridle, hyprlock, hyprpicker,
  hyprlauncher, hyprshutdown or `xdg-desktop-portal-hyprland` on its own —
  those resolve only from the `lionheartp/Hyprland` COPR. quickshell and
  matugen *do* have Fedora-proper packages (0.2.1 and 3.1.0), but this rice
  needs the newer versions the `errornointernet/quickshell` COPR carries
  (0.3.1 / 4.2.0) — nothing pins the COPR build's version, so if a future
  `dnf5 upgrade` ever pulled the older Fedora build back in instead, pin the
  COPR one by hand with `sudo dnf5 versionlock add matugen`.
- **An NVIDIA card, optionally.** If one is detected (`lspci`, or
  `/proc/driver/nvidia` as a fallback), the script also offers to enable RPM
  Fusion free/nonfree for `libva-nvidia-driver`.

See [What install.sh does](what-install-does.md) for the full dependency list
it checks and installs.
