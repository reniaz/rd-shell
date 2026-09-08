pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    // Short code of the active layout, e.g. "US" or "DE".
    property string code: ""

    // xkb display name of that same layout, e.g. "English (US)". Carried
    // alongside the code because the OSD has room to say which layout you just
    // landed on, where the pill only has room for the code.
    property string keymap: ""

    // Raised for one beat after every switch. Driven by the code changing and
    // not by whatever caused it, so the pill's click and the Hyprland keybind
    // both announce themselves without either knowing about the OSD.
    property bool osdVisible: false

    // The first code to arrive describes the layout that was already in force
    // when the shell started, and a config reload re-runs the same query. Both
    // would flash an OSD announcing a switch that never happened.
    property bool _announced: false

    // xkb display name ("German") to configured code ("de"). The activelayout
    // event names only the keymap, so the pairing is learned from the device
    // query and served from here afterwards: every switch past the first of a
    // given layout redraws straight off the event, with no process in between.
    // Keyed by name rather than index, so reordering kb_layout cannot stale it.
    property var _names: ({})

    // "all" so every keyboard follows; switching one device leaves the rest on
    // the old layout. Not Hyprland.dispatch: this config is Lua, where dispatch
    // is routed through hl.dispatch() and cannot express a native dispatcher.
    function cycle() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    // active_keymap is the display name; the configured codes are in layout,
    // indexed by active_layout_index, and a code is what belongs on a pill.
    function _parse(text) {
        const kb = JSON.parse(text).keyboards;
        const main = kb.find(k => k.main) ?? kb[0];
        if (!main) return;

        root._learn(main.active_keymap, main.layout.split(",")[main.active_layout_index]);
    }

    function _learn(name, code) {
        if (!code) return;

        root._names[name] = code;
        root.keymap = name;
        root.code = code.toUpperCase();
    }

    // A handler and not a binding: the OSD is a pulse with its own hold timer,
    // so it has to be raised by the change rather than derived from the value.
    onCodeChanged: {
        if (root.code === "") return;

        if (!root._announced) {
            root._announced = true;
            return;
        }

        root.osdVisible = true;
        osdHold.restart();
    }

    Timer {
        id: osdHold
        interval: 1200
        onTriggered: root.osdVisible = false
    }

    Process {
        id: query
        command: ["hyprctl", "-j", "devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Connections {
        target: Hyprland

        // "activelayout>><keyboard>,<keymap>", emitted once per keyboard. They
        // all switch together, so any one line carries the new layout and the
        // repeats settle on the same code, which QML drops as a no-op write.
        // A keymap seen for the first time falls back to the query, which both
        // resolves it and records it. Config reloads can change kb_layout under
        // us, so they re-query too.
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                query.running = true;
                return;
            }

            if (event.name !== "activelayout")
                return;

            const name = event.data.slice(event.data.indexOf(",") + 1);
            const code = root._names[name];

            if (code) {
                root.keymap = name;
                root.code = code.toUpperCase();
            } else {
                query.running = true;
            }
        }
    }
}
