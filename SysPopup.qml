import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// What the bar's system pill is a summary of, one part of the machine per tab.
// The card, the grow-out-of-the-icon animation and the click-outside dismissal
// all belong to BarPopup; what is left here is the panel's content.
BarPopup {
    id: root

    // View state, so it lives on the window and not on the service: which tab
    // was last read is not something the pill or the IPC handler needs.
    property int tab: 0

    readonly property var tabs: ["Processor", "Graphics", "Memory"]

    namespace: "qs-sysmon"
    popupWidth: 380

    // As short as the open tab needs and no taller than the screen allows.
    // The cap is Caelus.barHeight - Caelus.barInset -- the 38 the card now
    // hangs at, flush under the island -- plus Caelus.spaceEdge, the same 14
    // gap the bar's pills float in. Deriving it from those three instead of
    // writing the sum keeps it from going stale again if the bar's own
    // metrics move. BarPopup animates the change, so switching tabs is seen
    // to fold.
    //
    // The screen cap only applies once there is a screen height to cap against.
    // A layer surface is told its size a round trip after it is created, so for
    // the first frames `root.height` is zero, and an unguarded Math.min against
    // it asks for a card fifty-two pixels tall -- which is how the popup came to
    // open at BarPopup's floor and then grow into itself.
    popupHeight: root.height > 0
        ? Math.min(root.height - (Caelus.barHeight - Caelus.barInset + Caelus.spaceEdge), root.wantedHeight)
        : root.wantedHeight

    readonly property real wantedHeight: 28 + head.implicitHeight + 10 + root.pageHeight

    // The height the open tab would like. Deliberately not the StackLayout's
    // own implicit height, which is the tallest of all three pages.
    readonly property real pageHeight: [cpuPage, gpuPage, memPage][root.tab].naturalHeight

    // While the panel is up these numbers are the only thing on screen, so they
    // are read at the rate they are watched. Stopped on `open` rather than left
    // to the window's lifetime: the window now outlives its own exit animation,
    // and there is no reason to keep sampling a card the reader has already
    // dismissed. Once it is gone the pill falls back to its own two-second
    // cadence and process sampling stops entirely.
    Timer {
        interval: 1500
        running: root.open
        repeat: true
        onTriggered: SysMon.refresh()
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        onTriggered: SysMon.refreshProcesses()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceLoose

        // The rows above the pages, measured together and on their own: a card
        // that sized itself from the same layout it stretches would feed its
        // own height back into the sum.
        ColumnLayout {
            id: head

            Layout.fillWidth: true
            Layout.minimumHeight: implicitHeight
            spacing: Caelus.spaceLoose

            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.space

                Text {
                    text: "monitoring"
                    color: Colors.sysIcon
                    font.family: Caelus.symbolFamily
                    font.pixelSize: 17
                }

                Text {
                    text: "System"
                    color: Colors.sysTitle
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLead
                    Layout.fillWidth: true
                }

                Text {
                    text: "up " + Format.duration(SysMon.uptime)
                    color: Colors.sysMeta
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                Text {
                    text: "close"
                    color: closeArea.containsMouse ? Colors.sysKill : Colors.sysMeta
                    font.family: Caelus.symbolFamily
                    font.pixelSize: 17

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed()
                    }
                }
            }

            // ── tab bar ──────────────────────────────────────────────────
            Rectangle {
                id: tabBar

                Layout.fillWidth: true
                implicitHeight: 32
                radius: Caelus.radiusPill
                color: Colors.bg

                readonly property real inset: 4
                readonly property real tabWidth: (width - inset * 2) / root.tabs.length

                // One sliding pill rather than three toggling backgrounds: the
                // travel is what tells you which way you just moved.
                Rectangle {
                    y: tabBar.inset
                    x: tabBar.inset + root.tab * tabBar.tabWidth
                    width: tabBar.tabWidth
                    height: tabBar.height - tabBar.inset * 2
                    radius: Caelus.radiusPill
                    color: Colors.sysColor

                    Behavior on x {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: tabBar.inset

                    Repeater {
                        model: root.tabs

                        Item {
                            id: tabItem

                            required property int index
                            required property string modelData

                            width: tabBar.tabWidth
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: tabItem.modelData
                                color: root.tab === tabItem.index ? Colors.bg : Colors.sysMeta
                                font.family: Caelus.fontFamily
                                font.pixelSize: Caelus.sizeBody

                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = tabItem.index
                            }
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            // Always handed the whole remaining card, so a page is never sized
            // by the number it is being asked for.
            Layout.fillHeight: true
            currentIndex: root.tab

            SysCpuTab { id: cpuPage }

            SysGpuTab { id: gpuPage }

            SysMemTab { id: memPage }
        }
    }
}
