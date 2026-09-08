import QtQuick

// One object owns every column offset in the session table, and rows measure
// nothing of their own. Per-row measurement is exactly how a table stops being
// a table: two rows holding different text disagree about where a column
// starts, and the whole grid shears.
QtObject {
    id: root

    // QtObject has no default property, so a FontMetrics cannot be written here
    // as a plain child -- it only exists because a property holds it.
    readonly property FontMetrics metrics: FontMetrics {
        font.family: "caelusevka"
        font.pixelSize: root.fontSize
    }

    readonly property int rowHeight: 30
    readonly property int fontSize: 13
    readonly property int iconSize: 14
    readonly property int gap: 10
    readonly property int padLeft: 8
    readonly property int padRight: 4

    readonly property int glyphWidth: 16
    readonly property int meterWidth: 30
    readonly property int termWidth: 18

    // The attention stripe down a blocked row's left edge, drawn inside padLeft
    // so it costs the table no width at all.
    readonly property int stripeWidth: 2

    // Every state label this table can ever print. Sizing the column from the
    // whole vocabulary rather than from what is on screen is what stops it
    // resizing under the cursor when a session goes from busy to idle.
    readonly property var stateWords: ["NEEDS YOU", "working", "waiting", "busy", "idle", "done"]

    readonly property int stateWidth: {
        let w = 0;
        for (const word of root.stateWords) w = Math.max(w, root.metrics.advanceWidth(word));
        return Math.ceil(w);
    }

    // Sized for the widest number it can hold and right-aligned by the rows, so
    // "8%" and "74%" end on the same pixel.
    readonly property int pctWidth: Math.ceil(root.metrics.advanceWidth("100%"))

    // Measured over the model and capped: one unusually long project name must
    // not be allowed to push the elastic column off the end of the row.
    property int projectWidth: 84

    // Stays 0 unless something in the model actually carries a badge, so a
    // table with no subagents anywhere spends nothing on an empty gutter.
    property int badgeWidth: 0

    readonly property int xGlyph: root.padLeft
    readonly property int xProject: root.xGlyph + root.glyphWidth + 6
    readonly property int xState: root.xProject + root.projectWidth + root.gap
    readonly property int xPct: root.xState + root.stateWidth + root.gap
    readonly property int xMeter: root.xPct + root.pctWidth + 8
    readonly property int xActivity: root.xMeter + root.meterWidth + root.gap

    // Everything to the right of the elastic column as one number, so a row
    // anchors its activity text to the panel edge and lands where every other
    // row's does without knowing what sits in the gutter.
    readonly property int rightInset:
        root.padRight + root.termWidth + root.gap
        + (root.badgeWidth > 0 ? root.badgeWidth + root.gap : 0)

    // Re-run whenever the model gains, loses or repurposes a row. Cheap enough
    // to be called from a coalescing timer rather than guarded by a diff.
    function measure(model) {
        if (!model) return;

        let widest = 60;
        let badge = false;

        for (let i = 0; i < model.count; i++) {
            const r = model.get(i);
            // A job row puts its id where a session puts its project, so both
            // feed the same column.
            widest = Math.max(widest, root.metrics.advanceWidth(
                r.rowType === "job" ? (r.sessionId ?? "") : (r.project ?? "")));
            if ((r.subagents ?? 0) > 0 || (r.jobTasks ?? 0) > 0) badge = true;
        }

        root.projectWidth = Math.min(150, Math.ceil(widest) + 2);
        root.badgeWidth = badge
            ? root.iconSize + Math.ceil(root.metrics.advanceWidth("99")) + 2
            : 0;
    }
}
