import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.Config
import qs.Services

Rectangle {
    id: card

    required property var notification
    // popups get a slightly louder edge; panel entries sit quieter
    property bool popup: false

    // which side is flush against a screen edge: "", "left" or "right".
    // The flush side loses its rounding so the card reads as part of the screen.
    property string flush: ""

    // panel entries hide it -- the app name lives in the group header there
    property bool showApp: true

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property bool low: notification?.urgency === NotificationUrgency.Low

    // Hotkey feedback is the one notification that still appears under DND, so
    // it carries the DND state. Live rather than captured at arrival: only the
    // toast shows it, and a toast is only ever on screen for its own moment.
    readonly property bool hotkey: Notifications.isHotkey(notification)

    // "default" is the activate-on-click action and per spec is not drawn as a
    // button; a label-less action would render as an empty box, so drop both.
    readonly property var visibleActions: (notification?.actions ?? [])
        .filter(a => a.identifier !== "default" && (a.text ?? "") !== "")

    // The click-the-body action the filter above deliberately drops. Null for
    // notifications that offer nothing to open.
    readonly property var defaultAction:
        (notification?.actions ?? []).find(a => a.identifier === "default") ?? null

    // Emitted after a body click has been handled. The click itself lives here
    // rather than in NotificationPopups so panel entries behave identically;
    // the popup layer only listens in to retire its toast.
    signal activated()

    implicitHeight: layout.implicitHeight + 26
    radius: Caelus.radiusPopover
    topLeftRadius: flush === "left" ? 0 : radius
    bottomLeftRadius: flush === "left" ? 0 : radius
    topRightRadius: flush === "right" ? 0 : radius
    bottomRightRadius: flush === "right" ? 0 : radius
    color: Colors.notifCardBg
    border.width: critical || (popup && !low) ? 2 : 1
    border.color: critical ? Colors.notifCritical
        : popup && !low ? Colors.notifAccent
        : Colors.notifBorder

    HoverHandler { id: hover }

    // Declared BEFORE the layout so it sits underneath it: the close glyph and
    // the action chips are inside the layout and therefore still get first
    // refusal on their own clicks. Moving this below the layout would put it on
    // top and swallow both.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        // a card with nothing to open must not advertise itself as clickable
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            // activated() first: invoke() closes a non-resident notification, and
            // a dropped object can no longer be matched out of the popup list.
            card.activated();
            if (!card.defaultAction) return;
            // A resident notification survives its own action, so it would sit in
            // the panel after the user has already acted on it.
            const resident = card.notification?.resident ?? false;
            card.defaultAction.invoke();
            if (resident) Notifications.dismiss(card.notification);
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Caelus.spaceEdge
        anchors.rightMargin: Caelus.spaceEdge
        spacing: Caelus.spaceSnug

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Image {
                source: card.notification?.image ?? ""
                visible: source != ""
                sourceSize.width: 18
                sourceSize.height: 18
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                text: card.showApp ? (card.notification?.appName ?? "") : (card.notification?.summary ?? "")
                color: card.critical ? Colors.notifCritical
                    : card.low ? Colors.notifMeta
                    : card.showApp ? Colors.notifAccent
                    : Colors.notifTitle
                font.family: Caelus.fontFamily
                font.pixelSize: card.showApp ? Caelus.sizeBody : Caelus.sizeLead
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Panel entries leave this off: the bell above the list already
            // shows DND, and there it is live state next to a stale arrival.
            RowLayout {
                spacing: Caelus.spaceTight
                visible: card.popup && card.hotkey

                Text {
                    text: Notifications.dnd ? "notifications_off" : "notifications"
                    color: Notifications.dnd ? Colors.notifDndOn : Colors.notifDndOff
                    font.family: Caelus.symbolFamily
                    font.pixelSize: 14
                }

                Text {
                    text: Notifications.dnd ? "DND on" : "DND off"
                    color: Notifications.dnd ? Colors.notifDndOn : Colors.notifDndOff
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }

            Text {
                text: Notifications.timeOf(card.notification)
                color: Colors.notifMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Text {
                id: closeGlyph

                text: "close"
                color: closeArea.containsMouse ? Colors.notifCritical : Colors.notifMeta
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
                opacity: 0

                // hover.hovered flips on every card the pointer crosses, so
                // this fade runs more often than almost anything else in the
                // notification stack -- worth moving to the render thread so
                // it keeps up while the GUI thread is busy elsewhere. A State
                // rather than the old bound `opacity` + Behavior, since an
                // OpacityAnimator writes the property directly and would
                // fight a binding left in place on the same property.
                states: State {
                    name: "visible"
                    when: hover.hovered
                    PropertyChanges { target: closeGlyph; opacity: 1 }
                }

                transitions: Transition {
                    OpacityAnimator { target: closeGlyph; duration: Motion.fast }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismiss(card.notification)
                }
            }
        }

        Text {
            text: card.notification?.summary ?? ""
            color: Colors.notifTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLead
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: card.showApp && text !== ""
        }

        Text {
            text: card.notification?.body ?? ""
            color: Colors.notifBody
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            wrapMode: Text.WordWrap
            maximumLineCount: card.popup ? 3 : 6
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: text !== ""
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: Caelus.spaceSnug
            visible: repeater.count > 0

            Repeater {
                id: repeater
                model: card.visibleActions

                Rectangle {
                    required property var modelData

                    implicitWidth: actionText.implicitWidth + 20
                    implicitHeight: 26
                    radius: Caelus.radiusPill
                    color: actionArea.containsMouse ? Colors.notifBorder : Colors.notifPanelBg
                    border.width: 1
                    border.color: Colors.notifBorder

                    Behavior on color { ColorAnimation { duration: Motion.slow } }

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Colors.notifTitle
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
