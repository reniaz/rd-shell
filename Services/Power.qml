pragma Singleton
import Quickshell

Singleton {
    id: root

    // plasmalogin's greeter VT. NVIDIA + an SDDM-family display manager black-screens
    // on logout without this; adjust if the display manager moves.
    readonly property int greeterVt: 1

    // Owned here rather than by a Bar so the IPC handler and the pill drive the
    // same state. The Bar on the focused monitor is the one that renders it.
    property bool menuOpen: false

    readonly property var actions: [
        { icon: "power_settings_new", label: "Shut down", question: "Shut down?", run: () => root.shutdown() },
        { icon: "restart_alt",        label: "Restart",   question: "Restart?",   run: () => root.reboot() },
        // Locking is instantly reversible, so it is the one action that skips confirm.
        { icon: "lock",               label: "Lock",      confirm: false,         run: () => root.lock() },
        { icon: "logout",             label: "Log out",   question: "Log out?",   run: () => root.logout() },
    ]

    // hyprshutdown closes every client gracefully, then exits Hyprland. It does not
    // power the machine off itself, so restart/shutdown ride on --post-cmd.
    function lock() { Quickshell.execDetached(["hyprlock"]); }

    function logout() { _run([]); }
    function reboot() { _run(["--post-cmd", "systemctl reboot"]); }
    function shutdown() { _run(["--post-cmd", "systemctl poweroff"]); }

    function _args(extra) {
        return ["hyprshutdown", "--vt", String(greeterVt)].concat(extra);
    }

    function _run(extra) {
        Quickshell.execDetached(_args(extra));
    }
}
