pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Idea 43 (lock-resource-hover-swap): a small card on the lock screen that
// shows CPU/RAM at rest and swaps to the four session actions under the
// pointer -- caelestia-shell's lock Resources.qml (resourcesTranslate /
// buttonsTranslate) is the model this follows: two same-footprint rows, each
// carried on its own `Translate`, sliding past each other in opposite
// directions while they cross-fade.
//
// Stats source, decided up front: this does NOT stand up a second poller.
// Services/SysMon.qml's sampler Process is declared `running: true`
// unconditionally (see that file) -- it is already sampling /proc every tick
// whether or not any popup is open; `panelOpen` only gates the *extra*
// per-process scan, never the base cpuPercent/memPercent feed this card
// reads. Binding straight to SysMon.cpuPercent/memPercent therefore costs
// nothing beyond what is already running -- no new Process, no new Timer, no
// new /proc reads -- which is strictly cheaper than a "trimmed" one-shot
// /proc reader would be, since that would still be a poller that runs only
// while this card exists. That is the "already cheap, reuse it" branch the
// task asked to decide between.
//
// Actions source: Services/Power.qml's `actions` array is already the one
// place PowerMenu.qml reads shutdown/restart/lock/logout from (see its
// Repeater over `Power.actions`) -- there is nothing to refactor here, this
// card is simply a second reader of the same array, so PowerMenu's own
// behaviour is untouched.
Item {
    id: root

    implicitWidth: 200
    implicitHeight: 40

    // Hover, not a MouseArea: a MouseArea that accepts hover would sit in
    // front of everything under it and start competing with the action
    // tiles' own MouseAreas below (see Pill.qml's header comment for exactly
    // this trap). HoverHandler only ever observes -- it takes no buttons and
    // never accepts keyboard focus, so it cannot steal either from
    // LockSurface's password field.
    HoverHandler {
        id: hover
    }

    readonly property bool sessionShown: hover.hovered

    // A destructive action arms on its first click and only runs on a
    // second one inside `confirmWindow` -- the same two-step guard
    // PowerMenu.qml gives shutdown/restart/logout via its choose/confirm
    // stage, compressed into one tile instead of a second card face, since
    // this card has no room to spare for a whole confirm screen. Cleared the
    // moment the pointer leaves (sessionShown goes false) so a card that is
    // hovered again later never opens back up mid-arm.
    property string armedLabel: ""

    onSessionShownChanged: if (!root.sessionShown) {
        root.armedLabel = "";
        armTimer.stop();
    }

    Timer {
        id: armTimer
        interval: 2500
        onTriggered: root.armedLabel = ""
    }

    // Confirm-free actions (today, only Lock -- Power.actions marks it
    // `confirm: false` already) run on the first click, same as the power
    // menu. Locking again from the lock screen is a deliberate no-op, not a
    // dead button: scripts/lock.sh checks `ipc status` first and exits
    // immediately when already locked/locking, so this can never double-arm
    // a second lock surface or race the one already up.
    function activate(action) {
        if (action.confirm === false) {
            action.run();
            return;
        }
        if (root.armedLabel === action.label) {
            armTimer.stop();
            root.armedLabel = "";
            action.run();
        } else {
            root.armedLabel = action.label;
            armTimer.restart();
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Caelus.radiusCard
        color: Colors.surfaceRaised
        border.width: Caelus.borderWidth
        // Same convention as LockSurface's own password field: the accent
        // only shows up once the card is actually doing something, plain
        // outline otherwise.
        border.color: root.sessionShown ? Colors.popupAccent : Caelus.border
        // Both rows below are the same size as this card and only ever
        // travel by their own height -- without this they would paint over
        // the rounded corners (and each other) mid-slide instead of
        // appearing to leave/enter through them.
        clip: true

        Behavior on border.color {
            ColorAnimation { duration: Motion.fast }
        }

        // ── row 1: stats ─────────────────────────────────────
        Item {
            id: statsRow

            anchors.fill: parent
            anchors.margins: Caelus.space

            opacity: root.sessionShown ? 0 : 1

            // `slow` (220ms/OutCubic): Motion.qml's own words for it are
            // "something crossing the screen edge... a card leaving", which
            // is exactly this -- not `base`, which is for a shape resizing
            // in place, and not `fast`, which would read as a flicker over a
            // full row's travel.
            transform: Translate {
                y: root.sessionShown ? -statsRow.height : 0

                Behavior on y {
                    NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: Motion.slow }
            }

            RowLayout {
                anchors.fill: parent
                spacing: Caelus.spaceWide

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    spacing: Caelus.spaceSnug

                    Text {
                        text: "memory"
                        color: Colors.fgDim
                        font.family: Caelus.symbolFamily
                        font.pixelSize: 15
                    }

                    Text {
                        text: SysMon.cpuPercent >= 0 ? SysMon.cpuPercent + "%" : "--"
                        // Colors.usage(), not the sysColor/sysIcon base
                        // SysCpuTab/SysReadout pair it with elsewhere: those
                        // sit on a popup card or a bar pill, this sits on
                        // fg-toned lock-screen text, so `fg` is the "nothing
                        // to report" base instead -- same function, this
                        // card's own resting colour.
                        color: Colors.usage(SysMon.cpuPercent, Colors.fg)
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    spacing: Caelus.spaceSnug

                    // SysReadout.qml's own icon for this exact reading --
                    // reused rather than invented, so "RAM" looks the same
                    // glyph everywhere this shell shows it.
                    Text {
                        text: "memory_alt"
                        color: Colors.fgDim
                        font.family: Caelus.symbolFamily
                        font.pixelSize: 15
                    }

                    Text {
                        text: SysMon.memPercent >= 0 ? SysMon.memPercent + "%" : "--"
                        color: Colors.usage(SysMon.memPercent, Colors.fg)
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }
                }
            }
        }

        // ── row 2: session actions ───────────────────────────
        Item {
            id: actionsRow

            anchors.fill: parent
            anchors.margins: Caelus.spaceSnug

            opacity: root.sessionShown ? 1 : 0
            // Deliberate: opacity 0 keeps MouseAreas hit-testable, and the card's
            // clip is the only thing hiding the parked row today. Disabling it at
            // rest makes the tiles inert on their own, whatever the geometry.
            enabled: root.sessionShown

            // Mirrored travel (+height -> 0) and the same duration/easing as
            // the stats row above -- one crossing the same edge outbound and
            // the other inbound, so neither leads or lags the other.
            transform: Translate {
                y: root.sessionShown ? 0 : actionsRow.height

                Behavior on y {
                    NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: Motion.slow }
            }

            RowLayout {
                anchors.fill: parent
                spacing: Caelus.spaceTight

                Repeater {
                    model: Power.actions

                    Rectangle {
                        id: tile

                        required property var modelData

                        readonly property bool armed: root.armedLabel === tile.modelData.label
                        readonly property bool hovered: press.containsMouse

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Caelus.radiusChip
                        // Same "wash, not a solid fill" language as every
                        // other hover surface in this shell (Pill's
                        // hoverBg, Caelus.opacityHover/opacityPress) -- the
                        // armed wash just borrows the critical colour
                        // instead of `fg`, since arming *is* this tile's
                        // press state.
                        color: tile.armed ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, Caelus.opacityPress)
                            : (tile.hovered ? Colors.surfaceHover : "transparent")

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            // Only the icon reddens on arm -- the same
                            // "danger" signal PowerMenu's own confirm-stage
                            // Tile gives its "Yes" button, here standing in
                            // for that whole second stage since this card
                            // has no room for one.
                            color: tile.armed ? Colors.error : Colors.fgDim
                            font.family: Caelus.symbolFamily
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: press

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(tile.modelData)
                        }
                    }
                }
            }
        }
    }
}
