import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The account's side of the panel: what has been spent, where, and how close
// the limits are. Everything here is lifetime and account-wide -- per-session
// numbers belong on the session row that owns them.
Flickable {
    id: root

    readonly property var totals: ClaudeGlobal.totals

    // Eight and six rather than the whole lists. Both rankings have a long tail
    // of sub-percent entries whose bar rounds to a single pixel, and a row that
    // cannot show its own proportion costs a scroll and returns nothing.
    readonly property var projects: ClaudeGlobal.projects.slice(0, 8)
    readonly property var models: ClaudeGlobal.models.slice(0, 6)

    // Model ids carry a family, a version and often a release date
    // ("claude-haiku-4-5-20251001"). The vendor prefix is identical on every
    // row and the date never separates two rows that the version did not, so
    // both are dropped and the label becomes the part that actually varies.
    function _shortModel(name) {
        if (typeof name !== "string") return "";
        return name.replace(/^claude-/, "").replace(/-\d{8}$/, "");
    }

    // The two headline ceilings, plus any per-model weekly limit the account is
    // actually subject to. The scoped buckets are usually a row of zeroes -- a
    // limit that has never been approached is not news -- so one is only drawn
    // once it has moved or been marked active, which keeps the section two
    // rows tall on the days when two rows is the whole truth.
    readonly property var limitRows: {
        const l = ClaudeSession.limits;
        if (!l) return [];

        const rows = [
            { label: "5 hour", pct: l.fiveHour ?? 0, resets: l.fiveHourResets ?? "" },
            { label: "7 day", pct: l.sevenDay ?? 0, resets: l.sevenDayResets ?? "" }
        ];

        for (const b of (l.buckets ?? [])) {
            if ((b.model ?? "") === "") continue;
            if ((b.percent ?? 0) <= 0 && !(b.active ?? false)) continue;
            rows.push({
                label: "7 day · " + b.model,
                pct: b.percent ?? 0,
                resets: b.resets ?? ""
            });
        }

        return rows;
    }

    clip: true
    contentWidth: width
    contentHeight: usageCol.implicitHeight

    // What the panel would have to be to show this tab whole. The card takes
    // the smaller of this and the screen, and scrolls when the screen wins.
    readonly property real naturalHeight: root.contentHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: usageCol

        width: root.width
        spacing: 12

        // The scan reports the last day it found activity on rather than
        // today's date, so a quiet morning does not make a total that was
        // recomputed seconds ago look like it stopped being maintained.
        Text {
            text: ClaudeGlobal.ready
                ? "as of " + (root.totals?.lastDay ?? "")
                : "scanning transcripts…"
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 13
        }

        // Where these numbers come from, because this tab used to print
        // something very different. Every figure below is read out of the
        // transcripts themselves by scripts/claude-global.sh -- not out of
        // ~/.claude.json, whose cost keys describe the *last* session of each
        // project and understate a month of work by two orders of magnitude.
        //
        // Cost arrives by two routes. A transcript that carries the CLI's own
        // totalCostUSD is billed exactly, and that number is what `/cost`
        // prints for the session; the rest are reconstructed from their token
        // counts against the published per-model prices, which is close but is
        // not the invoice. totals.exactCost and totals.derivedCost split the
        // headline between the two, and the accuracy line at the foot of the
        // tab says how many sessions fall on each side of that split.
        ClaudeSection {
            Layout.fillWidth: true
            title: "lifetime spend"

            Text {
                text: ClaudeSession.money(root.totals?.cost ?? 0)
                color: Colors.claudeTitle
                font.family: "caelusevka"
                // Above the house figure size of 18, which the three tiles
                // below use: this is the one number the tab exists to answer,
                // and at 18 it would carry no more weight than the token count
                // sitting directly underneath it.
                font.pixelSize: 28
                Layout.fillWidth: true
            }

            Text {
                text: (root.totals?.sessions ?? 0) + " sessions · "
                    + (root.totals?.projects ?? 0) + " projects · since "
                    + (root.totals?.firstDay ?? "—")
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "tokens", value: root.totals?.tokens ?? 0 },
                    { label: "turns", value: root.totals?.turns ?? 0 },
                    { label: "tools", value: root.totals?.tools ?? 0 }
                ]

                ClaudeSection {
                    id: tile

                    required property var modelData

                    Layout.fillWidth: true

                    Text {
                        text: ClaudeSession.compact(tile.modelData.value)
                        color: Colors.claudeTitle
                        font.family: "caelusevka"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: tile.modelData.label
                        color: Colors.claudeMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Rate limits ride along on this tab: they are the other half of what
        // `/status` answers, and there is no third tab worth spending on two
        // numbers.
        ClaudeSection {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            title: "rate limits"
            visible: ClaudeSession.limits !== null

            Repeater {
                model: root.limitRows

                ColumnLayout {
                    id: limitRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: limitRow.modelData.label
                            color: Colors.claudeBody
                            font.family: "caelusevka"
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }

                        Text {
                            // ago() of a future instant reads as "in 0s"; the
                            // suffix is dropped and the word "resets" carries
                            // the sense. The wall clock rides along with the
                            // span because the two answer different questions:
                            // "2h 10m" says whether waiting is worth it, "14:30"
                            // says what else the afternoon has room for.
                            text: limitRow.modelData.resets !== ""
                                ? "resets in " + ClaudeSession.until(limitRow.modelData.resets)
                                    + " · " + ClaudeSession.clockAt(limitRow.modelData.resets)
                                : ""
                            color: Colors.claudeMeta
                            font.family: "caelusevka"
                            font.pixelSize: 13
                        }
                    }

                    ClaudeMeter {
                        Layout.fillWidth: true
                        fraction: limitRow.modelData.pct / 100
                        percent: limitRow.modelData.pct
                    }
                }
            }

            // Extra-usage credits are a separate ceiling from the plan limits
            // above: they are what keeps working once those are spent, and the
            // account is only subject to them when they have been switched on.
            ClaudeStatRow {
                Layout.topMargin: 2
                visible: ClaudeSession.limits?.extraEnabled ?? false
                label: "extra usage credits"
                dim: true
                value: (ClaudeSession.limits?.extraUsed ?? 0).toFixed(2) + " / "
                    + (ClaudeSession.limits?.extraLimit ?? 0)
                    + " " + (ClaudeSession.limits?.extraCurrency ?? "")
            }
        }

        // Deliberately one colour for every bar here. This is a ranking, and
        // when only the length carries meaning a second variable competing with
        // it makes the order harder to read, not easier.
        ClaudeSection {
            Layout.fillWidth: true
            title: "spend by project"
            trailing: ClaudeGlobal.projects.length > root.projects.length
                ? "top " + root.projects.length + " of " + ClaudeGlobal.projects.length
                : ""
            visible: root.projects.length > 0

            Repeater {
                model: root.projects

                ClaudeRankRow {
                    id: projectRow

                    required property var modelData

                    Layout.fillWidth: true
                    label: projectRow.modelData.name
                    value: ClaudeSession.money(projectRow.modelData.cost ?? 0)
                    // `share` is already a fraction of lifetime cost, so the
                    // bars stay comparable with the model list below even
                    // though the tail of each has been cut at a different row.
                    fraction: projectRow.modelData.share ?? 0
                    sublabel: (projectRow.modelData.sessions ?? 0) + " sessions · "
                        + ClaudeSession.compact(projectRow.modelData.turns ?? 0) + " turns"
                }
            }
        }

        // Here the series palette is worth the extra variable: the Statistics
        // tab draws these same models, in this same order, as a donut with a
        // colour legend, so "the orange one" has to mean one model on both
        // tabs or it means nothing on either.
        ClaudeSection {
            Layout.fillWidth: true
            title: "spend by model"
            visible: root.models.length > 0

            Repeater {
                model: root.models

                ClaudeRankRow {
                    id: modelRow

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    label: root._shortModel(modelRow.modelData.name)
                    value: ClaudeSession.money(modelRow.modelData.cost ?? 0)
                    fraction: modelRow.modelData.share ?? 0
                    fill: Colors.claudeSeries[modelRow.index % 10]
                    sublabel: ClaudeSession.compact(modelRow.modelData.turns ?? 0)
                        + " turns · " + ClaudeSession.compact(modelRow.modelData.tokens ?? 0)
                        + " tokens"
                }
            }
        }

        // Shown only when something actually was estimated. "189 of 189 billed
        // exactly" is a caveat about nothing, and a caveat printed when there
        // is no caveat teaches the eye to skip the line on the day it matters.
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            text: (root.totals?.exactSessions ?? 0) + " of "
                + (root.totals?.sessions ?? 0) + " sessions billed exactly; "
                + ClaudeSession.money(root.totals?.derivedCost ?? 0)
                + " estimated from token counts"
            visible: (root.totals?.derivedCost ?? 0) > 0
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}
