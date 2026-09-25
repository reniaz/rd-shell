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

    function close() {
        search.text = "";
        Keybinds.query = "";
        root.index = 0;
        root.dismissed();
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
                                root.activate(root.index);
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
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.modelData.ref ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: root.index = row.index
                        onClicked: root.activate(row.index)
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
}
