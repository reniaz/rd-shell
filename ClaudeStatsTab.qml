import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The shape of the account's history rather than its balance: where the money
// went over time, which model and which tool did the work, and when the work
// happened. Every figure comes from ClaudeGlobal's one lifetime scan -- the
// Usage tab answers "how much", this tab answers "how".
Flickable {
    id: root

    readonly property var totals: ClaudeGlobal.totals

    // Model ids carry a training date that is identical across most of the
    // list and so distinguishes nothing, while costing half the width of a
    // legend row. One function rather than a regex per call site, because the
    // donut, its legend and the session sublabels must all shorten the same
    // name to the same string.
    function shortModel(name) {
        if (typeof name !== "string") return "";
        return name.replace(/^claude-/, "").replace(/-\d{8}$/, "");
    }

    function hourLabel(h) {
        return (h < 10 ? "0" : "") + h + ":00";
    }

    // The bar chart scales against its own largest value, so the section header
    // states what that value was -- otherwise the tallest bar is a shape with
    // no magnitude attached to it.
    readonly property real peakDayCost: {
        let m = 0;
        for (const d of ClaudeGlobal.days) m = Math.max(m, d.cost ?? 0);
        return m;
    }

    readonly property var modelMix: ClaudeGlobal.models.map(m => ({
        name: root.shortModel(m.name ?? ""),
        cost: m.cost ?? 0
    }))

    readonly property var weekdayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // The scanner reports weekdays as 0=Sunday and the chart only knows how to
    // print a field of its model, so the name is resolved here instead of
    // teaching a general-purpose chart about calendars.
    readonly property var weekdayModel: ClaudeGlobal.weekdays.map(w => ({
        name: root.weekdayNames[w.day ?? 0] ?? "",
        turns: w.turns ?? 0
    }))

    readonly property string peakWeekday: {
        let best = null;
        for (const w of root.weekdayModel)
            if (best === null || w.turns > best.turns) best = w;
        return best === null ? "" : best.name;
    }

    readonly property var peakHour: {
        let best = null;
        for (const h of ClaudeGlobal.hours)
            if (best === null || (h.turns ?? 0) > (best.turns ?? 0)) best = h;
        return best;
    }

    // Five bars against one denominator, so they are comparable as parts of the
    // same whole. Cache reads are ~97% of every token this account has ever
    // moved, which is the entire point of showing the split.
    readonly property var tokenSplit: {
        const t = ClaudeGlobal.totals;
        if (t === null || t === undefined) return [];

        const all = (t.tokens ?? 0) > 0 ? t.tokens : 1;
        const row = (label, value, note) => ({
            label: label,
            value: ClaudeSession.compact(value ?? 0),
            fraction: (value ?? 0) / all,
            sublabel: note
        });

        return [
            row("input", t.input, ""),
            row("output", t.output, ""),
            row("thinking", t.thinking, "already counted inside output, not on top of it"),
            row("cache read", t.cacheRead, ""),
            row("cache write", t.cacheWrite, "")
        ];
    }

    readonly property var topTools: ClaudeGlobal.tools.slice(0, 10)

    // Sessions arrive sorted by cost, so the first one is the scale for the
    // rest. Reading sessions[0] unguarded would throw on the empty list this
    // tab shows for the first few seconds of a cold start.
    readonly property var topSessions: {
        const list = ClaudeGlobal.sessions;
        if (list.length === 0) return [];

        const top = list[0].cost ?? 0;
        return list.slice(0, 8).map(s => ({
            label: (s.title ?? "") !== "" ? s.title : String(s.id ?? "").slice(0, 8),
            sublabel: [s.project ?? "", root.shortModel(s.model ?? ""),
                       ClaudeSession.duration(s.durationMs ?? 0)]
                .filter(part => part !== "").join(" · "),
            // A derived figure is priced from token counts rather than read off
            // the CLI's own total, so it is marked rather than silently mixed
            // in with the exact ones.
            value: ClaudeSession.money(s.cost ?? 0) + (s.exact === false ? " ≈" : ""),
            fraction: top > 0 ? (s.cost ?? 0) / top : 0
        }));
    }

    readonly property int subagentShare: {
        const c = root.totals?.cost ?? 0;
        if (c <= 0) return 0;
        return Math.round(((root.totals?.subagentCost ?? 0) / c) * 100);
    }

    clip: true
    contentWidth: width
    contentHeight: statsCol.implicitHeight
    readonly property real naturalHeight: root.contentHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: statsCol

        width: root.width
        spacing: 12

        // The first scan parses the whole transcript corpus and takes a few
        // seconds. Drawing the sections against null totals would fill nine
        // cards with zeroes, which reads as "this account has never been used"
        // rather than as "not counted yet".
        Text {
            visible: !ClaudeGlobal.ready
            text: "scanning transcripts…"
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: 40
        }

        // One container for the whole body, so the empty state is a single
        // `visible` rather than the same guard repeated on nine sections.
        ColumnLayout {
            id: body

            visible: ClaudeGlobal.ready
            Layout.fillWidth: true
            spacing: 12

            ClaudeSection {
                Layout.fillWidth: true
                title: "daily spend"
                trailing: root.peakDayCost > 0 ? "peak " + ClaudeSession.money(root.peakDayCost) : ""
                visible: ClaudeGlobal.days.length > 0

                ClaudeBarChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    model: ClaudeGlobal.days
                    valueKey: "cost"
                    labelKey: "date"
                    labelChars: 2
                    moneyFormat: true
                    fill: Colors.claudeAccent
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "cumulative spend"
                trailing: ClaudeSession.money(root.totals?.cost ?? 0)
                visible: ClaudeGlobal.days.length > 0

                // No labels: this curve runs over exactly the days the bars
                // above it run over, and a second identical date axis 100px
                // below the first one is furniture, not information.
                ClaudeAreaChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    model: ClaudeGlobal.days
                    valueKey: "cost"
                    labelKey: ""
                    cumulative: true
                    moneyFormat: true
                    fill: Colors.claudeAccent
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "model mix"
                trailing: ClaudeGlobal.models.length > 0
                    ? ClaudeGlobal.models.length + " models"
                    : ""
                visible: root.modelMix.length > 0

                ClaudeDonutChart {
                    Layout.fillWidth: true
                    model: root.modelMix
                    valueKey: "cost"
                    labelKey: "name"
                    slices: 6
                    thickness: 14
                    centerTop: ClaudeSession.money(root.totals?.cost ?? 0)
                    centerBottom: "lifetime"
                }

                // `slices` must match the donut's or the legend captions the
                // wrong wedge as soon as a seventh model appears.
                ClaudeLegend {
                    Layout.fillWidth: true
                    model: root.modelMix
                    labelKey: "name"
                    valueKey: "cost"
                    moneyFormat: true
                    slices: 6
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "where it goes"
                trailing: ClaudeSession.compact(root.totals?.tokens ?? 0) + " tokens"
                visible: root.tokenSplit.length > 0

                Repeater {
                    model: root.tokenSplit

                    ClaudeRankRow {
                        id: splitRow

                        required property var modelData

                        Layout.fillWidth: true
                        label: splitRow.modelData.label
                        value: splitRow.modelData.value
                        fraction: splitRow.modelData.fraction
                        sublabel: splitRow.modelData.sublabel
                    }
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "busiest hours"
                trailing: root.peakHour !== null && root.peakHour !== undefined
                    ? "peak " + root.hourLabel(root.peakHour.hour ?? 0)
                    : ""
                visible: ClaudeGlobal.hours.length > 0

                ClaudeHeatmap {
                    Layout.fillWidth: true
                    model: ClaudeGlobal.hours
                    valueKey: "turns"
                    columns: 24
                    rows: 1
                    rowLabels: []
                }

                // Four ticks, each filling the six columns it opens, so a label
                // sits at the left edge of its own quarter of the strip. Sizing
                // them from the row instead of reading the heatmap's width
                // keeps this out of a binding loop.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: [0, 6, 12, 18]

                        Text {
                            id: tick

                            required property var modelData

                            Layout.fillWidth: true
                            text: root.hourLabel(tick.modelData)
                            color: Colors.claudeMeta
                            font.family: "caelusevka"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "by weekday"
                trailing: root.peakWeekday !== "" ? "peak " + root.peakWeekday : ""
                visible: root.weekdayModel.length > 0

                ClaudeBarChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    model: root.weekdayModel
                    valueKey: "turns"
                    labelKey: "name"
                    labelChars: 0
                    moneyFormat: false
                    fill: Colors.claudeAccent
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "tool use"
                trailing: ClaudeSession.compact(root.totals?.tools ?? 0) + " calls"
                visible: root.topTools.length > 0

                Repeater {
                    model: root.topTools

                    ClaudeRankRow {
                        id: toolRow

                        required property var modelData

                        Layout.fillWidth: true
                        label: toolRow.modelData.name ?? ""
                        value: ClaudeSession.compact(toolRow.modelData.count ?? 0)
                        fraction: toolRow.modelData.share ?? 0
                    }
                }
            }

            ClaudeSection {
                Layout.fillWidth: true
                title: "most expensive sessions"
                visible: root.topSessions.length > 0

                Repeater {
                    model: root.topSessions

                    ClaudeRankRow {
                        id: sessionRow

                        required property var modelData

                        Layout.fillWidth: true
                        label: sessionRow.modelData.label
                        value: sessionRow.modelData.value
                        fraction: sessionRow.modelData.fraction
                        sublabel: sessionRow.modelData.sublabel
                    }
                }
            }

            // What all of that spending actually produced. Lines and prompts
            // are the human-side figures; the two clocks are the machine's,
            // and they are wildly different numbers from wall time because a
            // session spends most of its life waiting to be typed at.
            ClaudeSection {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                title: "output"
                visible: ClaudeGlobal.ready

                ClaudeStatRow {
                    label: "lines added"
                    value: "+" + ClaudeSession.compact(root.totals?.linesAdded ?? 0)
                }

                ClaudeStatRow {
                    label: "lines removed"
                    value: "-" + ClaudeSession.compact(root.totals?.linesRemoved ?? 0)
                }

                ClaudeStatRow {
                    label: "prompts sent"
                    value: ClaudeSession.compact(root.totals?.prompts ?? 0)
                }

                ClaudeStatRow {
                    label: "subagents spawned"
                    value: ClaudeSession.compact(root.totals?.subagents ?? 0)
                }

                ClaudeStatRow {
                    label: "subagent spend"
                    value: ClaudeSession.money(root.totals?.subagentCost ?? 0)
                        + " · " + root.subagentShare + "%"
                    dim: true
                }

                ClaudeStatRow {
                    label: "api time"
                    value: ClaudeSession.duration(root.totals?.apiMs ?? 0)
                }

                ClaudeStatRow {
                    label: "tool time"
                    value: ClaudeSession.duration(root.totals?.toolMs ?? 0)
                }
            }
        }
    }
}
