import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Row of StatusNotifierItem icons, sized to sit inside a Pill like WorkspaceDots.
Row {
    id: root

    // Bluetooth is managed from its own applet window, so its tray icon is one
    // more thing in the corner that never gets clicked. Filtered here rather
    // than hidden with visible:false so the Row does not keep its 8px of
    // spacing, and so the pill can disappear entirely when nothing else is in
    // the tray -- which is why it is a property and not an inline expression.
    readonly property var shown: SystemTray.items.values
        .filter(i => !/blue(man|tooth)/i.test((i.id ?? "") + " " + (i.title ?? "")))

    spacing: 8

    Repeater {
        model: root.shown

        Item {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: 17
            implicitHeight: 17

            IconImage {
                id: icon
                anchors.fill: parent
                source: entry.modelData.icon
                asynchronous: true
            }

            QsMenuAnchor {
                id: itemMenu

                menu: entry.modelData.menu

                // entry.x/y are relative to the Row, not the window -- using them
                // directly put every menu at the window origin (screen corner).
                // Resolve the position against the window's content item, and do it
                // in onAnchoring so it is computed when the menu actually opens.
                anchor {
                    window: entry.QsWindow.window
                    // Bottom gravity alone centres the menu on the anchor rect;
                    // Bottom|Left made it extend leftwards off the icon.
                    gravity: Edges.Bottom
                    adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

                    onAnchoring: {
                        const pos = entry.QsWindow.contentItem.mapFromItem(entry, 0, entry.height + 6);
                        itemMenu.anchor.rect.x = pos.x;
                        itemMenu.anchor.rect.y = pos.y;
                        itemMenu.anchor.rect.width = entry.width;
                        itemMenu.anchor.rect.height = 1;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    // onlyMenu items have no activate action -- the menu is the item
                    if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu) {
                        if (entry.modelData.hasMenu) itemMenu.open();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    } else {
                        entry.modelData.activate();
                    }
                }

                onWheel: wheel => {
                    entry.modelData.scroll(wheel.angleDelta.y, false);
                    entry.modelData.scroll(wheel.angleDelta.x, true);
                }
            }
        }
    }
}
