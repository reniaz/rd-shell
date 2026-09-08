#!/usr/bin/env bash
# rd shell — one-time setup.
#
# Installs the packages the shell shells out to (including the two COPRs
# neither quickshell nor Hyprland ship in Fedora proper), links the config
# and its hypr scripts into place, and clears the system-level problems that
# otherwise leave its services dead: a notification daemon competing for the
# D-Bus name, and a third-party PipeWire drop-in that can take the whole
# audio stack down at boot.
#
# Safe to re-run: every step checks before it changes anything.
#
#     ./install.sh          interactive
#     ./install.sh -y       assume yes
#
# See "READ DAS HIER.md" for the compositor binds this prints at the end,
# a tour of the bar, and troubleshooting.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=rd-shell
FONT_DIR="$HOME/.local/share/fonts"
MSR_FILE='MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf'
MSR_URL='https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'
IRIUN_CONF=/usr/share/pipewire/pipewire.conf.d/iriunaudio.conf

# Fedora 44's dnf is dnf5; fall back to dnf so the script does not just die
# on an older system, but the COPR/rpmfusion flow below is written for dnf5.
DNF=dnf5
command -v dnf5 >/dev/null 2>&1 || DNF=dnf

ASSUME_YES=0
[ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ] && ASSUME_YES=1

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

# --- repositories -------------------------------------------------------
# quickshell is not in Fedora's own repos in the version this config is
# developed against (Fedora carries an older one). The Hyprland COPR is only
# reached for when hyprlock or hyprshutdown is missing — those two are what the
# power menu shells out to. The compositor itself is never installed or
# configured here: that is your setup, not the bar's.
# nvidia-settings needs rpmfusion-nonfree, and only on a machine with the card.
COPRS="errornointernet/quickshell"
if ! command -v hyprlock >/dev/null 2>&1 || ! command -v hyprshutdown >/dev/null 2>&1; then
    COPRS="$COPRS lionheartp/Hyprland"
fi

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
            elif ask "enable rpmfusion-$rf (needed for nvidia-settings)?"; then
                sudo dnf5 install -y \
                    "https://download1.rpmfusion.org/$rf/fedora/rpmfusion-$rf-release-$(rpm -E %fedora).noarch.rpm" \
                    >/dev/null 2>&1 && ok "rpmfusion-$rf enabled" || fail "could not enable rpmfusion-$rf"
            else
                warn "rpmfusion-$rf skipped; nvidia-settings below will fail to install"
            fi
        done
    fi
fi

# --- packages -------------------------------------------------------------
# Command the shell runs -> Fedora package providing it -> req(uired) or
# opt(ional). Optional ones still get offered below, just without the loud
# red fail() — the matching feature is simply disabled without them.
DEPS="
qs:quickshell:req
hyprlock:hyprlock:req
hyprshutdown:hyprshutdown:req
nmcli:NetworkManager:req
kcmshell6:kf6-kcmutils:req
pavucontrol:pavucontrol:req
wpctl:wireplumber:req
notify-send:libnotify:req
jq:jq:req
awk:gawk:req
top:procps-ng:req
free:procps-ng:req
df:coreutils:req
curl:curl:req
grim:grim:req
slurp:slurp:req
wl-copy:wl-clipboard:req
brightnessctl:brightnessctl:opt
playerctl:playerctl:opt
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

# Hyprland itself is deliberately absent from DEPS: the bar does not install
# your compositor. hyprctl is only probed so the widgets that talk to it can
# say why they are inert.
if command -v hyprctl >/dev/null 2>&1; then
    ok "hyprctl"
else
    warn "hyprctl not found — install and run Hyprland yourself; without it the"
    warn "  workspace dots, the keyboard-layout pill and window focus stay inert"
fi

# plasma-nm ships no binary of its own; the network pill's right-click opens
# this KCM through kcmshell6.
if compgen -G '/usr/lib*/qt6/plugins/plasma/kcms/*/kcm_networkmanagement.so' >/dev/null; then
    ok "kcm_networkmanagement"
else
    fail "kcm_networkmanagement (package plasma-nm)"
    missing+=(plasma-nm)
fi

# nvidia-settings only matters — and only installs cleanly — on a box that
# actually has the card; nvidia-smi has no Fedora package at all (it ships
# with cuda-devel) so it is deliberately not probed for here.
if has_nvidia; then
    if command -v nvidia-settings >/dev/null 2>&1; then
        ok "nvidia-settings"
    else
        warn "nvidia-settings not found (package nvidia-settings) — GPU temp/VRAM/fan will be blank"
        missing+=(nvidia-settings)
    fi
else
    ok "no NVIDIA card detected — nvidia-settings not needed"
fi

if [ ${#missing[@]} -gt 0 ]; then
    # procps-ng backs both top and free, so it lands in the list twice; dnf
    # copes, but a summary line that names a package twice reads like a bug.
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
    printf '   missing: %s\n' "${missing[*]}"
    if ask "install them with $DNF?"; then
        sudo "$DNF" install -y "${missing[@]}" || warn "$DNF install failed; install the packages above by hand"
    else
        warn "skipped; the matching features will not work until these are installed"
    fi
fi

# --- fonts ------------------------------------------------------------------
step "Material Symbols Rounded"
# grep -q closes the pipe early, which trips pipefail; match on the string instead.
if [ "$(fc-match -f '%{family}' 'Material Symbols Rounded' 2>/dev/null)" = 'Material Symbols Rounded' ]; then
    ok "font installed"
elif ask "not found — download it from github.com/google/material-design-icons?"; then
    mkdir -p "$FONT_DIR"
    if curl -fL --progress-bar -o "$FONT_DIR/$MSR_FILE" "$MSR_URL"; then
        fc-cache -f "$FONT_DIR" >/dev/null
        ok "installed to $FONT_DIR"
    else
        rm -f "$FONT_DIR/$MSR_FILE"
        fail "download failed — every icon in the bar will render as a box"
    fi
else
    warn "without it every icon in the bar renders as a box"
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

# --- config link ------------------------------------------------------------
step "Config"
link() {  # link <target> <link-path>
    local target=$1 path=$2
    mkdir -p "$(dirname "$path")"
    if [ "$(readlink -f "$path" 2>/dev/null)" = "$(readlink -f "$target")" ]; then
        ok "$path"
        return
    fi
    if [ -e "$path" ] && [ ! -L "$path" ]; then
        mv "$path" "$path.bak"
        warn "existing $path moved to $path.bak"
    fi
    ln -sfn "$target" "$path"
    ok "$path -> $target"
}

link "$REPO" "$HOME/.config/quickshell/$CONFIG"
link "$REPO/scripts/mic-toggle.sh" "$HOME/.config/hypr/scripts/mic-toggle.sh"
link "$REPO/scripts/screenshot.sh" "$HOME/.config/hypr/scripts/screenshot.sh"

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

# --- compositor -------------------------------------------------------------
step "Compositor"
cat <<EOF
   Add to hyprland.lua:

     hl.exec_cmd("$HOME/.config/quickshell/$CONFIG/launch.sh")

     hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc -c $CONFIG call power toggle"))
     hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
     hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc -c $CONFIG call notifications toggle"))

     hl.bind("CTRL + SHIFT + M", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/mic-toggle.sh"))
     hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/mic-toggle.sh"),
             { locked = true, repeating = true })

     hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

     hl.bind("CTRL + ALT + up", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenshot.sh area"))

   or hyprland.conf:

     exec-once = $HOME/.config/quickshell/$CONFIG/launch.sh

     bind = SUPER, M, exec, qs ipc -c $CONFIG call power toggle
     bind = SUPER, L, exec, hyprlock
     bind = SUPER, N, exec, qs ipc -c $CONFIG call notifications toggle

     bind = CTRL SHIFT, M, exec, $HOME/.config/hypr/scripts/mic-toggle.sh
     bindl = , XF86AudioMicMute, exec, $HOME/.config/hypr/scripts/mic-toggle.sh

     bind = CTRL SHIFT, SPACE, exec, hyprctl switchxkblayout all next

     bind = CTRL ALT, up, exec, $HOME/.config/hypr/scripts/screenshot.sh area

   The CTRL+SHIFT+SPACE bind (and the pill it drives) only does anything if
   hyprland's input.kb_layout lists two layouts, e.g. kb_layout = "us,de".

   See "READ DAS HIER.md" in this repo for what each of the above does, a
   tour of the bar, and troubleshooting.
EOF

printf '\n\033[1;32mDone.\033[0m Start it now with: %s/launch.sh\n\n' "$REPO"
