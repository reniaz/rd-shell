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
    // was last read is not something the pill or the IPC handler needs. The
    // initial value is a binding, not a literal: it reads Settings.sysTab
    // once at creation and then breaks the moment anything below assigns
    // `tab` imperatively (ordinary QML property semantics), which is exactly
    // the "read once on open, write forward from then on" split (h) below
    // wants -- the popup should not stay permanently synced to the setting,
    // only start from it.
    property int tab: Math.max(0, root.tabKeys.indexOf(Settings.sysTab))

    readonly property var tabs: ["Processor", "Graphics", "Memory"]
    readonly property var tabKeys: ["cpu", "gpu", "mem"]

    // Persisted so the tab survives not just the next open but the next
    // shell restart too -- see Services/Settings.qml.
    onTabChanged: Settings.sysTab = root.tabKeys[root.tab]

    // ←/→ switch tabs while the card holds focus. Deliberately not the
    // number keys the roadmap first floated: this popup has three tabs today
    // and may not tomorrow, and a bound-in "1/2/3" is one more thing to keep
    // in sync with `tabs` above every time it changes -- arrows need no such
    // bookkeeping. Declared on `root` itself rather than inside BarPopup.qml,
    // which this file may not edit: `card`, the item that actually holds
    // active focus, has no handler for either key (only Escape, in that
    // file), so an unaccepted press bubbles up through `cardClip` to `root`
    // -- the same FocusScope instantiated here -- exactly as Qt Quick's
    // ordinary unhandled-key propagation already carries Escape's rejection
    // the other way if `card` ever stopped wanting it.
    Keys.onLeftPressed: root.tab = Math.max(0, root.tab - 1)
    Keys.onRightPressed: root.tab = Math.min(root.tabs.length - 1, root.tab + 1)

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

    // No polling timer here any more: one sampler Process now runs
    // continuously on its own 2s cadence regardless of whether this popup is
    // open (see the SysMon API contract), and `panelOpen` -- flipped by
    // SysMon.togglePanel(), not by this file -- is what tells that sampler
    // to start and stop scanning individual processes. A popup-side Timer
    // calling the old refresh()/refreshProcesses() would be asking twice for
    // something already arriving on its own, and refreshProcesses() itself
    // no longer exists on the new service at all.
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

            // ── summary rings ────────────────────────────────────────────
            // The headline before the detail: CPU, GPU and RAM as one glance
            // across all three, in the same usage() colour the bar pill's own
            // icons already escalate through -- a card open to any one tab
            // still shows how the other two are doing.
            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.spaceLoose

                SysRing {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    label: "CPU"
                    value: SysMon.cpuPercent
                    available: SysMon.cpuPercent >= 0
                    fill: Colors.usage(SysMon.cpuPercent, Colors.sysColor)
                }

                SysRing {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    label: "GPU"
                    value: SysMon.gpuUtil ?? -1
                    available: (SysMon.gpuUtil ?? -1) >= 0
                    fill: Colors.usage(Math.max(0, SysMon.gpuUtil ?? 0), Colors.sysColor)
                }

                SysRing {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    label: "RAM"
                    value: SysMon.memPercent
                    available: SysMon.memPercent >= 0
                    fill: Colors.usage(SysMon.memPercent, Colors.sysColor)
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
