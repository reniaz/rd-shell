import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Idea 10, the edit half of KeybindOverview.qml (SUPER+K, "Edit" toggle).
// KeybindOverview owns the list and the Edit/Reset controls; this is only
// the capture surface for one rebind at a time -- a focused Item that reads
// the next chord out of Keys.onPressed, shows it live, warns on a clash
// with whatever is bound right now (stock or already-overridden), and asks
// Services/Keybinds.qml to write it. That write is a full round trip
// (rewrite keybind-overrides.lua, hyprctl reload, hyprctl configerrors,
// roll back on any error) before `saveFinished` below says how it went --
// this dialog just waits and reports the result, it never touches the file.
Item {
    id: root

    // The row being rebound (a Keybinds.binds entry), or null: also what
    // makes the whole overlay invisible.
    property var target: null
    readonly property bool capturing: root.target !== null

    signal closed()

    function startCapture(bind) {
        root.target = bind;
        root._heldSuper = false;
        root._heldCtrl = false;
        root._heldAlt = false;
        root._heldShift = false;
        root._captured = null;
        root._conflict = null;
        root._error = "";
        root._saving = false;
        capture.forceActiveFocus();
    }

    function cancel() {
        root.target = null;
        root.closed();
    }

    function save() {
        if (!root._captured || root._saving) return;
        root._saving = true;
        root._error = "";
        Keybinds.saveOverride(root.target, root._captured);
    }

    property bool _heldSuper: false
    property bool _heldCtrl: false
    property bool _heldAlt: false
    property bool _heldShift: false
    property var _captured: null   // ["SUPER", "SHIFT", "K"] once a real key lands
    property var _conflict: null
    property string _error: ""
    property bool _saving: false

    function _modKeys() {
        const m = [];
        if (root._heldSuper) m.push("SUPER");
        if (root._heldCtrl) m.push("CTRL");
        if (root._heldAlt) m.push("ALT");
        if (root._heldShift) m.push("SHIFT");
        return m;
    }

    readonly property string liveText: root._captured
        ? root._captured.join(" + ")
        : (root._modKeys().length > 0 ? root._modKeys().join(" + ") + " + …" : "Press a key combo…")

    // Hyprland's own bind-key spelling (see hyprland.lua's binds and
    // scripts/keybinds.sh's `keyname`, whose display arrows this mirrors
    // back into config syntax) -- not the Material Symbol or display name,
    // this is what ends up inside a written hl.bind() call.
    function _keyName(key, text) {
        switch (key) {
        case Qt.Key_Left: return "left";
        case Qt.Key_Right: return "right";
        case Qt.Key_Up: return "up";
        case Qt.Key_Down: return "down";
        case Qt.Key_Space: return "SPACE";
        case Qt.Key_Return:
        case Qt.Key_Enter: return "Return";
        case Qt.Key_Tab: return "Tab";
        case Qt.Key_Backspace: return "BackSpace";
        case Qt.Key_Delete: return "Delete";
        case Qt.Key_Home: return "Home";
        case Qt.Key_End: return "End";
        case Qt.Key_PageUp: return "Page_Up";
        case Qt.Key_PageDown: return "Page_Down";
        case Qt.Key_QuoteLeft: return "grave";
        case Qt.Key_Minus: return "minus";
        case Qt.Key_Equal: return "equal";
        case Qt.Key_BracketLeft: return "bracketleft";
        case Qt.Key_BracketRight: return "bracketright";
        case Qt.Key_Backslash: return "backslash";
        case Qt.Key_Semicolon: return "semicolon";
        case Qt.Key_Apostrophe: return "apostrophe";
        case Qt.Key_Comma: return "comma";
        case Qt.Key_Period: return "period";
        case Qt.Key_Slash: return "slash";
        }
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1);
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        return text && text.length === 1 ? text.toUpperCase() : "";
    }

    function _onKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.cancel();
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_Shift:
            root._heldShift = true; event.accepted = true; return;
        case Qt.Key_Control:
            root._heldCtrl = true; event.accepted = true; return;
        case Qt.Key_Alt:
        case Qt.Key_AltGr:
            root._heldAlt = true; event.accepted = true; return;
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
            root._heldSuper = true; event.accepted = true; return;
        }
        // Modifiers Qt reports directly on this event are trusted too --
        // covers a compositor that never delivers a Super key-press event
        // of its own, only sets the modifier bit on the real key's event.
        const mods = {
            zuper: root._heldSuper || (event.modifiers & Qt.MetaModifier) !== 0,
            ctrl: root._heldCtrl || (event.modifiers & Qt.ControlModifier) !== 0,
            alt: root._heldAlt || (event.modifiers & Qt.AltModifier) !== 0,
            shift: root._heldShift || (event.modifiers & Qt.ShiftModifier) !== 0
        };
        const name = root._keyName(event.key, event.text);
        event.accepted = true;
        if (name === "") return; // unrecognised key -- ignore, keep waiting
        const combo = [];
        if (mods.zuper) combo.push("SUPER");
        if (mods.ctrl) combo.push("CTRL");
        if (mods.alt) combo.push("ALT");
        if (mods.shift) combo.push("SHIFT");
        combo.push(name);
        root._captured = combo;
        root._conflict = Keybinds.findConflict(combo, root.target ? root.target.ref : "");
    }

    function _onRelease(event) {
        switch (event.key) {
        case Qt.Key_Shift: root._heldShift = false; break;
        case Qt.Key_Control: root._heldCtrl = false; break;
        case Qt.Key_Alt:
        case Qt.Key_AltGr: root._heldAlt = false; break;
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R: root._heldSuper = false; break;
        }
        event.accepted = true;
    }

    Connections {
        target: Keybinds

        function onSaveFinished(ok, error) {
            if (!root.capturing) return; // not from this dialog (only one editor at a time)
            root._saving = false;
            if (ok) {
                root.target = null;
                root.closed();
            } else {
                root._error = error;
            }
        }
    }

    visible: root.capturing
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 440
        height: content.implicitHeight + Caelus.spaceEdge * 2
        radius: Caelus.radiusPopover
        color: Colors.surfaceRaised
        border.width: Caelus.borderWidth
        border.color: root._conflict ? Colors.warn : Colors.accent

        Item {
            id: capture

            anchors.fill: parent
            focus: root.capturing

            Keys.onPressed: event => root._onKey(event)
            Keys.onReleased: event => root._onRelease(event)
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: Caelus.spaceEdge
            spacing: Caelus.spaceWide

            Text {
                Layout.fillWidth: true
                text: root.target ? root.target.action : ""
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.target ? `currently ${root.target.keys.join(" + ")}` : ""
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.popupBorder
            }

            Text {
                Layout.fillWidth: true
                text: root.liveText
                color: root._conflict ? Colors.warn : Colors.popupAccent
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                visible: root._conflict !== null
                text: root._conflict ? `Already used by "${root._conflict.action}" -- Save replaces it` : ""
                color: Colors.warn
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root._error.length > 0
                text: root._error
                color: Colors.error
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.space

                Text {
                    text: "Escape to cancel"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root._saving ? "Saving…" : "Save"
                    color: root._captured && !root._saving ? Colors.popupAccent : Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody

                    MouseArea {
                        id: saveArea

                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root._captured !== null && !root._saving
                        cursorShape: saveArea.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.save()
                    }
                }
            }
        }
    }
}
