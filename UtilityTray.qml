import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Ctrl+Alt+U's "Utilities" tray: three independent screen-reading tools --
// read text (OCR, tesseract), pick a colour (hyprpicker) and scan a QR/
// barcode (zbarimg) -- behind one small popup, built in WallpaperSwitcher.qml
// and BarStyleSwitcher.qml's own style (same scrim, same escape/click-
// outside dismissal, same card) since this reads as their sibling: a
// keybind-only overlay with no bar pill, because a region-grab tool is only
// ever wanted on purpose.
//
// Unlike those two, this card never shows a "working" state: picking a tool
// hides the whole tray (Services/Utilities.qml does that, not this file) so
// slurp/hyprpicker can see the screen underneath it, and the tray only comes
// back once there is a result (or a quiet cancel put it back at the tool
// list) -- see that file's state machine for the whole shape of it. `busy`
// below exists only for the rare case of a second keybind press reopening
// the tray while a previous pipeline is still running in the background.
PanelWindow {
    id: root

    property bool open: true
    property bool _entered: false
    readonly property bool _shown: root._entered && root.open

    readonly property bool resultReady: Utilities.activeTool !== ""
        && (Utilities.state === "done" || Utilities.state === "empty" || Utilities.state === "error")
    readonly property bool busy: Utilities.activeTool !== "" && !root.resultReady

    // The QR tool's own payload is the only one ever offered an Open action
    // -- an http(s) URL in an OCR'd screenshot is not necessarily something
    // worth opening sight-unseen, but a QR code whose whole job is encoding
    // a URL is.
    readonly property bool resultIsUrl: Utilities.activeTool === "qr"
        && Utilities.state === "done" && /^https?:\/\//i.test(Utilities.resultText)

    property bool _justCopied: false

    function copyResult() {
        const value = Utilities.activeTool === "color" ? Utilities.resultColor : Utilities.resultText;
        if (!value) return;
        Quickshell.execDetached(["wl-copy", value]);
        root._justCopied = true;
        _copiedTimer.restart();
    }

    Timer {
        id: _copiedTimer
        interval: 1500
        onTriggered: root._justCopied = false
    }

    // Resets the "Copied" label the moment there is something new to copy,
    // rather than leaving it stuck from whichever tool ran last.
    Connections {
        target: Utilities
        function onActiveToolChanged() { root._justCopied = false; }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while actually open -- the fade-out must not go on
    // swallowing keystrokes meant for whatever is behind it.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Reuses the shared "any other popup" namespace rather than a new
    // "qs-utilities" one -- hyprland.lua's blur layer rule already covers
    // `qs-popup` (BarPopup.qml's own default, see its header comment) and
    // this round's contract scopes the hyprland.lua edit to the keybind
    // itself, not a new alternation entry in that rule.
    WlrLayershell.namespace: "qs-popup"
    color: "transparent"

    mask: root.open ? null : closedMask
    Region { id: closedMask }

    Component.onCompleted: root._entered = true

    function close() {
        Utilities.panelOpen = false;
    }

    Item {
        id: input

        anchors.fill: parent
        focus: true
        opacity: root._shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape) return;
            root.close();
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.scrim
        }

        // Drawn first, under the card, so it only ever catches a click the
        // card itself did not want -- the same click-outside-dismisses
        // convention every popup in this shell uses.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: 340
            height: body.implicitHeight + Caelus.spaceEdge * 2
            radius: Caelus.radiusPopover
            color: Qt.rgba(Colors.surfaceRaised.r, Colors.surfaceRaised.g,
                           Colors.surfaceRaised.b, 0.92)
            border.width: Caelus.borderWidth
            border.color: Colors.popupBorder

            opacity: root._shown ? 1 : 0
            scale: root._shown ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

            MouseArea { anchors.fill: parent } // swallows clicks before the scrim's own

            ColumnLayout {
                id: body

                anchors.fill: parent
                anchors.margins: Caelus.spaceEdge
                spacing: Caelus.spaceWide

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Caelus.space

                    Text {
                        text: "qr_code_scanner"
                        color: Colors.popupAccent
                        font.family: Caelus.symbolFamily
                        font.pixelSize: 16
                    }

                    Text {
                        text: "Utilities"
                        color: Colors.fg
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                    }

                    Item { Layout.fillWidth: true }

                    // Only shown over a result -- the idle tool list has
                    // nowhere else to go back to.
                    Text {
                        visible: root.resultReady
                        text: "arrow_back"
                        color: Colors.fgMuted
                        font.family: Caelus.symbolFamily
                        font.pixelSize: Caelus.sizeTitle

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Utilities.backToList()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colors.popupBorder
                }

                // ── idle: the three tools ───────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.busy && !root.resultReady
                    spacing: Caelus.spaceSnug

                    ToolRow {
                        icon: "document_scanner"
                        label: "Read text"
                        enabled: Ocr.available
                        hint: "sudo dnf install tesseract"
                        onPicked: Utilities.startOcr()
                    }

                    ToolRow {
                        icon: "colorize"
                        label: "Pick colour"
                        enabled: Utilities.colorAvailable
                        hint: "hyprpicker not found"
                        onPicked: Utilities.startColor()
                    }

                    ToolRow {
                        icon: "qr_code_scanner"
                        label: "Scan QR / barcode"
                        enabled: Utilities.qrAvailable
                        hint: "sudo dnf install zbar-tools"
                        onPicked: Utilities.startQr()
                    }
                }

                // ── busy: only ever seen on a reopen mid-pipeline ─
                Text {
                    Layout.fillWidth: true
                    visible: root.busy
                    horizontalAlignment: Text.AlignHCenter
                    text: "Working…"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                // ── result: empty / error ────────────────────────
                Text {
                    Layout.fillWidth: true
                    visible: root.resultReady && Utilities.state === "empty"
                    horizontalAlignment: Text.AlignHCenter
                    text: Utilities.activeTool === "ocr" ? "No text found" : "No code found"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.resultReady && Utilities.state === "error"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Utilities.errorText || "Something went wrong"
                    color: Colors.error
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                // ── result: recognised text / decoded payload ────
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.resultReady && Utilities.state === "done" && Utilities.activeTool !== "color"
                    spacing: Caelus.spaceSnug

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 160
                        wrapMode: Text.WordWrap
                        clip: true
                        text: Utilities.resultText
                        color: Colors.fg
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }

                    RowLayout {
                        spacing: Caelus.spaceSnug

                        ActionChip {
                            icon: "content_copy"
                            label: root._justCopied ? "Copied" : "Copy"
                            onClicked: root.copyResult()
                        }

                        ActionChip {
                            visible: root.resultIsUrl
                            icon: "open_in_new"
                            label: "Open"
                            onClicked: Quickshell.execDetached(["xdg-open", Utilities.resultText])
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // ── result: colour swatch ─────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.resultReady && Utilities.state === "done" && Utilities.activeTool === "color"
                    spacing: Caelus.space

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Caelus.radiusChip
                        color: Utilities.resultColor
                        border.width: Caelus.borderWidth
                        border.color: Colors.popupBorder
                    }

                    Text {
                        text: Utilities.resultColor
                        color: Colors.fg
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }

                    Item { Layout.fillWidth: true }

                    ActionChip {
                        icon: "content_copy"
                        label: root._justCopied ? "Copied" : "Copy"
                        onClicked: root.copyResult()
                    }
                }
            }
        }
    }

    // One row of the idle tool list -- SettingsPopup.qml's "All settings"
    // row idiom (whole-row hover film, trailing chevron), with a disabled
    // state added for whichever binary Services/Utilities.qml's checks
    // didn't find: dimmed, no hover, a one-line install hint where the
    // chevron would be.
    component ToolRow: Rectangle {
        id: rowItem

        property string icon: ""
        property string label: ""
        property bool enabled: true
        property string hint: ""

        signal picked()

        Layout.fillWidth: true
        implicitHeight: 48
        radius: Caelus.radiusCard
        color: rowItem.enabled && rowMouse.containsMouse ? Colors.surfaceHover : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Caelus.spaceTight
            anchors.rightMargin: Caelus.spaceTight
            spacing: Caelus.space

            Text {
                text: rowItem.icon
                color: rowItem.enabled ? Colors.fgDim : Colors.fgMuted
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: rowItem.label
                    color: rowItem.enabled ? Colors.fg : Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    visible: !rowItem.enabled && rowItem.hint.length > 0
                    text: rowItem.hint
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }

            Text {
                visible: rowItem.enabled
                text: "chevron_right"
                color: Colors.fgMuted
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle
            }
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            enabled: rowItem.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rowItem.picked()
        }
    }

    // A small pill button for the result card's Copy/Open actions -- there
    // is no existing chip of this exact shape to copy (the bar's own chips
    // are all icon-only pills), so this is sized by its own label the way
    // PowerMenu.qml's Tile is, just as a row instead of a fixed square.
    component ActionChip: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""

        signal clicked()

        implicitWidth: chipRow.implicitWidth + Caelus.space * 2
        implicitHeight: 30
        radius: Caelus.radiusChip
        color: chipMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised
        border.width: Caelus.borderWidth
        border.color: Colors.popupBorder

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Caelus.spaceTight

            Text {
                text: chip.icon
                color: Colors.fgDim
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeBody
            }

            Text {
                text: chip.label
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
