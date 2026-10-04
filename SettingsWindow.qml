import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The settings *app* -- end-4/illogical-impulse's Super+I window, not the
// bar's own `✦` pill menu (SettingsPopup.qml, still a BarPopup card for the
// handful of toggles people actually reach for every day). This is the
// bigger surface behind it: a navigation rail on the left, one page of
// cards on the right, for everything that does not earn a spot on that
// quick card.
//
// A real `FloatingWindow` -- an xdg toplevel of its own, not another
// layer-shell surface folded into BarWindow.qml's fused strip -- because
// that is the only way Hyprland gives it the things an app window gets for
// free: a title bar's worth of window-manager behaviour (float, move,
// resize, close), a class `hl.window_rule` in hyprland.lua can target, and a
// lifetime the compositor itself ends when the person hits Super+Q or clicks
// the window's own close -- none of which a PanelWindow has, and all of
// which this window needs so that closing it from either direction (Esc
// inside, or the compositor from outside) agrees with SettingsApp.open.
//
// shell.qml only ever creates this behind `LazyLoader { active:
// SettingsApp.open }`, so the window itself can assume it is wanted the
// instant it exists -- there is no separate `open` property to fade in and
// out the way every layer-shell overlay in this shell (Launcher.qml,
// WallpaperSwitcher.qml, PowerMenu.qml) has to carry, because tearing a real
// toplevel down *is* the close animation as far as Hyprland is concerned.
FloatingWindow {
    id: root


    title: "rd-shell settings"
    color: "transparent"

    implicitWidth: 960 * Caelus.uiScale
    implicitHeight: 640 * Caelus.uiScale
    minimumSize: Qt.size(720 * Caelus.uiScale, 480 * Caelus.uiScale)
    // No reason for this window to grow past a size its own rail and page
    // column were ever designed to fill; keeps a maximize/tile attempt from
    // the window manager from stretching the rail into mostly empty space.
    maximumSize: Qt.size(1400 * Caelus.uiScale, 1000 * Caelus.uiScale)

    // The one signal `WindowInterface` (what every Quickshell window,
    // layer-shell or toplevel, is built on) fires when the *backing* window
    // goes away -- not just this QML object being destroyed, but Hyprland
    // itself tearing down the surface, whether that is Super+Q, `hyprctl
    // dispatch closewindow`, or the person clicking a close button a window
    // rule might someday add. SettingsApp.open has to follow that, not just
    // the other way around (this window existing only because that flag was
    // already true) -- otherwise closing the window from the compositor side
    // would leave SettingsApp certain the window is still up, and the next
    // Super+I or IPC `toggle` would try to open an already-closed window and
    // do nothing.
    onClosed: SettingsApp.close()

    // Every page id in rail order, found once per page change rather than
    // read inline at each of the three places below that need the index
    // (the active nav row, the sliding indicator, Ctrl+Tab's wraparound) --
    // all three would otherwise repeat the same `findIndex` call on every
    // one of SettingsApp.pages' re-evaluations.
    readonly property var _pageIds: SettingsApp.pages.map(p => p.id)
    readonly property int _activeIndex: root._pageIds.indexOf(SettingsApp.page)

    function _cyclePage(delta) {
        const count = root._pageIds.length;
        if (count === 0) return;
        const next = (root._activeIndex + delta + count) % count;
        SettingsApp.select(root._pageIds[next]);
    }

    // The rail's own width, named once since both the rail and the page
    // column's left edge are pinned off it.
    readonly property real railWidth: 220 * Caelus.uiScale

    // One focus scope covering the whole window -- Quickshell windows have
    // no key handling of their own (see Launcher.qml's TextInput and every
    // other overlay in this shell for the same idiom); this is the thing
    // that actually owns it, since unlike those overlays nothing inside this
    // one window always wants the keyboard the way a search field does.
    Item {
        id: content

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SettingsApp.close();
                event.accepted = true;
                return;
            }

            if (event.modifiers & Qt.ControlModifier) {
                // Qt reports Shift+Tab as Key_Backtab on most platforms, not
                // as Key_Tab with the Shift modifier still set -- both are
                // checked so Ctrl+Shift+Tab reliably cycles backwards rather
                // than occasionally falling through as an unhandled key.
                if (event.key === Qt.Key_Tab) {
                    root._cyclePage((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Backtab) {
                    root._cyclePage(-1);
                    event.accepted = true;
                    return;
                }

                // Ctrl+1..Ctrl+6 jump straight to a rail page by position --
                // Key_1.._Key_9 are contiguous, so one subtraction maps the
                // key to a rail index instead of writing six near-identical
                // branches.
                const slot = event.key - Qt.Key_1;
                if (slot >= 0 && slot < root._pageIds.length && event.key <= Qt.Key_9) {
                    SettingsApp.select(root._pageIds[slot]);
                    event.accepted = true;
                }
            }
        }

        // The window's own body. Translucent at the same alpha every popup
        // card in this shell draws its surface at (Caelus.opacitySurface,
        // read through Colors.popupBg), so Hyprland's blur -- already
        // enabled for any window with alpha < 1, no extra layer rule needed
        // the way a layer-shell surface requires -- shows the desktop
        // through it like glass instead of leaving a flat, opaque panel
        // that happens to be the wrong colour for one.
        Rectangle {
            anchors.fill: parent
            color: Colors.popupBg
        }

        // The rail. A slightly raised tint over the body so it reads as its
        // own strip without a hard seam -- the same "card on a panel" step
        // Caelus.elevated describes, built here from Colors.surfaceRaised at
        // the body's own glass alpha so the two surfaces still look like one
        // material rather than two different layers of transparency stacked
        // on each other.
        Rectangle {
            id: rail

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.railWidth
            color: Qt.rgba(Colors.surfaceRaised.r, Colors.surfaceRaised.g, Colors.surfaceRaised.b, Caelus.opacitySurface)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Caelus.spaceEdge
                spacing: Caelus.spaceWide

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Caelus.space

                    // The shell's own mark, same idiom as SettingsPopup.qml's
                    // header: a plain Unicode star from caelusevka, not a
                    // Material Symbol, so it is never confused with a rail
                    // icon.
                    Text {
                        text: "✦"
                        color: Colors.popupAccent
                        font.family: Caelus.fontFamily
                        font.pixelSize: 20
                    }

                    Text {
                        text: "settings"
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

                // The nav list itself. An Item, not a Layout, wraps the
                // indicator and the Repeater together: the indicator has to
                // sit *behind* the row it is currently under (declared
                // first, so later siblings paint over it) while still
                // sharing the exact same vertical rhythm the rows lay
                // themselves out in, and a Column already gives both of
                // them that rhythm for free through `spacing` and a fixed
                // per-row height.
                Item {
                    id: navArea

                    Layout.fillWidth: true
                    Layout.preferredHeight: navColumn.implicitHeight

                    readonly property real itemHeight: 44 * Caelus.uiScale
                    readonly property real itemSpacing: Caelus.spaceTight

                    // The sliding pill, one accent-filled rectangle that
                    // moves to whichever row is active instead of each row
                    // painting its own fill -- the same "one shape, one
                    // owner" idiom WorkspaceDots.qml's travelling indicator
                    // uses for the same reason: a pill that teleports reads
                    // as six different buttons, one that glides reads as
                    // one selection moving between them.
                    Rectangle {
                        id: indicator

                        x: 0
                        width: navArea.width
                        height: navArea.itemHeight
                        // Square, per the rounding rule: max radius anywhere
                        // in the settings app is 4px, and this isn't one of
                        // the small controls that rule carves out.
                        radius: 0
                        color: Colors.popupAccent
                        visible: root._activeIndex >= 0
                        y: Math.max(0, root._activeIndex) * (navArea.itemHeight + navArea.itemSpacing)

                        Behavior on y {
                            NumberAnimation {
                                duration: Motion.spatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Motion.spatialCurve
                            }
                        }
                    }

                    Column {
                        id: navColumn

                        width: navArea.width
                        spacing: navArea.itemSpacing

                        Repeater {
                            model: SettingsApp.pages

                            delegate: Item {
                                id: navRow

                                required property var modelData
                                required property int index

                                readonly property bool active: modelData.id === SettingsApp.page

                                width: navColumn.width
                                height: navArea.itemHeight
                                activeFocusOnTab: true

                                Keys.onReturnPressed: SettingsApp.select(navRow.modelData.id)
                                Keys.onSpacePressed: SettingsApp.select(navRow.modelData.id)

                                // Hover film, same formula every row in this
                                // shell draws it with -- faint on purpose so
                                // it never competes with the indicator's own
                                // accent fill on the active row.
                                Rectangle {
                                    anchors.fill: parent
                                    // Square -- see the indicator's own
                                    // comment above on the rounding rule.
                                    radius: 0
                                    color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover)
                                    opacity: navMouse.containsMouse && !navRow.active ? 1 : 0

                                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                                }

                                FocusRing {
                                    anchors.fill: parent
                                    radius: 0
                                    show: navRow.activeFocus
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Caelus.spaceWide
                                    anchors.rightMargin: Caelus.spaceWide
                                    spacing: Caelus.space

                                    Text {
                                        text: navRow.modelData.icon
                                        color: navRow.active ? Colors.onAccent : Colors.fgDim
                                        font.family: Caelus.symbolFamily
                                        font.pixelSize: Caelus.sizeTitle
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: navRow.modelData.name
                                        color: navRow.active ? Colors.onAccent : Colors.fg
                                        font.family: Caelus.fontFamily
                                        font.pixelSize: Caelus.sizeBody
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: navMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { navRow.forceActiveFocus(); SettingsApp.select(navRow.modelData.id); }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }

        // The page host. A missing or broken page file -- every
        // Settings*Page.qml is owned by a different agent landing its own
        // files alongside this one -- must never take the whole window down
        // with it, so the Loader's own error state gets a plain placeholder
        // instead of being left to whatever blank rectangle QML draws for a
        // component that failed to load.
        Item {
            id: pageHost

            anchors.left: rail.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            // Faded + risen in on every page change, same duration/curve
            // pair every ordinary (non-spatial) transition in this shell
            // uses -- `base` for something changing in place, `standard` as
            // the default decelerating curve.
            Loader {
                id: pageLoader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Caelus.spaceEdge
                asynchronous: true

                // Re-set on every page change (not just once) so a page that
                // failed to load because its file did not exist yet picks up
                // the moment that file lands -- Quickshell hot-reloads the
                // whole shell on save, but a Loader only re-resolves its own
                // `source` when that binding is actually re-evaluated.
                readonly property var _page: SettingsApp.pages.find(p => p.id === SettingsApp.page)
                source: pageLoader._page ? pageLoader._page.source : ""

                opacity: pageLoader.status === Loader.Ready ? 1 : 0
                y: pageLoader.status === Loader.Ready ? 0 : 16

                Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                Behavior on y { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
            }

            // Shown only once the Loader has actually failed (a page file
            // that does not exist yet, or one with a QML error) -- not while
            // it is merely loading asynchronously -- so the empty frame this
            // window can be in for a while during development reads as
            // "nothing here yet" rather than as broken.
            Text {
                anchors.centerIn: parent
                visible: pageLoader.status === Loader.Error
                text: "This page isn't ready yet."
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }
        }
    }
}
