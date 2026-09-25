import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The processes making the readings above them, grouped by app. One
// component serves the CPU, Memory and GPU tabs alike -- only the title, the
// default sort and whether a VRAM column belongs here differ, because a row
// costs CPU and memory wherever it is looked at, and there is nothing about
// that shape worth writing three times.
//
// SysMon.processes is a plain JS array, reassigned whole on every sample
// (see the API contract in Services/SysMon.qml) -- there is no ListModel on
// that side any more for this to bind straight to. A Repeater handed a fresh
// array reference on every poll throws every delegate away and rebuilds it
// from scratch each time (the same trap SysCores.qml's own comment warns
// about for `cores`), which would drop the row currently expanded and make
// every hover flicker. `procModel` below is what the old SysMon topCpu/topMem
// models used to buy for free: rows are matched by group `key`, moved rather
// than replaced, and rewritten in place, so a delegate survives for as long
// as its app keeps running.
SysCard {
    id: root

    property string defaultSort: "cpu"   // "cpu" | "mem" | "vram"
    // The GPU tab only: its list is "by VRAM" (see SysGpuTab), so it alone
    // filters SysMon.processes down to the groups actually holding any and
    // shows the column the other two tabs would have no use for.
    property bool gpu: false

    title: root.gpu ? "By VRAM" : "Processes"

    property string sort: root.defaultSort
    property bool sortDesc: true

    function toggleSort(key) {
        if (root.sort === key) root.sortDesc = !root.sortDesc;
        else { root.sort = key; root.sortDesc = true; }
    }

    // Which row, by group key rather than by position, is expanded. One at a
    // time: opening a second row is a change of mind about which one to
    // read, not a request to see both at once.
    property string expandedKey: ""

    // See the Flickable below. Infinity until the tab says otherwise, so a
    // list placed where nothing caps it just shows every row.
    property real availableHeight: Infinity
    readonly property real minRowsHeight: 3 * 28
    readonly property real overflow: Math.max(0, rowsCol.implicitHeight - rowsView.height)

    // Scrolls a row (the one just expanded) fully into view, top first if
    // it is taller than the view.
    function reveal(row) {
        const top = row.mapToItem(rowsCol, 0, 0).y;
        const bottom = top + row.height;
        if (bottom > rowsView.contentY + rowsView.height)
            rowsView.contentY = Math.min(top, bottom - rowsView.height);
        else if (top < rowsView.contentY)
            rowsView.contentY = top;
    }

    // Filtered and ordered for this tab, recomputed whenever SysMon samples
    // or the sort changes. Sorted with a fresh copy, not in place: the array
    // underneath is SysMon's own and gets reassigned wholesale next tick
    // regardless.
    readonly property var rows: {
        let r = (SysMon.processes ?? []).slice();
        if (root.gpu) r = r.filter(p => (p.vram ?? 0) > 0);
        const key = root.sort;
        r.sort((a, b) => {
            const av = a[key] ?? 0, bv = b[key] ?? 0;
            return root.sortDesc ? bv - av : av - bv;
        });
        return r;
    }

    onRowsChanged: {
        root._reconcile(procModel, root.rows);
        // A process that ended while its row was open leaves nothing to
        // point at any more.
        if (root.expandedKey !== "" && !root.rows.some(p => p.key === root.expandedKey))
            root.expandedKey = "";
    }

    // Writes `rows` into `model` without disturbing what is already there --
    // the same walk-from-the-top reconciler SysMon's own topCpu/topMem used
    // to run, moved here now that the data arrives as a plain array instead
    // of a model SysMon maintains itself. setProperty rewrites one role of
    // one row and move() carries its delegate with it, so a row that merely
    // changed rank keeps its expansion, its hover and its delegate identity.
    function _reconcile(model, rows) {
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            let at = -1;

            for (let j = i; j < model.count; j++) {
                if (model.get(j).key === row.key) {
                    at = j;
                    break;
                }
            }

            if (at < 0) {
                model.insert(i, row);
                continue;
            }

            if (at !== i) model.move(at, i, 1);

            const have = model.get(i);
            for (const k in row) {
                if (have[k] !== row[k]) model.setProperty(i, k, row[k]);
            }
        }

        if (model.count > rows.length)
            model.remove(rows.length, model.count - rows.length);
    }

    ListModel { id: procModel }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: -5
        Layout.rightMargin: -5
        spacing: 1

        RowLayout {
            id: header

            Layout.fillWidth: true
            Layout.leftMargin: 9
            Layout.rightMargin: 5
            spacing: 7

            Text {
                text: "Process"
                color: Colors.sysMeta
                font.family: Caelus.fontFamily
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            // Clicking a header toggles that column as the sort key; a
            // second click on the one already active flips direction rather
            // than doing nothing, which is what lets a reader check a list's
            // lightest row without leaving the tab.
            Repeater {
                model: root.gpu
                    ? [{ key: "cpu", label: "CPU" }, { key: "mem", label: "Mem" }, { key: "vram", label: "VRAM" }]
                    : [{ key: "cpu", label: "CPU" }, { key: "mem", label: "Mem" }]

                Text {
                    id: colHead

                    required property var modelData

                    text: colHead.modelData.label
                        + (root.sort === colHead.modelData.key ? (root.sortDesc ? " ▾" : " ▴") : "")
                    color: root.sort === colHead.modelData.key ? Colors.sysTitle : Colors.sysMeta
                    font.family: Caelus.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 46

                    TapHandler { onTapped: root.toggleSort(colHead.modelData.key) }
                }
            }

            // Lines the header up with the expand glyph every row ends in.
            Item { implicitWidth: 20 }
        }

        // Roles from procModel bind straight onto SysProcRow's own required
        // properties of the same name (key, cpu, mem, ...) -- that matching
        // is the delegate machinery's job, not something to repeat here; the
        // only thing this row needs from its list is a back-reference to it.
        // The rows scroll inside the card rather than the card running off
        // the popup: a busy machine lists thirty-odd groups, more than a
        // 1080p screen fits under the readings above them. The tab hands in
        // `availableHeight` (what is left of its page below this card's top)
        // and reports `overflow` back into its natural height, so the popup
        // still grows to show every row whenever the screen has the room.
        // Wider than the column by the rows' own -5 hover inset on each side,
        // so the clip doesn't shave the highlight.
        Flickable {
            id: rowsView

            Layout.fillWidth: true
            Layout.leftMargin: -5
            Layout.rightMargin: -5
            Layout.preferredHeight: Math.min(rowsCol.implicitHeight,
                Math.max(root.minRowsHeight, root.availableHeight - root.chromeHeight - header.implicitHeight - 1))
            contentHeight: rowsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: rowsCol.implicitHeight > rowsView.height

            ColumnLayout {
                id: rowsCol

                x: 5
                width: rowsView.width - 10
                spacing: 1

                Repeater {
                    model: procModel

                    SysProcRow {
                        list: root
                    }
                }
            }

            // Only there when something is scrolled out of sight.
            Rectangle {
                parent: rowsView
                anchors.right: parent.right
                y: rowsView.visibleArea.yPosition * rowsView.height
                width: 3
                height: rowsView.visibleArea.heightRatio * rowsView.height
                radius: 1.5
                color: Colors.sysMeta
                opacity: rowsView.interactive ? 0.5 : 0
            }
        }

        Text {
            text: "sampling…"
            color: Colors.sysMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
            // count, not length: procModel is not an array. It also stays
            // filled between openings now, so this line is only ever seen on
            // the first open of a session rather than on every one.
            visible: procModel.count === 0
            Layout.leftMargin: 9
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }
    }
}
