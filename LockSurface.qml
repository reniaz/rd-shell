pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Config
import qs.Services

// Per-screen lock surface -- WlLock.qml's WlSessionLock instantiates one of
// these per Quickshell.screens entry on its own. Everything on it is
// read-only display except the password field: the clock/date, now-playing
// and notification-count rows are the same Pill.qml the bar itself uses
// (implicit same-directory import, same as every other root-level file),
// just non-interactive here, so the lock screen reads as this shell's own
// chrome rather than a second, unrelated UI the way hyprlock's default look
// does.
WlSessionLockSurface {
    id: root

    required property var lock
    required property var pam

    color: "transparent"

    Image {
        anchors.fill: parent
        source: Wallpapers.current !== "" ? "file://" + Wallpapers.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: source !== ""
    }

    // The same scrim a modal overlay dims the desktop behind (Caelus.overlay
    // already carries its own alpha) -- reads as "the desktop, stepped back
    // for something in front of it", not a screen that has simply gone dark.
    Rectangle {
        anchors.fill: parent
        color: Caelus.overlay
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Caelus.spaceWide

        Pill {
            Layout.alignment: Qt.AlignHCenter
            interactive: false
            icon: "schedule"
            iconSize: 20
            label: Time.time + "  ·  " + Qt.formatDateTime(Time.now, "dddd, d MMMM")
        }

        Pill {
            Layout.alignment: Qt.AlignHCenter
            visible: Media.available
            interactive: false
            icon: Media.playing ? "graphic_eq" : "music_note"
            iconColor: Colors.mediaIcon
            label: Media.label
            maxLabelWidth: 320
        }

        Pill {
            Layout.alignment: Qt.AlignHCenter
            visible: Notifications.count > 0
            interactive: false
            icon: "notifications"
            iconColor: Colors.notifIcon
            label: Notifications.count + (Notifications.count === 1 ? " notification" : " notifications")
        }

        // ── password field ──────────────────────────────────────
        // Fixed-size wrapper Item, not the Rectangle itself, sits in the
        // layout: the shake below rides on the Rectangle's own anchor
        // offset (anchors.centerIn + horizontalCenterOffset, the usual pair
        // for this), so the layout's own positioning of the wrapper is never
        // fought by the animation moving the field inside it.
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Caelus.spaceWide
            implicitWidth: 240
            implicitHeight: 44

            Rectangle {
                id: field

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: Caelus.radiusPill
                color: Colors.surfaceRaised
                border.width: Caelus.borderWidth
                border.color: root.pam.failed ? Colors.error
                    : (field.activeFocus ? Colors.popupAccent : Caelus.border)

                Behavior on border.color {
                    ColorAnimation { duration: Motion.fast }
                }

                // Lock-out-proofing: this field must always hold the key
                // focus of its own surface. Nothing else on this surface is
                // focusable, so the only way it could ever lose activeFocus
                // is the compositor moving keyboard focus to a different
                // surface entirely (a different screen's LockSurface) --
                // reasserting it here the instant that is not the reason
                // costs nothing and guards against anything on this item's
                // own side (a hot-reload recreating siblings, say) stealing
                // it by accident.
                focus: true
                onActiveFocusChanged: if (!field.activeFocus) field.forceActiveFocus()
                Component.onCompleted: field.forceActiveFocus()

                Keys.onPressed: event => root.pam.handleKey(event)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Caelus.spaceWide
                    anchors.rightMargin: Caelus.spaceWide
                    spacing: Caelus.space

                    Text {
                        text: root.pam.busy ? "hourglass_top" : "lock"
                        font.family: Caelus.symbolFamily
                        font.pixelSize: 18
                        color: root.pam.failed ? Colors.error : Colors.fgDim
                    }

                    Text {
                        Layout.fillWidth: true
                        // A bullet per typed character, never the character
                        // itself -- there is no "show password" toggle here,
                        // on purpose: this surface can be seen by anyone
                        // standing behind the person unlocking it.
                        text: root.pam.buffer.length > 0
                            ? "•".repeat(root.pam.buffer.length)
                            : (root.pam.failed ? "wrong password" : "password")
                        color: root.pam.failed ? Colors.error : Colors.fgMuted
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                        elide: Text.ElideRight
                    }
                }

                Connections {
                    target: root.pam
                    function onFailFlash() { shake.restart(); }
                }

                // idea 61's own shake+flash (the border.color binding above
                // is the flash half) folded straight in here rather than
                // built as a separate piece: it is nothing but this field's
                // own PamContext failure branch. Decaying amplitude, quick.
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 8; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 4; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
                }
            }
        }
    }
}
