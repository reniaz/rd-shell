import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Config
import qs.Services

RowLayout {
    id: root

    // Exposed for BarOverlays.qml: each pill's offset for the popup that
    // anchors on it, and the open flags those popups need to read and close
    // back. claudePill, trayItems, localPill and bellPill hold no open state
    // of their own -- their popups are driven by their service instead.
    // micAnchorX/volumeAnchorX and bellAnchorX/menuAnchorX add their
    // BarGroup's own x on top of the pill's: those four now sit one level
    // deeper, inside `audioGroup`/`controlsGroup` rather than directly in
    // `root`, so the pill's own x alone is no longer root-relative.
    readonly property real claudeAnchorX: claudePill.x + claudePill.width / 2
    readonly property real diskAnchorX: diskPill.x + diskPill.width / 2
    readonly property real micAnchorX: audioGroup.x + micPill.x + micPill.width / 2
    readonly property real volumeAnchorX: audioGroup.x + volumePill.x + volumePill.width / 2
    readonly property real networkAnchorX: networkPill.x + networkPill.width / 2
    readonly property real localAnchorX: localPill.x + localPill.width / 2
    readonly property Item localPillItem: localPill.item
    readonly property Component _localPill: Qt.createComponent("Local/LocalPill.qml")
    readonly property real bellAnchorX: controlsGroup.x + bellPill.x + bellPill.width / 2
    readonly property real menuAnchorX: controlsGroup.x + menuPill.x + menuPill.width / 2

    property alias diskOpen: diskPill.open
    property alias micOpen: micPill.open
    property alias volumeOpen: volumePill.open
    property alias networkOpen: networkPill.open

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: Caelus.barMargin
    spacing: Caelus.barSpacing

    Pill {
        id: claudePill

        pressed: claudeArea.pressed

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
            id: claudeArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onClicked: ClaudeSession.togglePanel()
        }
    }

    Pill {
        pressed: keyboardArea.pressed

        icon: "keyboard"
        label: KeyboardLayout.code
        iconColor: Colors.keyboardIcon
        visible: KeyboardLayout.code !== ""

        MouseArea {
            id: keyboardArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onClicked: KeyboardLayout.cycle()
        }
    }

    Pill {
        id: diskPill

        pressed: diskArea.pressed

        // Open state lives on the pill and not on the service: which bar you
        // clicked is the whole question, and a second monitor's pill has its
        // own answer.
        property bool open: false

        icon: "hard_drive"
        label: Disk.percent + "%"
        iconColor: Colors.usage(Disk.percent, Colors.diskIcon)
        visible: Disk.percent >= 0

        MouseArea {
            id: diskArea
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

    // Mic and volume are one idea -- audio in, audio out -- so they sit in
    // one lighter capsule instead of reading as two of the same eleven pills.
    BarGroup {
        id: audioGroup

        Pill {
            id: micPill

            pressed: micArea.pressed

            // Same reasoning as the disk pill's: which bar you right-clicked is
            // the whole question, and a second monitor's pill has its own answer.
            property bool open: false

            visible: Audio.micReady
            // Pill's own icon/label pair swapped out for a RowLayout that
            // holds MuteGlyph in the icon's place instead -- the label Text
            // below is otherwise identical to Pill's own.
            content: RowLayout {
                spacing: 7
                MuteGlyph {
                    glyph: "mic"
                    muted: Audio.micMuted
                    color: Colors.micIcon
                }
                Text {
                    text: Audio.micPercent + "%"
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: 16
                }
            }

            MouseArea {
                id: micArea
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

            pressed: volumeArea.pressed

            // Same reasoning as the disk pill's: which bar you right-clicked is
            // the whole question, and a second monitor's pill has its own answer.
            property bool open: false

            // Pill's own icon/label pair swapped out the same way the mic
            // pill's is, just above.
            content: RowLayout {
                spacing: 7
                MuteGlyph {
                    glyph: "volume_up"
                    muted: Audio.muted
                    color: Colors.volumeIcon
                }
                Text {
                    text: Audio.percent + "%"
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: 16
                }
            }

            MouseArea {
                id: volumeArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? volumePill.open = !volumePill.open
                    : Audio.toggleMute()

                onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
    }

    // Only on a machine that has an adapter: no adapter (or no bluez), no
    // pill, and the row keeps no spacing for it. Settings.bluetoothPill
    // hides it by hand on a machine that has one but never uses it. Icon
    // only -- the glyph already says off / on / a device connected.
    Pill {
        id: bluetoothPill

        readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
        readonly property bool powered: adapter?.enabled ?? false
        readonly property bool linked: powered && (adapter?.devices.values.some(d => d.connected) ?? false)

        visible: adapter !== null && Settings.bluetoothPill
        pressed: bluetoothArea.pressed

        // bluez refuses to power an rfkill soft-blocked adapter, so turning
        // one on lifts the block first and powers it once it leaves Blocked.
        property bool _enableWhenUnblocked: false

        function toggle() {
            if (bluetoothPill.powered) {
                bluetoothPill.adapter.enabled = false;
            } else if (bluetoothPill.adapter.state === BluetoothAdapterState.Blocked) {
                bluetoothPill._enableWhenUnblocked = true;
                Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            } else {
                bluetoothPill.adapter.enabled = true;
            }
        }

        Connections {
            target: bluetoothPill.adapter

            function onStateChanged() {
                if (!bluetoothPill._enableWhenUnblocked || bluetoothPill.adapter.state === BluetoothAdapterState.Blocked) return;
                bluetoothPill._enableWhenUnblocked = false;
                if (!bluetoothPill.powered) bluetoothPill.adapter.enabled = true;
            }
        }

        icon: !powered ? "bluetooth_disabled" : linked ? "bluetooth_connected" : "bluetooth"
        iconColor: powered ? Colors.bluetoothIcon : Colors.bluetoothOff

        MouseArea {
            id: bluetoothArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            // Left switches the adapter on or off; right opens KDE's
            // Bluetooth settings for pairing, the same way the network
            // pill hands off to NetworkManager's.
            onClicked: mouse => mouse.button === Qt.RightButton
                ? Quickshell.execDetached(["kcmshell6", "kcm_bluetooth"])
                : bluetoothPill.toggle()
        }
    }

    Pill {
        id: networkPill

        pressed: networkArea.pressed

        // Same reasoning as the disk pill's: which bar you clicked is the
        // whole question, and a second monitor's pill has its own answer.
        property bool open: false

        icon: Network.wired ? "lan" : Network.connected ? "wifi" : "wifi_off"
        label: Network.wired ? "ETH" : Network.connected ? Network.name : "Offline"
        // Every other decorative icon on the bar went neutral, but this one
        // pill has no other way left to say "no link at all" -- the label
        // already reads "Offline" up close, the colour is what carries it at
        // a glance. A network that is merely slow is not this; only
        // Network.connected going false is.
        iconColor: Network.connected ? Colors.networkIcon : Colors.networkOffline

        MouseArea {
            id: networkArea
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

    // A machine-local pill from the gitignored Local/ folder (see
    // .gitignore): on a checkout without Local/LocalPill.qml the component
    // never becomes Ready, so nothing is loaded and nothing is logged.
    // Hidden with its item so the row keeps no spacing for an empty slot.
    Loader {
        id: localPill

        sourceComponent: root._localPill.status === Component.Ready ? root._localPill : null
        visible: item?.visible ?? false
    }

    // Bell, settings and power are one idea -- shell controls -- so they
    // share the same lighter capsule the audio pair above does.
    BarGroup {
        id: controlsGroup

        Pill {
            id: bellPill

            pressed: bellArea.pressed

            content: NotificationBell {}

            MouseArea {
                id: bellArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Notifications.toggleDnd()
                    : Notifications.togglePanel()
            }
        }

        // Settings and power used to be two pills; now one, opening the
        // merged menu that folds the power actions in. The glyph is a plain
        // Unicode star, not a Material Symbol, so it needs caelusevka rather
        // than the icon font -- see Pill.qml's iconFamily. Colour is neutral
        // like the rest of the chrome: colour on this bar now means state,
        // and a menu button has none at rest.
        Pill {
            id: menuPill

            pressed: menuArea.pressed

            icon: "✦"
            iconFamily: Caelus.fontFamily
            // caelusevka's star fills far less of its em box than a Material
            // Symbol does of its own, so it needs to run well above the 16px
            // the icon font sits at to land at the same optical size as the
            // bell and the network glyph beside it.
            iconSize: 22
            // The one coloured piece of chrome on a bar where colour
            // otherwise means state: this is the shell's own mark, matching
            // the star in the menu it opens, so it reads as a logo rather
            // than as another readout.
            iconColor: Colors.accent

            MouseArea {
                id: menuArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Power.menuOpen = !Power.menuOpen
            }
        }
    }
}
