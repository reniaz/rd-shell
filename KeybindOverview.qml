import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Every Hyprland bind, searchable (SUPER+K in hyprland.lua). The same card as
// Launcher.qml -- centred over a scrim, blurred, accent-edged, one search
// field that owns the keyboard -- because it is the same kind of thing: a
// list you type at to narrow. Enter (or a click) runs the selected bind, as
// if its keys had been pressed. Escape or a click outside closes it, and
// those two exits are wired as directly as in the launcher for the same
// reason: this window takes the whole keyboard.
PanelWindow {
    id: root

    signal dismissed()

    // Same open/_entered contract as Launcher.qml and every other overlay.
    property bool open: true
    property bool _entered: false
    readonly property bool shown: root._entered && root.open

    readonly property var results: Keybinds.results
    property int index: 0

    // Idea 10: edit mode turns Enter/click from "run this bind" into
    // "capture a new chord for it" -- KeybindManager.qml is the capture
    // dialog itself, this only decides when it opens and shows the
    // Edit/Reset controls and their status line.
    property bool editMode: false
    property string resetStatus: ""

    // Back to the top on every keystroke: unlike the launcher there is no
    // "the row you were about to pick" to keep, and the best match is first.
    onResultsChanged: root.index = 0

    function move(delta) {
        if (root.results.length === 0) return;
        root.index = Math.max(0, Math.min(root.results.length - 1, root.index + delta));
    }

    // Closes first, then runs: the bind should land on whatever was focused
    // before the overview opened, with the keyboard already handed back --
    // a bind that opens another overlay (the launcher, the switcher) must not
    // find this one still holding it.
    function activate(i) {
        const bind = root.results[i];
        if (!bind) return;
        root.close();
        Keybinds.run(bind);
    }

    // A mouse-drag bind (SUPER + LMB/RMB) carries no ref -- nothing the
    // overrides mechanism can re-invoke -- so it is left out of edit mode
    // rather than offered a rebind control that can never save.
    function startEdit(i) {
        const bind = root.results[i];
        if (!bind || !/^[0-9]+$/.test(bind.ref ?? "")) return;
        manager.startCapture(bind);
    }

    // The token `Keybinds.resetOverrides` handed back for the reset in
    // flight, so a saveFinished meant for some other save/reset (a rebind
    // started right after, say) gets ignored instead of overwriting
    // `resetStatus` with that unrelated result.
    property var _resetToken: null

    function resetToDefaults() {
        root.resetStatus = "Resetting…";
        root._resetToken = Keybinds.resetOverrides();
    }

    function close() {
        search.text = "";
        Keybinds.query = "";
        root.index = 0;
        root.editMode = false;
        root.resetStatus = "";
        if (manager.capturing) manager.cancel();
        root.dismissed();
    }

    // Belt-and-suspenders for the ShortcutInhibitor below: `close()` above
    // already cancels a capture on the way out, but `root.open` can also go
    // false without going through it -- SUPER+K again while mid-capture
    // calls Keybinds.toggle() directly, which this window only ever sees as
    // a change to `open`. Either way the inhibitor's `enabled` binding
    // follows `manager.capturing`, so cancelling here is what actually lets
    // go of the compositor's shortcuts once the sheet is on its way out.
    onOpenChanged: if (!root.open && manager.capturing) manager.cancel()

    Connections {
        target: Keybinds

        function onSaveFinished(ok, error, token) {
            // Only the reset flow reports through this label -- a rebind's
            // own result shows inside KeybindManager.qml's own dialog, which
            // is still open (or just closed itself) when this fires.
            if (root.resetStatus === "") return;
            if (token !== root._resetToken) return; // not the reset this label is waiting on
            root.resetStatus = ok ? "Reset" : error;
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-keybinds"
    color: "transparent"

    mask: root.open ? null : closedMask
    Region { id: closedMask }

    Component.onCompleted: root._entered = true

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.shown ? 0.5 : 0

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.close()
        }
    }

    readonly property int rowHeight: 34
    readonly property int visibleRows: 12
    // Wide enough for the longest combo in use (CTRL + SHIFT + SPACE) as
    // keycaps, so every description starts on the same line.
    readonly property int keysWidth: 230

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 640
        height: layout.implicitHeight + Caelus.spaceEdge * 2
        radius: Caelus.radiusIsland
        // Translucent and blurred like the launcher -- see the
        // `quickshell-osd-blur` layer rule in hyprland.lua.
        color: Qt.rgba(Colors.surfaceRaised.r, Colors.surfaceRaised.g,
                       Colors.surfaceRaised.b, 0.55)
        border.width: Caelus.borderWidth
        border.color: Colors.accent

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Caelus.spaceEdge
            spacing: Caelus.spaceWide

            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.space

                Text {
                    text: "keyboard"
                    color: Colors.popupAccent
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: search.implicitHeight

                    TextInput {
                        id: search

                        anchors.fill: parent
                        color: Colors.fg
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                        selectByMouse: true
                        focus: true

                        onTextEdited: Keybinds.query = search.text

                        // Same BeforeItem split as the launcher: only the
                        // keys accepted here are claimed, typing still edits.
                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.close();
                                break;
                            case Qt.Key_Up:
                                root.move(-1);
                                break;
                            case Qt.Key_Down:
                                root.move(1);
                                break;
                            case Qt.Key_PageUp:
                                root.move(-root.visibleRows);
                                break;
                            case Qt.Key_PageDown:
                                root.move(root.visibleRows);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                if (root.editMode) root.startEdit(root.index);
                                else root.activate(root.index);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search keybinds…"
                        visible: search.text.length === 0
                        color: Colors.fgDim
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                    }
                }

                // How many binds the current search leaves, out of all of
                // them -- the one way to tell "no bind for that" from "typo".
                Text {
                    text: search.text.length > 0
                        ? `${root.results.length}/${Keybinds.binds.length}`
                        : `${Keybinds.binds.length}`
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                // Idea 10: the edit-mode toggle. "Reset to defaults" and its
                // status only show up once inside edit mode -- there is
                // nothing to reset from the read-only view, and the label
                // would just be clutter there.
                Text {
                    text: root.editMode ? "done" : "edit"
                    color: root.editMode ? Colors.popupAccent : Colors.fgMuted
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editMode = !root.editMode;
                            if (!root.editMode) root.resetStatus = "";
                        }
                    }
                }

                Text {
                    visible: root.editMode
                    text: "Reset to defaults"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToDefaults()
                    }
                }

                Text {
                    visible: root.editMode && root.resetStatus.length > 0
                    text: root.resetStatus
                    color: root.resetStatus === "Reset" || root.resetStatus === "Resetting…"
                        ? Colors.fgMuted : Colors.error
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.popupBorder
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: root.visibleRows * root.rowHeight
                    + (root.visibleRows - 1) * Caelus.spaceTight
                clip: true
                spacing: Caelus.spaceTight
                model: root.results
                currentIndex: root.index

                onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: list.width
                    height: root.rowHeight
                    radius: Caelus.radiusCard
                    color: row.index === root.index ? Colors.surfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Caelus.spaceWide
                        anchors.rightMargin: Caelus.spaceWide
                        spacing: Caelus.spaceWide

                        // One keycap per key, joined by nothing: the caps
                        // themselves say "together", a "+" between them only
                        // adds width.
                        Row {
                            Layout.preferredWidth: root.keysWidth
                            spacing: Caelus.spaceTight

                            Repeater {
                                model: row.modelData.keys

                                Rectangle {
                                    id: cap

                                    required property string modelData

                                    width: capText.implicitWidth + 2 * Caelus.space
                                    height: capText.implicitHeight + Caelus.spaceTight
                                    radius: Caelus.radiusChip
                                    color: Colors.surfaceRaised
                                    border.width: Caelus.borderWidth
                                    border.color: Colors.popupBorder

                                    Text {
                                        id: capText

                                        anchors.centerIn: parent
                                        text: cap.modelData
                                        color: Colors.popupAccent
                                        font.family: Caelus.fontFamily
                                        font.pixelSize: Caelus.sizeLabel
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.action
                            color: Colors.fg
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeBody
                            elide: Text.ElideRight
                        }

                        // Edit mode's own affordance -- a mouse-drag bind has
                        // no ref (see root.startEdit) so it gets no pencil,
                        // the same rows a click cannot rebind either.
                        Text {
                            visible: root.editMode && !!row.modelData.ref
                            text: "edit"
                            color: Colors.popupAccent
                            font.family: Caelus.symbolFamily
                            font.pixelSize: Caelus.sizeBody
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.modelData.ref ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: root.index = row.index
                        onClicked: root.editMode ? root.startEdit(row.index) : root.activate(row.index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Keybinds.binds.length === 0 ? "Reading binds…" : "No matching keybinds"
                    visible: list.count === 0
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            }
        }
    }

    // The capture dialog for whichever row startEdit() picked -- covers the
    // whole window (scrim included) so Escape/click-outside on it can never
    // be mistaken for this window's own close().
    KeybindManager {
        id: manager

        anchors.fill: parent
        onClosed: search.forceActiveFocus()
    }

    // Hyprland matches its OWN compositor binds before this window -- even
    // with WlrKeyboardFocus.Exclusive above -- ever sees the key, so a chord
    // already bound elsewhere (SUPER+S, etc.) would never reach
    // KeybindManager's Keys.onPressed without this. `enabled` tracks
    // `manager.capturing` exactly, not `root.open`: read-only browsing and
    // the search field's own Up/Down/Enter handling must never have
    // Hyprland's shortcuts inhibited, only the one dialog that is actually
    // waiting on a chord. `manager.cancel()` above (from close(), Escape, a
    // successful save, or a failed one's own Escape) and onOpenChanged's
    // failsafe both drop `capturing` straight back to false, which this
    // binding follows immediately -- there is no path that leaves
    // `capturing` true once the sheet is not both open and mid-capture, so
    // there is none that leaves this inhibited either. `cancelled` fires if
    // the compositor drops the inhibitor on its own (a lock screen, e.g.);
    // treated exactly like the user having pressed Escape.
    ShortcutInhibitor {
        id: shortcutInhibitor

        window: root
        enabled: manager.capturing
        onCancelled: if (manager.capturing) manager.cancel()
    }
}
