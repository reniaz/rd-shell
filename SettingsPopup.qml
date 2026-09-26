import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The live half of roadmap §7.6: a small, hand-picked surface over the
// settings a person actually reaches for. The dynamic colour switch was
// taken off the card -- colour simply follows the wallpaper whenever dynamic
// colour is on. Whether that colour keeps the wallpaper's own chroma or is
// reshaped into today's tonal-spot scheme is still a real choice, so that
// gets its own toggle, above the desktop widgets layer and the power
// section.
// The card and the click-outside dismissal both belong to BarPopup, same as
// every other popup on this bar.
//
// Also the one menu behind the bar's `✦` pill: the settings and power
// pills used to open separate windows, and now open this one instead, with
// PowerMenu.qml embedded as a section at the bottom -- see its own header
// for why the confirm flow that used to justify a dedicated window did not
// need one. Both halves open and close on the same flag, Power.menuOpen,
// which is what keeps the Super+M keybind and the IPC call in hyprland.lua
// working unchanged.
BarPopup {
    id: root

    namespace: "qs-settings"
    popupWidth: 320

    // As tall as the content needs and no taller than the screen allows --
    // the same idiom SysPopup uses. The screen cap only starts applying once
    // there is a screen height to cap against: a layer surface is told its
    // size a round trip after creation, so root.height is zero for the first
    // few frames, and an unguarded Math.min against that would open the card
    // at the floor and then grow.
    popupHeight: root.height > 0
        ? Math.min(root.height - (Caelus.barHeight - Caelus.barInset + Caelus.spaceEdge), body.implicitHeight + 28)
        : body.implicitHeight + 28

    // Belt-and-braces alongside whatever the loader that embeds this wires
    // its own onDismissed to: a Connections block, not `onDismissed:` on the
    // root itself, so this still fires even if a caller also sets its own
    // handler on the instance -- the two do not compete for the same slot.
    Connections {
        target: root

        function onDismissed() { Power.menuOpen = false; }
    }

    // Idea 9 (Accessibility settings pane): maps a 0..1 drag/wheel ratio onto
    // the slider's real range and snaps it to the step the brief asks for,
    // so the drag handler below stays a one-liner. Clamped at both ends
    // first -- a fast wheel notch or a drag past the track's edge must land
    // on the range's own limit, not spill past it.
    function setUiScale(ratio) {
        const clamped = Math.max(0, Math.min(1, ratio));
        const raw = 0.85 + clamped * (1.5 - 0.85);
        const stepped = Math.round(raw / 0.05) * 0.05;
        Settings.uiScale = Math.max(0.85, Math.min(1.5, stepped));
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceWide

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            // The shell's own mark rather than a gear, and the same glyph the
            // bar pill that opens this carries -- a plain Unicode star, so it
            // comes from caelusevka and not from the icon font every other
            // popup header draws from. It runs larger than those for the same
            // reason the bar pill's does: the star fills far less of its em
            // box than a Material Symbol fills of its own.
            Text {
                text: "✦"
                color: Colors.popupAccent
                font.family: Caelus.fontFamily
                font.pixelSize: 20
            }

            Text {
                text: "rd ✦ shell"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Whether matugen keeps the wallpaper's own colours instead of
        // reshaping them into today's tonal-spot scheme -- the binary on/off
        // the user asked for, not a scheme picker (Caelus.qml's scheme stays
        // fixed either way). Same glyph-swap idiom as every toggle on this
        // card, with a one-line caption under the label naming which way it
        // currently sits since the two states are not self-explanatory the
        // way "on"/"off" usually is here. Only meaningful while dynamic
        // colour is actually on -- Settings.dynamicColour is what gates
        // whether the shell recolours from the wallpaper at all -- so the
        // whole row dims and stops answering clicks when that is off, same
        // as this shell dims anything else a dependency has turned moot.
        RowLayout {
            id: wallpaperColoursRow

            Layout.fillWidth: true
            spacing: Caelus.space
            opacity: Settings.dynamicColour ? 1 : 0.4

            Behavior on opacity { NumberAnimation { duration: Motion.base } }

            Text {
                text: Settings.wallpaperColours ? "toggle_on" : "toggle_off"
                color: Settings.wallpaperColours ? Colors.popupAccent : Colors.fgMuted
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: Settings.dynamicColour
                    cursorShape: Settings.dynamicColour ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Settings.wallpaperColours = !Settings.wallpaperColours
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Wallpaper colours"
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    text: Settings.wallpaperColours
                        ? "Colours taken straight from the wallpaper"
                        : "Today's colours (default)"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Whether nvim and bat -- the two templates in matugen/hue.toml that
        // read syntax/ANSI colours -- keep a hued scheme even once the row
        // above resolves to matugen's scheme-monochrome (an achromatic
        // wallpaper). Meaningless unless wallpaper colours is actually on and
        // has actually landed on monochrome, but this row can't tell
        // colourful-wallpaper monochrome-toggle-off apart from an achromatic
        // one without re-running matugen just to check, so it dims and stops
        // answering clicks whenever either dependency above is off -- same
        // idiom as that row, one level down.
        RowLayout {
            id: keepAppColoursRow

            Layout.fillWidth: true
            spacing: Caelus.space
            opacity: (Settings.dynamicColour && Settings.wallpaperColours) ? 1 : 0.4

            Behavior on opacity { NumberAnimation { duration: Motion.base } }

            Text {
                text: Settings.keepAppColours ? "toggle_on" : "toggle_off"
                color: Settings.keepAppColours ? Colors.popupAccent : Colors.fgMuted
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: Settings.dynamicColour && Settings.wallpaperColours
                    cursorShape: (Settings.dynamicColour && Settings.wallpaperColours)
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Settings.keepAppColours = !Settings.keepAppColours
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Keep app colours"
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    text: Settings.keepAppColours
                        ? "nvim and bat keep syntax colours"
                        : "nvim and bat follow the wallpaper too"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // The one real toggle left on this card. Same glyph-swap idiom
        // NotificationPanel.qml's own DND control uses: a Material Symbol
        // that names the current state, not a separate switch widget.
        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: Settings.desktopWidgets ? "toggle_on" : "toggle_off"
                color: Settings.desktopWidgets ? Colors.popupAccent : Colors.fgMuted
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.desktopWidgets = !Settings.desktopWidgets
                }
            }

            Text {
                text: "Desktop widgets"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Idea 9: a dedicated accessibility pane. Every toggle below repeats
        // the desktop-widgets glyph-swap idiom above -- a Material Symbol
        // that names the current state rather than a separate switch widget
        // -- and each is wrapped in a plain focusable Item so Tab reaches it
        // and FocusRing has something real to outline; this is also the
        // section that setting exists for.
        Text {
            text: "Accessibility"
            color: Colors.fgMuted
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Item {
                id: scaleFocus

                implicitWidth: scaleIcon.implicitWidth
                implicitHeight: scaleIcon.implicitHeight
                activeFocusOnTab: true

                Text {
                    id: scaleIcon

                    text: "text_increase"
                    color: Colors.fgMuted
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle
                }

                FocusRing {
                    anchors.fill: parent
                    anchors.margins: -4
                    show: scaleFocus.activeFocus
                }
            }

            Text {
                text: "UI scale"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Settings.uiScale.toFixed(2) + "×"
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        Rectangle {
            id: scaleTrack

            Layout.fillWidth: true
            implicitHeight: 6
            radius: Caelus.radiusPill
            color: Colors.popupBorder

            readonly property real ratio: (Settings.uiScale - 0.85) / (1.5 - 0.85)

            Rectangle {
                width: Math.round(scaleTrack.width * scaleTrack.ratio)
                height: parent.height
                radius: parent.radius
                color: Colors.popupAccent
            }

            FocusRing {
                anchors.fill: parent
                anchors.margins: -6
                radius: Caelus.radiusPill
                show: scaleTrackFocus.activeFocus
            }

            Item {
                id: scaleTrackFocus

                anchors.fill: parent
                activeFocusOnTab: true

                Keys.onLeftPressed: root.setUiScale(scaleTrack.ratio - 0.05 / (1.5 - 0.85))
                Keys.onRightPressed: root.setUiScale(scaleTrack.ratio + 0.05 / (1.5 - 0.85))

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => { scaleTrackFocus.forceActiveFocus(); root.setUiScale(mouse.x / width); }
                    onPositionChanged: mouse => { if (pressed) root.setUiScale(mouse.x / width); }
                    onWheel: wheel => root.setUiScale(scaleTrack.ratio + (wheel.angleDelta.y > 0 ? 1 : -1) * 0.05 / (1.5 - 0.85))
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Item {
                id: contrastFocus

                implicitWidth: contrastIcon.implicitWidth
                implicitHeight: contrastIcon.implicitHeight
                activeFocusOnTab: true

                Keys.onReturnPressed: Settings.highContrast = !Settings.highContrast
                Keys.onSpacePressed: Settings.highContrast = !Settings.highContrast

                Text {
                    id: contrastIcon

                    text: Settings.highContrast ? "toggle_on" : "toggle_off"
                    color: Settings.highContrast ? Colors.popupAccent : Colors.fgMuted
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { contrastFocus.forceActiveFocus(); Settings.highContrast = !Settings.highContrast; }
                    }
                }

                FocusRing {
                    anchors.fill: parent
                    anchors.margins: -4
                    show: contrastFocus.activeFocus
                }
            }

            Text {
                text: "High contrast"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Item {
                id: focusRingFocus

                implicitWidth: focusRingIcon.implicitWidth
                implicitHeight: focusRingIcon.implicitHeight
                activeFocusOnTab: true

                Keys.onReturnPressed: Settings.focusRing = !Settings.focusRing
                Keys.onSpacePressed: Settings.focusRing = !Settings.focusRing

                Text {
                    id: focusRingIcon

                    text: Settings.focusRing ? "toggle_on" : "toggle_off"
                    color: Settings.focusRing ? Colors.popupAccent : Colors.fgMuted
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { focusRingFocus.forceActiveFocus(); Settings.focusRing = !Settings.focusRing; }
                    }
                }

                FocusRing {
                    anchors.fill: parent
                    anchors.margins: -4
                    show: focusRingFocus.activeFocus
                }
            }

            Text {
                text: "Visible focus ring"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Shutting down and logging out are the only irreversible controls
        // in this shell, so they sit behind the same divider idiom as every
        // other popup's sections.
        PowerMenu {
            Layout.fillWidth: true
        }
    }
}
