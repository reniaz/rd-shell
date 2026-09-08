import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    color: "transparent"

    // leftGroup sits directly in the window, so its x plus the pill's is
    // already window-relative and stays live as the workspace dots beside it
    // change width.
    readonly property real systemAnchorX: leftGroup.x + systemPill.x + systemPill.width / 2

    RowLayout {
        id: leftGroup
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        spacing: 8

        Pill {
            content: WorkspaceDots {
                id: dots
                monitor: Hyprland.monitorFor(bar.modelData)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: wheel => Workspaces.relative(dots.monitor, wheel.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Pill {
            icon: Media.playing ? "pause" : "play_arrow"
            label: Media.label
            iconColor: Colors.mediaIcon
            maxLabelWidth: 280
            visible: Media.available

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Media.toggle()
            }
        }

        // One pill, three readings: what the processor, the graphics card and
        // memory are each doing, and what it is costing them. Each keeps its
        // own colour inside it, so the group reads as one object and still says
        // which part of the machine is the hot one.
        //
        // Last in the group so that it sits beside whatever is playing rather
        // than being pushed along the bar as the track title changes width.
        Pill {
            id: systemPill

            content: SysReadout {}
            visible: SysMon.available

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: SysMon.togglePanel()
            }
        }
    }

    RowLayout {
        id: centerGroup
        anchors.centerIn: parent
        spacing: 8

        Pill {
            id: clockPill
            property bool expanded: false

            icon: "schedule"
            label: expanded ? `${Time.time} | ${Time.date}` : Time.time

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: clockPill.expanded = !clockPill.expanded
            }
        }
    }

    RowLayout {
        id: rightGroup
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 14
        spacing: 8

        Pill {
            id: claudePill

            icon: "terminal"
            // Busy or idle underneath, but an account near its limit outranks
            // both: the same thresholds the disk pill runs on.
            iconColor: Colors.usage(ClaudeSession.usagePercent,
                ClaudeSession.busy ? Colors.claudeBusy : Colors.claudeIcon)
            label: ClaudeSession.usagePercent >= 0
                ? ClaudeSession.usagePercent + "%"
                : ""
            visible: ClaudeSession.available

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: ClaudeSession.togglePanel()
            }
        }

        Pill {
            icon: "keyboard"
            label: KeyboardLayout.code
            iconColor: Colors.keyboardIcon
            visible: KeyboardLayout.code !== ""

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: KeyboardLayout.cycle()
            }
        }

        Pill {
            id: diskPill

            // Open state lives on the pill and not on the service: which bar you
            // clicked is the whole question, and a second monitor's pill has its
            // own answer.
            property bool open: false

            icon: "hard_drive"
            label: Disk.percent + "%"
            iconColor: Colors.usage(Disk.percent, Colors.diskIcon)
            visible: Disk.percent >= 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    Disk.refresh();
                    diskPill.open = true;
                }
            }
        }

        Pill {
            content: TrayItems { id: trayItems }
            // Counts what the tray actually draws, not what is registered: with
            // only a filtered item present this would otherwise be an empty pill.
            visible: trayItems.shown.length > 0
        }

        Pill {
            icon: Audio.micMuted ? "mic_off" : "mic"
            label: Audio.micPercent + "%"
            iconColor: Colors.micIcon
            visible: Audio.micReady

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Audio.openSettings(4)
                    : Audio.toggleMicMute()

                onWheel: wheel => Audio.setMicVolume(Audio.micVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Pill {
            icon: Audio.muted == false ? "volume_up" : "volume_off"
            label: Audio.percent + "%"
            iconColor: Colors.volumeIcon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Audio.openSettings(3)
                    : Audio.toggleMute()

                onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Pill {
            icon: Network.wired ? "lan" : Network.connected ? "wifi" : "wifi_off"
            label: Network.wired ? "ETH" : Network.connected ? Network.name : "Offline"
            iconColor: Colors.networkIcon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Network.openSettings()
            }
        }

        Pill {
            id: bellPill

            content: NotificationBell {}

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Notifications.toggleDnd()
                    : Notifications.togglePanel()
            }
        }

        Pill {
            icon: "power_settings_new"
            iconColor: Colors.powerIcon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Power.menuOpen = true
            }
        }
    }

    // Only the bar on the focused monitor renders the overlay, so a keybind press
    // opens it where you are looking and two screens never fight over the keyboard.
    // Compared by name with a fallback: Hyprland.focusedMonitor can be unresolved
    // right after a config reload, and without the fallback the menu would silently
    // refuse to open on any screen.
    readonly property string overlayScreen: Hyprland.focusedMonitor?.name
        ?? Quickshell.screens[0]?.name
        ?? ""

    LazyLoader {
        active: Power.menuOpen && bar.modelData.name === bar.overlayScreen

        PowerMenu {
            screen: bar.modelData
            onDismissed: Power.menuOpen = false
        }
    }

    LazyLoader {
        active: (Notifications.panelOpen || Notifications.panelClosing)
            && bar.modelData.name === bar.overlayScreen

        NotificationPanel {
            screen: bar.modelData
            anchorX: rightGroup.x + bellPill.x + bellPill.width / 2
            onDismissed: Notifications.closePanel()
        }
    }

    // Not gated on overlayScreen the way the keybind-driven overlays are: this
    // one is opened by a click on a specific bar, so it belongs to that screen
    // whether or not the pointer left the focused one.
    LazyLoader {
        active: SysMon.panelOpen && bar.modelData.name === bar.overlayScreen

        SysPopup {
            screen: bar.modelData
            anchorX: bar.systemAnchorX
            onDismissed: SysMon.panelOpen = false
        }
    }

    LazyLoader {
        active: diskPill.open

        DiskPopup {
            screen: bar.modelData
            // Centre of the pill in bar coordinates. rightGroup sits directly in
            // the window, so its x plus the pill's is already window-relative,
            // and both stay live as the pills either side change width.
            anchorX: rightGroup.x + diskPill.x + diskPill.width / 2
            onDismissed: diskPill.open = false
        }
    }

    LazyLoader {
        active: KeyboardLayout.osdVisible && bar.modelData.name === bar.overlayScreen

        KeyboardLayoutOsd { screen: bar.modelData }
    }

    LazyLoader {
        active: Notifications.popups.length > 0 && bar.modelData.name === bar.overlayScreen

        NotificationPopups { screen: bar.modelData }
    }

    LazyLoader {
        active: (ClaudeSession.panelOpen || ClaudeSession.panelClosing)
            && bar.modelData.name === bar.overlayScreen

        ClaudePanel {
            screen: bar.modelData
            // Same reasoning as the disk popup below: rightGroup sits directly
            // in the window, so its x plus the pill's is already window-relative
            // and stays live as the pills either side change width.
            anchorX: rightGroup.x + claudePill.x + claudePill.width / 2
            onDismissed: ClaudeSession.closePanel()
        }
    }
}

