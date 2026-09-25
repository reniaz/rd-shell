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
