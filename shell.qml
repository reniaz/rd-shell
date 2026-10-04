//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.Services

ShellRoot {
    // Above the BarWindow variants so the background-layer wallpaper surface
    // is created first on every screen -- order here has no bearing on the
    // compositor's actual layer stacking (WlrLayershell.layer does that), it
    // just means Wallpaper never has to race BarWindow's own startup.
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    // One fused window per screen -- bar strip, islands and every popup that
    // used to be its own PanelWindow now live inside it (Tier 3).
    // BarWindow.qml is a Scope, not a window itself: it holds the exclusion
    // window that reserves the 44px strip and the actual fused surface as
    // two siblings, since wlr-layer-shell will not honour a positive
    // exclusiveZone on a surface anchored to all four edges.
    Variants {
        model: Quickshell.screens

        BarWindow {}
    }

    // Hover-revealed per-monitor edge panel (brightness/contrast over DDC) --
    // see EdgeBar.qml. One per screen, same idiom as Wallpaper and BarWindow
    // above; EdgeBar itself works out which screen gets which edge from
    // geometry.
    Variants {
        model: Quickshell.screens

        EdgeBar {}
    }

    // The desktop layer: giant clock + now-playing card, seen on an empty
    // workspace or through the gaps between tiles. See DesktopWidgets.qml
    // for the layer it sits on; it hides itself entirely when
    // Settings.desktopWidgets is off, so this Variants block stays
    // unconditional the same way BarWindow's does.
    Variants {
        model: Quickshell.screens

        DesktopWidgets {}
    }

    // Bound to Super+M in hyprland.lua: qs ipc -c rd-shell call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void {
            Power.menuOpen = !Power.menuOpen;
        }
    }

    // Bound to Super+Space in hyprland.lua, replacing the rofi shell-out:
    // qs ipc -c rd-shell call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Apps.toggle();
        }
    }

    // Bound to Super+K in hyprland.lua: qs ipc -c rd-shell call keybinds toggle
    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            Keybinds.toggle();
        }
    }

    // Bound to Super+N in hyprland.lua: qs ipc -c rd-shell call notifications toggle
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Notifications.togglePanel();
        }

        // same toggle the panel's bell performs; handy for a keybind
        function dnd(): void {
            Notifications.toggleDnd();
        }
    }

    // qs ipc -c rd-shell call system toggle
    IpcHandler {
        target: "system"

        function toggle(): void {
            SysMon.togglePanel();
        }
    }

    // Bound to Super+I in hyprland.lua: qs ipc -c rd-shell call settings toggle.
    // `open <page>` is the same call SettingsPopup.qml's "All settings" row and
    // the in-shell launcher's built-in "Settings" result use, just over IPC
    // instead of a function call -- `qs ipc -c rd-shell call settings open bar`
    // opens straight to the Bar page.
    IpcHandler {
        target: "settings"

        function toggle(): void {
            SettingsApp.toggle();
        }

        function open(page: string): void {
            SettingsApp.show(page);
        }
    }

    // The settings window itself -- a real xdg toplevel (SettingsWindow.qml's
    // own FloatingWindow), not a layer-shell overlay, so it is zero cost while
    // closed: LazyLoader only ever instantiates it while SettingsApp.open is
    // true, and destroys it the instant that goes false again, whichever side
    // -- Esc inside the window, Super+I, the IPC call, or the compositor
    // closing it directly -- flipped the flag.
    LazyLoader {
        active: SettingsApp.open

        SettingsWindow {}
    }

    // qs ipc -c rd-shell call claude toggle — unbound by default; the pill opens it too
    IpcHandler {
        target: "claude"

        function toggle(): void {
            ClaudeSession.togglePanel();
        }
    }

    // Bound to CTRL+ALT+F in hyprland.lua: qs ipc -c rd-shell call wallpaper toggle.
    // There is no pill for this one -- the switcher covers the screen and is only
    // ever wanted on purpose, so the keybind is the whole of its way in.
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            Wallpapers.togglePanel();
        }
    }

    // Bound to CTRL+ALT+B in hyprland.lua: qs ipc -c rd-shell call barstyle toggle.
    // No pill for the same reason as the wallpaper switcher above.
    IpcHandler {
        target: "barstyle"

        function toggle(): void {
            BarStyles.togglePanel();
        }
    }

    // Bound to CTRL+ALT+P in hyprland.lua: qs ipc -c rd-shell call animpresets
    // toggle. No pill, same reasoning as the bar style switcher above.
    IpcHandler {
        target: "animpresets"

        function toggle(): void {
            AnimPresets.togglePanel();
        }
    }

    // Bound to CTRL+ALT+U in hyprland.lua: qs ipc -c rd-shell call utilities toggle.
    // No pill, same reasoning as the wallpaper and bar-style switchers above --
    // a region-grab tool is only ever wanted on purpose.
    IpcHandler {
        target: "utilities"

        function toggle(): void {
            Utilities.togglePanel();
        }
    }

    // The "Utilities" tray (read text / pick colour / scan QR) -- one per
    // screen like Wallpaper/BarWindow/DesktopWidgets above, but gated to
    // whichever one is actually focused through Services/Utilities.qml's own
    // `focusedScreen` (the same "sticky, not a live binding" idea BarWindow.qml's
    // `overlayScreen` uses for every other keybind-driven overlay, kept local to
    // this file since BarWindow.qml/BarOverlays.qml are not this round's to
    // touch) so a keybind press opens exactly one copy of it. PopupLoader buys
    // it the same animated-exit hold every bar popup gets -- see PopupLoader.qml.
    Variants {
        model: Quickshell.screens

        PopupLoader {
            required property var modelData

            open: Utilities.panelOpen && modelData.name === Utilities.focusedScreen

            UtilityTray {
                screen: modelData
            }
        }
    }

    // Native WlSessionLock lock screen (idea 15) -- reachable over IPC only
    // (target "lock": lock(), test(seconds), status()), never bound to a key.
    // hyprlock stays the real default for Super+L and hypridle; this is
    // opt-in until it has proven itself. Not a Variants block: WlLock.qml's
    // own WlSessionLock creates one surface per screen internally. See
    // WlLock.qml for the safety invariant this depends on.
    WlLock {}

    // Idea 31 -- clipboard-paste ripple. Not a Variants block over every
    // screen: ClipboardRipple.qml is one persistent, always-mapped overlay
    // that re-targets itself onto whichever monitor is focused at the
    // moment a copy fires (see its own header for why). Gated on
    // Settings.clipboardRipple internally, including the wl-paste process
    // itself, so there is nothing more to gate here.
    ClipboardRipple {}
}
