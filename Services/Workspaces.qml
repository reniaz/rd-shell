pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var list: Hyprland.workspaces.values
    readonly property HyprlandWorkspace focused: Hyprland.focusedWorkspace
    readonly property int focusedId: focused?.id ?? -1
    readonly property string focusedName: focused?.name ?? ""

    function dotsFor(monitor) {
        return list
            .filter(w => w.id > 0 && w.monitor?.name === monitor?.name)
            .sort((a, b) => a.id - b.id);
    }

    function windowCount(id) {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === id).length;
    }

    function _ws(w) {
        return typeof w === "number" ? w : `"${w}"`;
    }

    function switchTo(w) {
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ workspace = ${_ws(w)}})`);
        else Hyprland.dispatch(`workspace ${w}`);
    }

    function moveTo(w) { 
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${_ws(w)}})`);
        else Hyprland.dispatch(`movetoworkspace ${w}`);
    }

    // Raises one window and goes to it, wherever something in the bar knows
    // which window it means. Dispatched the same way the workspace calls above
    // are, and for the same reason: under a Lua config every dispatch is
    // evaluated as Lua source, so the native `focuswindow address:0x...` is a
    // syntax error there -- Lua reads `address:0x...` as a method call and
    // rejects it -- whether it is sent through Hyprland.dispatch or through
    // hyprctl. hl.dsp.focus also carries the workspace switch, so one call both
    // raises the window and takes you to it.
    // Hyprland only answers to the 0x form, and half the places an address comes
    // from have already dropped the prefix: HyprlandToplevel.address is bare,
    // hyprctl prints it either way. Put back rather than required, so no caller
    // has to know which kind it is holding.
    function focusWindow(address) {
        if (!address || address === "") return;

        const target = address.startsWith("0x") ? address : `0x${address}`;
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${target}" })`);
        else Hyprland.dispatch(`focuswindow address:${target}`);
    }

    function relative(monitor, delta) {
        const dots = dotsFor(monitor);
        if (dots.length === 0) return;

        const i = dots.findIndex(w => w.id === monitor?.activeWorkspace?.id);
        switchTo(dots[(i + delta + dots.length) % dots.length].id);
    }
}
