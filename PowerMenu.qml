import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Config
import qs.Services

PanelWindow {
    id: root

    signal dismissed()

    // "choose" picks an action, "confirm" asks about the pending one. Both stages
    // drive the same `index`, so hover and the arrow keys can never disagree about
    // what Enter would activate.
    property string stage: "choose"
    property int index: 0
    property var pending: null
    property bool shown: false

    readonly property var options: stage === "choose"
        ? Power.actions
        : [{ icon: "close", label: "No" }, { icon: "check", label: "Yes" }]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-power"
    color: "transparent"

    Component.onCompleted: shown = true

    function activate(i) {
        root.index = i;
        if (root.stage === "choose") {
            const action = Power.actions[i];
            if (action.confirm === false) {
                action.run();
                root.dismissed();
                return;
            }
            root.pending = action;
            root.stage = "confirm";
            root.index = 0; // default to No, so a stray Enter is harmless
        } else if (i === 1) {
            root.pending.run();
            root.dismissed();
        } else {
            root.back();
        }
    }

    function back() {
        root.index = Power.actions.indexOf(root.pending);
        root.pending = null;
        root.stage = "choose";
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                if (root.stage === "confirm") root.back();
                else root.dismissed();
                break;
            case Qt.Key_Left:
            case Qt.Key_H:
                root.index = (root.index - 1 + root.options.length) % root.options.length;
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
                root.index = (root.index + 1) % root.options.length;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.activate(root.index);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.shown ? 0.72 : 0

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismissed()
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 26
            opacity: root.shown ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.pending?.question ?? ""
                visible: root.stage === "confirm"
                color: Colors.fg
                font.family: "caelusevka"
                font.pixelSize: 22
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Repeater {
                    model: root.options

                    Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool selected: index === root.index
                        readonly property bool danger: root.stage === "confirm" && index === 1
                        readonly property color mark: danger ? Colors.error : Colors.accent

                        width: 132
                        height: 132
                        radius: 16
                        color: Colors.bg
                        border.width: 2
                        border.color: selected ? mark : Colors.fgMuted

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: selected ? mark : Colors.fgMuted
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 48

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Colors.fg
                                font.family: "caelusevka"
                                font.pixelSize: 16
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: root.index = index
                            onClicked: root.activate(index)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.stage === "confirm"
                    ? "Esc to go back  ·  ←/→ to move  ·  Enter to confirm"
                    : "Esc to cancel  ·  ←/→ to move  ·  Enter to select"
                color: Colors.fgMuted
                font.family: "caelusevka"
                font.pixelSize: 14
            }
        }
    }
}
