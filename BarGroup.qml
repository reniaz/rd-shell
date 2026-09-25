import QtQuick
import QtQuick.Layouts
import qs.Config

// A layout container, not a surface. Two or three pills that share one idea
// -- mic and volume are audio in and audio out, bell and the menu pill are
// shell controls -- sit closer together than the rest of the island, so the
// group reads as one thing by proximity alone, the way the reference shell
// does it. The tighter `Caelus.spaceTight` spacing below is the entire cue;
// this draws nothing. A Pill already draws its own hover and press wash, and
// a fill behind it -- opaque or a faint wash, both were tried -- gave a
// grouped pill a second layer under it that an ungrouped pill never has, so
// its rest state stopped matching the rest of the bar. Proximity costs
// nothing and does not have that problem.
//
// Height follows the tallest pill exactly, with no padding of its own: the
// island above is sized to one pill tall (`barHeight - 2 * barInset`), and
// anything taller would poke through its top and bottom edge.
Item {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Caelus.spaceTight
    }
}
