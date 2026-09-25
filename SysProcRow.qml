import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// One app -- one or more processes sharing an executable, summed together by
// the sampler's own grouping rule (see scripts/sysmon.py) -- shown as a
// single row, and, once clicked, expanded in place to show and end the
// specific process listed as `pid`, the group's heaviest member.
//
// Required properties are named after the model's own roles rather than one
// `data` object, the same device the old per-tab topCpu/topMem rows used:
// the delegate machinery fills a required property from the role of the
// same name when SysProcList's `_reconcile` moves or rewrites a row in
// place, so a process whose figures moved updates those properties instead
// of arriving as a freshly built row. `state` is deliberately not among
// them -- it is not shown anywhere below, and declaring it would collide
// with Item's own built-in `state` property (the States system every Item
// already carries), which a delegate cannot override.
ColumnLayout {
    id: root

    required property string key
    required property string name
    required property int pid
    required property var pids
    required property int count
    required property real cpu
    required property real mem
    required property real vram
    required property string user
    required property string cmdline
    required property int threads
    required property real runtime

    // The list this row lives in: whether a VRAM column belongs here, and
    // which row -- tracked by group key, since sorting reorders every row on
    // every poll and an index would point at the wrong one within a tick --
    // is currently expanded.
    required property var list

    readonly property bool expanded: root.list.expandedKey === root.key

    // Height changes when the detail block lands, which is the moment the
    // whole expanded row can be scrolled into view.
    onHeightChanged: if (root.expanded) root.list.reveal(root)

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        id: summary

        Layout.fillWidth: true
        Layout.leftMargin: -5
        Layout.rightMargin: -5
        implicitHeight: 27
        radius: Caelus.radiusCard
        color: hover.hovered || root.expanded ? Colors.sysTrack : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        HoverHandler { id: hover }

        // A tap anywhere on the row toggles it -- there is no separate
        // affordance to hit, unlike the old hover-revealed kill button this
        // replaces: expanding is not destructive, so it does not need the
        // same two-step guard ending the process still does, below.
        TapHandler {
            onTapped: root.list.expandedKey = root.expanded ? "" : root.key
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 5
            spacing: 7

            Text {
                text: root.name + (root.count > 1 ? " ×" + root.count : "")
                color: Colors.sysTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.cpu.toFixed(1) + "%"
                color: Colors.sysBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 46
            }

            Text {
                text: Format.human(root.mem)
                color: Colors.sysBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 46
            }

            // Only the GPU tab's list carries this: SysMon.processes mixes
            // top-cpu, top-rss and every vram>0 group into one array (see
            // the sampler's emit rule), and CPU/Mem have no use for a column
            // that would read 0 on almost every row they show.
            Text {
                text: Format.human(root.vram)
                color: Colors.sysBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 46
                visible: root.list.gpu
            }

            Text {
                text: root.expanded ? "expand_less" : "expand_more"
                color: Colors.sysMeta
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
                Layout.preferredWidth: 20
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Everything that describes `pid` specifically, plus the two ways to end
    // it. A Loader rather than a plain always-built Item: with up to 30 rows
    // a tab, building this detail block -- five rows and two buttons -- for
    // every one of them just to keep 29 hidden costs real layout time on
    // every single poll, where a Loader that stays inactive costs nothing.
    // `visible` too: a Loader keeps the implicit height of the item it just
    // destroyed, so without it a collapsed row would keep its open gap.
    Loader {
        Layout.fillWidth: true
        active: root.expanded
        visible: root.expanded
        sourceComponent: detail
    }

    Component {
        id: detail

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 9
            Layout.rightMargin: 5
            Layout.topMargin: 3
            Layout.bottomMargin: 7
            spacing: 4

            Text {
                text: root.cmdline
                color: Colors.sysBody
                font.family: Caelus.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }

            SysStatRow { label: "User"; value: root.user }
            SysStatRow { label: "Threads"; value: String(root.threads) }
            SysStatRow { label: "Running"; value: Format.duration(root.runtime) }
            SysStatRow {
                label: "Processes"
                value: root.count > 1 ? root.count + " (ending pid " + root.pid + ")" : String(root.pid)
            }

            // Asked once and answered: the two buttons are separate promises
            // -- SIGTERM lets the process close its files, SIGKILL does not
            // -- so neither is the default and both need their own tap.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 7

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [{ label: "End", force: false }, { label: "Force", force: true }]

                    Rectangle {
                        id: button

                        required property var modelData

                        implicitWidth: caption.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: buttonHover.hovered ? Colors.sysKill : "transparent"
                        border.width: 1
                        border.color: Colors.sysKill

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            id: caption

                            anchors.centerIn: parent
                            text: button.modelData.label
                            color: buttonHover.hovered ? Colors.bg : Colors.sysKill
                            font.family: Caelus.fontFamily
                            font.pixelSize: 11
                        }

                        HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            onTapped: {
                                // Every pid in the group, not just the one
                                // shown above -- "End" on a grouped row means
                                // the app, not the one thread that happened
                                // to be heaviest.
                                SysMon.kill(root.pids, button.modelData.force);
                                root.list.expandedKey = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
