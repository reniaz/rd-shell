#!/usr/bin/env bash
# rd shell + Hyprland — one-time setup.
#
# This is the ONE installer for the whole rice: the Hyprland compositor and
# its dotfiles (hypr/, this machine's actual ~/.config/hypr, copied into the
# repo so it ships with it), and the bar that sits on top of it (rd-shell
# itself). The two used to be separate scripts in separate repos; this folds
# ~/.config/hypr/install.sh's job into this one so there is a single
# `./install.sh` for a fresh Fedora box. That standalone script is retired.
#
# Installs the packages both configs shell out to (including the COPRs
# neither Hyprland nor quickshell ship in Fedora proper), builds the two
# from-source extras (fetchit, wayvibes), links the configs and app dotfiles
# into place, fetches the cursor theme, adds the hyprexpo plugin, clears the
# system-level problems that otherwise leave services dead (a notification
# daemon competing for the D-Bus name, a third-party PipeWire drop-in that
# can take the whole audio stack down at boot), copies in the wallpapers and
# renders the first colour theme so nothing on first launch points at a file
# that does not exist yet.
#
# Safe to re-run: every step checks before it changes anything.
#
#     ./install.sh          interactive
#     ./install.sh -y       assume yes
#
# See README.md for the keybinds, a tour of the bar, and troubleshooting.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=rd-shell
HYPR="$HOME/.config/hypr"
FONT_DIR="$HOME/.local/share/fonts"
MSR_FILE='MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf'
MSR_URL='https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'
MSR_CONF=99-rd-shell-symbols.conf
IRIUN_CONF=/usr/share/pipewire/pipewire.conf.d/iriunaudio.conf
CURSOR_THEME=Bibata-Original-Classic
CURSOR_API='https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest'
ICON_DIR="$HOME/.local/share/icons"
GHOSTTY_STATE="$HOME/.local/state/ghostty/new-window"
WALL_DIR="$HOME/Pictures/wall"
LAINOS_DIR="$WALL_DIR/LainOS-wallpapers"
LAINOS_GIT=https://github.com/The-LainOS-Project/LainOS-wallpapers.git
FALLBACK_WALL="$LAINOS_DIR/rd.png"
BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qs-bar-build"
FETCHIT_GIT=https://codeberg.org/nzuum/fetchit
WAYVIBES_GIT=https://github.com/sahaj-b/wayvibes
HYPREXPO_GIT=https://github.com/sandwichfarm/hyprexpo

# Fedora 44's dnf is dnf5; fall back to dnf so the script does not just die
# on an older system, but the COPR/rpmfusion flow below is written for dnf5.
DNF=dnf5
command -v dnf5 >/dev/null 2>&1 || DNF=dnf

ASSUME_YES=0
for a in "$@"; do
    [ "$a" = "-y" ] || [ "$a" = "--yes" ] && ASSUME_YES=1
done

step() { printf '\n\033[1;34m::\033[0m \033[1m%s\033[0m\n' "$1"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '   \033[31m✗\033[0m %s\n' "$1"; }

ask() {
    [ "$ASSUME_YES" = 1 ] && return 0
    [ -t 0 ] || return 1
    local reply
    read -rp "$(printf '   \033[33m?\033[0m %s [y/N] ' "$1")" reply
    [ "${reply,,}" = y ] || [ "${reply,,}" = yes ]
}

link() {  # link <target> <link-path>
    local target=$1 path=$2
    mkdir -p "$(dirname "$path")"
    if [ "$(readlink -f "$path" 2>/dev/null)" = "$(readlink -f "$target")" ]; then
        ok "$path"
        return
    fi
    if [ -e "$path" ] && [ ! -L "$path" ]; then
        local bak
        bak="$path.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$path" "$bak"
        warn "existing $path backed up to $bak"
    fi
    ln -sfn "$target" "$path"
    ok "$path -> $target"
}

# lspci lives in pciutils, which is not guaranteed to be installed; the
# kernel driver directory is there whenever the proprietary driver is
# loaded, so it works as a fallback probe.
has_nvidia() {
    if command -v lspci >/dev/null 2>&1; then
        # Matched on a captured string rather than through `grep -q`: grep closes
        # the pipe as soon as it matches, and the SIGPIPE that gives lspci trips
        # pipefail, which would report "no card" on a machine that has one.
        case "$(lspci 2>/dev/null)" in
            *[Nn][Vv][Ii][Dd][Ii][Aa]*) return 0 ;;
        esac
        return 1
    fi
    [ -d /proc/driver/nvidia ]
}

# Fedora's copr plugin names a repo file after the project, so this is a
# cheap idempotency check with no network round-trip.
copr_enabled() {  # copr_enabled owner/project
    [ -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${1/\//:}.repo" ]
}

# The config files are what this installs a desktop for, and none of them are
# downloaded from anywhere -- they sit next to this script. Copying install.sh
# out of the repo on its own would otherwise install every package and then
# link nothing, which looks like it worked.
if [ ! -f "$REPO/shell.qml" ]; then
    fail "shell.qml is not next to this script ($REPO)"
    fail "copy or clone the whole repository, not install.sh on its own"
    exit 1
fi

# The "Config" step below symlinks the whole repo into ~/.config/quickshell,
# hyprland.lua/hyprland-gui.lua/hypridle.conf/hyprlock.conf into ~/.config/hypr,
# and the whole ghostty dir into ~/.config/ghostty -- so editing any of those
# through their ~/.config link edits a file this git clone tracks. A plain
# `git pull` (see docs/installation/updating.md) can then refuse outright, or
# leave `<<<<<<<`/`>>>>>>>` conflict markers in the file if it changed
# upstream too. Catch the conflict-marker case here: symlinking a config that
# still has them into ~/.config/hypr would otherwise fail silently, showing up
# as a Hyprland config-parse error far from the actual cause.
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    conflicted="" modified=""
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        # `<<<<<<< ` alone: a bare ======= line can be legitimate content.
        if grep -qE '^<{7} ' "$REPO/$f" 2>/dev/null; then
            conflicted="$conflicted $f"
        else
            modified="$modified $f"
        fi
    done < <(git -C "$REPO" diff --name-only HEAD -- . ':!Local')

    if [ -n "$conflicted" ]; then
        fail "unresolved git merge conflict markers in:$conflicted"
        fail "resolve them by hand (keep your machine-specific lines, take the"
        fail "incoming version of the rest), 'git add' the file(s), then re-run"
        fail "this script -- see docs/installation/updating.md"
        exit 1
    fi
    if [ -n "$modified" ]; then
        warn "tracked files edited in place, through their ~/.config symlink:$modified"
        warn "install.sh uses them as they are, but the next 'git pull' can refuse"
        warn "or conflict on them -- see docs/installation/updating.md"
    fi
fi

# --- repositories -------------------------------------------------------
# Fedora carries none of Hyprland, hypridle, hyprlock, hyprpicker, hyprlauncher,
# hyprshutdown, xdg-desktop-portal-hyprland or uwsm itself on this host --
# every one of them only resolves from the lionheartp/Hyprland COPR (verified
# with `dnf5 repoquery`, not assumed). quickshell and matugen DO exist in
# Fedora proper too (0.2.1 and 3.1.0), but this rice is built against the
# newer COPR builds (0.3.1 / 4.2.0) -- the config files here are not verified
# against matugen 3.x's template syntax, so the older Fedora build is not a
# safe fallback. The COPR wins on NEVRA as long as it stays enabled below;
# nothing here version-locks it, since doing that needs the separate
# dnf5-command(versionlock) plugin for one edge case that has not actually
# happened -- if a future `dnf5 upgrade` ever downgrades matugen, pin it by
# hand with `sudo dnf5 versionlock add matugen`. It used to be enabled here
# only when hyprlock/hyprshutdown were missing, which left matugen and
# hyprpicker impossible to install on a machine that got those two from
# somewhere else first -- so it is unconditional now.
# ghostty and yazi are COPR-only the same way, each from its own project.
COPRS="lionheartp/Hyprland errornointernet/quickshell scottames/ghostty lihaohong/yazi"

step "Repositories"
if [ "$DNF" != dnf5 ]; then
    warn "dnf5 not found — this script targets Fedora 44; enable these by hand:"
    warn "  $COPRS"
else
    if ! rpm -q dnf5-plugins >/dev/null 2>&1; then
        if ask "install dnf5-plugins (needed for 'dnf5 copr')?"; then
            sudo dnf5 install -y dnf5-plugins || warn "dnf5-plugins install failed"
        else
            warn "without dnf5-plugins the COPRs below cannot be enabled"
        fi
    fi

    for cp in $COPRS; do
        if copr_enabled "$cp"; then
            ok "copr $cp"
        elif ask "enable copr $cp?"; then
            sudo dnf5 copr enable -y "$cp" >/dev/null 2>&1 && ok "copr $cp enabled" || fail "could not enable copr $cp"
        else
            warn "copr $cp skipped; its packages will not be installable below"
        fi
    done

    if has_nvidia; then
        for rf in free nonfree; do
            if rpm -q "rpmfusion-$rf-release" >/dev/null 2>&1; then
                ok "rpmfusion-$rf"
            elif ask "enable rpmfusion-$rf (needed for libva-nvidia-driver)?"; then
                sudo dnf5 install -y \
                    "https://download1.rpmfusion.org/$rf/fedora/rpmfusion-$rf-release-$(rpm -E %fedora).noarch.rpm" \
                    >/dev/null 2>&1 && ok "rpmfusion-$rf enabled" || fail "could not enable rpmfusion-$rf"
            else
                warn "rpmfusion-$rf skipped; the NVIDIA-only bits below will fail to install"
            fi
        done
    fi
fi

# --- packages -------------------------------------------------------------
# Command a bind, a QML service or an autostart line shells out to -> Fedora
# package providing it -> req(uired) or opt(ional). Optional ones still get
# offered below, just without the loud red fail() — the matching feature or
# bind is simply inert without them. Every name here was checked with
# `dnf5 repoquery <name>` on this host before being added.
#
# node/npm/go/pip3/unzip/rg/fd/gcc/g++/make are not shelled to by a bind --
# they are what nvim's own plugin managers need once nvim is linked in below:
# Mason installs pyright, svelte-language-server and @biomejs/biome and needs
# node+npm for that (nodejs22/nodejs22-npm-bin -- plain nodejs/npm are not a
# thing on Fedora 44), gopls through go install (golang), `MasonInstall
# clang-format` through pip (python3-pip), and Mason's github-release
# downloads need unzip. telescope's vimgrep/file-finder need rg/fd (ripgrep,
# fd-find). treesitter's `:TSUpdate` and telescope-fzf-native's `build =
# make` both compile, hence gcc/gcc-c++/make/git (git is already required
# above for other reasons). All opt, matching nvim's own opt: skip nvim,
# skip these too, nothing else needs them.
DEPS="
qs:quickshell:req
hyprctl:hyprland:req
hyprlock:hyprlock:req
hyprshutdown:hyprshutdown:req
hypridle:hypridle:req
hyprlauncher:hyprlauncher:req
uwsm:uwsm:req
dolphin:dolphin:req
firefox:firefox:opt
tuned-adm:tuned:opt
nmcli:NetworkManager:req
kcmshell6:kf6-kcmutils:req
plasma-apply-colorscheme:plasma-workspace:req
kreadconfig6:kf6-kconfig:req
pavucontrol:pavucontrol:req
wpctl:wireplumber:req
notify-send:libnotify:req
jq:jq:req
awk:gawk:req
python3:python3:req
free:procps-ng:req
df:coreutils:req
curl:curl:req
wget:wget2-wget:opt
git:git:req
grim:grim:req
slurp:slurp:req
swappy:swappy:opt
wl-copy:wl-clipboard:req
ghostty:ghostty:req
flatpak:flatpak:opt
nvim:neovim:opt
node:nodejs22:opt
npm:nodejs22-npm-bin:opt
go:golang:opt
pip3:python3-pip:opt
unzip:unzip:opt
rg:ripgrep:opt
fd:fd-find:opt
gcc:gcc:opt
g++:gcc-c++:opt
make:make:opt
yazi:yazi:opt
matugen:matugen:req
magick:ImageMagick:req
btop:btop:opt
cava:cava:opt
bat:bat:opt
pw-link:pipewire-utils:opt
ddcutil:ddcutil:opt
xdg-open:xdg-utils:opt
canberra-gtk-play:libcanberra-gtk3:opt
qalc:qalculate:opt
brightnessctl:brightnessctl:opt
playerctl:playerctl:opt
hyprpicker:hyprpicker:opt
"

step "Dependencies"
missing=()
for entry in $DEPS; do
    cmd=${entry%%:*}; rest=${entry#*:}; pkg=${rest%%:*}; kind=${rest##*:}
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    elif [ "$kind" = opt ]; then
        warn "$cmd not found (package $pkg) — optional"
        missing+=("$pkg")
    else
        fail "$cmd (package $pkg)"
        missing+=("$pkg")
    fi
done

# Packages with no binary of their own to probe for.
# xdg-desktop-portal-hyprland backs screen sharing and the file pickers;
# polkit-kde is the authentication agent that anything asking for root pops
# up; plasma-integration backs QT_QPA_PLATFORMTHEME=kde in hyprland.lua,
# without which Qt applications ignore the system theme (it also pulls in
# breeze-cursor-theme itself, which is why that one is not listed here too
# -- hyprland-gui.lua's XCURSOR_THEME is Bibata from the start, never
# breeze, so nothing needs it directly; the fallback cursor a missing
# Bibata leaves behind, further down, still comes from it). adw-gtk3-theme
# is the libadwaita port of Adwaita for GTK3, used by the GTK theme step
# below for its adw-gtk3 and adw-gtk3-dark GtkTheme (verified: `dnf info
# adw-gtk3-theme` resolves to 6.4-3.fc44 from the Fedora repo, no COPR
# needed -- upstream is a few point releases ahead at v6.5, close enough
# that chasing GitHub releases here isn't worth the extra failure mode).
for pkg in xdg-desktop-portal-hyprland polkit-kde plasma-integration adw-gtk3-theme; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        ok "$pkg"
    else
        fail "$pkg"
        missing+=("$pkg")
    fi
done

# plasma-nm ships no binary of its own; the network pill's right-click opens
# this KCM through kcmshell6.
if compgen -G '/usr/lib*/qt6/plugins/plasma/kcms/*/kcm_networkmanagement.so' >/dev/null; then
    ok "kcm_networkmanagement"
else
    fail "kcm_networkmanagement (package plasma-nm)"
    missing+=(plasma-nm)
fi

# libva-nvidia-driver only matters -- and only installs cleanly -- on a box
# that actually has the card; nvidia-smi has no Fedora package at all (it
# ships with cuda-devel) so it is deliberately not probed for either.
# hyprland.lua sets LIBVA_DRIVER_NAME=nvidia unconditionally, which is simply
# wrong on a machine with no card -- see the summary at the end.
# GPU stats (util, clocks, power, VRAM, fan, processes) come from the driver's
# own libnvidia-ml.so.1 through ctypes in scripts/sysmon.py -- nvidia-settings
# is no longer used and is not probed for.
if has_nvidia; then
    if rpm -q libva-nvidia-driver >/dev/null 2>&1; then
        ok "libva-nvidia-driver"
    else
        warn "libva-nvidia-driver not found — hardware video decoding will not work"
        missing+=(libva-nvidia-driver)
    fi
else
    ok "no NVIDIA card detected — libva-nvidia-driver not needed"
fi

if [ ${#missing[@]} -gt 0 ]; then
    # procps-ng backs both top and free, so it lands in the list twice; dnf
    # copes, but a summary line that names a package twice reads like a bug.
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
    printf '   missing: %s\n' "${missing[*]}"
    if ask "install them with $DNF?"; then
        sudo "$DNF" install -y "${missing[@]}" || warn "$DNF install failed; install the packages above by hand"
    else
        warn "skipped; the matching features/binds will not work until these are installed"
    fi
fi

# --- from source: fetchit, wayvibes --------------------------------------
# Neither has a Fedora/COPR package. Both build into $BUILD_DIR (never the
# repo) and skip straight past the clone+build if the binary is already on
# PATH, so re-running this after a first successful build costs one
# `command -v`.
step "fetchit (source build)"
if command -v fetchit >/dev/null 2>&1; then
    ok "fetchit"
else
    builddeps=(gcc make pkgconf lua-devel)
    bmissing=()
    for p in "${builddeps[@]}"; do rpm -q "$p" >/dev/null 2>&1 || bmissing+=("$p"); done
    if [ ${#bmissing[@]} -gt 0 ]; then
        if ask "install fetchit's build deps (${bmissing[*]})?"; then
            sudo "$DNF" install -y "${bmissing[@]}" || warn "build-dep install failed"
        else
            warn "fetchit build skipped; build deps missing"
        fi
    fi
    if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        mkdir -p "$BUILD_DIR"
        src="$BUILD_DIR/fetchit"
        if [ ! -d "$src" ]; then
            git clone --depth 1 "$FETCHIT_GIT" "$src" 2>/dev/null || fail "fetchit clone failed"
        fi
        if [ -d "$src" ]; then
            # Never `make install-config` — the user's own config comes from
            # dotfiles/fetchit/ below, not fetchit's own defaults.
            if ( cd "$src" && make >/dev/null 2>&1 ); then
                if ( cd "$src" && sudo make install >/dev/null 2>&1 ); then
                    ok "fetchit installed to /usr/local/bin/fetchit"
                else
                    fail "fetchit: make install failed"
                fi
            else
                fail "fetchit: build failed"
            fi
        fi
    else
        warn "fetchit build skipped; gcc/make not on PATH"
    fi
fi

step "wayvibes (optional, source build)"
if command -v wayvibes >/dev/null 2>&1; then
    ok "wayvibes"
elif ask "build wayvibes (keypress sounds, needs your own soundpack)?"; then
    builddeps=(gcc-c++ libevdev-devel json-devel)
    bmissing=()
    for p in "${builddeps[@]}"; do rpm -q "$p" >/dev/null 2>&1 || bmissing+=("$p"); done
    if [ ${#bmissing[@]} -gt 0 ]; then
        if ask "install wayvibes's build deps (${bmissing[*]})?"; then
            sudo "$DNF" install -y "${bmissing[@]}" || warn "build-dep install failed"
        else
            warn "wayvibes build skipped; build deps missing"
        fi
    fi
    if command -v g++ >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        mkdir -p "$BUILD_DIR"
        src="$BUILD_DIR/wayvibes"
        [ -d "$src" ] || git clone --depth 1 "$WAYVIBES_GIT" "$src" 2>/dev/null || fail "wayvibes clone failed"
        if [ -d "$src" ]; then
            if ( cd "$src" && make >/dev/null 2>&1 ); then
                if ( cd "$src" && sudo make install >/dev/null 2>&1 ); then
                    ok "wayvibes installed to /usr/local/bin/wayvibes"
                    warn "add yourself to the 'input' group and reboot for key events"
                    warn "put a soundpack in ~/Documents/Soundpacks or edit hyprland.lua"
                else
                    fail "wayvibes: make install failed"
                fi
            else
                fail "wayvibes: build failed"
            fi
        fi
    else
        warn "wayvibes build skipped; g++/make not on PATH"
    fi
else
    warn "wayvibes not installed — keypress sounds are off"
fi

# --- fonts ------------------------------------------------------------------
step "Material Symbols Rounded"
# Applications that use a few of these icons ship their own cut of the font
# under the same family name. One of those outranking the full font is not a
# missing-font failure and does not look like one: the icons are ligatures, so
# Qt falls back to a text font and the bar reads "queue_music" in words. The
# rule drops subsets, and goes in before anything is matched below.
link "$REPO/assets/fontconfig/$MSR_CONF" "$HOME/.config/fontconfig/conf.d/$MSR_CONF"

# Installed means a font of that family that can spell an icon name, which is
# asked for by demanding U+005F alongside it: the full font carries the Latin
# letters and underscore its ligatures are written with, and a cut of icon
# glyphs does not. A machine holding nothing but somebody's subset answers the
# plain lookup and cannot draw one icon on this bar, so the plain lookup is not
# the question.
# grep -q closes the pipe early, which trips pipefail; match on the string instead.
if [ "$(fc-match -f '%{family}' 'Material Symbols Rounded:charset=5f' 2>/dev/null)" != 'Material Symbols Rounded' ]; then
    if ask "not found — download it from github.com/google/material-design-icons?"; then
        mkdir -p "$FONT_DIR"
        if curl -fL --progress-bar -o "$FONT_DIR/$MSR_FILE" "$MSR_URL"; then
            fc-cache -f "$FONT_DIR" >/dev/null
            ok "installed to $FONT_DIR"
        else
            rm -f "$FONT_DIR/$MSR_FILE"
            fail "download failed — every icon in the bar will render as its own name"
        fi
    else
        warn "without it every icon in the bar renders as its own name"
    fi
fi

# Which file answers the plain lookup, now that the full font is known to be
# there: the rule above only drops the subsets that name themselves one, and any
# other file claiming this family can still outrank it. Both lookups have to
# come back with the same file.
if [ "$(fc-match -f '%{family}' 'Material Symbols Rounded:charset=5f' 2>/dev/null)" = 'Material Symbols Rounded' ]; then
    msr_plain=$(fc-match -f '%{file}' 'Material Symbols Rounded' 2>/dev/null)
    msr_full=$(fc-match -f '%{file}' 'Material Symbols Rounded:charset=5f' 2>/dev/null)
    if [ "$msr_plain" = "$msr_full" ]; then
        ok "resolves to $msr_plain"
    else
        warn "resolves to $msr_plain, which cannot spell the bar's icon names"
        warn "the full font is $msr_full — add the file above to $MSR_CONF"
    fi
fi

step "caelusevka"
# Custom Iosevka build used for all label text; not on any distro repo, so
# it ships as TTFs inside the repo itself rather than a download.
if [ "$(fc-match -f '%{family}' 'caelusevka' 2>/dev/null)" = 'caelusevka' ]; then
    ok "font installed"
elif [ ! -d "$REPO/assets/fonts" ]; then
    warn "$REPO/assets/fonts missing — text falls back to the system sans and looks off"
elif ask "install caelusevka from $REPO/assets/fonts?"; then
    mkdir -p "$FONT_DIR"
    if cp "$REPO"/assets/fonts/*.ttf "$FONT_DIR/" 2>/dev/null; then
        fc-cache -f "$FONT_DIR" >/dev/null
        ok "installed to $FONT_DIR"
    else
        fail "copy failed — text falls back to the system sans and looks off"
    fi
else
    warn "without it text falls back to the system sans and looks off"
fi

# --- cursor theme -----------------------------------------------------------
# hyprland.lua runs `hyprctl setcursor Bibata-Original-Classic 36` at startup.
# Bibata has no Fedora package, so it comes from the upstream release tarball.
step "Cursor theme"
if [ -d "$ICON_DIR/$CURSOR_THEME" ]; then
    ok "$CURSOR_THEME"
elif ask "download $CURSOR_THEME from github.com/ful1e5/Bibata_Cursor?"; then
    url=$(curl -fsSL "$CURSOR_API" 2>/dev/null \
        | grep -o "https://[^\"]*$CURSOR_THEME\.tar\.xz" | head -1)
    if [ -z "$url" ]; then
        fail "could not find $CURSOR_THEME in the latest release"
    else
        mkdir -p "$ICON_DIR"
        if curl -fL --progress-bar "$url" | tar -xJ -C "$ICON_DIR"; then
            ok "installed to $ICON_DIR/$CURSOR_THEME"
        else
            fail "download failed — the cursor falls back to breeze_cursors"
        fi
    fi
else
    warn "without it the cursor falls back to breeze_cursors"
fi

# --- icon theme (Papirus) ----------------------------------------------
# Stock Breeze -> Papirus. No Fedora package for either piece, so both come
# from their own upstream repos, same pattern as the Bibata cursor block
# above (both use $ICON_DIR, defined with the rest of this script's
# variables at the top). Run here, before the first colour
# render below, so that render's [templates.papirus] post_hook
# (scripts/papirus-accent.sh) finds Papirus-Dark and papirus-folders already
# in place instead of no-oping on a theme that is not there yet.
#
# Installed user-level (DESTDIR=$ICON_DIR) rather than the project's own
# default (DESTDIR=/usr/share/icons, system-wide, root-owned) -- and that
# choice is deliberate even though a system-wide install is arguably more
# "standard". papirus-folders (below) needs write access to the theme
# directory to flip which folder-<color>.svg a symlink points at; against a
# root-owned /usr/share/icons that means sudo, and scripts/papirus-accent.sh
# runs unattended from a matugen post_hook on every wallpaper switch, where
# there is no terminal to prompt at and a stalled sudo would just hang the
# switch. A user-level install keeps every piece of this feature -- theme,
# tool, and the script driving it -- sudo-free end to end. Idempotent: only
# Papirus-Dark is checked for and only Papirus-Dark is fetched
# (EXTRA_THEMES), since that's the only variant scripts/papirus-accent.sh
# ever names with -t. The install.sh this curls in turn shells out to wget
# for the actual per-file fetches (curl above only gets that script itself)
# -- wget2-wget in the Dependencies step above covers it; without it this
# step fails cleanly and the icon theme just stays Breeze, same as any
# other network fetch here.
step "Icon theme (Papirus)"
if [ -d "$ICON_DIR/Papirus-Dark" ]; then
    ok "Papirus-Dark"
elif ask "install Papirus-Dark from github.com/PapirusDevelopmentTeam/papirus-icon-theme (user-level, no sudo)?"; then
    if curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-icon-theme/master/install.sh \
        | env DESTDIR="$ICON_DIR" EXTRA_THEMES="Papirus-Dark" sh; then
        ok "installed to $ICON_DIR/Papirus-Dark"
    else
        fail "download/install failed — the icon theme stays Breeze"
    fi
else
    warn "without it the icon theme stays Breeze"
fi

# papirus-folders: the CLI scripts/papirus-accent.sh drives to recolour
# Papirus-Dark's folders to match the wallpaper accent. No Fedora package;
# it's one self-contained bash script (>=4.0, which Fedora's /bin/bash
# always is) from its own repo. Installed straight into ~/.local/bin, the
# same user bin dir the rest of this installer already assumes is on PATH.
if [ -x "$HOME/.local/bin/papirus-folders" ]; then
    ok "papirus-folders"
elif ask "install papirus-folders from github.com/PapirusDevelopmentTeam/papirus-folders?"; then
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders \
        -o "$HOME/.local/bin/papirus-folders" && chmod +x "$HOME/.local/bin/papirus-folders"; then
        ok "installed to $HOME/.local/bin/papirus-folders"
    else
        fail "download failed — folders stay the theme's default colour"
    fi
else
    warn "without it folders stay the theme's default colour"
fi

# --- config: rd-shell + hypr --------------------------------------------
step "Config"

# The bar. Quickshell addresses configs by directory name, so this has to be
# exactly ~/.config/quickshell/rd-shell.
link "$REPO" "$HOME/.config/quickshell/$CONFIG"

# hyprland.lua vs hyprland.conf: Hyprland uses hyprland.lua INSTEAD of
# hyprland.conf whenever hyprland.lua exists, silently, from the next full
# restart -- not a `hyprctl reload`, and nothing prints a word about it. A
# fresh Fedora session (scenario A) has, at most, the distro's own
# autogenerated stub there, safe to leave in place since it will simply stop
# being read; a machine with someone's own hand-edited hyprland.conf
# (scenario B) is exactly the "silently loses work" case this installer must
# never cause, so that one gets backed up and loudly warned about instead of
# just left to go stale next to a file that has quietly stopped applying.
HYPRLAND_CONF_NOTE=""
HC="$HYPR/hyprland.conf"
if [ -f "$HC" ]; then
    is_stub=0
    if grep -q 'AUTOGENERATED HYPRLAND CONFIG' "$HC" 2>/dev/null; then
        is_stub=1
    elif [ -f /usr/share/hypr/hyprland.conf ] && cmp -s "$HC" /usr/share/hypr/hyprland.conf; then
        is_stub=1
    fi
    if [ "$is_stub" = 1 ]; then
        ok "$HC is the distro's autogenerated stub — hyprland.lua takes over"
    else
        hcbak="$HC.bak-$(date +%Y%m%d-%H%M%S)"
        cp -a "$HC" "$hcbak"
        warn "$HC looks like your own config, not the autogenerated stub"
        warn "backed up to $hcbak (original left in place, unused)"
        warn "hyprland.lua only takes over after a FULL Hyprland restart"
        warn "(log out/in, or 'uwsm stop' + relaunch) -- 'hyprctl reload'"
        warn "keeps reading the old hyprland.conf until then"
        HYPRLAND_CONF_NOTE=$(cat <<NOTE

   hyprland.conf -> hyprland.lua        your own $HC was backed up to
                           $hcbak (left in place otherwise).
                           hyprland.lua replaces it, but only from the next
                           FULL Hyprland restart (log out/in, or 'uwsm stop'
                           + relaunch) -- 'hyprctl reload' still reads the
                           old hyprland.conf until then.
NOTE
)
    fi
fi

# Hyprland's own files, individually -- not the whole ~/.config/hypr directory,
# which also holds hyprmod's state, generated lock colours and whatever else
# accumulates there that is not this repo's to own.
for f in hyprland.lua hyprland-gui.lua hypridle.conf hyprlock.conf; do
    [ -f "$REPO/hypr/$f" ] && link "$REPO/hypr/$f" "$HYPR/$f"
done

# ghostty is a whole-directory symlink on the machine this was copied from
# (~/.config/ghostty -> hypr/dotfiles/ghostty), so that is what gets
# recreated -- not a per-file copy into a real directory.
link "$REPO/hypr/dotfiles/ghostty" "$HOME/.config/ghostty"

# hyprland.lua calls these three by their ~/.config/hypr/scripts path; on the
# real machine that path is a symlink into this repo's own scripts/, so there
# is no duplicate to copy -- just the three links to recreate.
for f in keybinds.sh mic-toggle.sh screenshot.sh; do
    link "$REPO/scripts/$f" "$HYPR/scripts/$f"
done

# SUPER+Q opens ghostty with --working-directory pointed here; ghostty
# refuses to start in a directory that does not exist, so the first terminal
# of a fresh install fails without this.
mkdir -p "$GHOSTTY_STATE" && ok "$GHOSTTY_STATE"

# --- app dotfiles ---------------------------------------------------------
# Every other app piece the rice needs, mirroring ~/.config/<app> paths --
# matugen's own config + its per-app templates, fetchit's config, the nvim
# theme pieces. Linked individually (these are real files on the machine this
# was copied from, not directory symlinks), so an app's other, unrelated
# config next to them is left alone. The vesktop/spicetify templates go in
# even when those apps are absent: matugen aborts its whole run -- ghostty,
# btop, nvim and all -- on the first template whose input_path is missing,
# and dotfiles/matugen/config.toml names both.
step "App dotfiles"
if [ -d "$REPO/dotfiles" ]; then
    # btop.conf and cava/config are excluded here on purpose -- both are
    # copied instead, by the "btop theme" and "cava theme" steps further
    # down, never symlinked. btop rewrites its whole config file on every
    # exit and cava's whole config file is rewritten by matugen on every
    # wallpaper switch; a symlink at either path would mean routine use
    # dirties a tracked repo file. Everything else here is a real,
    # untouched-at-runtime config, so the plain per-file link is fine.
    while IFS= read -r f; do
        rel=${f#"$REPO"/dotfiles/}
        case "$rel" in
            btop/btop.conf|cava/config) continue ;;
        esac
        link "$f" "$HOME/.config/$rel"
    done < <(find "$REPO/dotfiles" -type f | sort)
else
    warn "$REPO/dotfiles missing — matugen, fetchit and the nvim theme fall back to nothing"
fi

# nvim's whole config (init.lua, lua/*.lua, lazy-lock.json, plus
# matugen_watch.lua/colorscheme.lua already in dotfiles/nvim/) is now this
# rice's to own, same as every other app above -- the loop just linked it in
# per-file, exactly like ghostty/btop/cava/yazi/bat. Per-file (not a
# directory symlink) so an existing user's own extra lua/foo.lua next to it
# is left alone; it can never break init.lua either way, since Lua only
# loads what something explicitly require()s, and this init.lua only
# require()s the six modules it ships with.

# Pre-installs the plugin set (including the build-heavy ones -- treesitter's
# :TSUpdate, telescope-fzf-native) so the first real `nvim` is not a plugin
# download in the middle of typing. Guarded and never fatal: Lazy needs a
# live fetch per plugin and two of them additionally compile, so this can
# legitimately fail on a slow link or a missing toolchain piece (see the
# node/npm/go/pip3/unzip/rg/fd/gcc/make block in Dependencies above) -- nvim
# just falls back to installing everything itself on its own next launch,
# exactly as it always has.
step "nvim plugins (headless)"
if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim not installed — skipping plugin bootstrap"
elif [ ! -f "$HOME/.config/nvim/init.lua" ]; then
    warn "no ~/.config/nvim/init.lua — skipping plugin bootstrap"
else
    for c in git gcc g++ make; do
        command -v "$c" >/dev/null 2>&1 || warn "$c not found — some plugins may fail to build"
    done
    if nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1; then
        ok "plugins installed"
    else
        warn "headless plugin install failed — run nvim once by hand to finish it"
    fi
fi

# --- GTK3/GTK4/libadwaita theming -------------------------------------------
# adw-gtk3(-dark) + matugen colours, so non-Qt apps (xdg-desktop-portal-gtk's
# file picker, pavucontrol, ...) stop looking like stock Breeze.
step "GTK theme"
for ver in gtk-3.0 gtk-4.0; do
    dir="$HOME/.config/$ver"
    mkdir -p "$dir"
    ini="$dir/settings.ini"
    [ -f "$ini" ] || printf '[Settings]\n' > "$ini"
    for kv in \
        "gtk-theme-name=adw-gtk3-dark" \
        "gtk-icon-theme-name=Papirus-Dark" \
        "gtk-cursor-theme-name=$CURSOR_THEME" \
        "gtk-cursor-theme-size=36"
    do
        key=${kv%%=*}
        if grep -q "^$key=" "$ini" 2>/dev/null; then
            sed -i "s|^$key=.*|$kv|" "$ini"
        else
            sed -i "/^\[Settings\]/a $kv" "$ini"
        fi
    done
    ok "$ini"

    # gtk.css is the one hook GTK gives for user overrides, and on this
    # desktop it is also the file kde-gtk-config (KDE's GTK sync) fully
    # regenerates on its own triggers -- observed firing once at kded6
    # startup. Re-asserting our @import on every run (rather than symlinking
    # gtk.css wholesale, which would fight that resync outright and drop
    # KDE's own colors.css) is what makes this step self-healing across a
    # resync; it just needs install.sh re-run, same as any other drifted
    # setting. gtk-colors.css itself comes from matugen (see the
    # [templates.gtk] entry in dotfiles/matugen/config.toml) -- the first
    # colour render step below writes ~/.cache/rd-shell/gtk-colors.css
    # before anything reading this @import needs it.
    css="$dir/gtk.css"
    marker='@import url("file://'"$HOME"'/.cache/rd-shell/gtk-colors.css");'
    if [ -f "$css" ] && ! grep -qF "$marker" "$css"; then
        cp -a "$css" "$css.bak-$(date +%Y%m%d-%H%M%S)"
        warn "existing $css backed up"
    fi
    [ -f "$css" ] || : > "$css"
    grep -qF "$marker" "$css" || printf '%s\n' "$marker" >> "$css"
    ok "$css"
done

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
gsettings set org.gnome.desktop.interface cursor-size 36
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
ok "gsettings gtk-theme/icon-theme/cursor-theme/cursor-size/color-scheme"

# --- KDE/Qt icon + cursor theme ----------------------------------------
# Colour scheme itself is applied after the first render below (matugen's
# own [templates.kde] post_hook, SCRATCH/entries/kde.toml, handles every
# apply after that); this only sets the two pieces that are not
# wallpaper-dependent.
step "KDE icon/cursor theme"

mkdir -p "$HOME/.local/share/color-schemes"

# Icon theme. Papirus-Dark is installed user-level by the step above; this
# just points kdeglobals at it. No plasma-apply-icontheme binary exists on
# this system (Plasma 6.7.5) -- kwriteconfig6 --notify is what Plasma's own
# icon-theme KCM uses under the hood to write this exact key, and its
# --notify broadcasts the same kdeglobals-changed signal a real KCM apply
# would, so running KDE apps pick it up without a restart.
if [ "$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)" = "Papirus-Dark" ]; then
    ok "kdeglobals Icons Theme already Papirus-Dark"
else
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "Papirus-Dark" --notify \
        && ok "kdeglobals Icons Theme=Papirus-Dark" \
        || warn "could not set kdeglobals Icons Theme"
fi

# Cursor theme + size. plasma-apply-cursortheme is preferred (it notifies
# running apps), but it snaps --size to the theme's nearest pre-rendered
# size -- verified: `plasma-apply-cursortheme --size 36
# Bibata-Original-Classic` printed "requested size '36' is not available,
# using 32 instead" and left kcminputrc's cursorSize at 32. Hyprland's own
# XCURSOR_SIZE/HYPRCURSOR_SIZE env (hypr/hyprland.lua) is already 36, so
# cursorSize is force-written to 36 afterwards with kwriteconfig6 to match --
# Bibata is scalable, so Qt/GTK apps that read kcminputrc directly render it
# fine at a size the theme's own picker considers "unavailable".
if [ "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null)" = "Bibata-Original-Classic" ] \
    && [ "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorSize 2>/dev/null)" = "36" ]; then
    ok "kcminputrc cursor already Bibata-Original-Classic @36"
else
    plasma-apply-cursortheme --size 36 Bibata-Original-Classic >/dev/null 2>&1
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 36 --notify
    ok "kcminputrc cursor set to Bibata-Original-Classic @36"
fi

# btop.conf is a real per-machine config (far more in it than the theme
# line) that btop itself REWRITES WHOLESALE on every exit
# (save_config_on_exit = true, on by default) -- linking it from the repo,
# like the rest of dotfiles/, would mean quitting btop dirties a tracked
# file every time. Copied instead (see the App dotfiles loop above, which
# skips this path on purpose), so this only ever touches the one key that
# points it at the rendered matugen theme: patched in place if a config
# already exists (a user's own tuning is not ours to overwrite), or copied
# whole from dotfiles/btop/btop.conf -- the config this machine actually
# runs, filters/model names already generic and color_theme already
# "matugen" -- if btop has never been run here before.
step "btop theme"
BTOP_CONF="$HOME/.config/btop/btop.conf"
if [ -f "$BTOP_CONF" ]; then
    if grep -q '^color_theme[[:space:]]*=[[:space:]]*"matugen"' "$BTOP_CONF"; then
        ok "btop.conf already set to matugen"
    elif grep -q '^color_theme[[:space:]]*=' "$BTOP_CONF"; then
        cp "$BTOP_CONF" "$BTOP_CONF.bak-$(date +%Y%m%d-%H%M%S)"
        sed -i 's/^color_theme[[:space:]]*=.*/color_theme = "matugen"/' "$BTOP_CONF"
        ok "btop.conf color_theme set to matugen (backup taken)"
    else
        printf 'color_theme = "matugen"\n' >> "$BTOP_CONF"
        ok "btop.conf: appended color_theme = matugen"
    fi
elif [ -f "$REPO/dotfiles/btop/btop.conf" ]; then
    mkdir -p "$(dirname "$BTOP_CONF")"
    cp "$REPO/dotfiles/btop/btop.conf" "$BTOP_CONF"
    ok "copied $BTOP_CONF from dotfiles/btop/btop.conf"
else
    mkdir -p "$(dirname "$BTOP_CONF")"
    printf 'color_theme = "matugen"\n' > "$BTOP_CONF"
    ok "created minimal $BTOP_CONF"
fi

# cava, unlike btop, has no user-editable part at all: dotfiles/cava/matugen/
# config's own header explains why (no theme/include directive in 0.10.2), so
# the whole file at ~/.config/cava/config is matugen-owned and gets fully
# rewritten on every wallpaper switch. Same reasoning as btop.conf above,
# just triggered by matugen instead of by the app itself -- copied, not
# linked (the App dotfiles loop skips this path too), so the repo's copy
# only ever seeds a fresh machine; the "First colour render" step further
# down (or the next wallpaper switch) overwrites it with a real render.
step "cava theme"
CAVA_CONF="$HOME/.config/cava/config"
if [ -f "$CAVA_CONF" ]; then
    ok "$CAVA_CONF"
elif [ -f "$REPO/dotfiles/cava/config" ]; then
    mkdir -p "$(dirname "$CAVA_CONF")"
    cp "$REPO/dotfiles/cava/config" "$CAVA_CONF"
    ok "seeded $CAVA_CONF (replaced by the first colour render below)"
else
    warn "$REPO/dotfiles/cava/config missing — cava starts unthemed until a wallpaper switch"
fi

# starship itself: no Fedora package and no COPR here carries it either
# (checked with `dnf5 repoquery starship`), so — same no-sudo, own-installer
# pattern as papirus-folders/spicetify above — it comes from the official
# install.sh, pinned to $HOME/.local/bin, the same user bin dir the rest of
# this installer already assumes is on PATH.
step "Starship (binary)"
if command -v starship >/dev/null 2>&1; then
    ok "starship"
elif ask "install starship from starship.rs (curl installer, no sudo, into ~/.local/bin)?"; then
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin" >/dev/null 2>&1; then
        ok "installed to $HOME/.local/bin/starship"
    else
        fail "starship install failed — install it yourself from starship.rs"
    fi
else
    warn "without it the prompt stays bash's default"
fi

# Starship prompt. The matugen template/output wiring is already covered by
# the App dotfiles loop above (dotfiles/matugen/templates/starship.toml ->
# ~/.config/matugen/templates/starship.toml) and by [templates.starship] in
# dotfiles/matugen/config.toml itself; the only piece install.sh needs to add
# by hand is enabling starship in bash, since ~/.bashrc is a real per-user
# file this script never links or owns wholesale. Guarded and idempotent,
# same shape as the btop.conf color_theme check above: skip if already
# wired, append (with a backup) if bash init has content, otherwise this is
# a machine without starship installed and nothing is written.
step "Starship prompt"
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -q 'starship init bash' "$BASHRC"; then
    ok "~/.bashrc already wires starship"
elif command -v starship >/dev/null 2>&1; then
    [ -f "$BASHRC" ] && cp -p "$BASHRC" "$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"
    {
        printf '\n# Starship prompt, matugen-themed (~/.config/starship.toml is a matugen\n'
        printf '# output -- see [templates.starship] in ~/.config/matugen/config.toml).\n'
        printf 'command -v starship >/dev/null && eval "$(starship init bash)"\n'
    } >> "$BASHRC"
    ok "~/.bashrc: appended starship init"
else
    warn "starship not installed — ~/.bashrc left untouched"
fi

# Super+Q opens every Ghostty window in $GHOSTTY_STATE as a marker; this hook
# moves the new shell to ~ and runs fetchit there. The hook itself lives in
# the repo (scripts/ghostty-new-window.bash) so a `git pull` updates it;
# ~/.bashrc only gets the one line that sources it. An older hand-written
# copy of the same block (it tests the same marker dir) counts as wired.
step "Ghostty new-window hook"
NEWWIN_HOOK="$HOME/.config/quickshell/$CONFIG/scripts/ghostty-new-window.bash"
if [ -f "$BASHRC" ] && grep -qE 'ghostty/new-window|ghostty-new-window\.bash' "$BASHRC"; then
    ok "~/.bashrc already wires the new-window hook"
else
    [ -f "$BASHRC" ] && cp -p "$BASHRC" "$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"
    {
        printf '\n# New Ghostty window (Super+Q): start in ~ and run fetchit.\n'
        printf '[ -f "%s" ] && . "%s"\n' "${NEWWIN_HOOK/#$HOME/\$HOME}" "${NEWWIN_HOOK/#$HOME/\$HOME}"
    } >> "$BASHRC"
    ok "~/.bashrc: appended the new-window hook"
fi

# --- terminal defaults -------------------------------------------------------
# Only written if absent: anything that already set its own $TERMINAL or
# default-terminal entry made a deliberate choice this script should not
# override.
step "Terminal defaults"
TERM_ENV="$HOME/.config/environment.d/terminal.conf"
if [ -f "$TERM_ENV" ]; then
    ok "$TERM_ENV"
else
    mkdir -p "$(dirname "$TERM_ENV")"
    cat > "$TERM_ENV" <<'EOF'
# Ensure everything that respects $TERMINAL (various scripts and launchers,
# e.g. a file manager's "open terminal here") picks ghostty instead of
# falling through to kitty.
TERMINAL=/usr/bin/ghostty
EOF
    ok "created $TERM_ENV"
fi

XDG_TERM_LIST="$HOME/.config/xdg-terminals.list"
if [ -f "$XDG_TERM_LIST" ]; then
    ok "$XDG_TERM_LIST"
else
    mkdir -p "$(dirname "$XDG_TERM_LIST")"
    printf 'com.mitchellh.ghostty.desktop\n' > "$XDG_TERM_LIST"
    ok "created $XDG_TERM_LIST"
fi

# --- wallpapers --------------------------------------------------------------
# LainOS-wallpapers is a large public repo (~550 files, ~290MB + history), so
# it is cloned rather than shipped; the user's own additions on top of it are
# the small set this repo carries in wallpapers/, copied in without ever
# overwriting a file the clone (or an earlier run) already put there.
step "Wallpapers"
mkdir -p "$WALL_DIR"
if [ -d "$LAINOS_DIR" ]; then
    ok "$LAINOS_DIR"
elif ask "clone LainOS-wallpapers into $LAINOS_DIR (~290MB)?"; then
    git clone --depth 1 "$LAINOS_GIT" "$LAINOS_DIR" && ok "cloned" || fail "clone failed"
else
    warn "skipped; the fallback wallpaper and the switcher's default set stay missing"
fi
if [ -d "$REPO/wallpapers" ]; then
    cp -rn "$REPO/wallpapers/." "$WALL_DIR/" 2>/dev/null
    ok "wallpapers/ copied into $WALL_DIR (existing files kept)"
else
    warn "$REPO/wallpapers missing — nothing to add on top of the clone"
fi

# --- hyprexpo plugin ----------------------------------------------------
# hyprpm needs a running Hyprland to add/enable a plugin into (it talks to
# the running instance over its socket) -- there is nothing to do here on a
# machine that has not logged into Hyprland yet. hyprland.lua's own
# `hyprpm reload -n` autostart line loads it into the session once it is
# enabled, so this only ever needs the add+enable, never the reload.
step "Hyprland plugin: hyprexpo"
HYPREXPO_LOG="$BUILD_DIR/hyprexpo.log"
if ! command -v hyprpm >/dev/null 2>&1; then
    warn "hyprpm not found — install Hyprland first, then run:"
    warn "  hyprpm add $HYPREXPO_GIT && hyprpm enable hyprexpo"
elif [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    warn "not running inside Hyprland — after your first login, run:"
    warn "  hyprpm add $HYPREXPO_GIT && hyprpm enable hyprexpo"
elif hyprpm list 2>/dev/null | grep -qi hyprexpo; then
    ok "hyprexpo already added"
    hyprpm enable hyprexpo >/dev/null 2>&1 || true
else
    # hyprpm builds the plugin from source against the running Hyprland's own
    # headers -- without this toolchain it used to fail under the >/dev/null
    # that hid the reason, which read exactly like a silent bug: "added and
    # enabled" just never printed. hyprland-devel comes from the same
    # lionheartp/Hyprland COPR Hyprland itself does above.
    builddeps=(cmake meson ninja-build pkgconf gcc-c++ hyprland-devel)
    bmissing=()
    for p in "${builddeps[@]}"; do rpm -q "$p" >/dev/null 2>&1 || bmissing+=("$p"); done
    if [ ${#bmissing[@]} -gt 0 ]; then
        if ask "install hyprexpo's build deps (${bmissing[*]})?"; then
            sudo "$DNF" install -y "${bmissing[@]}" || warn "build-dep install failed"
        else
            warn "hyprexpo build skipped; build deps missing"
        fi
    fi
    mkdir -p "$(dirname "$HYPREXPO_LOG")"
    if hyprpm add "$HYPREXPO_GIT" >"$HYPREXPO_LOG" 2>&1 && hyprpm enable hyprexpo >>"$HYPREXPO_LOG" 2>&1; then
        ok "hyprexpo added and enabled"
    else
        fail "hyprpm add/enable hyprexpo failed — see $HYPREXPO_LOG"
    fi
fi

# --- notification daemon ----------------------------------------------------
# org.freedesktop.Notifications is an exclusive D-Bus name and all three of
# these are D-Bus activated, so stopping one is not enough — anything that
# sends a notification starts it right back up and the shell loses the name
# on its next restart. Masking is the only fix that sticks.
step "Notification daemon"
found_daemon=0
for daemon in swaync dunst mako; do
    command -v "$daemon" >/dev/null 2>&1 || continue
    found_daemon=1
    svc="$daemon.service"
    if [ "$(systemctl --user is-enabled "$svc" 2>/dev/null)" = masked ]; then
        ok "$daemon masked"
    elif ask "mask $daemon so the shell owns org.freedesktop.Notifications?"; then
        systemctl --user stop "$svc" 2>/dev/null
        systemctl --user mask "$svc" >/dev/null 2>&1 && ok "$daemon masked" || fail "could not mask $daemon"
    else
        warn "$daemon will keep stealing the notification bus name"
    fi
done
[ "$found_daemon" = 0 ] && ok "no competing daemon installed"

# --- audio ------------------------------------------------------------------
step "Audio"
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1
systemctl --user reset-failed pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null
systemctl --user start pipewire.service wireplumber.service >/dev/null 2>&1
if wpctl status >/dev/null 2>&1; then
    ok "PipeWire graph responding"
else
    fail "no PipeWire graph — run: journalctl --user -u pipewire -b"
fi

# A failed object in context.objects aborts PipeWire's whole context unless it
# is marked nofail. The Iriun Webcam package ships one without that flag, and
# when its plugin fails early in the session PipeWire crash-loops past its start
# limit: no sinks, no sources, and pavucontrol stuck on "Establishing connection
# to PulseAudio". The flag keeps the Iriun mic when it works and skips it when
# it does not. It cannot be fixed from a user drop-in — PipeWire loads every
# conf.d file from all three directories and appends array sections, so a
# same-named file in ~/.config does not shadow the system one.
if [ -f "$IRIUN_CONF" ]; then
    if grep -q 'nofail' "$IRIUN_CONF"; then
        ok "iriunaudio.conf already has nofail"
    elif ask "patch $IRIUN_CONF so a failed Iriun mic cannot kill PipeWire?"; then
        if sudo sed -i.bak \
            's|^\( *\){ factory = adapter$|\1{ factory = adapter\n\1    flags = [ nofail ]|' \
            "$IRIUN_CONF" && grep -q nofail "$IRIUN_CONF"; then
            ok "patched (backup at $IRIUN_CONF.bak)"
            warn "the file belongs to the iriunwebcam package; re-run this after updating it"
        else
            fail "patch failed — edit $IRIUN_CONF by hand"
        fi
    else
        warn "PipeWire can still be taken down at boot by the Iriun drop-in"
    fi
fi

# --- idle -------------------------------------------------------------------
# hypridle.conf locks the session after 5 minutes and blanks the displays
# after 10, but only if the daemon runs — nothing in hyprland.lua starts it.
step "Idle"
if ! command -v hypridle >/dev/null 2>&1; then
    warn "hypridle not installed — hypridle.conf is inert"
elif [ "$(systemctl --user is-enabled hypridle.service 2>/dev/null)" = enabled ]; then
    ok "hypridle.service enabled"
elif ask "enable hypridle.service (lock after 5 min, displays off after 10)?"; then
    systemctl --user enable --now hypridle.service >/dev/null 2>&1 \
        && ok "hypridle.service enabled" || fail "could not enable hypridle.service"
else
    warn "the session will not lock on idle"
fi

# --- first colour render -----------------------------------------------------
# So that nothing on first launch references a file matugen has not written
# yet (ghostty's `theme = matugen` fails hard without themes/matugen). Two
# runs, the bar's own first, exactly like scripts/wallpaper-apply.sh does it
# on every wallpaper switch afterwards: matugen/bar.toml holds only the bar's
# template and stops the run before any app template can fail it; the fixed
# --mode dark --type scheme-tonal-spot --prefer saturation here is
# deliberate, not scripts/wallpaper-apply.sh's own runtime scheme/mode
# lookup — a render that depends on Config/Caelus.qml having already loaded
# is not a safe thing to lean on during install. Dynamic colour itself
# defaults to on (Services/Settings.qml) and nothing here writes
# settings.json, so the bar starts in these wallpaper colours, not the
# static caelus palette.
step "First colour render"
# The same script the switcher and Hyprland's --restore run, so a fresh install
# gets every piece a wallpaper switch writes -- matugen's bar + app themes, the
# lock-screen colours hyprlock.conf sources, lock.png, and the state file the
# bar restores from -- instead of a second copy of that logic that could drift.
# It swallows matugen failures by design (a bad render must never block a
# wallpaper switch), so the outputs are checked here instead of its status.
#
# Fallback wallpaper vs --restore: WALL_STATE is the same state file
# wallpaper-apply.sh itself writes on every switch and Hyprland's own
# --restore reads on login -- its presence is exactly "this machine has run
# this step (or a wallpaper switch) before". First install (no state file
# yet): render the fallback wallpaper, same as always, so nothing on first
# launch points at a template output that doesn't exist. Every re-run over
# an existing install (updating.md): --restore, so a plain `./install.sh`
# to pick up a template/package fix (a broken starship prompt, say) does not
# also silently reset whoever's own wallpaper and theme back to the
# fallback.
APPLY="$HOME/.config/quickshell/$CONFIG/scripts/wallpaper-apply.sh"
WALL_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell/wallpaper"
if ! command -v matugen >/dev/null 2>&1; then
    warn "matugen not installed — the bar starts in the static caelus palette"
elif [ ! -s "$WALL_STATE" ] && [ ! -f "$FALLBACK_WALL" ]; then
    warn "$FALLBACK_WALL missing — skipping the render; re-run once wallpapers are in place"
elif [ ! -x "$APPLY" ]; then
    warn "$APPLY missing — skipping the render"
else
    if [ -s "$WALL_STATE" ]; then
        "$APPLY" --restore >/dev/null 2>&1 || true
        render_note="re-render, --restore — kept your own wallpaper"
    else
        "$APPLY" "$FALLBACK_WALL" >/dev/null 2>&1 || true
        render_note="first render, fallback wallpaper"
    fi
    [ -s "${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell/matugen.json" ] \
        && ok "bar theme rendered ($render_note)" \
        || warn "bar theme render failed (matugen/bar.toml) — the bar starts in the static palette"
    [ -s "$HOME/.config/ghostty/themes/matugen" ] \
        && ok "app themes rendered (ghostty, btop, cava, yazi, nvim, vesktop, spicetify)" \
        || warn "app theme render failed — ghostty's 'theme = matugen' will fail to load until this is re-run"
    [ -s "$HOME/.config/hypr/hyprlock-colors.conf" ] \
        && ok "lock screen colours + image" \
        || warn "hyprlock-colors.conf not written — hyprlock falls back to its own defaults"
    # starship re-reads ~/.config/starship.toml fresh on every prompt with no
    # cache to invalidate, so a template fix (a rendering bug like the
    # doubled-backslash one that shipped once) only reaches an existing
    # install through this render actually running -- worth a check of its
    # own, since matugen swallows a bad render silently by design (above) and
    # a broken starship.toml otherwise only shows up the next time a shell
    # opens, far from here.
    if command -v starship >/dev/null 2>&1 && [ -f "$HOME/.config/starship.toml" ]; then
        starship_err=$(STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt 2>&1 1>/dev/null)
        if printf '%s' "$starship_err" | grep -qi 'unable to parse'; then
            fail "~/.config/starship.toml failed to parse — starship falls back to its defaults"
        else
            ok "~/.config/starship.toml parses"
        fi
    fi
fi

# --- KDE colour scheme (first apply) ----------------------------------------
# matugen's own [templates.kde] post_hook (dotfiles/matugen/config.toml)
# handles every apply after this one, alternating between the Matugen/
# Matugen2 scheme names because plasma-apply-colorscheme refuses to
# re-apply whichever name is already active. This only covers the very
# first one, now that the render above has (or has not) written
# ~/.local/share/color-schemes/Matugen.colors.
step "KDE colour scheme"
if [ -f "$HOME/.local/share/color-schemes/Matugen.colors" ]; then
    cur=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)
    if [ "$cur" != "Matugen" ] && [ "$cur" != "Matugen2" ]; then
        plasma-apply-colorscheme Matugen >/dev/null 2>&1 \
            && ok "applied Matugen colour scheme" \
            || warn "could not apply Matugen colour scheme"
    else
        ok "Matugen colour scheme already active ($cur)"
    fi
else
    warn "no rendered Matugen.colors — run a wallpaper switch once matugen/plasma-workspace are installed"
fi

# --- bat theme ---------------------------------------------------------------
# Theme + config come from dotfiles/bat/* via the generic "App dotfiles"
# link loop above; this only builds bat's cache once so `--theme=matugen`
# resolves immediately instead of waiting for the next wallpaper switch.
step "bat theme"
if ! command -v bat >/dev/null 2>&1; then
    warn "bat not installed — skipping cache build"
elif [ -f "$HOME/.config/bat/themes/matugen.tmTheme" ]; then
    bat cache --build >/dev/null 2>&1 || true
    ok "bat cache built (matugen theme)"
else
    warn "bat theme not rendered yet — run a wallpaper switch to generate it"
fi

# --- spotify + spicetify -----------------------------------------------------
# Spotify itself is the flatpak com.spotify.Client, never installed any other
# way here. It has to be a per-user install (~/.local/share/flatpak, owned by
# $USER) rather than the system-wide one Fedora's own flatpak defaults to --
# spicetify patches the app's own files in place, and doing that against a
# root-owned system install would mean either sudo on every apply (including
# the unattended one after a Spotify auto-update) or loosening permissions on
# a system directory, neither of which this installer will do. A system-wide
# Spotify already on the machine is left exactly alone; this only warns and
# tells you how to move it.
step "Spotify (flatpak, per-user)"

FLATPAK_SPOTIFY_USER_FILES="$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
SPOTIFY_PREFS="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"

spotify_scope() {  # prints "system", "user", or nothing (not installed)
    flatpak info --system com.spotify.Client >/dev/null 2>&1 && { printf system; return; }
    flatpak info --user com.spotify.Client >/dev/null 2>&1 && { printf user; return; }
}

SPOTIFY_SCOPE=$(spotify_scope)
SPOTIFY_SWITCH_NOTE=""
if [ "$SPOTIFY_SCOPE" = system ]; then
    warn "Spotify is installed system-wide — spicetify needs a per-user install"
    warn "to patch it without root or loosening /var/lib/flatpak. Switch with:"
    warn "  flatpak uninstall --system com.spotify.Client"
    warn "  flatpak install --user flathub com.spotify.Client"
    SPOTIFY_SWITCH_NOTE=$(cat <<NOTE

   Spotify theming (spicetify)          Spotify is installed system-wide;
                           spicetify needs a per-user install to patch it
                           without root. Switch it with:
                             flatpak uninstall --system com.spotify.Client
                             flatpak install --user flathub com.spotify.Client
                           then re-run this script to theme it.
NOTE
)
elif [ "$SPOTIFY_SCOPE" = user ]; then
    ok "Spotify installed (per-user flatpak)"
elif ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak not found — install it, then re-run, for Spotify + spicetify"
elif ask "install Spotify as a per-user flatpak (flathub com.spotify.Client)?"; then
    flatpak remote-list --user 2>/dev/null | grep -q '^flathub' \
        || flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    if flatpak install --user -y flathub com.spotify.Client >/dev/null 2>&1; then
        ok "Spotify installed (per-user flatpak)"
        SPOTIFY_SCOPE=user
    else
        fail "flatpak install --user flathub com.spotify.Client failed"
    fi
else
    warn "Spotify not installed — spicetify theming skipped"
fi

# spicetify itself: same curl-installer, no-sudo, ~/.local-ish pattern as
# papirus-folders above. The theme (caelus24) is already linked into
# ~/.config/spicetify/Themes/caelus24 by the App dotfiles loop; this only
# points spicetify's own config at it and at the per-user flatpak paths, then
# reapplies. `backup apply` (not plain `apply`) so a re-run survives a
# Spotify update -- apply alone fails once its saved backup predates the
# installed build.
step "spicetify"
SPICETIFY="$HOME/.spicetify/spicetify"
if [ -x "$SPICETIFY" ]; then
    ok "spicetify installed"
elif command -v spicetify >/dev/null 2>&1; then
    SPICETIFY=spicetify
    ok "spicetify installed"
elif ask "install spicetify (curl installer from spicetify-cli, no sudo)?"; then
    # The upstream script ends on a Marketplace prompt read straight from
    # /dev/tty -- with its output hidden here, that would be a silent stall
    # in the middle of an unattended run. setsid takes the controlling
    # terminal away, so the read fails at once instead, after the CLI is
    # already in place; the binary is what decides success, not the exit
    # status. Marketplace itself is installed just below.
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/main/install.sh | setsid -w sh >/dev/null 2>&1
    if [ -x "$HOME/.spicetify/spicetify" ]; then
        SPICETIFY="$HOME/.spicetify/spicetify"
        ok "installed to $SPICETIFY"
    else
        fail "spicetify install failed"
        SPICETIFY=""
    fi
else
    warn "without it Spotify stays unthemed"
    SPICETIFY=""
fi

# Marketplace, what that prompt would have fetched: the release zip unpacked
# where spicetify looks for custom apps. Not its own install script, which
# runs `spicetify apply` before Spotify has ever started and sets a
# placeholder theme -- the config below does both properly.
MARKETPLACE_DIR="$HOME/.config/spicetify/CustomApps/marketplace"
if [ -n "$SPICETIFY" ] && [ ! -d "$MARKETPLACE_DIR" ]; then
    mp_tmp=$(mktemp -d)
    if curl -fsSL -o "$mp_tmp/marketplace.zip" \
            https://github.com/spicetify/marketplace/releases/latest/download/marketplace.zip \
        && unzip -q "$mp_tmp/marketplace.zip" -d "$mp_tmp" \
        && mkdir -p "${MARKETPLACE_DIR%/*}" \
        && mv "$mp_tmp/marketplace-dist" "$MARKETPLACE_DIR"; then
        ok "spicetify Marketplace installed"
    else
        warn "spicetify Marketplace download failed — Spotify is themed without it"
    fi
    rm -rf "$mp_tmp"
fi

if [ -n "$SPICETIFY" ] && [ "$SPOTIFY_SCOPE" = user ]; then
    # The prefs file only exists once Spotify has run once. Never touch an
    # already-running Spotify (same rule as the rest of this installer for
    # the live shell/Hyprland/Firefox) -- only launch it, and only kill it
    # again, when nothing was running to begin with; 20s is a generous wait
    # for a flatpak's first cold start to write its prefs.
    if [ ! -f "$SPOTIFY_PREFS" ]; then
        if pgrep -f 'com.spotify.Client' >/dev/null 2>&1; then
            warn "Spotify is already running with no prefs file yet — waiting"
            for _ in $(seq 1 20); do
                [ -f "$SPOTIFY_PREFS" ] && break
                sleep 1
            done
        else
            warn "no Spotify prefs yet — starting it briefly to generate them"
            flatpak run com.spotify.Client >/dev/null 2>&1 &
            sp_pid=$!
            for _ in $(seq 1 20); do
                [ -f "$SPOTIFY_PREFS" ] && break
                sleep 1
            done
            kill "$sp_pid" 2>/dev/null
            wait "$sp_pid" 2>/dev/null
            pkill -f 'com.spotify.Client' 2>/dev/null
        fi
    fi

    if [ -f "$SPOTIFY_PREFS" ]; then
        "$SPICETIFY" config spotify_path "$FLATPAK_SPOTIFY_USER_FILES" >/dev/null 2>&1
        "$SPICETIFY" config prefs_path "$SPOTIFY_PREFS" >/dev/null 2>&1
        "$SPICETIFY" config current_theme caelus24 >/dev/null 2>&1
        "$SPICETIFY" config color_scheme caelus >/dev/null 2>&1
        "$SPICETIFY" config home_config 1 >/dev/null 2>&1
        "$SPICETIFY" config sidebar_config 0 >/dev/null 2>&1
        "$SPICETIFY" config experimental_features 1 >/dev/null 2>&1
        SPICETIFY_INI="$HOME/.config/spicetify/config-xpui.ini"
        if [ ! -d "$MARKETPLACE_DIR" ]; then
            : # not downloaded, nothing to enable
        elif [ -f "$SPICETIFY_INI" ] && grep -q '^custom_apps.*marketplace' "$SPICETIFY_INI"; then
            : # already enabled -- config custom_apps appends, so skip re-adding
        else
            "$SPICETIFY" config custom_apps marketplace >/dev/null 2>&1
        fi
        if "$SPICETIFY" backup apply >/dev/null 2>&1; then
            ok "spicetify theme applied (caelus24)"
        else
            fail "spicetify backup apply failed — run it by hand: $SPICETIFY backup apply"
        fi
    else
        warn "Spotify prefs still missing — run Spotify once, then:"
        warn "  $SPICETIFY backup apply"
    fi
elif [ -n "$SPICETIFY" ] && [ -z "$SPOTIFY_SWITCH_NOTE" ]; then
    warn "no per-user Spotify install — spicetify config/apply skipped"
fi

# --- firefox ----------------------------------------------------------------
# userChrome.css/userContent.css only load from a profile's chrome/ directory,
# and Firefox only reads that directory at startup -- so, like the render
# above, this needs one Firefox restart before it does anything. Firefox
# >= ~147 moved the profile root to an XDG-style path (~/.config/mozilla/
# firefox, what this machine has); ~/.mozilla/firefox is the older layout,
# still checked as a fallback. installs.ini (new, keyed by install hash,
# Default=<relative path>) is preferred over profiles.ini's own Default=1
# flag -- the same order Firefox itself resolves a default profile in.
step "Firefox"

firefox_default_profile() {  # firefox_default_profile <profile-root>
    local root=$1 rel abs
    if [ -f "$root/installs.ini" ]; then
        rel=$(awk -F= '{ gsub(/\r$/, "") } /^Default=/ { print $2; exit }' "$root/installs.ini")
        if [ -n "$rel" ] && [ -d "$root/$rel" ]; then
            printf '%s\n' "$root/$rel"
            return 0
        fi
    fi
    if [ -f "$root/profiles.ini" ]; then
        # IsRelative=1 (the common case) means Path is under $root; =0 means
        # Path is already absolute. Default=1 marks the profile to use.
        # `exit` inside a rule still runs the END block below it, so a "done"
        # flag guards against printing the same match twice.
        abs=$(awk -v root="$root/" -F= '
            { gsub(/\r$/, "") }
            /^\[/          { if (!done && isdef && path != "") { done = 1; print (isrel == "0" ? path : root path); exit }
                              path = ""; isrel = "1"; isdef = 0 }
            /^Path=/       { path = $2 }
            /^IsRelative=/ { isrel = $2 }
            /^Default=/    { if ($2 == "1") isdef = 1 }
            END            { if (!done && isdef && path != "") print (isrel == "0" ? path : root path) }
        ' "$root/profiles.ini")
        if [ -n "$abs" ] && [ -d "$abs" ]; then
            printf '%s\n' "$abs"
            return 0
        fi
    fi
    return 1
}

profile=""
for root in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [ -d "$root" ] || continue
    profile=$(firefox_default_profile "$root") && break
done

if [ -z "$profile" ]; then
    warn "no Firefox profile found — start Firefox once, then re-run this script"
else
    # Stubs rather than links. Firefox lets a file: sheet @import only from
    # its own directory or below, and a symlinked sheet counts as living where
    # it points -- so chrome/userChrome.css as a link into the repo loses its
    # matugen.css import. Instead chrome/ holds two real two-line sheets that
    # import matugen.css and rd-shell/<sheet>, both symlinks sitting inside
    # chrome/, which Firefox follows. Anything else already there is backed up.
    link "$REPO/firefox" "$profile/chrome/rd-shell"
    for sheet in userChrome.css userContent.css; do
        dest="$profile/chrome/$sheet"
        stub="/* Written by rd-shell's install.sh; edit firefox/$sheet in the repo instead. */
@import \"matugen.css\";
@import \"rd-shell/$sheet\";"
        if [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(cat "$dest")" = "$stub" ]; then
            ok "$dest"
            continue
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            bak="$dest.bak-$(date +%Y%m%d-%H%M%S)"
            mv "$dest" "$bak"
            warn "existing $dest backed up to $bak"
        fi
        printf '%s\n' "$stub" > "$dest"
        ok "$dest"
    done
    # Points into the cache dir matugen writes to, not a repo file -- dangling
    # until the "First colour render" step above (or matugen failing there, or
    # the first wallpaper switch) actually writes it. link() doesn't care
    # either way, and neither does Firefox until the @import actually resolves.
    link "${XDG_CACHE_HOME:-$HOME/.cache}/rd-shell/firefox-colors.css" "$profile/chrome/matugen.css"

    USER_JS="$profile/user.js"
    PREF_LINE='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    if [ -f "$USER_JS" ] && grep -qF "$PREF_LINE" "$USER_JS"; then
        ok "user.js already allows chrome/ stylesheets"
    else
        printf '%s\n' "$PREF_LINE" >> "$USER_JS"
        ok "user.js: enabled chrome/ stylesheets"
    fi
fi

# --- Vencord call banner ----------------------------------------------------
# Vesktop sends no desktop notification for an incoming call, so the bar's
# call banner instead rides Vencord's built-in XSOverlay plugin: it already
# opens a WebSocket and posts a "ringing" message on CALL_UPDATE, which
# scripts/vencord-call-bridge.py (started by Services/DiscordCall.qml) turns
# into the banner. The plugin just needs pointing at that bridge's port with
# every other notification source it can also drive turned off, so only
# calls -- never message content -- ever reach it. Vesktop only reads this
# file at start, so nothing here can make the banner live without a restart;
# only wired up if Vesktop has been run at least once (nothing here installs
# or starts it, same as the rest of this script).
step "Vencord call banner (XSOverlay plugin)"
VESKTOP_SETTINGS="$HOME/.config/vesktop/settings/settings.json"
if [ ! -f "$VESKTOP_SETTINGS" ]; then
    warn "no $VESKTOP_SETTINGS — start Vesktop once, then re-run this script to wire up the call banner"
else
    want='{"enabled":true,"callNotifications":true,"preferUDP":false,"webSocketPort":42070,"dmNotifications":false,"groupDmNotifications":false,"serverNotifications":false,"botNotifications":false}'
    # Compared as data, not bytes: Vencord writes 4-space JSON and jq's own
    # formatting differs, so a byte compare would rewrite (and back up) the
    # file on every run. Written back at Vencord's own indent.
    if ! merged=$(jq --indent 4 --argjson want "$want" \
            '.plugins.XSOverlay = ((.plugins.XSOverlay // {}) + $want)' \
            "$VESKTOP_SETTINGS" 2>/dev/null); then
        fail "could not parse $VESKTOP_SETTINGS as JSON — leaving it untouched"
    elif jq -e --argjson want "$want" \
            '(.plugins.XSOverlay // {}) == ((.plugins.XSOverlay // {}) + $want)' \
            "$VESKTOP_SETTINGS" >/dev/null 2>&1; then
        ok "XSOverlay plugin already set up for the call banner"
    else
        bak="$VESKTOP_SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
        cp -p "$VESKTOP_SETTINGS" "$bak"
        tmp="$VESKTOP_SETTINGS.tmp.$$"
        if printf '%s\n' "$merged" > "$tmp" && mv "$tmp" "$VESKTOP_SETTINGS"; then
            chmod --reference="$bak" "$VESKTOP_SETTINGS" 2>/dev/null
            ok "XSOverlay plugin enabled for the call banner (backup: $bak)"
            warn "restart Vesktop for this to take effect"
        else
            rm -f "$tmp"
            fail "could not write $VESKTOP_SETTINGS — backup left at $bak"
        fi
    fi
fi

printf '\n\033[1;32mDone.\033[0m\n'

# --- summary -----------------------------------------------------------------
step "Summary — left to do by hand"
cat <<EOF
   Machine-specific lines already in hypr/hyprland.lua that only make sense
   on the machine this rice was copied from — edit them for yours:

     hl.monitor(...)      two outputs named DP-1 (2560x1440@240) and DP-2
                           (1920x1080@240, auto-right). Run 'hyprctl monitors'
                           for the names yours has, or delete both lines to
                           let Hyprland auto-detect.

     MAIN, SECOND          the same two output names again, used to split
                           workspaces 1-6 / 7-10 across the two screens.

     hl.env("LIBVA_DRIVER_NAME", "nvidia")
                           delete this line on a machine with no NVIDIA card;
                           left in, hardware video decoding just silently
                           does not use it.

     input.kb_layout = "us,de"
                           set to your own layouts. CTRL+SHIFT+SPACE cycles
                           it and the bar's keyboard pill only shows with
                           more than one listed.

     Firefox chrome/ stylesheets          restart Firefox once to load them.
                           Paste firefox/sidebery.css into Sidebery -> Settings
                           -> Styles, and firefox/stylus-global.user.css into
                           the Stylus style. The Sidebery/Stylus UUIDs baked
                           into firefox/userContent.css are from this machine —
                           swap in your own from
                           about:debugging#/runtime/this-firefox.

     vesktop / flatpak signal / wayvibes soundpacks
                           autostarted from hyprland.lua when present, never
                           installed here. Install the apps yourself, e.g.
                           'flatpak install flathub dev.vencord.Vesktop
                           org.signal.Signal'; their matugen themes are
                           already linked and follow on the next wallpaper
                           switch. Spotify (flatpak, per-user) and its
                           spicetify theme (caelus24) are installed above.
$SPOTIFY_SWITCH_NOTE
     dotfiles/fetchit/init.lua
                           the gpu line is typed out by hand for the machine
                           this came from — edit it for yours. The os line
                           now reads your own login (user.name) at runtime.

     login screen wallpaper
                           plasmalogin only follows the wallpaper after a
                           one-time root setup: 'sudo install -d -o \$USER
                           -g \$USER -m 755 /usr/share/backgrounds/rd-shell'
                           and pointing /etc/plasmalogin.conf at
                           current.png in there.
$HYPRLAND_CONF_NOTE
   Log out and pick "Hyprland" at the login screen. GTK/Qt colours now
   follow the wallpaper automatically (the GTK theme and KDE colour scheme
   steps above, refreshed by matugen on every switch); this installer only
   wires the dark palette, so switching to light mode is still a manual
   kcmshell6 kcm_style / kcm_colors change.

   See README.md in this repo for the full keybind list (or press Super+K)
   and a tour of the bar.
EOF
