import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services

// Helper for SettingsLookPage.qml: the folder-navigable wallpaper grid, one
// level under the hero preview in SettingsLookHero.qml. Reads and drives
// `Wallpapers` exactly the way WallpaperSwitcher.qml's coverflow does --
// `entries`/`dir`/`open`/`back`/`apply` are the same singleton, so a folder
// opened from here is exactly as open the next time Ctrl+Alt+F brings up the
// full switcher, and vice versa. That shared state is accepted, not a bug:
// see the contract this page was built against.
//
// Kept light on purpose (the contract's own words): a GridView, not a Grid,
// so a folder the size of WallpaperSwitcher's own Wallhaven example (112
// thumbnails, per Wallpapers.qml's header comment) only ever decodes the
// handful of cells actually inside `gridBody`'s fixed viewport -- scrolled
// with its own ThinScrollBar rather than left to grow into the page's outer
// Flickable, which is what keeps the decode count bounded regardless of how
// large the folder is.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    // `Wallpapers.entries` starts empty and stays that way until something
    // actually asks it to scan a directory -- normally the first time Ctrl+
    // Alt+F opens the full switcher (see `togglePanel()`). A session where
    // nobody has done that yet would otherwise land on this card and read
    // "nothing here" under a perfectly good wallpaper tree. Guarded on
    // `entries.length === 0` rather than firing unconditionally like
    // `togglePanel()` does: this page's Loader tears the component down and
    // rebuilds it on every switch away and back (see SettingsWindow.qml's
    // page host), and a scan already sitting in `entries` from an earlier
    // visit -- or from the switcher itself -- is exactly as current as a
    // fresh one would be, so there is nothing to gain from re-running
    // wallpaper-scan.sh every single time this card is reshown.
    Component.onCompleted: {
        if (Wallpapers.entries.length === 0 && !Wallpapers.scanning)
            Wallpapers.refresh();
    }

    function _activate(entry) {
        if (!entry) return;
        switch (entry.kind) {
        case "image":
            Wallpapers.apply(entry.path);
            break;
        case "folder":
            Wallpapers.open(entry.path);
            break;
        case "back":
            Wallpapers.back();
            break;
        }
    }

    // ── breadcrumb ───────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(36 * Caelus.uiScale, crumbRow.implicitHeight + Caelus.spaceWide * 2)

        RowLayout {
            id: crumbRow

            anchors.fill: parent
            anchors.margins: Caelus.spaceWide
            spacing: Caelus.space

            Item {
                id: backFocus

                visible: !Wallpapers.atRoot
                implicitWidth: backIcon.implicitWidth + Caelus.spaceTight * 2
                implicitHeight: backIcon.implicitHeight + Caelus.spaceTight * 2
                activeFocusOnTab: !Wallpapers.atRoot

                Keys.onReturnPressed: Wallpapers.back()
                Keys.onSpacePressed: Wallpapers.back()

                Rectangle {
                    anchors.fill: parent
                    // A hover film, not a push button -- square per the
                    // ROUNDING RULE's "rows + row hover film" entry.
                    radius: 0
                    color: backHover.containsMouse ? Colors.surfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Text {
                    id: backIcon

                    anchors.centerIn: parent
                    text: "arrow_back"
                    color: Colors.fgDim
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle
                }

                MouseArea {
                    id: backHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { backFocus.forceActiveFocus(); Wallpapers.back(); }
                }

                FocusRing {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 0
                    show: backFocus.activeFocus
                }
            }

            Text {
                text: Wallpapers.label !== "" ? Wallpapers.label : "wall"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: Wallpapers.scanning
                text: "scanning…"
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(1, Caelus.borderWidth)
        color: Colors.popupBorder
    }

    // ── grid ─────────────────────────────────────────────────────
    Item {
        id: gridBody

        Layout.fillWidth: true
        implicitHeight: 300 * Caelus.uiScale
        clip: true

        GridView {
            id: grid

            anchors.fill: parent
            anchors.margins: Caelus.spaceSnug
            cellWidth: 104 * Caelus.uiScale
            cellHeight: 104 * Caelus.uiScale
            model: Wallpapers.entries
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // A handful of rows' worth either side of what is actually on
            // screen, so a fast scroll finds its next cell's thumbnail
            // already decoding instead of starting cold -- the same reason
            // WallpaperSwitcher.qml's own PathView keeps a `cacheItemCount`.
            cacheBuffer: 4 * cellHeight

            ScrollBar.vertical: ThinScrollBar {}

            delegate: Item {
                id: cell

                required property var modelData

                readonly property bool isImage: cell.modelData.kind === "image"
                readonly property bool isBack: cell.modelData.kind === "back"
                readonly property bool isCurrent: cell.isImage && cell.modelData.path === Wallpapers.current

                width: grid.cellWidth
                height: grid.cellHeight

                Item {
                    id: tileArea

                    anchors.fill: parent
                    anchors.margins: Caelus.spaceSnug

                    Rectangle {
                        id: tile

                        anchors.fill: parent
                        // Grid tiles (and the selection outline drawn on this
                        // same Rectangle's border) are square per the
                        // ROUNDING RULE.
                        radius: 0
                        clip: true
                        color: cell.isImage ? Colors.surface : Colors.surfaceRaised
                        border.width: cell.isCurrent ? 2 : Caelus.borderWidth
                        border.color: cell.isCurrent ? Colors.popupAccent : Colors.surfaceHover

                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.width { NumberAnimation { duration: Motion.fast } }

                        Image {
                            anchors.fill: parent
                            visible: !!cell.modelData.thumb
                            // No `file://` prefix -- `thumb` is read exactly
                            // the way WallpaperSwitcher.qml's own delegate
                            // reads it, straight off what wallpaper-scan.sh
                            // prints.
                            source: cell.modelData.thumb ?? ""
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 160
                            sourceSize.height: 160
                            retainWhileLoading: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !cell.isImage
                            color: Colors.surface
                            opacity: 0.55
                        }

                        Column {
                            visible: !cell.isImage
                            anchors.centerIn: parent
                            width: parent.width - Caelus.spaceWide * 2
                            spacing: Caelus.spaceTight

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.isBack ? "arrow_back" : "folder"
                                color: Colors.accentBright
                                font.family: Caelus.symbolFamily
                                font.pixelSize: Caelus.sizeTitle * 1.5
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: cell.modelData.name ?? ""
                                color: Colors.fg
                                font.family: Caelus.fontFamily
                                font.pixelSize: Caelus.sizeLabel
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        id: cellFocus

                        anchors.fill: parent
                        activeFocusOnTab: true

                        Keys.onReturnPressed: root._activate(cell.modelData)
                        Keys.onSpacePressed: root._activate(cell.modelData)

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { cellFocus.forceActiveFocus(); root._activate(cell.modelData); }
                        }

                        FocusRing {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 0
                            show: cellFocus.activeFocus
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: Wallpapers.entries.length === 0
            text: Wallpapers.scanning ? "scanning…" : "nothing here"
            color: Colors.fgMuted
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }
    }
}
