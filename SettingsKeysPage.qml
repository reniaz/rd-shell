import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services

// Settings app page (see the scratchpad contract this round builds
// against): "Keybinds" -- a searchable, browsable view of every live
// Hyprland bind (the same data KeybindOverview.qml's SUPER+K card shows),
// with rebinding done in place rather than by sending someone off to that
// card. `KeybindManager.qml` -- the capture dialog SUPER+K's own "edit"
// mode already uses -- is embedded directly below rather than reimplemented,
// since it already owns the whole capture/conflict/save flow; this file
// only has to give it a bind to capture for and a place to sit.
//
// The one thing KeybindManager.qml does not carry with it is the
// `ShortcutInhibitor` that makes capturing a SUPER-chord possible at all --
// in KeybindOverview.qml that is a sibling of the capture dialog, not part
// of it, wired to that file's own PanelWindow. Hyprland matches its own
// compositor binds before any client sees the key, toplevel or layer-shell
// alike, so without an inhibitor tied to *this* window, pressing SUPER+S
// here would just run Hyprland's SUPER+S instead of ever reaching
// KeybindManager's Keys.onPressed. The settings window itself
// (SettingsWindow.qml) is another agent's file and carries no inhibitor of
// its own -- but `QsWindow.window`, the same attached property
// TrayItems.qml already uses to reach its own enclosing window from deep
// inside a Row, gets this file to the real FloatingWindow instance without
// needing SettingsWindow.qml to cooperate at all. That is what makes
// embedding (rather than the contract's fallback of a button to
// `Keybinds.toggle()`) the right call here: the capture dialog works
// exactly as it does in the standalone overview, from a page file that
// touches nothing outside itself.
//
// The root is a plain `Item`, not a `SettingsPage` literal, because the
// capture dialog has to sit as a sibling OVER the page's own scrollable
// content, not inside it: `SettingsPage`'s default `content` alias would
// otherwise swallow a directly-nested KeybindManager into its scrolling
// column like any other row. `SettingsPage` itself is still the one and
// only thing filling this `Item`, so the page host's Loader (which sizes
// whatever root item a page returns) sizes this exactly as it would a bare
// `SettingsPage`.
Item {
    id: root

    // Fixed-width column for the key chips so every row's action text
    // starts at the same x regardless of how many keys a given chord has --
    // same idea as KeybindOverview.qml's own `keysWidth`, sized here for the
    // page's wider column rather than that card's 640px one.
    readonly property real keysWidth: 220 * Caelus.uiScale

    // One row of this page's bind list: key chips, the action (with any
    // "(remapped)" suffix hyprland.lua's override loader appends split out
    // into its own badge instead of left in the sentence), and a rebind
    // button for anything `Services/Keybinds.qml` can actually save a
    // capture for. Declared as its own type (an inline component, this
    // repo's idiom for a one-file-only delegate -- see PowerMenu.qml's
    // `Tile`) rather than reaching into the enclosing page's ids directly:
    // an inline component is its own scope, so -- exactly like `Tile`
    // signalling `picked()` instead of calling `root.choose()` itself --
    // this only ever emits `rebindRequested()` and leaves starting the
    // capture to whoever instantiates it.
    component BindRow: Item {
        id: bindRow

        // A Keybinds.binds / Keybinds.results entry: { keys, action, ref, raw, haystack }.
        required property var modelData

        readonly property bool canRebind: /^[0-9]+$/.test(bindRow.modelData.ref ?? "")
        readonly property bool remapped: typeof bindRow.modelData.action === "string"
            && bindRow.modelData.action.endsWith(" (remapped)")
        readonly property string actionText: bindRow.remapped
            ? bindRow.modelData.action.slice(0, bindRow.modelData.action.length - " (remapped)".length)
            : bindRow.modelData.action

        signal rebindRequested()

        // Column (not ColumnLayout) is what the group cards below stack
        // these in, so this sets its own width off its parent rather than
        // through a Layout attached property that a plain Column would
        // never read.
        width: bindRow.parent ? bindRow.parent.width : 0
        implicitHeight: Math.max(40 * Caelus.uiScale, rowInner.implicitHeight + Caelus.spaceSnug * 2)
        height: bindRow.implicitHeight

        readonly property bool _hovered: rowHover.containsMouse

        // ROUNDING RULE: row hover film is square, same as every other list
        // row in the settings app.
        Rectangle {
            anchors.fill: parent
            radius: 0
            color: bindRow._hovered ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover) : "transparent"

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: rowHover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: rowInner

            anchors.fill: parent
            anchors.margins: Caelus.spaceSnug
            spacing: Caelus.spaceWide

            // One keycap per key, same chip as KeybindOverview.qml's own list.
            Row {
                Layout.preferredWidth: root.keysWidth
                spacing: Caelus.spaceTight

                Repeater {
                    model: bindRow.modelData.keys

                    Rectangle {
                        id: cap

                        required property string modelData

                        width: capText.implicitWidth + 2 * Caelus.space
                        height: capText.implicitHeight + Caelus.spaceTight
                        radius: Caelus.radiusChip
                        color: Colors.surfaceRaised
                        border.width: Caelus.borderWidth
                        border.color: Colors.popupBorder

                        Text {
                            id: capText

                            anchors.centerIn: parent
                            text: cap.modelData
                            color: Colors.popupAccent
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeLabel
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: bindRow.actionText
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideRight
            }

            Text {
                visible: bindRow.remapped
                text: "remapped"
                color: Colors.popupAccent
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }

            // A mouse-drag bind carries no ref -- see Services/Keybinds.qml's
            // own `run()` and KeybindOverview.qml's `startEdit()` -- so there
            // is nothing here for it either.
            // ROUNDING RULE: this is a small push button, so it gets the one
            // radius the settings app allows above 0 -- Caelus.radiusChip,
            // never radiusPill.
            Rectangle {
                id: rebindButton

                visible: bindRow.canRebind
                implicitWidth: 28 * Caelus.uiScale
                implicitHeight: 28 * Caelus.uiScale
                radius: Caelus.radiusChip
                color: (rebindArea.containsMouse || rebindFocus.activeFocus) ? Colors.surfaceHover : Colors.surface

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "edit"
                    color: Colors.fg
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeBody
                }

                MouseArea {
                    id: rebindArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { rebindFocus.forceActiveFocus(); bindRow.rebindRequested(); }
                }

                Item {
                    id: rebindFocus

                    anchors.fill: parent
                    activeFocusOnTab: true

                    Keys.onReturnPressed: bindRow.rebindRequested()
                    Keys.onSpacePressed: bindRow.rebindRequested()
                }

                FocusRing {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Caelus.radiusChip
                    show: rebindFocus.activeFocus
                }
            }
        }
    }

    // --- This page's view onto the service's live bind list.
    //
    // `Services/Keybinds.qml` used to only re-read `hyprctl binds` on an
    // edge of its own `open` property (the flag `BarOverlays.qml`'s
    // `PopupLoader` uses to decide whether the standalone SUPER+K overview
    // exists on screen at all) -- so this page can't just set
    // `Keybinds.open = true` to piggyback on that reload: it would also pop
    // the real overview window open over this one (a layer-shell surface
    // that takes the keyboard exclusively). `Keybinds.reload()` is the
    // public way around that -- same `load` Process, no overlay side
    // effect -- called once below as soon as this page exists, so
    // `Keybinds.binds`/`Keybinds.findConflict` are populated whether or not
    // SUPER+K was ever opened this session. `_query` stays local to this
    // page and is never written into `Keybinds.query` -- that property
    // drives the standalone overview's own search field, not this one.
    property string _query: ""

    Component.onCompleted: Keybinds.reload()

    readonly property var _results: Keybinds.search(root._query)

    // Grouped by every key but the last one (e.g. "SUPER", "SUPER + SHIFT",
    // "No modifier" for the bare media/arrow binds), browsing-mode only --
    // hyprland.lua's own bind order already clusters related binds this
    // way, this just gives that clustering a visible label, the same label
    // style SettingsCard's own `title` already draws. While a search is
    // active the grouping drops out in favour of `_results`' own relevance
    // order (best match first): a result list is for scanning top to
    // bottom, not for browsing by category. Empty altogether (`[]`) both
    // while `Keybinds.binds` hasn't loaded yet and when a search matches nothing --
    // `_emptyText` below tells those two apart for the message that
    // replaces the card list in that case.
    readonly property var _sections: {
        const searching = root._query.trim().length > 0;
        const list = root._results;
        if (searching) return list.length > 0 ? [{ header: "", items: list }] : [];
        if (list.length === 0) return [];
        const groups = [];
        const byHeader = {};
        for (const b of list) {
            const header = b.keys.length > 1 ? b.keys.slice(0, -1).join(" + ") : "No modifier";
            if (!byHeader[header]) {
                byHeader[header] = { header, items: [] };
                groups.push(byHeader[header]);
            }
            byHeader[header].items.push(b);
        }
        return groups;
    }

    readonly property string _emptyText: Keybinds.binds.length === 0 ? "Reading binds…" : "No matching keybinds"

    Component.onDestruction: if (manager.capturing) manager.cancel()

    SettingsPage {
        id: page

        anchors.fill: parent
        title: "Keybinds"
        subtitle: "Every Hyprland bind running right now. Search to filter, the pencil to rebind."

        SettingsCard {
            Item {
                id: searchRow

                Layout.fillWidth: true
                implicitHeight: Math.max(52 * Caelus.uiScale, searchInner.implicitHeight + Caelus.spaceWide * 2)

                RowLayout {
                    id: searchInner

                    anchors.fill: parent
                    anchors.margins: Caelus.spaceWide
                    spacing: Caelus.space

                    Text {
                        text: "search"
                        color: Colors.fgDim
                        font.family: Caelus.symbolFamily
                        font.pixelSize: Caelus.sizeTitle
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: searchField.implicitHeight

                        TextInput {
                            id: searchField

                            anchors.fill: parent
                            color: Colors.fg
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeBody
                            selectByMouse: true
                            activeFocusOnTab: true

                            onTextEdited: root._query = searchField.text

                            // Escape clears the field when there's something
                            // to clear, same as the standalone overview's own
                            // search field; an already-empty field has
                            // nothing for Escape to do here, so the event is
                            // left unaccepted and bubbles up to
                            // SettingsWindow.qml, which closes the window on
                            // it.
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape && searchField.text.length > 0) {
                                    searchField.text = "";
                                    root._query = "";
                                    event.accepted = true;
                                }
                            }

                            // ROUNDING RULE: the search field is square.
                            FocusRing {
                                anchors.fill: parent
                                anchors.margins: -6
                                radius: 0
                                show: searchField.activeFocus
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search keybinds…"
                            visible: searchField.text.length === 0
                            color: Colors.fgDim
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeBody
                        }
                    }

                    Text {
                        text: root._query.trim().length > 0
                            ? `${root._results.length}/${Keybinds.binds.length}`
                            : `${Keybinds.binds.length}`
                        color: Colors.fgMuted
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel
                    }
                }
            }

            SettingsButtonRow {
                icon: "open_in_new"
                label: "Full keybind overview"
                caption: "The same list in its own floating card -- run a bind, not just browse it (SUPER + K)"
                buttonText: "Open"
                onClicked: Keybinds.toggle()
            }
        }

        SettingsCard {
            SettingsButtonRow {
                icon: "restart_alt"
                label: "Reset keybinds to defaults"
                caption: root._resetStatus !== "" ? root._resetStatus
                    : (Keybinds.overrideEntries.length === 0
                        ? "Every bind is at its default"
                        : `${Keybinds.overrideEntries.length} bind${Keybinds.overrideEntries.length === 1 ? "" : "s"} remapped from the defaults`)
                buttonText: "Reset"
                onClicked: {
                    root._resetStatus = "Resetting…";
                    root._resetToken = Keybinds.resetOverrides();
                }
            }
        }

        Repeater {
            model: root._sections

            SettingsCard {
                required property var modelData

                title: modelData.header

                Column {
                    Layout.fillWidth: true
                    spacing: Caelus.spaceTight

                    Repeater {
                        model: modelData.items

                        BindRow {
                            onRebindRequested: manager.startCapture(modelData)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root._sections.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: root._emptyText
            color: Colors.fgMuted
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }
    }

    // The token `Keybinds.resetOverrides` handed back for the reset in
    // flight, the same way KeybindOverview.qml's own reset label tracks it --
    // without it, a stale `saveFinished` from a rebind started and abandoned
    // right before "Reset" was clicked could overwrite this status with a
    // result that was never about the reset at all.
    property var _resetToken: null
    property string _resetStatus: ""

    Connections {
        target: Keybinds

        function onSaveFinished(ok, error, token) {
            if (root._resetStatus === "") return; // not mid-reset
            if (token !== root._resetToken) return; // some other save/reset
            root._resetStatus = ok ? "Reset to defaults" : error;
        }
    }

    // The capture dialog itself -- see the header comment for why this is
    // embedded rather than left to the overview. Sits over the whole page
    // (including the rail-free area the Loader gave this file), the same
    // full-bleed scrim KeybindOverview.qml gives it there.
    KeybindManager {
        id: manager

        anchors.fill: parent
        // ROUNDING RULE: square inside the settings app, unlike the
        // standalone SUPER+K overview this same dialog otherwise matches.
        cardRadius: 0
    }

    // What actually makes capturing a SUPER-chord possible from inside this
    // window -- see the header comment. `enabled` follows `manager.capturing`
    // exactly, never `SettingsApp.open` or similar, so Hyprland's own
    // shortcuts are only ever inhibited for the handful of seconds a capture
    // is actually waiting on a key, not for the window's whole lifetime.
    ShortcutInhibitor {
        window: root.QsWindow.window
        enabled: manager.capturing

        onCancelled: if (manager.capturing) manager.cancel()
    }
}
