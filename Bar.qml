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
    // One surface edge to edge, not a transparent strip with islands floating
    // in it. The colour comes from the wallpaper by way of pywal, so changing
    // the picture changes the bar with it.
    color: Colors.barBg

    Behavior on color { ColorAnimation { duration: 200 } }

    // leftGroup sits directly in the window, so its x plus the pill's is
    // already window-relative and stays live as the workspace dots beside it
    // change width.
    readonly property real systemAnchorX: leftGroup.x + systemPill.x + systemPill.width / 2
    readonly property real mediaAnchorX: leftGroup.x + mediaPill.x + mediaPill.width / 2

    // centerGroup is centred in the window rather than laid out from an edge,
    // but it is still a direct child of it, so its x needs no conversion either.
    readonly property real clockAnchorX: centerGroup.x + clockPill.x + clockPill.width / 2

    // rightGroup is laid out from the far edge and is likewise a direct child,
    // so the same sum holds. Named here rather than written out at the loader,
    // the way the disk and volume popups still do it, because the network pill
    // has pills on both sides of it that come and go -- the tray appearing and
    // the mic being unplugged each move it, and this keeps that in one place.
    readonly property real networkAnchorX: rightGroup.x + networkPill.x + networkPill.width / 2

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
            id: mediaPill

            // Same reasoning as the disk pill's: which bar you right-clicked is
            // the whole question, and a second monitor's pill has its own answer.
            property bool open: false

            icon: Media.playing ? "pause" : "play_arrow"
            label: Media.label
            iconColor: Colors.mediaIcon
            maxLabelWidth: 280
            visible: Media.available

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                // Left toggles whatever the pill is showing; right asks which
                // player it should have been showing; middle goes to the window
                // the sound is coming out of.
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) mediaPill.open = !mediaPill.open;
                    else if (mouse.button === Qt.MiddleButton) Media.focusWindow();
                    else Media.toggle();
                }

                // Turns down the player the pill is showing rather than the
                // sink, so quietening a video leaves the music alone. Same
                // notch the volume pill uses, so the wheel means one thing
                // along the whole bar.
                onWheel: wheel => Media.stepVolume(null, wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }

            // The last player quitting takes this pill off the bar. Forgetting
            // the open state with it is what stops the card reappearing on its
            // own when the next player starts.
            onVisibleChanged: if (!visible) mediaPill.open = false
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
            property bool showReminder: false
            property bool calendarOpen: false

            icon: "schedule"
            // What is next to go off, in the place the date used to sit -- a
            // timer is set to be glanced at, and the date is a right-click away
            // in the month itself.
            label: clockPill.showReminder
                ? `${Time.time} | ${Reminders.next ? Format.countdown(Reminders.next.at, Reminders.now) : "no timer"}`
                : Time.time

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                // Left folds in what is next; right hangs the whole month under
                // it, which is where reminders are set.
                onClicked: mouse => mouse.button === Qt.RightButton
                    ? clockPill.calendarOpen = !clockPill.calendarOpen
                    : clockPill.showReminder = !clockPill.showReminder
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
            id: micPill

            // Same reasoning as the disk pill's: which bar you right-clicked is
            // the whole question, and a second monitor's pill has its own answer.
            property bool open: false

            icon: Audio.micMuted ? "mic_off" : "mic"
            label: Audio.micPercent + "%"
            iconColor: Colors.micIcon
            visible: Audio.micReady

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? micPill.open = !micPill.open
                    : Audio.toggleMicMute()

                onWheel: wheel => Audio.setMicVolume(Audio.micVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }

            // The default source disappearing takes this pill off the bar.
            // Forgetting the open state with it is what stops the card
            // reappearing on its own when a mic is plugged back in.
            onVisibleChanged: if (!visible) micPill.open = false
        }

        Pill {
            id: volumePill

            // Same reasoning as the disk pill's: which bar you right-clicked is
            // the whole question, and a second monitor's pill has its own answer.
            property bool open: false

            icon: Audio.muted == false ? "volume_up" : "volume_off"
            label: Audio.percent + "%"
            iconColor: Colors.volumeIcon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? volumePill.open = !volumePill.open
                    : Audio.toggleMute()

                onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Pill {
            id: networkPill

            // Same reasoning as the disk pill's: which bar you clicked is the
            // whole question, and a second monitor's pill has its own answer.
            property bool open: false

            icon: Network.wired ? "lan" : Network.connected ? "wifi" : "wifi_off"
            label: Network.wired ? "ETH" : Network.connected ? Network.name : "Offline"
            iconColor: Colors.networkIcon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                // Left hangs the throughput card under the pill -- what the
                // link is actually carrying, which is the question the pill's
                // own name and icon cannot answer. Right keeps what this pill
                // has always done and hands the connection to NetworkManager's
                // settings page.
                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Network.openSettings()
                    : networkPill.open = !networkPill.open
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

    // Every overlay below is held by a PopupLoader rather than a bare LazyLoader,
    // and the difference is the whole of the exit animation: a LazyLoader wired
    // straight to an open flag destroys its window on the frame that flag drops,
    // so the card never gets to play itself back into the icon it came out of.
    // PopupLoader keeps the window for one animation's worth of time after the
    // flag goes, and writes the flag into the window on the way down so it knows
    // to leave. Which of the two kinds of open state it is handed -- a Pill's,
    // or a service's -- it does not care; see PopupLoader.qml.

    PopupLoader {
        open: Power.menuOpen && bar.modelData.name === bar.overlayScreen

        PowerMenu {
            screen: bar.modelData
            onDismissed: Power.menuOpen = false
        }
    }

    // The same one-screen rule as the power menu: the switcher takes the keyboard
    // exclusively, so two of them would fight over it, and a strip of wallpapers
    // is only wanted on the screen you are looking at. It closes itself through
    // the service rather than a dismissed signal, because applying a wallpaper
    // has to shut it too and only Wallpapers knows when that happened.
    PopupLoader {
        open: Wallpapers.panelOpen && bar.modelData.name === bar.overlayScreen

        WallpaperSwitcher {
            screen: bar.modelData
        }
    }

    // Held open by the service and not by this loader alone, because Escape, the
    // bell and the IPC handler can all shut this panel and only one of them is
    // that window.
    PopupLoader {
        open: Notifications.panelOpen && bar.modelData.name === bar.overlayScreen

        NotificationPanel {
            screen: bar.modelData
            anchorX: rightGroup.x + bellPill.x + bellPill.width / 2
            onDismissed: Notifications.closePanel()
        }
    }

    // Not gated on overlayScreen the way the keybind-driven overlays are: this
    // one is opened by a click on a specific bar, so it belongs to that screen
    // whether or not the pointer left the focused one.
    PopupLoader {
        open: SysMon.panelOpen && bar.modelData.name === bar.overlayScreen

        SysPopup {
            screen: bar.modelData
            anchorX: bar.systemAnchorX
            onDismissed: SysMon.panelOpen = false
        }
    }

    PopupLoader {
        open: diskPill.open

        DiskPopup {
            screen: bar.modelData
            // Centre of the pill in bar coordinates. rightGroup sits directly in
            // the window, so its x plus the pill's is already window-relative,
            // and both stay live as the pills either side change width.
            anchorX: rightGroup.x + diskPill.x + diskPill.width / 2
            onDismissed: diskPill.open = false
        }
    }

    // Both of these are opened by a right-click on a specific bar, so they follow
    // the disk popup rather than the keybind-driven overlays: no overlayScreen
    // gate, and the open state lives on the pill that was clicked.
    PopupLoader {
        open: clockPill.calendarOpen

        CalendarPopup {
            screen: bar.modelData
            anchorX: bar.clockAnchorX
            onDismissed: clockPill.calendarOpen = false
        }
    }

    // Closed with the pill it hangs from: the last player quitting takes the
    // pill off the bar, and a card left pointing at a gap is not dismissable by
    // clicking the icon that opened it. A player merely reloading no longer
    // costs the card its window -- the loader's hold outlasts the blink, and
    // the card is handed back instead of being built again.
    PopupLoader {
        open: mediaPill.open && Media.available

        MediaPopup {
            screen: bar.modelData
            anchorX: bar.mediaAnchorX
            onDismissed: mediaPill.open = false
        }
    }

    // Same pill, same reasoning as the disk popup above: rightGroup sits
    // directly in the window, so its x plus the pill's is already
    // window-relative and stays live as the pills either side change width.
    PopupLoader {
        open: volumePill.open

        AudioPopup {
            screen: bar.modelData
            anchorX: rightGroup.x + volumePill.x + volumePill.width / 2
            onDismissed: volumePill.open = false
        }
    }

    // Closed with the pill it hangs from, same as the media popup above: the
    // default source disappearing takes the pill off the bar, and a card
    // left pointing at a gap is not dismissable by clicking the icon that
    // opened it.
    PopupLoader {
        open: micPill.open && Audio.micReady

        AudioPopup {
            capture: true
            screen: bar.modelData
            anchorX: rightGroup.x + micPill.x + micPill.width / 2
            onDismissed: micPill.open = false
        }
    }

    // What the link is actually carrying, which is the one thing the pill's own
    // name and icon cannot say. Opened by a click on a specific bar, so it is
    // ungated like the disk and calendar cards rather than following the focused
    // monitor.
    PopupLoader {
        open: networkPill.open

        NetworkPopup {
            screen: bar.modelData
            anchorX: bar.networkAnchorX
            onDismissed: networkPill.open = false
        }
    }

    PopupLoader {
        open: KeyboardLayout.osdVisible && bar.modelData.name === bar.overlayScreen

        KeyboardLayoutOsd { screen: bar.modelData }
    }

    // The whole stack is retired at once by Notifications' own popup timer, so
    // this goes from several toasts to none in a single change. The loader holds
    // the window through the slide that takes them back off the right edge.
    PopupLoader {
        open: Notifications.popups.length > 0 && bar.modelData.name === bar.overlayScreen

        NotificationPopups { screen: bar.modelData }
    }

    // Held open by the service and not by this loader alone, because Escape, the
    // pill, the panel's own close button and the IPC handler can all shut it and
    // only one of them is that window.
    PopupLoader {
        open: ClaudeSession.panelOpen && bar.modelData.name === bar.overlayScreen

        ClaudePanel {
            screen: bar.modelData
            // Same reasoning as the disk popup above: rightGroup sits directly
            // in the window, so its x plus the pill's is already window-relative
            // and stays live as the pills either side change width.
            anchorX: rightGroup.x + claudePill.x + claudePill.width / 2
            onDismissed: ClaudeSession.closePanel()
        }
    }
}

