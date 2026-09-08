import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Everything the account is doing, hung under the bar's Claude pill. The card,
// its notch, the grow-out-of-the-icon animation and the click-outside dismissal
// all belong to BarPopup; what is left here is the panel's own content.
BarPopup {
    id: root

    // View state, so it lives on the window and not on the service: which tab
    // you were last reading is not something the pill or the IPC handler needs.
    property int tab: 0

    readonly property var tabs: ["Sessions", "Usage", "Statistics", "Optimize"]

    namespace: "qs-claude"

    // 520 rather than 420: the session table's fixed columns take ~314px, which
    // would leave the activity column barely seventy.
    popupWidth: 520

    // As short as the open tab needs and no shorter, up to everything between
    // the notch and the bottom of the screen. 60 is the 46 the card hangs at
    // plus the same 14 gap the bar's pills float in. BarPopup animates the
    // change, so switching from Statistics to Sessions is seen to fold up.
    popupHeight: Math.min(root.height - 60, 36 + head.implicitHeight + 12 + root.pageHeight)

    // The height the open tab would like. Deliberately not the StackLayout's
    // own implicit height, which is the tallest of all four pages: that would
    // hold the panel at Statistics height while Sessions shows three rows.
    readonly property real pageHeight: [sessionsPage, usagePage, statsPage, optimizePage][root.tab].naturalHeight

    // The service holds the open state rather than the loader, because Escape,
    // the pill, the close button and the IPC handler can all shut this panel and
    // only one of them is this window.
    open: ClaudeSession.panelOpen

    Component.onCompleted: {
        // The lifetime scan runs on a two-minute timer of its own, which is the
        // right cadence for a total that moves in cents -- but opening the panel
        // is exactly the moment somebody wants it current, and the refresh is
        // ~0.1s against a warm cache.
        ClaudeGlobal.refresh();
    }

    // Escape, the pill and the IPC handler all route through closePanel(), so
    // onDismissed would miss two of the three ways out -- and the detail scan
    // would then keep re-running every 5s against a window that no longer exists.
    Component.onDestruction: ClaudeDetail.collapse()


    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // The rows above the tabs, measured together and on their own: a card
        // that sized itself from the same layout it stretches would be feeding
        // its own height back into the sum, and settles at zero when it does.
        ColumnLayout {
            id: head

            Layout.fillWidth: true
            // The page below is the only thing that gives when the screen is
            // shorter than the panel wants to be.
            Layout.minimumHeight: implicitHeight
            spacing: 12

            // ── header ───────────────────────────────────────────────────
            // Every row above the tabs states its own height as a floor, so that a
            // panel capped by the screen takes the shortfall out of the page below
            // rather than out of the limits it is there to show.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "terminal"
                    color: Colors.claudeIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                }

                Text {
                    text: "Claude"
                    color: Colors.claudeTitle
                    font.family: "caelusevka"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                Text {
                    text: ClaudeSession.busyCount > 0
                        ? ClaudeSession.sessionCount + " live · " + ClaudeSession.busyCount + " busy"
                        : ClaudeSession.sessionCount + " live"
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }

                // Only ever shown when it is not zero: "0 waiting" is the normal
                // state and would train the eye to ignore the line that matters.
                Text {
                    text: "· " + ClaudeSession.waitingCount + " waiting"
                    color: Colors.claudeAttention
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    visible: ClaudeSession.waitingCount > 0
                }

                Text {
                    text: "close"
                    color: closeArea.containsMouse ? Colors.claudeCritical : Colors.claudeMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18

                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed()
                    }
                }
            }

            // The account's two limits sit in the header rather than only on the
            // Usage tab: they decide whether starting another session is even
            // worth doing, which is a question asked while looking at sessions.
            // The reset instant is the other half of that decision -- 96% ten
            // minutes before the window rolls is not the same news as 96% with
            // four hours left, and the bar alone cannot tell those apart.
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: ClaudeSession.limits !== null

                Repeater {
                    model: [
                        {
                            label: "5h",
                            pct: ClaudeSession.limits?.fiveHour ?? 0,
                            resets: ClaudeSession.limits?.fiveHourResets ?? ""
                        },
                        {
                            label: "7d",
                            pct: ClaudeSession.limits?.sevenDay ?? 0,
                            resets: ClaudeSession.limits?.sevenDayResets ?? ""
                        }
                    ]

                    ColumnLayout {
                        id: headMeter

                        required property var modelData

                        Layout.fillWidth: true
                        // Only one of the two limits usually carries a reset
                        // string, so without this the shorter column would
                        // centre itself against the taller one and the two
                        // meters would stop sharing a baseline.
                        Layout.alignment: Qt.AlignTop
                        spacing: 2

                        // Above the meter and not beside it: the row is
                        // already a label and a full-width track, and a third
                        // column would take its width from the one element
                        // whose length is the information. Sitting on top
                        // also means the clock time is read before the bar
                        // rather than after it, which is the order the
                        // question is actually asked in at 100%.
                        Text {
                            Layout.fillWidth: true
                            text: "resets " + ClaudeSession.clockAt(headMeter.modelData.resets)
                                + " · in " + ClaudeSession.until(headMeter.modelData.resets)
                            visible: headMeter.modelData.resets !== ""
                            color: Colors.claudeMeta
                            font.family: "caelusevka"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: headMeter.modelData.label
                                color: Colors.claudeMeta
                                font.family: "caelusevka"
                                font.pixelSize: 13
                            }

                            ClaudeMeter {
                                Layout.fillWidth: true
                                thickness: 4
                                fraction: headMeter.modelData.pct / 100
                                percent: headMeter.modelData.pct
                            }
                        }
                    }
                }
            }

            // ── tab bar ──────────────────────────────────────────────────
            Rectangle {
                id: tabBar

                Layout.fillWidth: true
                implicitHeight: 34
                radius: height / 2
                color: Colors.claudeTabBar

                readonly property real inset: 4
                readonly property real tabWidth: (width - inset * 2) / root.tabs.length

                // One sliding pill rather than four toggling backgrounds: the
                // travel is what tells you which way you just moved.
                Rectangle {
                    y: tabBar.inset
                    x: tabBar.inset + root.tab * tabBar.tabWidth
                    width: tabBar.tabWidth
                    height: tabBar.height - tabBar.inset * 2
                    radius: height / 2
                    color: Colors.claudeTabActive

                    Behavior on x {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: tabBar.inset

                    Repeater {
                        model: root.tabs

                        Item {
                            id: tabItem

                            required property int index
                            required property string modelData

                            width: tabBar.tabWidth
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: tabItem.modelData
                                color: root.tab === tabItem.index
                                    ? Colors.claudeTitle
                                    : Colors.claudeTabInactive
                                font.family: "caelusevka"
                                font.pixelSize: 13

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = tabItem.index
                            }
                        }
                    }
                }
            }

        }

        StackLayout {
            Layout.fillWidth: true
            // Always handed the whole remaining card, so a page is never sized
            // by the number it is being asked for. Every page here scrolls, so
            // a card capped by the screen simply shows less of one.
            Layout.fillHeight: true
            currentIndex: root.tab

            ClaudeSessionList { id: sessionsPage }

            ClaudeUsageTab { id: usagePage }

            ClaudeStatsTab { id: statsPage }

            ClaudeOptimizeTab { id: optimizePage }
        }
    }
}
