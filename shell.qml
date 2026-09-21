//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.Services

ShellRoot {
    // Above the Bar variants so the background-layer wallpaper surface is
    // created first on every screen -- order here has no bearing on the
    // compositor's actual layer stacking (WlrLayershell.layer does that), it
    // just means Wallpaper never has to race Bar's own startup.
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Bound to Super+M in hyprland.lua: qs ipc -c rd-shell call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void {
            Power.menuOpen = !Power.menuOpen;
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
}
