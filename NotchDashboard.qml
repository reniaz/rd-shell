import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The panel the "corners" style's notch tab drops -- Ambxst's own utility
// tray (~/coding/shell-ideas/img/ocr-colorpicker-qr-utility-tray-1.png) is
// the layout this takes after: a row of quick toggles up top, then a media
// card, a calendar and a short notification peek on the left, brightness and
// volume on the right.
//
// Built on BarPopup exactly like CalendarPopup.qml/NotificationPanel.qml are
// -- same card, same clipped join at `Caelus.barHeight - Caelus.barInset`,
// same click-outside/Escape plumbing -- so it costs nothing extra to fuse
// into Blob's one shared silhouette the way every other popup already does.
//
// NOTCH FUSION, read before changing anything about the top edge: this file
// draws no Shape of its own for the island-to-card join. Tier 2 of the
// popup-edge-fusion plan once called for a hand-drawn concave-fillet Shape
// inside the popup window for exactly this seam, but Tier 3 (already
// shipped -- see Blob.qml, BarOverlays.cards, BarPopup's own cardRect/
// cardRadius/cardAlpha) replaced that per-corner geometry with one SDF
// smooth-min across every island and every open card at once. The notch tab
// agent S draws is a third Blob island; this card's own cardRect is reported
// through the exact same BarPopup mechanism CalendarPopup's card already
// uses, and BarOverlays.qml's `anchoredLoaders` carries this loader into
// that same shared fold (see the edit there). A narrow island smooth-min'd
// into a much wider card below it already produces the concave flare either
// side of the island's footprint that Tier 2 had to draw by hand -- it is
// an emergent property of the shared shader, not a second thing to get
// right here. That shader already enforces the guard on its own (`uJoinY`,
// pinned to this exact `Caelus.barHeight - Caelus.barInset` line) for every
// popup that reaches it, this one included, so there is no new seam risk to
// introduce by adding a duplicate, hand-rolled Shape on top of it.
BarPopup {
    id: root

    namespace: "qs-dashboard"
    popupWidth: 620
    popupHeight: body.implicitHeight + 28

    // Escape always closes, pinned or not -- unlike click-outside (see
    // BarOverlays.qml's `onDismissed` for that half). `dismissed()` fires
    // for both causes with no way to tell them apart from here (BarPopup's
    // own card both eats outside clicks and handles Escape through the same
    // signal -- see BarPopup.qml), so this reads Dashboard.open directly
    // instead of going through that signal at all. A Shortcut rather than a
    // Keys handler on something inside `body`: everything this panel
    // contains is a descendant of BarPopup's own `card`, which holds
    // `focus: true` itself, so a Keys handler down here would never be the
    // thing the key event actually reaches first.
    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: Dashboard.open = false
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceLoose

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: "dashboard"
                color: Colors.popupAccent
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: "Dashboard"
                color: Colors.calTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            // A second way to pin, for whoever is already looking at the
            // open panel rather than at the bar tab -- BarLeft.qml's own pin
            // glyph (agent S, corners-only) calls the same
            // `Dashboard.togglePinned()` this does.
            Text {
                text: "keep"
                color: Dashboard.pinned ? Colors.popupAccent : pinHover.hovered ? Colors.calTitle : Colors.calMeta
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeLead

                HoverHandler { id: pinHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Dashboard.togglePinned()
                }
            }
        }

        DashToggleRow {
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.spaceLoose

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 360
                spacing: Caelus.spaceLoose

                DashMediaCard {
                    Layout.fillWidth: true
                }

                // Round 5: the grid plus a picked day's agenda (or
                // "Upcoming" with nothing picked) -- see DashCalendarPane.qml.
                // DashCalendarGrid.qml is retired alongside this swap.
                DashCalendarPane {
                    Layout.fillWidth: true
                }

                DashNotifications {
                    Layout.fillWidth: true
                }
            }

            DashSideColumn {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
            }
        }
    }
}
