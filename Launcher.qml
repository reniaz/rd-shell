import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services

// The Quickshell replacement for `rofi -show drun` (SUPER+SPACE in
// hyprland.lua, bound there as "App launcher"). Search-as-you-type
// over Services/Apps.qml, dismissed the same way every modal in this shell
// already is: Escape, or a click outside.
//
// This is the one window in the tree that needs real keyboard focus -- see
// WlrLayershell.keyboardFocus below -- everywhere else a Quickshell surface
// is read, not typed into. That makes the two exits load-bearing rather than
// a nicety: a window that grabs the whole keyboard and cannot be talked out
// of it again is worse than no launcher at all, so both are wired straight
// to the key and mouse events that ask for them rather than assumed to work.
PanelWindow {
    id: root

    signal dismissed()

    // Same contract every overlay in this shell uses (PowerMenu.qml,
    // WallpaperSwitcher.qml): true by default because the window exists
    // before whatever loads it can push a real value in, driven false to
    // play the exit animation before the window is actually torn down. The
    // lead's loader is what flips this in response to `dismissed()`.
    property bool open: true

    // Raised once the window exists, so the first frame drawn is the
    // collapsed one and the card is seen to grow in rather than arriving
    // already there.
    property bool _entered: false
    readonly property bool shown: root._entered && root.open

    readonly property var _appResults: Apps.results

    // The calculator's synthetic row (idea 5) rides at index 0, ahead of
    // every app match, whenever Calc has an answer for the current query.
    // Folded into the same array move()/activate() already walk rather than
    // kept as a parallel case, so neither has to know a calc row exists as
    // anything other than "row 0 sometimes".
    readonly property var rows: Calc.hasResult
        ? [{ calc: true }].concat(root._appResults.map(entry => ({ calc: false, entry })))
        : root._appResults.map(entry => ({ calc: false, entry }))

    property int index: 0

    // Clamped rather than reset to 0 on every keystroke: narrowing ten
    // matches down to three should keep the selection where it lands if
    // that row is still in range, not always snap back to the top.
    onRowsChanged: root.index = Math.min(root.index, Math.max(0, root.rows.length - 1))

    function move(delta) {
        if (root.rows.length === 0) return;
        root.index = (root.index + delta + root.rows.length) % root.rows.length;
    }

    // Takes the index explicitly rather than reading root.index, the same
    // shape PowerMenu.activate(i) uses -- a click and Enter both funnel
    // through here, and a click should launch the row it landed on even if
    // hover happened to race the button press.
    function activate(i) {
        const row = root.rows[i];
        if (!row) return;
        root.index = i;
        if (row.calc) Calc.copyResult();
        else Apps.launch(row.entry);
        root.close();
    }

    // The one place that clears the search before the window goes away, so
    // Escape, a click outside and a launch all hand back an empty field
    // instead of only some of them doing it.
    function close() {
        search.text = "";
        Apps.query = "";
        Calc.submit("");
        root.index = 0;
        root.dismissed();
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive while open, exactly like PowerMenu and WallpaperSwitcher --
    // every keystroke has to land here while the launcher is up, not in
    // whatever window was focused before it. Given back the instant `open`
    // goes false so the fade-out below cannot end up holding the keyboard
    // hostage after the launcher is already gone from view.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-launcher"
    color: "transparent"

    // Covers the whole screen and outlives its own fade, same as every
    // other overlay here -- a click meant for the desktop must not be eaten
    // by a launcher that is already on its way out.
    mask: root.open ? null : closedMask
    Region { id: closedMask }

    Component.onCompleted: root._entered = true

    // The scrim, and the click-outside dismissal: it is the whole screen
    // and sits under the card, so only a click that misses the card reaches
    // it.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.shown ? 0.5 : 0

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.close()
        }
    }

    // A row is a fixed height rather than one derived from its text, so the
    // list below can be sized to a whole number of them. A card whose last
    // row is sliced through the middle reads as broken, not as scrollable.
    readonly property int rowHeight: 38
    readonly property int visibleRows: 8

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 560
        height: layout.implicitHeight + Caelus.spaceEdge * 2
        radius: Caelus.radiusIsland
        // Translucent and blurred by the compositor, like the OSD card and
        // the bar's own islands -- see the `quickshell-launcher-blur` layer
        // rule in hyprland.lua. A solid plate here reads as a dialog from
        // some other program; this one is made of what is behind it.
        color: Qt.rgba(Colors.surfaceRaised.r, Colors.surfaceRaised.g,
                       Colors.surfaceRaised.b, 0.55)
        border.width: Caelus.borderWidth
        // The accent, not the structural popup edge: this card floats in the
        // middle of the screen over a scrim, and in dynamic mode the accent
        // is the wallpaper's own colour, which is what ties it to the rest.
        border.color: Colors.accent

        // Same register as OsdCard: a small overshoot-free rise from 0.96,
        // not a bounce. This is a field you are about to type into, and a
        // playful entrance would draw the eye away from it.
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

        // First child, so it sits under the real content and only catches a
        // click that lands on the card's own background -- the same swallow
        // BarPopup and PowerMenu use to stop that click falling through to
        // the scrim's dismiss handler above.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Caelus.spaceEdge
            spacing: Caelus.spaceWide

            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.space

                Text {
                    text: "search"
                    color: Colors.popupAccent
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: search.implicitHeight

                    TextInput {
                        id: search

                        anchors.fill: parent
                        color: Colors.fg
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                        selectByMouse: true
                        // The only focusable thing in this window -- see
                        // the note on the window itself about why that has
                        // to be watertight. Keys.priority defaults to
                        // BeforeItem, so the handler below runs before
                        // TextInput's own editing and only claims the keys
                        // it sets event.accepted on; everything else --
                        // typing, backspace, the cursor keys -- still
                        // reaches TextInput's normal behaviour afterwards.
                        focus: true

                        onTextEdited: {
                            Apps.query = search.text;
                            Calc.submit(search.text);
                        }

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.close();
                                break;
                            case Qt.Key_Up:
                                root.move(-1);
                                break;
                            case Qt.Key_Down:
                                root.move(1);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.activate(root.index);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search apps…"
                        visible: search.text.length === 0
                        color: Colors.fgDim
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.popupBorder
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: root.visibleRows * root.rowHeight
                    + (root.visibleRows - 1) * Caelus.spaceTight
                clip: true
                spacing: Caelus.spaceTight
                model: root.rows
                currentIndex: root.index

                ScrollBar.vertical: ThinScrollBar {}

                // The keyboard is what drives `index`, not this view -- all
                // this has to do is keep whichever row that is on screen as
                // it moves, the same way ClaudeSessionRow keeps its own row
                // visible when it becomes current.
                onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool selected: row.index === root.index
                    readonly property bool isCalc: row.modelData?.calc === true

                    width: list.width
                    height: root.rowHeight
                    radius: Caelus.radiusCard
                    color: row.selected ? Colors.surfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    // Visible only when the a11y toggle is on (Settings.focusRing,
                    // gated inside FocusRing itself) -- the keyboard-selected row
                    // gets the same visible-focus overlay every other focusable
                    // control in this shell does.
                    FocusRing {
                        anchors.fill: parent
                        show: row.selected
                        radius: Caelus.radiusCard
                    }

                    RowLayout {
                        id: line

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Caelus.spaceWide
                        anchors.rightMargin: Caelus.spaceWide
                        spacing: Caelus.spaceWide

                        // The synthetic calculator row (idea 5): same icon +
                        // text shape every other row uses, a calculator glyph
                        // in place of an app icon and "expression = result"
                        // in place of a name.
                        Text {
                            visible: row.isCalc
                            text: "calculate"
                            color: Colors.popupAccent
                            font.family: Caelus.symbolFamily
                            font.pixelSize: Caelus.sizeTitle
                        }

                        IconImage {
                            visible: !row.isCalc
                            implicitSize: 22
                            source: row.isCalc ? "" : Apps.iconSource(row.modelData?.entry)
                            asynchronous: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.isCalc
                                ? `${Calc.expression} = ${Calc.result}`
                                : (row.modelData?.entry?.name ?? "")
                            color: Colors.fg
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeLead
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.index = row.index
                        onClicked: root.activate(row.index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "No matching apps"
                    visible: list.count === 0
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            }
        }
    }
}
