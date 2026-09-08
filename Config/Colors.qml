pragma Singleton
import Quickshell
import QtQuick

// Palette derived from ~/.config/vesktop/themes/system24-caelus.theme.css
// (system24 "caelus" by refact0r / dacctal). CSS hsl() values are resolved to
// hex here; the theme's own hex values are copied verbatim.
Singleton {
    id: root

    // ── accents ──────────────────────────────────────────────
    readonly property color accent: "#b86e38"      // main accent
    readonly property color accentBright: "#ef934d" // theme --accent-2/-3
    readonly property color accentLight: "#f8ccab"  // theme --accent-1
    readonly property color accentDeep: "#d76e1d"   // theme --accent-5

    // ── surfaces ─────────────────────────────────────────────
    readonly property color bg: "#000000"          // pill background
    readonly property color surface: "#1b1d1c"     // theme --bg-4
    readonly property color surfaceRaised: "#222623" // theme --bg-3
    readonly property color surfaceHover: "#38423b"  // theme --bg-1

    // ── text ─────────────────────────────────────────────────
    readonly property color fg: "#f8f5f2"          // theme --text-1
    readonly property color fgDim: "#cfbeb4"       // theme --text-3
    readonly property color fgMuted: "#746863"     // theme --text-5

    // ── status ───────────────────────────────────────────────
    readonly property color ok: "#7ec97e"          // theme --green-2
    readonly property color warn: "#ef934d"        // theme --yellow-2
    readonly property color error: "#f16e65"       // theme --red-2

    // ── icon colors ──────────────────────────────────────────
    readonly property color volumeColor: "#93c893" // theme --accent-2/-3
    readonly property color micColor: "#f16e65"
    readonly property color netColor: "#d76e1d"
    readonly property color keyboardColor: "#98a49d" // theme --blue-1, light teal
    readonly property color mediaColor: "#c4a898" // theme --purple-2
    readonly property color powerColor: "#f16e65" // theme --red-2
    readonly property color notifColor: "#c4a898"  // theme --purple-2

    // ── widgets ──────────────────────────────────────────────
    readonly property color volumeIcon: volumeColor
    readonly property color micIcon: micColor
    readonly property color networkIcon: netColor
    readonly property color keyboardIcon: keyboardColor
    readonly property color mediaIcon: mediaColor
    readonly property color powerIcon: powerColor

    // ── notifications ────────────────────────────────────────
    // All derived from the tokens above, so re-theming the notification centre
    // is a matter of editing those and nothing else.
    readonly property color notifPanelBg: surface   // theme --bg-4, not pure black
    readonly property color notifCardBg: surfaceRaised
    readonly property color notifBorder: surfaceHover
    readonly property color notifTitle: fg
    readonly property color notifBody: fgDim
    readonly property color notifMeta: fgMuted
    readonly property color notifSection: notifColor
    readonly property color notifCritical: error
    readonly property color notifDndOn: notifCritical   // do not disturb active
    readonly property color notifDndOff: ok             // notifications flowing
    readonly property color notifAccent: notifColor

    // Unread badge on the bar's bell. Deliberately the bright accent and not
    // `error`: an unread count is information, not a fault, and the red is
    // reserved for critical notifications inside the panel.
    readonly property color notifUnread: accentBright

    // ── claude session widget ────────────────────────────────
    // Same derivation discipline as the notification block above: every token
    // resolves back to the base palette, so re-theming needs no edits here.
    readonly property color claudeColor: "#e87d2c"   // theme --accent-4, deep orange
    readonly property color claudeIcon: claudeColor
    readonly property color claudeAccent: popupAccent

    readonly property color claudePanelBg: surface
    readonly property color claudeCardBg: surfaceRaised
    readonly property color claudeBorder: surfaceHover
    readonly property color claudeTitle: fg
    readonly property color claudeBody: fgDim
    readonly property color claudeMeta: fgMuted

    readonly property color claudeBusy: ok
    readonly property color claudeIdle: fgMuted
    readonly property color claudeWarn: warn
    readonly property color claudeCritical: error

    readonly property color claudeTabBar: bg
    readonly property color claudeTabActive: popupAccent
    readonly property color claudeTabInactive: fgMuted
    readonly property color claudeTrack: surfaceHover

    // A session that is blocked waiting on you. Shares the critical red instead
    // of the busy green so the one row that needs you out-shouts every row that
    // is merely working, before any label has been read.
    readonly property color claudeAttention: claudeCritical

    // Subagents. Deliberately not claudeAccent: a session and the agents it
    // spawned share a row, so colour is the only thing telling them apart.
    // --blue-1 is the coolest token in the palette and reads as delegated work.
    readonly property color claudeAgent: templateColor8

    // Rules and separators inside an expanded session's sections. Matches the
    // card outline on purpose -- a second, different grey inside an already
    // bordered card reads as an accident rather than as structure.
    readonly property color claudeDim: claudeBorder

    // ── charts ───────────────────────────────────────────────
    // One ordered series palette, used by every chart in the Statistics tab so
    // that "the orange one" means the same model on the donut as on the bars.
    // Ordered by how far each colour sits from the one before it rather than by
    // the palette's own numbering: adjacent slices must not read as a gradient.
    readonly property var claudeSeries: [
        claudeColor,       // deep orange -- the account accent leads
        templateColor8,    // light teal
        templateColor1,    // light orange
        templateColor5,    // green
        templateColor9,    // warm taupe
        templateColor3,    // red
        templateColor7,    // muted teal
        templateColor10,   // light taupe
        templateColor4,    // light red
        templateColor6     // light green
    ]

    // Chart furniture. Both are deliberately dimmer than claudeBorder: a
    // gridline that competes with the card outline turns every chart into a
    // table.
    readonly property color claudeGrid: "#2b302d"
    readonly property color claudeAxis: fgMuted

    // The heatmap ramp runs from the empty-cell grey to the account accent, so
    // an idle hour reads as background rather than as a dark value.
    readonly property color claudeHeatEmpty: "#242826"
    readonly property color claudeHeatLow: "#3a2a1e"
    readonly property color claudeHeatHigh: claudeColor

    // ── system monitor ───────────────────────────────────────
    // The CPU, GPU and memory pills all start green and are only ever coloured
    // by their own reading, so they share one base with the disk pill: on this
    // bar green means "nothing to look at here" wherever it appears.
    readonly property color sysColor: diskColor
    readonly property color sysIcon: sysColor

    readonly property color sysTitle: fg
    readonly property color sysBody: fgDim
    readonly property color sysMeta: fgMuted
    readonly property color sysTrack: surfaceHover
    readonly property color sysCard: surfaceRaised

    // Ending a process is the one destructive control on the bar, so it is the
    // only thing in the popup allowed to wear the critical red.
    readonly property color sysKill: error

    // Where a temperature stops being a reading and starts being a warning.
    // Same two-step shape as usage() -- accent first, then red -- but on a
    // scale that only makes sense per sensor, so the thresholds come from the
    // caller and live next to the sensor that needs them.
    function heat(celsius, warmAt, hotAt, base) {
        return celsius >= hotAt ? error : celsius >= warmAt ? accent : base;
    }

    // ── popups ───────────────────────────────────────────────
    // Every card the bar hangs under a pill shares one surface and one outline:
    // they are the same object seen from different icons.
    readonly property color popupBg: surface
    readonly property color popupBorder: surfaceHover

    // ...and one accent across all of them. The pills keep their own colours --
    // that is how you tell one icon from the next along the bar -- but once a
    // card is open it is the bar talking, so the disk, Claude, player and
    // calendar cards all head and highlight in the main accent.
    readonly property color popupAccent: accent

    // ── media popup ──────────────────────────────────────────
    // Shares the pill's warm taupe, so the card reads as that icon opened up
    // rather than as a second widget about sound.
    readonly property color mediaTitle: fg
    readonly property color mediaBody: fgDim
    readonly property color mediaMeta: fgMuted
    readonly property color mediaCard: surfaceRaised

    // The outline on a player that is actually sounding. Deliberately the pill's
    // own colour: "this is the one the bar is talking about".
    readonly property color mediaActive: popupAccent

    // ── calendar ─────────────────────────────────────────────
    // Today wears the main accent as a filled disc, so the one cell that matters
    // is found before the month name has been read. Days from the neighbouring
    // months keep the card's own outline colour -- present enough to fill the
    // grid, dim enough never to be mistaken for this month.
    readonly property color calIcon: popupAccent
    readonly property color calTitle: fg
    readonly property color calBody: fgDim
    readonly property color calMeta: fgMuted
    readonly property color calToday: popupAccent
    readonly property color calTodayFg: bg
    readonly property color calOutside: surfaceHover

    // ── disk widget ──────────────────────────────────────────
    // Green rather than one more orange: the pill sits between the keyboard's
    // light teal and the mic's red, and every warm token on this bar is already
    // spoken for by the network, media and Claude widgets.
    readonly property color diskColor: templateColor5  // --green-2
    readonly property color diskIcon: diskColor

    readonly property color diskTitle: fg
    readonly property color diskBody: fgDim
    readonly property color diskMeta: fgMuted
    readonly property color diskTrack: surfaceHover

    // How full is too full. One owner for every percentage the bar colours --
    // the disk pill and its popup bars, the Claude pill's share of the account
    // limit -- so nothing can disagree about what "nearly full" looks like.
    // `base` is whatever the widget shows while there is nothing to say; the
    // middle band is the main accent rather than the brighter --yellow-2 `warn`,
    // since three quarters full is a reading and not a fault.
    function usage(percent, base) {
        return percent >= 90 ? error : percent >= 75 ? accent : base;
    }

    readonly property color dotActive: accent
    readonly property color dotOccupied: "#8a6a58"
    readonly property color dotEmpty: "#3a3a3a"

    // ── spare theme colors for future widgets ────────────────
    // Rename these as they get used; numbering is stable so they can be
    // reassigned without touching anything already wired up.
    readonly property color templateColor1: "#f8ccab"  // --accent-1  light orange
    readonly property color templateColor2: "#e87d2c"  // --accent-4  deep orange (= claudeColor)
    readonly property color templateColor3: "#f16e65"  // --red-2     red
    readonly property color templateColor4: "#f7b0ab"  // --red-1     light red
    readonly property color templateColor5: "#7ec97e"  // --green-2   green
    readonly property color templateColor6: "#93c893"  // --green-1   light green
    readonly property color templateColor7: "#6c756f"  // --blue-2    muted teal
    readonly property color templateColor8: "#98a49d"  // --blue-1    light teal
    readonly property color templateColor9: "#c4a898"  // --purple-2  warm taupe
    readonly property color templateColor10: "#dbcec7" // --purple-1  light taupe
    readonly property color templateColor11: "#e9dfd8" // --text-2    heading
    readonly property color templateColor12: "#988881" // --text-4    icon grey
}
