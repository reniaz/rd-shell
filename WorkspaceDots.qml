import QtQuick
import Quickshell.Hyprland
import qs.Config
import qs.Services

Item {
    id: root

    required property HyprlandMonitor monitor

    // Which slot below currently owns the accent pill, so the indicator behind
    // the row knows where to sit. Each slot assigns itself here the moment it
    // becomes active. When that slot is later removed by the Repeater (its
    // workspace went away) QML nulls this out on its own, since an
    // object-typed property is guarded and notifies when its object dies.
    // That happens far more often than "the active workspace vanished",
    // though -- see the indicator's opacity below for what it costs.
    property Item activeSlot: null

    // The beat glow's own switch, off by default -- see the cross-request in
    // S5.md asking for a Caelus token the lead can bind here once one
    // exists. Left local rather than read from Config/Caelus.qml directly:
    // that file is not mine to add a property to, and binding to a token
    // that does not exist yet would break every consumer of this component
    // until it did.
    property bool beatReactive: Caelus.workspaceBeatGlow

    // A border stroke's alpha is the cheapest thing on `indicator` to
    // modulate: unlike width/height it never touches implicitWidth or
    // implicitHeight, so it cannot compete with the x/width tracking below
    // or reflow dotsRow the way the roadmap warns against. The stroke width
    // itself stays constant below -- only its colour's alpha channel moves --
    // so there is no geometry change here needing a Behavior of its own.
    readonly property real _beatBorderWidth: 1
    // Ceiling on the border's opacity at full level. Low on purpose: this is
    // the "thing nobody else has" the roadmap asks for, and the way to ruin
    // a detail like that is to make it loud enough to notice on its own
    // rather than merely to feel.
    readonly property real _beatMaxOpacity: 0.35

    // Zero whenever the gate is off or cava has nothing playing -- checked
    // explicitly rather than trusted to Cava.level alone (which already
    // settles to 0 the same instant, see Services/Cava.qml) so this reads as
    // inert by construction and not just by the service's current
    // implementation.
    readonly property real _beatOpacity: root.beatReactive && Cava.active
        ? Cava.level * root._beatMaxOpacity
        : 0

    // Class substring -> Material Symbols glyph, so an occupied workspace
    // reads as "a browser is here" the way caelestia-shell's own workspace
    // row does, rather than showing the app's own full-colour icon the way
    // an earlier version of this file did -- that put a second, unrelated
    // icon language next to every monochrome glyph pill on the bar. Matched
    // by substring against the lowercased class (Workspaces.firstAppClass),
    // not by exact name: a Flatpak or Snap build routinely wraps the same
    // app in a longer reverse-DNS id (org.mozilla.firefox, dev.zed.zed),
    // and a substring test catches both without a second table to keep in
    // sync. To add an app, add one line below; every glyph name here is one
    // already shipping in caelestia-shell's own category table, checked
    // against that rather than guessed, since a wrong name renders as a
    // blank box -- the exact failure this table exists to remove.
    readonly property var categoryGlyphs: ({
        // browsers
        firefox: "web", librewolf: "web", waterfox: "web", chromium: "web",
        "google-chrome": "web", chrome: "web", brave: "web", vivaldi: "web",
        opera: "web", edge: "web", zen: "web",

        // terminals
        kitty: "terminal", alacritty: "terminal", foot: "terminal",
        wezterm: "terminal", konsole: "terminal", xterm: "terminal",
        tilix: "terminal", terminator: "terminal", terminal: "terminal",

        // editors / IDEs
        code: "code", vscodium: "code", zed: "code", nvim: "code",
        neovim: "code", vim: "code", emacs: "code", jetbrains: "code",
        idea: "code", pycharm: "code", clion: "code", webstorm: "code",
        "sublime_text": "code",

        // chat
        discord: "chat", vesktop: "chat", slack: "chat", telegram: "chat",
        signal: "chat", element: "chat", teams: "chat",

        // media players
        spotify: "music_note", vlc: "music_note", mpv: "music_note",
        rhythmbox: "music_note", celluloid: "music_note", totem: "music_note",

        // file managers
        nautilus: "files", dolphin: "files", thunar: "files", nemo: "files",
        pcmanfm: "files",

        // image / graphics
        gimp: "photo_library", inkscape: "photo_library", krita: "photo_library",
        blender: "photo_library", darktable: "photo_library",

        // games
        steam: "sports_esports", lutris: "sports_esports", heroic: "sports_esports",
        minecraft: "sports_esports", prismlauncher: "sports_esports", retroarch: "sports_esports",
    })

    // What an unmatched class draws instead of nothing. "apps" rather than
    // leaving the table's lookup return an empty string is what makes the
    // blank-capsule bug structurally impossible: every occupied workspace
    // now always has a glyph to show, matched or not.
    readonly property string fallbackGlyph: "apps"

    function glyphFor(cls) {
        if (!cls) return root.fallbackGlyph;
        const key = Object.keys(root.categoryGlyphs).find(k => cls.includes(k));
        return key ? root.categoryGlyphs[key] : root.fallbackGlyph;
    }

    implicitWidth: dotsRow.implicitWidth
    // Fixed, and the dots hang off its centre. The active dot turns into a
    // tall capsule when it is carrying a count, and sizing this from its
    // children the way a bare Item or Row normally would have moved the whole
    // thing up and down inside the bar as windows come and go behind a
    // fullscreen one.
    implicitHeight: 20
    // No explicit `height` and no Layout attached property: Bar.qml:78 puts
    // this inside Pill's RowLayout, which takes a non-Layout-aware child's
    // implicitHeight as its preferred height and does not stretch it, since
    // nothing here sets fillHeight. The 20 above is therefore what the layout
    // writes back, and restating it was a duplicate of the layout's own work.

    // The travelling indicator. It is the only thing left that paints the
    // accent colour, so switching workspaces reads as one pill sliding across
    // the bar rather than a new dot growing while the old one shrinks away.
    Rectangle {
        id: indicator

        radius: Caelus.radiusPill
        color: Colors.dotActive
        anchors.verticalCenter: parent.verticalCenter
        // These hold their last value when activeSlot goes null rather than
        // collapsing to (0, 0). Writing a property back its own value is a
        // no-op in Qt -- setX and friends return early on an equal value and
        // notify nothing -- so the self-reference cannot re-enter and is not
        // a binding loop. Dependency capture is per-evaluation, so the
        // self-dependency the false branch registers is dropped again the
        // moment there is an active slot to follow.
        x: root.activeSlot ? root.activeSlot.x : indicator.x
        width: root.activeSlot ? root.activeSlot.width : indicator.width
        // No Behavior, deliberately: the slot animates its own implicitWidth,
        // so this already arrives one frame at a time and tracking it exactly
        // is what keeps the pill the size of the thing underneath it.
        height: root.activeSlot ? root.activeSlot.height : indicator.height
        // Driven by the monitor rather than by activeSlot, which is not the
        // same question. Adding or removing any workspace hands the Repeater
        // a new array and it rebuilds every delegate, so activeSlot goes null
        // and back on the most ordinary event there is -- stepping off an
        // empty workspace and letting Hyprland reap it. Keyed on that, the
        // pill blinked out and back each time. The monitor's own
        // activeWorkspace survives the rebuild and is what "is there anything
        // to point at" actually means.
        // `> 0` rather than merely non-null, because dotsFor() keeps only
        // `w.id > 0`: a special workspace is active but has no slot to sit
        // on, and without the test the pill stayed lit on the workspace you
        // left with that slot's own dot switched back on inside it.
        opacity: (root.monitor?.activeWorkspace?.id ?? -1) > 0 ? 1 : 0

        // A tint on the stroke, not the fill: `color` above is what says
        // "you are here", and letting the beat modulate that directly would
        // make the indicator's own identity flicker along with the music.
        // The border sits outside that story -- present or not, it never
        // changes what colour means "active" -- and `accentBright` keeps it
        // in the same accent family rather than introducing a second hue.
        border.width: root._beatBorderWidth
        border.color: Qt.rgba(Colors.accentBright.r, Colors.accentBright.g, Colors.accentBright.b, root._beatOpacity)

        // Alpha-only, so this never touches the geometry the comment above
        // is protecting. Motion.fast rather than left to snap: `level` is
        // already its own envelope follower (Services/Cava.qml), so this is
        // a second, gentle pass rather than the thing doing the smoothing.
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        // Disabled while there is no slot to follow. The false branch above
        // reads x back through this interceptor, so a workspace closing
        // mid-slide would retarget the running animation to wherever the
        // pill had got to and strand it between two dots instead of leaving
        // it on the last one.
        Behavior on x {
            enabled: root.activeSlot !== null
            NumberAnimation { duration: Motion.base; easing.type: Motion.enter; easing.overshoot: Motion.enterOvershoot }
        }
        // Width is deliberately not animated here. The slot it copies is
        // already running its own Motion.base ramp on implicitWidth, so a
        // Behavior on this side restarted a fresh 170ms curve on every frame
        // of that one and the pill trailed at roughly twice the duration,
        // visibly narrower than the dot it is meant to be covering for the
        // whole badge and icon transition.
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Row {
        id: dotsRow

        spacing: Caelus.spaceSnug
        height: root.height

        Repeater {
            model: Workspaces.dotsFor(root.monitor)

            Item {
                id: slot

                required property HyprlandWorkspace modelData
                readonly property bool active: slot.modelData?.id === root.monitor?.activeWorkspace?.id
                readonly property bool occupied: Workspaces.windowCount(slot.modelData?.id ?? -1) > 0

                // Only ever on the dot you are looking at. A count on an inactive
                // workspace would be describing somewhere you are not, and the
                // thing being reported -- that what is in front of you is hiding
                // the rest -- is only true of the one you are on.
                readonly property int hidden: slot.active ? Workspaces.focusedHidden : 0
                readonly property bool badge: slot.hidden > 0

                // The class of one window on this workspace, matched below
                // against root.categoryGlyphs. Empty for a bare workspace or
                // one whose only window never reported a class.
                readonly property string appClass: Workspaces.firstAppClass(slot.modelData?.id ?? -1)
                // glyphFor always answers with something -- a matched
                // category glyph or root.fallbackGlyph -- so there is no
                // "resolution failed" case left to fall through to a blank
                // capsule the way the old icon-theme lookup could.
                readonly property string glyph: root.glyphFor(slot.appClass)
                // Keyed on `occupied`, not on whether the class matched a
                // specific category: glyphFor's fallback means every
                // occupied workspace has a glyph to show, so this is exactly
                // "is there a window here" again -- unlike the old
                // icon-theme lookup, which could leave a hole for a window
                // with no desktop entry and no icon-theme match.
                readonly property bool showGlyph: slot.occupied

                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: slot.badge ? 20 : (slot.showGlyph || slot.active) ? 20 : 8
                implicitWidth: slot.badge ? label.implicitWidth + 20 : (slot.showGlyph || slot.active) ? 20 : 8

                Behavior on implicitWidth { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

                // Registers itself as the indicator's target as soon as it is
                // active. A Behavior never fires for a value a property was
                // *created* with (Services/Workspaces.qml:23 documents the
                // same trap), so the slot that is already active when the bar
                // first draws needs the onCompleted branch too -- without it
                // the indicator would sit invisible until the next switch.
                Component.onCompleted: if (slot.active) root.activeSlot = slot;
                // Clearing it again matters as much as setting it. Only the
                // slot that actually holds the registration may clear it, or
                // the outgoing slot would wipe the incoming one's claim on
                // the same switch and the pill would have nothing to follow.
                onActiveChanged: {
                    if (slot.active) root.activeSlot = slot;
                    else if (root.activeSlot === slot) root.activeSlot = null;
                }

                Rectangle {
                    id: body

                    anchors.fill: parent
                    radius: Caelus.radiusPill
                    color: slot.occupied ? Colors.dotOccupied : Colors.dotEmpty
                    // The indicator behind the row is now the only thing that
                    // paints the active colour, and an icon or a badge
                    // already says "something is here" on its own -- drawing
                    // this dot as well would just be a coloured square
                    // peeking out from under a bigger shape.
                    // Faded rather than switched. A bare `visible` flip put
                    // the outgoing slot's dot back at full strength while the
                    // pill was still sitting over it and had only begun to
                    // slide, which read as a flash just before the movement.
                    opacity: !slot.showGlyph && !slot.badge && !slot.active ? 1 : 0
                    visible: body.opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                // The category glyph. A plain Text rather than a clipped
                // IconImage -- this is a vector glyph with no background of
                // its own, so unlike the app's own icon (ghostty's square
                // one was the case that forced the old clip) there is
                // nothing here for a round mask to be protecting against.
                //
                // A sibling of `body` rather than a child of it: body stops
                // painting itself for this same state, and an invisible
                // parent takes its children down with it, so the glyph would
                // never appear if it were nested inside.
                Text {
                    id: glyphText

                    anchors.centerIn: parent
                    text: slot.glyph
                    font.family: Caelus.symbolFamily
                    // 16, not a Caelus size token: it is the same visual
                    // footprint the icon this replaces used to fill (the old
                    // clip was a 16x16 box), and it matches the hardcoded
                    // glyph size Pill.qml and SysReadout already use for an
                    // icon sitting this small in a bar row.
                    font.pixelSize: 16
                    // The active slot sits on top of the accent indicator
                    // pill, so its glyph reads against that fill the same
                    // way the badge's own glyph and count do below.
                    // Everything merely occupied has no pill behind it;
                    // Colors.dotOccupied is the same token the plain dot
                    // used to paint itself with, carried onto the glyph that
                    // now stands in for it.
                    color: slot.active ? Caelus.textOnAccent : Colors.dotOccupied
                    // Cross-faded with the badge rather than cut against it.
                    // The count fades out over Motion.fast while the capsule
                    // is still shrinking over Motion.base, so a glyph that
                    // simply became visible arrived at full strength on top
                    // of a glyph and a number that were both still on screen
                    // and centred in the same place -- the two drew over each
                    // other every time you left fullscreen.
                    opacity: slot.badge ? 0 : 1
                    visible: slot.showGlyph && glyphText.opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                // A glyph and the number, not the number alone. One digit
                // inside a dot was clean and said nothing at a glance: it
                // reads as decoration until you already know to look for it.
                // Stacked sheets plus a count is the one arrangement that
                // cannot be read as anything except "there are more of these
                // behind this".
                Row {
                    id: label

                    anchors.centerIn: parent
                    spacing: 3
                    opacity: slot.badge ? 1 : 0
                    // Tied to the animated implicitHeight rather than to
                    // `badge` directly, so the label fades out in step with
                    // the box shrinking instead of vanishing the instant the
                    // count clears while the box is still mid-shrink.
                    visible: slot.implicitHeight > 10

                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "layers"
                        color: Caelus.textOnAccent
                        font.family: Caelus.symbolFamily
                        // 14 sat exactly between sizeBody (13) and sizeLead
                        // (15) -- a tie on distance alone. sizeLead wins it:
                        // VolumeSlider.qml pairs its own icon+label the same
                        // way this badge does (a symbol glyph next to a
                        // sizeLabel value) and sizes the glyph at sizeLead,
                        // so this keeps the same glyph-to-label ratio that
                        // convention already sets elsewhere in the bar.
                        font.pixelSize: Caelus.sizeLead
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: slot.hidden
                        color: Caelus.textOnAccent
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Caelus.spaceSnug
                    // Clicking the workspace you are already on does nothing, so
                    // while it is carrying a count that click is free: it drops
                    // the covering window back into the stack and the others come
                    // back. Everywhere else it still just switches workspace.
                    onClicked: {
                        if (slot.badge) Workspaces.uncover();
                        else Workspaces.switchTo(slot.modelData.id);
                    }
                }
            }
        }
    }
}
