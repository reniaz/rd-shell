import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app: the scrollable body every page root
// in SettingsWindow.qml's Loader is. One centred column capped at
// ~680*uiScale -- the window frame is free to be as wide as the person
// drags it, but a line of text stretched across all of it is not, so the
// page's own content stops growing well before the window does.
//
// Title and subtitle live inside the very same ColumnLayout the page's own
// cards stack in, not a separate header above it: `default property alias
// content: col.data` appends whatever a page declares straight after them
// in one declaration order, so there is only ever one spacing rhythm
// (Caelus.spaceWide*1.5) to keep in sync, not a header layout and a body
// layout that could drift apart.
Item {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: col.data

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + Caelus.spaceEdge * 4
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ThinScrollBar {}

        ColumnLayout {
            id: col

            x: Math.round((flick.width - width) / 2)
            y: Caelus.spaceEdge * 2
            width: Math.min(flick.width - Caelus.spaceEdge * 4, 680 * Caelus.uiScale)
            spacing: Caelus.spaceWide * 1.5

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeTitle * 1.35
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                wrapMode: Text.WordWrap
            }
        }
    }
}
