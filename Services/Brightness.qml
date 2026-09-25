pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Backlight brightness through brightnessctl. hyprland.lua's XF86MonBrightness*
// binds call the same binary directly rather than going through this shell, so
// this is not the only thing that ever changes the backlight -- the sysfs file
// below is watched instead of polled, which is what lets a hardware key be
// picked up exactly like a change made through this service, with nothing
// asking on a timer either way.
//
// This machine's outputs are DP-1/DP-2 with no backlight device at all, which
// `brightnessctl -c backlight` reports as a class with zero devices. The bare
// default (no -c) does not: it falls back to whatever class it finds first,
// which on this box is a keyboard LED reporting a max brightness of 1 -- and
// would be read as a real backlight sitting at 0% forever.
//
// A desktop with no backlight is not a desktop with no brightness control,
// though -- see Services/Ddc.qml. When the startup probe finds nothing, this
// singleton falls back to driving Ddc for whichever screen is currently
// focused, behind the exact same available/brightness/percent/set/step/
// osdVisible surface, so BrightnessOsd.qml and anything else already wired
// to this service need not know or care which path answered it. A laptop
// with a real backlight never takes this path at all.
Singleton {
    id: root

    // False until the startup probe finds a real device, and forever after if
    // it does not -- unless that "forever after" hands off to Ddc instead, in
    // which case this tracks Ddc's own readiness for the focused screen. No
    // retry of the backlight probe itself: a backlight that is not there at
    // startup is not going to appear, and asking again would be the
    // retry-on-a-loop the §4 contract rules out.
    property bool available: false

    // True once the probe has confirmed there is no real backlight, so every
    // read and write below goes through Ddc instead. Decided once, at probe
    // time -- the two paths never both apply to the same running shell.
    property bool _usingDdc: false

    readonly property real brightness: root._usingDdc
        ? Math.max(0, root._ddcPercent) / 100
        : (root._max > 0 ? root._current / root._max : 0)
    readonly property int percent: Math.round(root.brightness * 100)

    property int _current: 0
    property int _max: 0
    property string _device: ""

    // Ddc mutates its cache in place and announces the change with its own
    // `changed` signal rather than a property reassignment, so nothing here
    // can just bind to Ddc.brightness() and expect it to move on its own --
    // this is refreshed explicitly from the Connections block below.
    property int _ddcPercent: -1

    // Hyprland.focusedMonitor?.name, sticky the same way Bar.qml's
    // overlayScreen is: Hyprland can report no focused monitor at all while
    // a layer surface holds keyboard focus, which is exactly what dragging a
    // slider driven by this value would be doing.
    property string _focusedScreen: Hyprland.focusedMonitor?.name
        ?? Quickshell.screens[0]?.name ?? ""

    // Same shape as KeyboardLayout.osdVisible: a pulse the OSD pulls, raised
    // by whatever changed rather than mirrored straight off the value.
    property bool osdVisible: false

    // The first read on either path is the level the display already had
    // before this shell looked at it, not a change to announce -- the same
    // trap KeyboardLayout.qml guards against on its first devices query.
    property bool _announced: false

    function set(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));

        if (root._usingDdc) {
            if (!root.available) return;
            Ddc.setBrightness(root._focusedScreen, clamped);
            return;
        }

        if (!root.available) return;
        setProc.command = ["brightnessctl", "-c", "backlight", "-d", root._device,
            "set", clamped + "%"];
        setProc.running = true;
    }

    function step(deltaPct) {
        root.set(root.percent + deltaPct);
    }

    // Pulls available/_ddcPercent from Ddc for whichever screen is currently
    // focused. Called whenever either of those could have moved: Ddc finishing
    // detection, or focus moving to a different monitor -- a real change in
    // cached value is picked up separately, by the Connections block below,
    // since Ddc announces those through its own signal instead.
    function _syncDdc() {
        root.available = Ddc.has(root._focusedScreen);
        if (!root.available) return;

        const v = Ddc.brightness(root._focusedScreen);
        if (v >= 0) root._ddcPercent = v;
    }

    // device,class,current,percent,max -- brightnessctl's own machine format
    // for a single device. A short line, a missing field or a max of zero all
    // mean the same thing: nothing usable came back, whether that is because
    // the binary is missing (sh's own "not found" lands on stderr, swallowed
    // below) or because -c backlight simply found no device.
    function _probed(text) {
        const f = (text.trim().split("\n")[0] ?? "").split(",");

        if (f.length < 5 || !(parseInt(f[4]) > 0)) {
            // No real backlight on this machine -- fall through to Ddc for
            // whichever screen is focused. _syncDdc() covers the case where
            // Ddc's detection has already finished by the time this probe
            // comes back; the Connections block below covers it finishing
            // later, which is the common case since a getvcp round trip is
            // slower than this probe.
            root._usingDdc = true;
            root._syncDdc();
            return;
        }

        root._device = f[0];
        root._current = parseInt(f[2]);
        root._max = parseInt(f[4]);
        root.available = true;

        // Only watched once a real device is confirmed. An unset path never
        // opens a watch, so a machine with no backlight never touches the
        // filesystem again after this one probe.
        watcher.path = `/sys/class/backlight/${root._device}/brightness`;
    }

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["sh", "-c", "brightnessctl -c backlight -m info 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._probed(this.text)
        }
    }

    Process {
        id: setProc
    }

    // Keeps _focusedScreen current the same way Bar.qml's overlayScreen does,
    // and -- only on the Ddc path -- re-syncs available/_ddcPercent when focus
    // moves to a different monitor, since that can change which screen (or
    // whether any screen) is DDC-controllable without Ddc's own cache having
    // changed at all.
    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            const name = Hyprland.focusedMonitor?.name ?? "";
            if (name === "") return;

            root._focusedScreen = name;
            if (root._usingDdc) root._syncDdc();
        }
    }

    // Ddc's two ways of telling this singleton something moved: `ready`
    // once detection finishes (covers a probe that resolved before Ddc did),
    // and `changed` for every cache update after that -- a set() call here,
    // a slider on EdgeSlider.qml driving Ddc directly, or the priming read
    // that first learns the screen's real value.
    Connections {
        target: Ddc

        function onReadyChanged() {
            if (root._usingDdc) root._syncDdc();
        }

        function onChanged(screenName) {
            if (!root._usingDdc || screenName !== root._focusedScreen) return;

            const v = Ddc.brightness(screenName);
            if (v < 0) return;

            root.available = true;

            // Ddc raises one `changed` per screen for either property it
            // caches, so this fires on a contrast drag every bit as much as
            // on a brightness one -- and the contrast slider popping the
            // brightness OSD, reading a number that had not moved, is what
            // that cost before this guard. Brightness standing still is the
            // whole test: whatever else moved on that screen is not this
            // singleton's to announce.
            const moved = v !== root._ddcPercent;
            root._ddcPercent = v;

            if (!root._announced) {
                root._announced = true;
                return;
            }

            if (!moved) return;

            root.osdVisible = true;
            osdHold.restart();
        }
    }

    // The only source of truth once a device exists: this fires whether the
    // change came from set() above or from brightnessctl called directly by a
    // hardware key in hyprland.lua, and an inotify watch costs nothing while
    // no write happens -- unlike a timer, which would ask whether one had.
    FileView {
        id: watcher
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const v = parseInt(text());
            if (!(v >= 0)) return;

            root._current = v;

            if (!root._announced) {
                root._announced = true;
                return;
            }

            root.osdVisible = true;
            osdHold.restart();
        }
    }

    Timer {
        id: osdHold
        interval: 1200
        onTriggered: root.osdVisible = false
    }
}
