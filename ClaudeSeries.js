// Shared by ClaudeDonutChart and ClaudeLegend, which must agree exactly: the
// legend captions the donut, so a tail collapsed differently in the two of them
// would label the wrong wedge. One implementation is the only way that cannot
// drift.
.pragma library

function _num(v) {
    return typeof v === "number" && isFinite(v) ? v : 0;
}

// Returns the drawable series: the largest `slices - 1` entries in model order,
// followed by one "other" entry carrying whatever is left. A model that already
// fits comes back untouched and gains no "other" row.
//
// The palette index travels with each entry rather than being recomputed from
// the array position, because the two consumers iterate different arrays --
// the donut walks wedges and the legend walks rows -- and both must land on the
// same colour for the same model.
function collapse(model, valueKey, labelKey, slices) {
    const src = Array.isArray(model) ? model : [];
    const max = Math.max(1, slices);

    const rows = src.map(function (r, i) {
        return {
            label: String((r && r[labelKey] !== undefined) ? r[labelKey] : ""),
            value: _num(r ? r[valueKey] : 0),
            colorIndex: i
        };
    }).filter(function (r) { return r.value > 0; });

    if (rows.length <= max) return rows;

    const head = rows.slice(0, max - 1);
    let rest = 0;
    for (let i = max - 1; i < rows.length; i++) rest += rows[i].value;

    head.push({ label: "other", value: rest, colorIndex: max - 1 });
    return head;
}

function total(rows) {
    let t = 0;
    for (let i = 0; i < rows.length; i++) t += rows[i].value;
    return t;
}
