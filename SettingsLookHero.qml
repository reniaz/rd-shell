import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Helper for SettingsLookPage.qml (the Appearance page's hero card): the
// wallpaper actually on screen right now, next to the palette it is driving.
// Deliberately read-only -- nothing here is a control, so it carries no
// FocusRing of its own, unlike every row in SettingsLookGrid.qml below it on
// the same page.
//
// The swatches are the whole point of putting this above the browsing grid:
// every `color:` binding below reads straight off `Colors`, which is itself
// a live re-derivation from `Wal` (see Colors.qml's own header), so picking
// a different wallpaper repaints this strip the instant matugen answers,
// with no extra plumbing -- the same reason WallpaperSwitcher.qml's own
// swatch row under the strip needs no refresh logic either.
Item {
    id: root

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Caelus.spaceWide * 2

    // One id per swatch, read back off `Colors` in the delegate below rather
    // than captured as a value here -- a plain array of colours would freeze
    // at whatever they were when this binding last ran, same reasoning as
    // WallpaperSwitcher's `previewRoles?.[modelData]` lookup.
    readonly property var _swatchIds: [
        "accent", "accentBright", "accentLight", "accentDeep",
        "surface", "surfaceRaised", "fg", "fgDim", "ok", "warn", "error"
    ]

    // "accentBright" -> "Accent bright" -- turns a token name into the label
    // under its swatch without a second, hand-written list to keep in sync.
    function _label(id) {
        const spaced = id.replace(/([A-Z])/g, " $1").toLowerCase();
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Caelus.spaceWide
        spacing: Caelus.spaceWide

        // The wallpaper itself, decoded small -- this is a hero thumbnail,
        // not the desktop, so it is capped at a fraction of the full
        // resolution WallpaperSwitcher's own flat-frame view asks for.
        Rectangle {
            id: previewFrame

            Layout.preferredWidth: 168 * Caelus.uiScale
            Layout.preferredHeight: 104 * Caelus.uiScale
            Layout.alignment: Qt.AlignVCenter
            // Square, per the ROUNDING RULE: the wallpaper hero is named
            // explicitly as a radius-0 surface, same as every card and row
            // in the app.
            radius: 0
            clip: true
            color: Colors.surface

            Image {
                anchors.fill: parent
                visible: Wallpapers.current !== ""
                source: Wallpapers.current !== "" ? "file://" + Wallpapers.current : ""
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                // Pinned, not bound to the frame's own (animated-by-uiScale)
                // size, for the same cache-key reason WallpaperSwitcher.qml's
                // thumbnails pin theirs -- a size that rode uiScale would
                // force a re-decode every time the slider moved.
                sourceSize.width: 336
                sourceSize.height: 208
                retainWhileLoading: true
            }

            Text {
                anchors.centerIn: parent
                visible: Wallpapers.current === ""
                text: "no wallpaper set"
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                wrapMode: Text.WordWrap
                width: parent.width - Caelus.spaceWide
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: Caelus.borderWidth
                border.color: Colors.popupBorder
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Caelus.spaceSnug

            Text {
                Layout.fillWidth: true
                text: "Current wallpaper"
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }

            Text {
                Layout.fillWidth: true
                text: Wallpapers.current !== "" ? Wallpapers.current.slice(Wallpapers.current.lastIndexOf("/") + 1) : "none yet"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideMiddle
            }

            // The live palette, named. One Repeater straight over Colors'
            // own property names -- see `_label()` above -- rather than a
            // hand-built array of {name, color} objects, so a swatch's
            // colour is read fresh off `Colors` every time it repaints
            // instead of being captured once into a model.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Caelus.spaceTight
                spacing: Caelus.spaceWide

                Repeater {
                    model: root._swatchIds

                    ColumnLayout {
                        id: swatch

                        required property string modelData

                        spacing: Caelus.spaceTight

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 22 * Caelus.uiScale
                            height: 22 * Caelus.uiScale
                            // Palette swatches are square per the ROUNDING
                            // RULE, not a "small control" -- radiusChip is
                            // reserved for switches, push buttons, key chips
                            // and the scrollbar thumb.
                            radius: 0
                            color: Colors[swatch.modelData]
                            border.width: Caelus.borderWidth
                            border.color: Colors.popupBorder

                            Behavior on color { ColorAnimation { duration: Motion.base; easing.type: Motion.standard } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root._label(swatch.modelData)
                            color: Colors.fgMuted
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeLabel * 0.85
                        }
                    }
                }
            }
        }
    }
}
