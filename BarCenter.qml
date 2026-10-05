import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

RowLayout {
    id: root

    // Exposed for BarOverlays.qml: the clock pill's offset for the
    // dashboard to anchor on in "islands"/"full" (`root.clockAnchorX`,
    // read via BarWindow.qml's own forwarding property of the same name --
    // "corners" anchors the dashboard on the notch tab instead and never
    // reads this). Still `clockPill`'s own centre, not `cell`'s -- the pill
    // keeps its resting position and size even while `cell` has grown
    // around it for idea 38's banner (see `cell` below).
    //
    // Round 5: this group no longer has an open flag of its own for
    // BarOverlays.qml to read -- the right-click below drives
    // `Dashboard.open` directly now, the same global flag the notch tab
    // already toggles, so there is nothing pill-local left to expose here.
    // `calendarOpen`/`CalendarPopup.qml` (this alias's own reason for
    // existing) are gone.
    readonly property real clockAnchorX: clockPill.x + clockPill.width / 2

    // Set only by BarWindow.qml, only in the "corners" style: the item to
    // dock this group's right edge against instead of centring in the
    // window. Null (the default) keeps every other style's behaviour
    // exactly as it was -- the two anchor lines below are both gated on
    // it rather than one replacing the other outright, which is what lets
    // a live style switch flip between them with nothing warning about a
    // binding loop (an `anchors.centerIn` and an `anchors.right` on the
    // same item fight if both are ever set at once; here only one half of
    // each pair is ever non-undefined for a given value of `dockRight`).
    property Item dockRight: null

    anchors.centerIn: root.dockRight ? undefined : parent
    anchors.right: root.dockRight ? root.dockRight.left : undefined
    anchors.rightMargin: root.dockRight ? Caelus.barSpacing : 0
    anchors.verticalCenter: root.dockRight ? parent.verticalCenter : undefined
    spacing: Caelus.barSpacing

    // Idea 38's incoming-call banner: the clock pill itself morphs into it
    // in place, the way St0rmosu/dynamic-island-hyprland's own reference
    // does it, rather than a card dropping out from under the pill. `cell`
    // is the thing that actually grows -- BarWindow.qml's `centerIsland` is
    // anchored to this whole group's bounding box (`anchors.fill: group`,
    // see the comment on `Island` there), so animating `cell`'s width is
    // what makes the fused island plate grow with it, no different from a
    // media title scrolling a group wider today. `implicitWidth` with a
    // `Behavior` is the same idiom WorkspaceDots.qml already grows a dot
    // into a capsule with -- just reaching for `Motion.spatial`/
    // `spatialCurve` (BarPopup's own card-growth pairing) rather than
    // `Motion.base`, since this is the wider of the two.
    //
    // Height never animates and never appears in that Behavior: the island
    // grows sideways only, exactly Pill.qml's own fixed `implicitHeight`
    // (`clockPill.implicitHeight`, itself `Caelus.barHeight -
    // Caelus.barInset * 2`) at every moment, clock or call. An earlier
    // version let `cell` grow taller to fit the banner's content and the
    // island ended up hanging past the bar's own bottom edge into whatever
    // sits below it -- DiscordCallBanner.qml now sizes its own content to
    // this same fixed height instead, so nothing here ever asks the island
    // to be taller than the bar it lives in.
    Item {
        id: cell

        readonly property bool call: DiscordCall.visible

        implicitWidth: cell.call ? callContent.implicitWidth : clockPill.implicitWidth
        implicitHeight: clockPill.implicitHeight
        width: implicitWidth
        height: implicitHeight
        // Belt-and-braces alongside the opacity delay below: clockPill and
        // callContent both sit centred here at their own full (unanimated)
        // width the instant either becomes the target, while only `cell`'s
        // own width actually travels. The opacity delay already keeps
        // whichever one is arriving invisible until `cell` is nearly at its
        // target width, so this should never have anything to clip in
        // practice -- it is here so a future change to that timing (or an
        // animation interrupted mid-flight) fails safe instead of hanging
        // avatar/button/text past the island's own edge.
        clip: true

        // Leads immediately on expand (grows for the full `Motion.spatial`
        // span while the outgoing clock fades out underneath it, fast and
        // unclipped, since a growing `cell` never shrinks below whatever
        // clockPill already fit at) but trails on collapse, held at the
        // still-full width for exactly `Motion.fast` -- the same span
        // callContent's own immediate fade-out below takes -- before it
        // starts shrinking. Without that hold, the shrink and the outgoing
        // content's fade used to run at once, clipping callContent's avatar
        // and name out from the sides while it was still partway through
        // fading, rather than letting it disappear cleanly first.
        // Both directions still total `Motion.spatial` end to end, and the
        // shrink's own duration is shortened by exactly the hold so the two
        // stay matched.
        Behavior on implicitWidth {
            SequentialAnimation {
                PauseAnimation { duration: cell.call ? 0 : Motion.fast }
                NumberAnimation {
                    property: "implicitWidth"
                    duration: cell.call ? Motion.spatial : Motion.spatial - Motion.fast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Motion.spatialCurve
                }
            }
        }

        Pill {
            id: clockPill

            anchors.centerIn: parent
            pressed: clockArea.pressed

            property bool showReminder: false

            icon: "schedule"
            // What is next to go off, in the place the date used to sit -- a
            // timer is set to be glanced at, and the dashboard is a
            // right-click away for the month itself.
            //
            // Round 5: once something is due inside the hour, its own text
            // rides along with the countdown rather than the countdown
            // standing alone -- "no timer" told you nothing was coming, but
            // a bare "4m" told you something was about to fire without
            // saying what. Further out than an hour the countdown alone is
            // still all this fold shows, exactly as it always has: a
            // reminder days away naming itself here would make the fold
            // read as a running agenda rather than the one-line "is
            // something about to happen" glance it is. `Reminders.next.text`
            // is read straight off the v2 record (Services/Reminders.qml);
            // `Pill.qml`'s own `elide`/`maxLabelWidth` already cap a long
            // one rather than growing the island without bound.
            label: clockPill.showReminder
                ? (Reminders.next
                    ? (Reminders.next.at - Reminders.now <= 3600000
                        ? `${Time.time} | ${Reminders.next.text} ${Format.countdown(Reminders.next.at, Reminders.now)}`
                        : `${Time.time} | ${Format.countdown(Reminders.next.at, Reminders.now)}`)
                    : `${Time.time} | no timer`)
                : Time.time

            // Cross-fades out under the call content rather than being torn
            // down -- the banner replaces it in place, and neither the
            // reminder toggle nor the dashboard means anything while a call
            // is ringing. `interactive: false` also mutes the pill's own
            // hover wash, so it doesn't sit there half-visible under the
            // banner suggesting it can still be clicked.
            //
            // The two directions are deliberately NOT symmetric in timing,
            // even though they share the same fade duration: whichever
            // content is on its way OUT fades immediately (pause: 0 below),
            // so it never overlaps the incoming content mid-crossfade, while
            // whichever is coming IN waits out most of `cell`'s own
            // `Motion.spatial` width travel first -- there is nowhere to
            // put it, readably, until the island has mostly finished
            // growing (opening) or is about to finish shrinking (closing).
            // `cell.call` already holds the new state by the time this
            // Behavior's target (the ternary above) is evaluated, so the
            // same pause expression reads correctly for both directions:
            // 0 while this pill is the one leaving, the delay while it is
            // the one about to arrive.
            opacity: cell.call ? 0 : 1
            interactive: !cell.call

            // NumberAnimation, not OpacityAnimator, once this is nested
            // inside a SequentialAnimation: an Animator's target/property is
            // only auto-wired by Behavior when it is the animation directly
            // (the single-fade case DiscordCallBanner/callContent used
            // before this needed a delay stage too) -- nested under a
            // PauseAnimation like this, it never picked up a target at all,
            // so the pause below was a no-op and opacity jumped straight to
            // its bound value with no animation.
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: cell.call ? 0 : Motion.spatial - Motion.fast }
                    NumberAnimation { property: "opacity"; duration: Motion.fast }
                }
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                enabled: !cell.call
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                // Left folds in what is next; right opens the dashboard,
                // calendar and all, in every bar style now -- not just the
                // notch tab "corners" grew for it. Round 5 deliberate
                // choice: `Dashboard.toggle()` is the one flag every style
                // already gates its own dashboard popup on (see
                // BarOverlays.qml's `dashboardLoader`), so a right-click
                // here needs no style check of its own, the same way the
                // notch tab needs none either.
                onClicked: mouse => mouse.button === Qt.RightButton
                    ? Dashboard.toggle()
                    : clockPill.showReminder = !clockPill.showReminder
            }
        }

        DiscordCallBanner {
            id: callContent

            anchors.centerIn: parent
            // Delayed on the way in, immediate on the way out -- the
            // mirror image of clockPill's own opacity Behavior above (see
            // its comment for why); together the two mean only one of
            // clock/call content is ever visible at a time, and never
            // while `cell` is still narrower than whichever one is about
            // to show, since the incoming side's fade only starts once the
            // width travel is nearly done.
            opacity: cell.call ? 1 : 0
            visible: opacity > 0

            // NumberAnimation, not OpacityAnimator -- see clockPill's own
            // Behavior above for why a nested Animator does not work here.
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: cell.call ? Motion.spatial - Motion.fast : 0 }
                    NumberAnimation { property: "opacity"; duration: Motion.fast }
                }
            }
        }
    }
}
