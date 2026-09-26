import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The content shown once BarCenter.qml's clock island has morphed into idea
// 38's call banner -- see BarCenter.qml for the morph itself (the island
// growing wider -- never taller -- and cross-fading the clock pill out, both
// driven off DiscordCall.visible). This file only draws what fills that
// grown shape: the caller's avatar, name, an inline "Incoming call" label,
// and the two round accept/decline buttons, all pinned to the island's own
// resting height and never past it -- an earlier version let this grow
// taller than the bar and hung a card's worth of content past its bottom
// edge; `rowHeight` below is exactly Pill.qml's own fixed `implicitHeight`
// (`Caelus.barHeight - Caelus.barInset * 2`), so the island's footprint at
// rest and mid-call are the same number, not two numbers that happen to
// often agree.
//
// `maxWidth` is a deliberately modest, fixed cap rather than a measurement
// of BarLeft/BarRight's actual content (not this file's to know) -- comfortably
// short of where either side is likely to start on a normal bar.
//
// Accept sends Discord's own documented "answer" shortcut (Ctrl+Return,
// voice-only) and decline sends its "decline" shortcut (Escape), both
// straight to the single Vesktop window Hyprland currently knows about,
// targeted by its exact address and never focused first. If there is not
// exactly one Vesktop window to target, the banner just dismisses -- see
// Services/DiscordCall.qml's header comment for the exact mechanism, what
// it is confirmed against, and what is not.
Item {
    id: root

    readonly property var call: DiscordCall.call
    readonly property int rowHeight: Caelus.barHeight - Caelus.barInset * 2
    readonly property int maxWidth: 440

    implicitWidth: Math.min(row.implicitWidth + Caelus.spaceWide * 2, root.maxWidth)
    implicitHeight: root.rowHeight
    // Belt-and-braces against the cap above: every child below also carries
    // its own Layout.maximumWidth sized so the row's natural width never
    // exceeds `maxWidth` in the first place, but nothing here should ever
    // paint past this island's own bounds regardless.
    clip: true

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Caelus.spaceSnug

        // The one piece of this banner idea 38 is actually about: the
        // caller's real avatar rather than a generic app icon. MediaArt
        // already does exactly this fallback shape (circular art, or a
        // glyph while there is none/it fails to load) for DesktopMedia's
        // album art -- nothing here is call-specific about the masking, so
        // this reuses it rather than redrawing it. Sized a touch under
        // `rowHeight`, the same margin CalendarPopup's own round buttons
        // sit in from a taller row.
        MediaArt {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            source: root.call?.avatar ?? ""
            fallbackGlyph: "call"
            glyphColor: Colors.notifAccent
        }

        // One line, not two -- at a 32px-tall row (this island's own resting
        // height) two stacked lines has no room to sit without reaching
        // past the top/bottom edge the way an earlier version did. Name and
        // "Incoming call" share the line instead, name in the bar's own
        // label colour, the rest muted, so the two still read as separate
        // pieces without a second row of text. Notification content is
        // untrusted text, not markup -- PlainText keeps a caller name that
        // happens to contain "<b>" or similar from being interpreted as
        // rich text instead of shown literally.
        // Only the name ever elides: "· Incoming voice/video" is the part
        // that says what this is, so it always shows in full.
        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 170
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Caelus.fontFamily
            font.pixelSize: 16
            text: root.call?.name ?? ""
            color: Colors.fg
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            font.family: Caelus.fontFamily
            font.pixelSize: 16
            text: root.call?.kind === "video" ? "· Incoming video" : "· Incoming voice"
            color: Colors.fgMuted
        }

        RowLayout {
            spacing: Caelus.spaceTight
            Layout.alignment: Qt.AlignVCenter

            // Left is accept, right is decline -- the order the user asked
            // for, not Pill.qml's own icon-then-label reading order. Both
            // send Discord's own documented shortcut for the action straight
            // to Vesktop's window (Ctrl+Return / Escape) rather than raising
            // it -- see DiscordCall.qml's accept()/decline() for the exact
            // mechanism, and its header comment for what that is confirmed
            // against and what is not. Green/red are the honest colours for
            // "this joins the call" vs. "this ends it here".
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Caelus.radiusPill
                color: Colors.ok

                Text {
                    anchors.centerIn: parent
                    text: "call"
                    color: Colors.bg
                    font.family: Caelus.symbolFamily
                    font.pixelSize: 13
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: DiscordCall.accept() }
            }

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Caelus.radiusPill
                color: Colors.error

                Text {
                    anchors.centerIn: parent
                    text: "call_end"
                    color: Colors.bg
                    font.family: Caelus.symbolFamily
                    font.pixelSize: 13
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: DiscordCall.decline() }
            }
        }
    }
}
