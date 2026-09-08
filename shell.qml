//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.Services

ShellRoot {
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
}
