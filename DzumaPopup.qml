import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The drops behind the bar's dzuma pill. The card and the click-outside
// dismissal both belong to BarPopup, which now sits the card flush against
// the island above instead of pointing a notch back up at the pill -- a
// notch would have had to be drawn inside that island itself, in a second
// translucent window, where two glass surfaces over one another
// double-composite into a seam rather than a pointer. What is left here is
// the merch itself and the two things worth doing about it.
BarPopup {
    id: root

    namespace: "qs-dzuma"
    popupWidth: 300

    // As short as the drop list wants and no taller than the screen allows.
    // Every other content-sized popup in the bar caps itself this way
    // (SysPopup, ClaudePanel); this one didn't, and it is the one with the
    // least bound on how tall its content can get -- a slow week is a
    // handful of drops, a busy one is dozens, and each drop can silently
    // add another 150px once its picture decodes (see the Image below).
    // Left uncapped, a big enough drop list would ask BarPopup for a card
    // taller than the screen, and a layer surface can only be told to grow
    // downward off the bottom of a display that isn't there.
    //
    // The cap is Caelus.barHeight - Caelus.barInset -- the 38 the card now
    // hangs at, flush under the island -- plus Caelus.spaceEdge, the same
    // 14px gap the bar's pills float in, the same sum SysPopup and
    // ClaudePanel cap against so all three agree on how close to the
    // bottom edge a card may come.
    //
    // The screen cap only applies once there is a screen height to cap
    // against. A layer surface is told its size a round trip after it is
    // created, so for the first frames root.height is zero, and an
    // unguarded Math.min against it would ask for a card pinned to
    // BarPopup's own floor instead of its real, content-driven height.
    popupHeight: root.height > 0
        ? Math.min(root.height - (Caelus.barHeight - Caelus.barInset + Caelus.spaceEdge), root.wantedHeight)
        : root.wantedHeight

    readonly property real wantedHeight: body.implicitHeight + 28

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceWide

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: "local_mall"
                color: Colors.popupAccent
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            Text {
                text: "dzuma"
                color: Colors.notifTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: Dzuma.count === 1 ? "1 drop" : Dzuma.count + " drops"
                color: Colors.notifMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        Repeater {
            model: Dzuma.drops

            ColumnLayout {
                id: drop

                required property var modelData

                Layout.fillWidth: true
                spacing: Caelus.spaceSnug

                // The still the scraper cut from the product clip. A price
                // change carries no picture, so the frame only exists once the
                // file does.
                Image {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    source: drop.modelData.media ? "file://" + drop.modelData.media : ""
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Caelus.space

                    Text {
                        Layout.fillWidth: true
                        text: drop.modelData.name
                        color: Colors.notifTitle
                        elide: Text.ElideRight
                        font.family: Caelus.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        text: drop.modelData.price
                        color: Colors.accentBright
                        font.family: Caelus.fontFamily
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Dzuma.openShop(drop.modelData.url)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            DzumaButton {
                Layout.fillWidth: true
                label: "Open shop"
                accent: true
                onTriggered: Dzuma.openShop(Dzuma.latest ? Dzuma.latest.url : "")
            }

            DzumaButton {
                Layout.fillWidth: true
                label: "Got it"
                onTriggered: Dzuma.ack()
            }
        }
    }
}
