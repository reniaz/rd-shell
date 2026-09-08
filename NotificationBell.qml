import QtQuick
import qs.Config
import qs.Services

// Bell glyph plus an unread badge, sized to sit inside a Pill the way
// WorkspaceDots and TrayItems do. The badge is a child of the glyph rather than
// of the Pill so it tracks the icon's own top-right corner and does not shift
// when the pill's width changes.
Item {
    id: root

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    Text {
        id: glyph

        text: Notifications.dnd ? "notifications_off" : "notifications"
        color: Notifications.dnd ? Colors.notifDndOn : Colors.notifColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16
    }

    Rectangle {
        id: badge

        // Hidden under do-not-disturb: the count keeps rising in the service, but
        // while the user has asked for quiet the bar must not nag about it.
        visible: !Notifications.dnd && Notifications.hasUnseen

        width: 8
        height: 8
        radius: width / 2
        color: Colors.notifUnread

        // Overhangs the glyph's top-right corner; the 1px ring keeps it legible
        // where it overlaps the bell's own strokes.
        anchors.right: glyph.right
        anchors.top: glyph.top
        anchors.rightMargin: -2
        anchors.topMargin: 1

        border.width: 1
        border.color: Colors.bg

        scale: visible ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }
}
