import QtQuick
import QtQuick.Layouts
import qs.Config

// One segment of the bar. At rest it draws nothing -- the island behind the
// group it belongs to is the surface, and a pill is only the spacing and the
// two texts. Under the pointer it lifts a faint film, which is the only
// feedback that a pill is a thing you can click.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Colors.accent
    property int maxLabelWidth: 400
    // Every existing call site draws from Material Symbols and stays on the
    // default. Only a call site reaching for a plain-Unicode glyph outside
    // that font -- the merged menu pill's star -- needs to override either.
    property string iconFamily: Caelus.symbolFamily
    property int iconSize: 16
    property alias content: row.data
    // A pill nobody can act on should not pretend otherwise.
    property bool interactive: true
    // Driven by the call site's own MouseArea -- hoverPoint below takes no
    // buttons (see its own comment), so a press has to be reported in from
    // outside rather than sensed here.
    property bool pressed: false

    readonly property bool hovered: hoverPoint.containsMouse && root.interactive

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 32
    // The pill's own box is the layout cell and the hit area. It never paints;
    // the highlight below does, one step inside it.
    color: "transparent"

    // Inset from the pill rather than filling it. The island around a group is
    // padded only on its sides, so its height is one pill exactly -- a hover
    // that filled the pill would run flush into the island's top and bottom
    // edge while still sitting `barIslandPad` in from its sides, and read as a
    // shape misaligned inside another shape instead of as a highlight. The
    // vertical inset gives it a margin on all four sides.
    Rectangle {
        id: hoverBg

        anchors.fill: parent
        anchors.topMargin: Caelus.spaceTight
        anchors.bottomMargin: Caelus.spaceTight
        radius: Caelus.radiusPill
        // A flat, opaque wash -- the strength is entirely the opacity below,
        // which is what lets rest/hover/press share one Rectangle instead of
        // animating between three colours. Colors.fg rather than
        // Colors.barPillHover: that token already bakes an alpha in, and
        // stacking a second opacity on top of a colour that is already
        // translucent would make press read weaker than hover instead of
        // stronger.
        color: Colors.fg
        // Not gated behind `root.hovered`: the pointer can drift off a pill
        // slightly while the button stays down, and the press wash should
        // not vanish mid-click just because it did.
        opacity: root.interactive && root.pressed ? Caelus.opacityPress
            : root.hovered ? Caelus.opacityHover : 0
        // Behind the pill's contents. The island is a sibling of the group, a
        // level up from here, so this cannot collide with it.
        z: -1

        // OutCubic starts at full speed (Motion.standard), so press still
        // visibly registers inside the ~90ms a real click lasts even sharing
        // `fast` with the hover transition, rather than needing a duration
        // faster than anything the Motion singleton has.
        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
        }
    }

    // Hover has to be read from above everything else. Each pill carries its
    // own MouseArea for clicks and wheel, and any MouseArea that sets a cursor
    // shape accepts hover events and stops them there -- a handler parented to
    // the pill itself sits *under* that child and never fires. This probe
    // stacks over the lot and takes hover first. It cannot steal the clicks:
    // it accepts no mouse buttons, and a HoverHandler handles only hover, so
    // press and wheel fall straight through to the MouseArea beneath.
    MouseArea {
        id: hoverPoint

        anchors.fill: parent
        // Above the caller's own MouseArea, for the cursor rather than for the
        // hover: Qt picks the shape from the topmost item that sets one, so at
        // the default z a call site's own PointingHandCursor would win and an
        // `interactive: false` pill would never show an arrow.
        z: 100
        hoverEnabled: true
        // Takes no buttons, so a press falls through to the MouseArea beneath
        // and every pill's click still works.
        acceptedButtons: Qt.NoButton
        // The shape has to be re-stated here: this probe now owns hover, and
        // the cursor follows whichever item accepted it.
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        // Wheel is not ours. Said explicitly rather than left to MouseArea's
        // default, because the workspace dots and the media pill both scroll
        // and both would otherwise depend on an implementation detail.
        //
        // Note what this probe costs: a hovering MouseArea is the end of the
        // line for a hover event, so nothing inside a pill can have a hover
        // state of its own any more. No tray icon or workspace dot wants one
        // today; the day one does, it has to move up here rather than be added
        // below, the way the popups reach for HoverHandler instead.
        onWheel: wheel => wheel.accepted = false
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.icon
            color: root.iconColor
            font.family: root.iconFamily
            font.pixelSize: root.iconSize
            visible: root.icon !== ""
        }

        Text {
            text: root.label
            color: Colors.fg
            font.family: Caelus.fontFamily
            font.pixelSize: 16
            elide: Text.ElideRight
            Layout.maximumWidth: root.maxLabelWidth
            visible: root.label !== ""
        }
    }
}
