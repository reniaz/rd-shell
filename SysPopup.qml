import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// What the bar's system pill is a summary of, one part of the machine per tab.
// The card, its notch, the grow-out-of-the-icon animation and the click-outside
// dismissal all belong to BarPopup; what is left here is the panel's content.
BarPopup {
    id: root

    // View state, so it lives on the window and not on the service: which tab
    // was last read is not something the pill or the IPC handler needs.
    property int tab: 0

    readonly property var tabs: ["Processor", "Graphics", "Memory"]

    namespace: "qs-sysmon"
    popupWidth: 380

    // As short as the open tab needs and no taller than the screen allows. 60
    // is the 46 the card hangs at plus the same 14 gap the bar's pills float
    // in. BarPopup animates the change, so switching tabs is seen to fold.
    popupHeight: Math.min(root.height - 60, 28 + head.implicitHeight + 10 + root.pageHeight)

    // The height the open tab would like. Deliberately not the StackLayout's
    // own implicit height, which is the tallest of all three pages.
    readonly property real pageHeight: [cpuPage, gpuPage, memPage][root.tab].naturalHeight

    // Held open by the service, so the pill, Escape and the IPC handler can all
    // shut the same panel.
    open: SysMon.panelOpen

    // While the panel is up these numbers are the only thing on screen, so they
    // are read at the rate they are watched. The loader destroys this window on
    // close, which takes the timers with it: the pill falls back to its own
    // two-second cadence and process sampling stops entirely.
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: SysMon.refresh()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: SysMon.refreshProcesses()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // The rows above the pages, measured together and on their own: a card
        // that sized itself from the same layout it stretches would feed its
        // own height back into the sum.
        ColumnLayout {
            id: head

            Layout.fillWidth: true
            Layout.minimumHeight: implicitHeight
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "monitoring"
                    color: Colors.sysIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 17
                }

                Text {
                    text: "System"
                    color: Colors.sysTitle
                    font.family: "caelusevka"
                    font.pixelSize: 15
                    Layout.fillWidth: true
                }

                Text {
                    text: "up " + Format.duration(SysMon.uptime)
                    color: Colors.sysMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }

                Text {
                    text: "close"
                    color: closeArea.containsMouse ? Colors.sysKill : Colors.sysMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 17

                    Behavior on color { ColorAnimation { duration: 120 } }

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
                radius: height / 2
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
                    radius: height / 2
                    color: Colors.sysColor

                    Behavior on x {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
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
                                font.family: "caelusevka"
                                font.pixelSize: 13

                                Behavior on color { ColorAnimation { duration: 120 } }
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
