import QtQuick
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app: a label + live value readout above a
// draggable track, generalising the two-tier shape SettingsPopup.qml's own
// UI-scale slider already uses (see that file's `setUiScale`) to any
// {from,to,stepSize} range, so every slider in the settings app snaps and
// clamps the exact same way. Rows never write Settings themselves: `moved`
// hands the page an already-snapped, already-clamped number, and the page
// decides what to assign it to.
ColumnLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string caption: ""
    property string valueText: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.05

    signal moved(real value)

    Layout.fillWidth: true
    spacing: Caelus.spaceSnug

    opacity: root.enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Motion.base } }

    readonly property bool _hovered: headerHover.containsMouse

    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(52 * Caelus.uiScale, header.implicitHeight + Caelus.spaceWide * 2)

        Rectangle {
            anchors.fill: parent
            // ROUNDING RULE (user instruction): rows and their hover film
            // are square -- 0, never radiusCard.
            radius: 0
            color: root._hovered ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover) : "transparent"

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: headerHover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: header

            anchors.fill: parent
            anchors.margins: Caelus.spaceWide
            spacing: Caelus.space

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: Colors.fgDim
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.label
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.caption !== ""
                    text: root.caption
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                visible: root.valueText !== ""
                text: root.valueText
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }
    }

    Rectangle {
        id: track

        Layout.fillWidth: true
        Layout.leftMargin: Caelus.spaceWide
        Layout.rightMargin: Caelus.spaceWide
        Layout.bottomMargin: Caelus.spaceSnug
        implicitHeight: 6 * Caelus.uiScale
        // ROUNDING RULE (user instruction): the track is square like the
        // segmented choice row's own track -- 0, never radiusPill/height-2
        // pills. The fill Rectangle below follows `parent.radius`, so it
        // never needs its own copy of this value to stay in sync.
        radius: 0
        color: Colors.popupBorder

        readonly property real range: root.to - root.from
        readonly property real ratio: track.range > 0 ? (root.value - root.from) / track.range : 0

        // Maps a 0..1 position on the track to a value in [from,to], snapped
        // to `stepSize` and clamped at both ends -- the same shape
        // SettingsPopup.setUiScale uses, generalised off a fixed 0.85..1.5.
        function applyRatio(r) {
            const clamped = Math.max(0, Math.min(1, r));
            const raw = root.from + clamped * track.range;
            const stepped = root.stepSize > 0 ? Math.round(raw / root.stepSize) * root.stepSize : raw;
            root.moved(Math.max(root.from, Math.min(root.to, stepped)));
        }

        Rectangle {
            width: Math.round(track.width * track.ratio)
            height: parent.height
            radius: parent.radius
            color: Colors.popupAccent
        }

        Rectangle {
            id: handle

            readonly property real d: 14 * Caelus.uiScale

            width: d
            height: d
            // Square, like the track it rides on -- only switch/button/chip
            // controls are named exceptions in the rounding rule, and the
            // slider handle isn't one of them.
            radius: 0
            y: (track.height - d) / 2
            x: Math.max(0, Math.min(track.width - d, track.width * track.ratio - d / 2))
            color: Colors.popupAccent
            border.width: Caelus.borderWidth
            border.color: Colors.surfaceRaised

            Behavior on x {
                enabled: !trackMouse.pressed
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
            }
        }

        FocusRing {
            anchors.fill: parent
            anchors.margins: -6
            radius: 0
            show: trackFocus.activeFocus
        }

        Item {
            id: trackFocus

            anchors.fill: parent
            activeFocusOnTab: true

            Keys.onLeftPressed: track.applyRatio(track.ratio - root.stepSize / Math.max(track.range, 0.0001))
            Keys.onRightPressed: track.applyRatio(track.ratio + root.stepSize / Math.max(track.range, 0.0001))

            MouseArea {
                id: trackMouse

                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => { trackFocus.forceActiveFocus(); track.applyRatio(mouse.x / width); }
                onPositionChanged: mouse => { if (pressed) track.applyRatio(mouse.x / width); }
                onWheel: wheel => track.applyRatio(track.ratio + (wheel.angleDelta.y > 0 ? 1 : -1) * root.stepSize / Math.max(track.range, 0.0001))
            }
        }
    }
}
