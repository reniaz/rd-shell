import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Config
import qs.Services

RowLayout {
    id: root

    required property var modelData

    // Exposed for BarOverlays.qml: the pill offsets its popups anchor on, and
    // mediaPill's own open flag so the media popup can close it back.
    readonly property real systemAnchorX: systemPill.x + systemPill.width / 2
    readonly property real mediaAnchorX: mediaPill.x + mediaPill.width / 2
    property alias mediaOpen: mediaPill.open

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Caelus.barMargin
    spacing: Caelus.barSpacing

    Pill {
        // Its own MouseArea takes no mouse buttons (wheel only, below) and
        // WorkspaceDots handles its own dot clicks internally, so there is no
        // press state on this pill to wire up -- `pressed` would just sit at
        // false forever.
        content: WorkspaceDots {
            id: dots
            monitor: Hyprland.monitorFor(root.modelData)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            onWheel: wheel => Workspaces.relative(dots.monitor, wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    Pill {
        id: mediaPill

        pressed: mediaArea.pressed

        // Same reasoning as the disk pill's: which bar you right-clicked is
        // the whole question, and a second monitor's pill has its own answer.
        property bool open: false

        icon: Media.playing ? "pause" : "play_arrow"
        label: Media.label
        iconColor: Colors.mediaIcon
        // A long title scrolls into view instead of ending in "..." -- see
        // Pill.qml's own comment on scrollLabel/labelActive. Only worth
        // animating while something is actually playing; paused or with no
        // player at all (the pill goes invisible then, via Media.available
        // below) there is nothing to burn a frame budget scrolling toward.
        scrollLabel: true
        labelActive: Media.playing
        // Lowered from 280: hb-shape measured the left island swinging
        // 717-805px wide as track titles changed length, shoving CavaBars
        // and the system pill sideways on every song. 160px is enough for a
        // meaningful chunk of most titles before Pill's own elide takes over.
        maxLabelWidth: 160
        // maxLabelWidth only ever bounds the label's ceiling inside Pill, not
        // its floor, so a short title still let the whole pill shrink to fit
        // it -- the actual swing this is fixing. Pinning the pill's own
        // Layout width is what stops that: icon (~20) + row spacing (7) +
        // the label cap (160) + Pill's own 18px of padding, plus a little
        // slack for the icon glyph estimate. One side effect worth knowing:
        // Pill centres its content, so a short title now sits centred inside
        // slack space rather than flush left -- worth a PRESS ticket if that
        // reads oddly once it's on screen, but it is what stops every pill
        // after this one from moving.
        Layout.preferredWidth: 210
        visible: Media.available

        MouseArea {
            id: mediaArea
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

    // A mini-EQ for whatever the media pill beside it is playing. Bare,
    // not wrapped in a Pill: it collapses to zero width by itself when
    // nothing is playing (Services/Cava.qml), so an empty pill shell is
    // not left standing beside a silent media pill.
    //
    // Settings.cavaPill gates it off entirely (default true, today's
    // unconditional behaviour). Wrapped in a plain Item rather than setting
    // `visible` on CavaBars directly: CavaBars.qml owns its own `visible`
    // binding (tied to its collapsed/live width, see that file) and is not
    // a file this round touches -- overriding that property from here would
    // silently replace its self-collapse logic instead of adding to it. The
    // wrapper mirrors CavaBars' own implicitWidth/Height so RowLayout still
    // sizes and spaces it identically whenever it's visible, and going
    // invisible here closes the gap the same way bluetoothPill/mediaPill
    // already do when they hide (RowLayout reserves no spacing for an
    // invisible child).
    Item {
        id: cavaSlot

        implicitWidth: cavaBars.implicitWidth
        implicitHeight: cavaBars.implicitHeight
        visible: Settings.cavaPill && cavaBars.visible

        CavaBars { id: cavaBars }
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

        pressed: systemArea.pressed

        content: SysReadout {}
        // Settings.systemPill is a person's own override on top of the
        // self-gate SysMon.available already was -- default true, exactly
        // today's behaviour, same shape as bluetoothPill's adapter default.
        visible: SysMon.available && Settings.systemPill

        MouseArea {
            id: systemArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onClicked: SysMon.togglePanel()
        }
    }

    // The dashboard's own pin, kept here rather than inside the notch tab
    // (BarWindow.qml) because that tab already carries the open/close
    // glyph and this is a second, independent action -- whether the panel
    // stays up past the next click-outside. Only reachable while there is
    // a dashboard to pin at all: "corners" is the one style the panel
    // exists under (Services/Dashboard.qml's own file comment), and while
    // it is actually open, the same way a popup's own pin control would
    // only show up on its card. Last in the left group since BarLeft has
    // no slot of its own this naturally belongs in.
    Pill {
        id: dashboardPinPill

        visible: BarStyles.current === "corners" && Dashboard.open
        pressed: dashboardPinArea.pressed
        icon: Dashboard.pinned ? "keep" : "keep_off"
        iconColor: Dashboard.pinned ? Colors.accentBright : Colors.fgMuted

        MouseArea {
            id: dashboardPinArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onClicked: Dashboard.togglePinned()
        }
    }
}
