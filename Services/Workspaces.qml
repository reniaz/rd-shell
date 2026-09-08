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

    function relative(monitor, delta) {
        const dots = dotsFor(monitor);
        if (dots.length === 0) return;

        const i = dots.findIndex(w => w.id === monitor?.activeWorkspace?.id);
        switchTo(dots[(i + delta + dots.length) % dots.length].id);
    }
}
