import QtQuick
import QtQuick.Effects
import qs.Config
import qs.Services

// The artist line under the title: main artist, then whatever else is
// credited. Spotify usually buries the featured names in the title
// ("Song (feat. X)") rather than MPRIS's own artist list -- the actual
// parsing lives in Media.artistsOf(), this only has to lay the result out.
//
// Three ways to show it, picked from a measurement rather than guessed:
// "Author · feat1, feat2" fits whole -> shown whole; it overflows by a
// little -> the ordinary elide every other line on this card already uses;
// it overflows by a lot, or there are simply too many names to read on one
// line at all, -> the features take turns instead, fading through one at a
// time under a fixed "Author · " -- the part of the line that never
// moves, so a glance always finds the main artist in the same place.
Item {
    id: root

    property var player
    // The card sets this false while collapsed (see DesktopMedia.qml) so
    // the cycle timer isn't quietly ticking -- and restarting itself on
    // every collapse -- for a line nobody can see.
    property bool active: true

    readonly property var _artists: Media.artistsOf(root.player)
    readonly property string _main: root._artists[0] ?? ""
    readonly property var _features: root._artists.length > 1 ? root._artists.slice(1) : []
    readonly property bool _hasFeatures: root._features.length > 0
    // U+00B7 MIDDLE DOT, not the U+318D the request was typed with --
    // caelusevka (`fc-list | grep -i caelusevka`) has no glyph for U+318D,
    // and U+00B7 renders identically at this size.
    readonly property string _prefix: root._hasFeatures ? `${root._main} · ` : root._main
    readonly property string _fullText: root._hasFeatures
        ? `${root._main} · ${root._features.join(", ")}`
        : root._main

    visible: root._main !== ""
    implicitHeight: staticText.implicitHeight

    TextMetrics {
        id: fullMetrics
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
        text: root._fullText
    }

    // Ratio, not a flat pixel margin: a name a few px over its box still
    // reads fine elided; a line a third again too wide is the point past
    // which eliding stops being worth reading versus just waiting a couple
    // seconds for the cycle to show the rest.
    readonly property real _overflow: root.width > 0 ? fullMetrics.width / root.width : 1

    // More than "about 2" features cycles outright, however short the
    // names -- "Author · A, B, C, D" is a list, not a line, no matter
    // how well it happens to fit.
    readonly property bool _cycle: root._hasFeatures
        && (root._features.length > 2 || root._overflow > 1.3)

    // ── fits, or overflows a little: one line, ordinary elide ──
    Text {
        id: staticText

        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root._cycle
        text: root._fullText
        color: Colors.mediaMeta
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
        elide: Text.ElideRight

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.6
            shadowOpacity: 0.5
            shadowVerticalOffset: 1
        }
    }

    // ── too many names, or too wide even elided: cycle them ────
    Row {
        id: cycleRow

        anchors.left: parent.left
        anchors.right: parent.right
        visible: root._cycle

        Text {
            id: prefixText
            text: root._prefix
            color: Colors.mediaMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 0.6
                shadowOpacity: 0.5
                shadowVerticalOffset: 1
            }
        }

        Text {
            id: featureText

            width: Math.max(0, cycleRow.width - prefixText.implicitWidth)
            text: root._features[cycler.index] ?? ""
            color: Colors.mediaMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
            elide: Text.ElideRight

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 0.6
                shadowOpacity: 0.5
                shadowVerticalOffset: 1
            }

            // A fade-out/fade-in dip rather than a true overlapping
            // crossfade: two stacked Texts sharing this card's already
            // heavy per-line MultiEffect shadow (see MediaArt.qml's own
            // crash history with layered effects) is more machinery than a
            // one-line swap needs, and a dip through zero opacity reads
            // just as clearly as a name changing.
            Behavior on opacity {
                NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
            }
        }
    }

    QtObject {
        id: cycler
        property int index: 0
    }

    // 2.5s, not a Motion token: every duration in Motion.qml times a UI
    // *reaction* (a hover, a reveal), and tops out at Motion.reveal (700ms)
    // for a full scene change. This is a steady read-then-swap loop with
    // nothing to react to, on a cadence the user asked for directly, so it
    // gets its own literal instead of a token that was never meant to fit.
    readonly property int _holdMs: 2500

    Timer {
        id: cycleTimer
        interval: root._holdMs
        repeat: true
        // Pausing while collapsed (`root.active`) or while there is only
        // ever one thing to show covers both "the card isn't visible" and
        // "cycling a single feature back to itself" -- neither needs a
        // running timer.
        running: root.active && root._cycle && root._features.length > 1
        onTriggered: {
            featureText.opacity = 0;
            advance.restart();
        }
    }

    // Waits out the fade-out (see featureText's own Behavior above) before
    // swapping the name underneath and fading the new one in -- the same
    // "don't move the text while it's still visible" rule MarqueeText.qml
    // follows for its own swap-back-to-start.
    Timer {
        id: advance
        interval: Motion.slow
        onTriggered: {
            cycler.index = (cycler.index + 1) % root._features.length;
            featureText.opacity = 1;
        }
    }

    // A track change can leave the cycle mid-way through the old track's
    // feature list; jump back to the first one rather than opening on
    // whatever index the previous track happened to stop at.
    on_FullTextChanged: {
        cycleTimer.stop();
        advance.stop();
        cycler.index = 0;
        featureText.opacity = 1;
    }
}
