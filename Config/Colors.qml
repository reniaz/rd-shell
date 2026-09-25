pragma Singleton
import Quickshell
import QtQuick

// Palette derived from ~/.config/vesktop/themes/system24-caelus.theme.css
// (system24 "caelus" by refact0r / dacctal). CSS hsl() values are resolved to
// hex here; the theme's own hex values are copied verbatim.
Singleton {
    id: root

    // Gated on Wal.known as well as the setting: flipping this on where
    // matugen has never run must not blank the bar. Every property below that
    // reads Wal falls back to its caelus hex the instant either half of this
    // is false, so turning it back off -- or never turning it on -- puts
    // today's bar back exactly.
    readonly property bool dynamic: Caelus.dynamicColour && Wal.known

    // ── accents ──────────────────────────────────────────────
    // The hex after the colon is the revert: it is caelus.palette transcribed
    // verbatim, and it is what stays live for anyone who never touches
    // `dynamic`. Only the property lookups before the `?` are new.
    readonly property color accent: root.dynamic ? Wal.accent : "#b86e38"      // main accent
    readonly property color accentBright: root.dynamic ? Wal.accentBright : "#ef934d" // theme --accent-2/-3
    readonly property color accentLight: root.dynamic ? Wal.accentLight : "#f8ccab"  // theme --accent-1
    readonly property color accentDeep: root.dynamic ? Wal.accentDeep : "#d76e1d"   // theme --accent-5

    // ── bar ──────────────────────────────────────────────────
    // The window stays transparent; what shows through it is the wallpaper.
    // The bar's body is three islands drawn on top of that, each a near-opaque
    // plate the compositor can blur behind -- a fully transparent layer blurs
    // nothing, which is why the strip had to gain a body before the Hyprland
    // layer rule could do anything. The alpha is what makes the blur read as
    // glass instead of as paint.
    readonly property color barBg: "transparent"
    // One number to tune how much wallpaper comes through. Raise it towards 1
    // and the islands go solid; drop it and they go glassy, but the compositor
    // only blurs a layer whose alpha clears `ignore_alpha` in the Hyprland
    // layer rule (0.2), so do not take it below that or the blur switches off
    // along with the body.
    // One alpha with the popup cards, not a lower one of its own -- see
    // Caelus.opacitySurface for why they have to match.
    readonly property real barIslandOpacity: Caelus.opacitySurface
    readonly property color barIsland: Qt.rgba(surface.r, surface.g, surface.b, barIslandOpacity)
    // Kept equal to surfaceHover by hand instead of written as that name, but
    // the two still have to move together -- otherwise dynamic mode would
    // leave the bar's own outline behind while every popup's outline follows
    // the wallpaper, and the two chrome layers would visibly stop matching.
    readonly property color barIslandBorder: root.dynamic ? Wal.surfaceHover : "#38423b" // surfaceHover, as popups use
    // The film a segment lifts under the pointer. Deliberately faint: an icon's
    // colour is what identifies its pill, so a hover must not recolour it.
    // The literal is `fg` at low alpha (the trailing six digits are its hex);
    // the dynamic side rebuilds that same alpha over Wal.fg instead of
    // reaching for a second, unrelated grey.
    readonly property color barPillHover: root.dynamic
        ? Qt.rgba(Wal.fg.r, Wal.fg.g, Wal.fg.b, 0x14 / 255)
        : "#14f8f5f2"

    // ── surfaces ─────────────────────────────────────────────
    // `bg` stays a plain literal: it is pure black on purpose, for popup
    // buttons and pill icons sitting on top of a surface, not a tone of the
    // surface ladder itself, so wallpaper colour has no business reaching it.
    readonly property color bg: "#000000"          // popup buttons, pill icons
    readonly property color surface: root.dynamic ? Wal.surface : "#1b1d1c"     // theme --bg-4
    readonly property color surfaceRaised: root.dynamic ? Wal.surfaceRaised : "#222623" // theme --bg-3
    readonly property color surfaceHover: root.dynamic ? Wal.surfaceHover : "#38423b"  // theme --bg-1

    // ── text ─────────────────────────────────────────────────
    // fgDim and fgMuted stay static like every other semantic tone below --
    // only the single brightest text colour follows the wallpaper, not the
    // whole ladder, so body and meta text keep reading as caelus regardless.
    readonly property color fg: root.dynamic ? Wal.fg : "#f8f5f2"          // theme --text-1
    // Follows the wallpaper through Wal.onSurfaceVariant (§7.2 light mode):
    // matugen's own contrast-checked "dim text" role, which inverts
    // correctly when surface flips light. The static hex it replaces is a
    // light tan -- correct as light-on-dark, but never designed to sit on a
    // light surface, and dynamic mode had never produced one before matugen
    // gained a mode flag here. fgMuted below stays static and does NOT need
    // this: at #746863 its luminance sits close enough to the middle of the
    // range that it keeps roughly 5:1 contrast against a light surface too
    // (measured), so the "reads as caelus regardless" comment above still
    // holds for it specifically, just not for fgDim.
    readonly property color fgDim: root.dynamic ? Wal.onSurfaceVariant : "#cfbeb4"       // theme --text-3
    readonly property color fgMuted: "#746863"     // theme --text-5

    // ── status ───────────────────────────────────────────────
    // Meaning lives in the hue, style lives in everything else. Green is
    // "fine" and red is "wrong" whatever is on the desktop behind them, so
    // these never hand their hue to the wallpaper -- `Wal.reshade` keeps it
    // and borrows only the palette's saturation and brightness, which is
    // what stops a fixed literal looking pasted onto a dynamic bar. A colour
    // with no meaning to protect (the network pill, the keyboard pill) takes
    // a palette role outright instead, a few lines below.
    readonly property color ok: root.dynamic ? Wal.reshade("#7ec97e") : "#7ec97e"   // --green-2
    readonly property color warn: root.dynamic ? Wal.reshade("#ef934d") : "#ef934d" // --yellow-2
    readonly property color error: root.dynamic ? Wal.reshade("#f16e65") : "#f16e65" // --red-2

    // ── icon colors ──────────────────────────────────────────
    // Volume is green and mic is red at every hour of the day -- those two
    // are read at a glance and never puzzled over, which only works while the
    // colour is the same one it was yesterday. Reshaded, so they still sit in
    // the wallpaper's register.
    readonly property color volumeColor: root.dynamic ? Wal.reshade("#93c893") : "#93c893" // --accent-2/-3
    readonly property color micColor: root.dynamic ? Wal.reshade("#f16e65") : "#f16e65"    // --red-2
    // Used to be the same red as micColor -- an accident, not a decision: two
    // pills sharing a hue is exactly what stops colour meaning anything. Power
    // is a button, not a state, so it takes the same neutral every decorative
    // icon below gets; the red stays micColor's alone, since that is the one
    // pill on this bar where "coloured" genuinely means "you are live".
    readonly property color powerColor: fgDim
    // Everything from here down used to take a palette role of its own --
    // orange, magenta, green, pale blue -- so the resting bar showed five hue
    // families before a single pill had anything to say. None of these five
    // carry information at rest, so they collapse onto fgDim, the one neutral
    // every other piece of static bar chrome already reads against. That also
    // settles the other accidental collision the audit found: keyboardColor
    // and notifColor used to both be Wal.tertiary verbatim; keyboardColor is
    // fgDim now, so there is nothing left for it to collide with.
    readonly property color netColor: fgDim
    // The one alert this pill actually has: no link at all. Bar.qml does not
    // yet switch to this when Network.connected is false -- see the request
    // in S7.md -- but the token is here for whoever wires it in.
    readonly property color networkOffline: error
    readonly property color keyboardColor: fgDim
    readonly property color mediaColor: fgDim
    // The notification pill has no palette role of its own any more. Its
    // resting glyph takes the same neutral as the four above (notifIcon), and
    // once a toast or the panel is open it is a card like any other, so its
    // accent edge, "which app" chip and section headings read popupAccent
    // below. A tertiary of their own made a toast the one card on screen in a
    // second hue -- pink beside a blue bar, on a blue wallpaper.
    readonly property color notifIcon: fgDim

    // ── widgets ──────────────────────────────────────────────
    // volumeIcon and micIcon keep an identity colour on purpose; every other
    // icon here inherits fgDim through the tokens just above, so this list
    // does not need to repeat that reasoning at each line.
    readonly property color volumeIcon: volumeColor
    readonly property color micIcon: micColor
    readonly property color networkIcon: netColor
    readonly property color keyboardIcon: keyboardColor
    readonly property color mediaIcon: mediaColor
    readonly property color powerIcon: powerColor

    // ── notifications ────────────────────────────────────────
    // All derived from the tokens above, so re-theming the notification centre
    // is a matter of editing those and nothing else. notifPanelBg stays solid
    // on purpose -- see the popups section below for why it is not popupBg's
    // alpha layered a second time.
    readonly property color notifPanelBg: surface   // theme --bg-4, not pure black
    readonly property color notifCardBg: surfaceRaised
    readonly property color notifBorder: surfaceHover
    readonly property color notifTitle: fg
    readonly property color notifBody: fgDim
    readonly property color notifMeta: fgMuted
    readonly property color notifSection: popupAccent
    readonly property color notifCritical: error
    readonly property color notifDndOn: notifCritical   // do not disturb active
    readonly property color notifDndOff: ok             // notifications flowing
    readonly property color notifAccent: popupAccent

    // Unread badge on the bar's bell. Deliberately the bright accent and not
    // `error`: an unread count is information, not a fault, and the red is
    // reserved for critical notifications inside the panel.
    readonly property color notifUnread: accentBright

    // ── claude session widget ────────────────────────────────
    // Same derivation discipline as the notification block above: every token
    // resolves back to the base palette, so re-theming needs no edits here.
    // claudeColor used to be the one icon token in this whole file with no
    // dynamic branch at all -- a hardcoded hex that could not follow the
    // wallpaper even with dynamic mode on. Reshaded rather than a straight
    // palette role, matching templateColor2 further down, which already
    // carried this exact hex for the chart series; the two now move together,
    // so the account accent never reads as one orange on the bar and a
    // slightly different one in its own chart.
    readonly property color claudeColor: root.dynamic ? Wal.reshade("#e87d2c") : "#e87d2c"   // theme --accent-4, deep orange
    // The pill's resting glyph goes neutral like every other decorative icon
    // on the bar; claudeColor itself keeps the account orange for what still
    // genuinely wants it -- claudeSeries and claudeHeatHigh below. Bar.qml
    // already swaps to claudeBusy while a session is running, so the state
    // that matters keeps its colour, and idle -- the resting state -- is now
    // fgDim like the rest of the island.
    readonly property color claudeIcon: fgDim
    readonly property color claudeAccent: popupAccent

    // Solid for the same reason notifPanelBg is: see the popups section below.
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
    // table. That was tuned by eye against a dark surfaceRaised, where the
    // fixed dark literal stays invisible-by-design (§7.2 light mode) -- on a
    // light surfaceRaised the same literal would instead be the single
    // darkest, most attention-grabbing line in the card. The dynamic branch
    // blends a little of `fg` into `surfaceRaised` instead, a small step in
    // whichever direction `fg` itself already is (light in dark mode, dark
    // in light mode), which keeps the line exactly as understated in both.
    readonly property color claudeGrid: root.dynamic
        ? Qt.rgba(surfaceRaised.r + (fg.r - surfaceRaised.r) * 0.12,
                   surfaceRaised.g + (fg.g - surfaceRaised.g) * 0.12,
                   surfaceRaised.b + (fg.b - surfaceRaised.b) * 0.12, 1.0)
        : "#2b302d"
    readonly property color claudeAxis: fgMuted

    // The heatmap ramp runs from the empty-cell grey to the account accent, so
    // an idle hour reads as background rather than as a dark value. That
    // contract breaks under the same light-surface case as claudeGrid just
    // above, and for the same reason: "reads as background" only holds if
    // the empty tone actually tracks the surface it sits on, not a fixed
    // dark literal that used to happen to be close to it. claudeHeatLow and
    // claudeHeatHigh stay fixed -- they are values on the ramp, not a stand-in
    // for empty, so a harder step at the low end in light mode is not the
    // same kind of bug as an idle cell reading as the most emphasised one.
    readonly property color claudeHeatEmpty: root.dynamic
        ? Qt.rgba(surfaceRaised.r + (fg.r - surfaceRaised.r) * 0.05,
                   surfaceRaised.g + (fg.g - surfaceRaised.g) * 0.05,
                   surfaceRaised.b + (fg.b - surfaceRaised.b) * 0.05, 1.0)
        : "#242826"
    readonly property color claudeHeatLow: "#3a2a1e"
    readonly property color claudeHeatHigh: claudeColor

    // ── system monitor ───────────────────────────────────────
    // sysColor stays diskColor: the popup's own tabs still read it directly as
    // their usage()/heat() base (SysCpuTab, SysGpuTab, SysMemTab, SysCores, the
    // tab strip's own fill), and that is the detail view, not the resting bar,
    // so it keeps the identity it already had. sysIcon is the pill out on the
    // bar, and that is resting chrome now: it goes to fgDim like every other
    // icon on the island, and SysReadout still passes it into usage()/heat() as
    // the base, so a hot core or a loaded GPU still escalates through accent to
    // error exactly as before -- only the "nothing to report" colour changed.
    readonly property color sysColor: diskColor
    readonly property color sysIcon: fgDim

    readonly property color sysTitle: fg
    readonly property color sysBody: fgDim
    readonly property color sysMeta: fgMuted
    readonly property color sysTrack: surfaceHover
    readonly property color sysCard: surfaceRaised

    // Ending a process is the one destructive control on the bar, so it is the
    // only thing in the popup allowed to wear the critical red.
    readonly property color sysKill: error

    // Where a temperature stops being a reading and starts being a warning.
    // Same two-step shape as usage() -- warn first, then red -- but on a
    // scale that only makes sense per sensor, so the thresholds come from the
    // caller and live next to the sensor that needs them.
    function heat(celsius, warmAt, hotAt, base) {
        return celsius >= hotAt ? error : celsius >= warmAt ? warn : base;
    }

    // ── popups ───────────────────────────────────────────────
    // Every card the bar hangs under a pill shares one surface and one outline:
    // they are the same object seen from different icons. Every popup built on
    // BarPopup (Audio, Calendar, Claude, Disk, Dzuma, Media, Network,
    // Notification, Settings, Sys) reads popupBg and popupBorder for that one
    // shared shell, so this is the only place glass needs to be turned on.
    // The wash behind a modal overlay. Derived from `surface` rather than a
    // fixed near-black so a light scheme dims towards its own background
    // instead of towards something that is not in the palette at all.
    readonly property color scrim: Qt.rgba(surface.r, surface.g, surface.b, 0.8)

    // The same alpha the bar islands are drawn at, out of the same token: a
    // card opens flush against the island above it, and the two only read as
    // one material if there is no step in tone at the join. See
    // Caelus.opacitySurface.
    readonly property color popupBg: Qt.rgba(surface.r, surface.g, surface.b, Caelus.opacitySurface)
    // Exactly the formula barIslandBorder uses over barIsland, and now over the
    // same alpha as well, so the two outlines match at the join too.
    //
    // notifPanelBg and claudePanelBg were also candidates for this alpha, but
    // both turned out to be something else on inspection: not a second outer
    // shell, but a nested tone used for small elements *inside* an already-
    // glass panel (a resting action button in a notification card, a chip or
    // a subagent row in the Claude detail view) that want to sit back at the
    // panel's own level rather than raise like a card. Giving either of them
    // a second layer of alpha on top of popupBg's would double-transparent
    // exactly the content this pass is trying to keep legible, so both stay
    // solid `surface`. notifCardBg and claudeCardBg are the actual "card
    // inside a popup" case -- the notification row and the Claude session row
    // themselves -- and both are already `surfaceRaised`, solid, for the same
    // reason. The one place this is not yet true: standalone toast
    // notifications (NotificationPopups.qml) draw NotificationCard directly
    // with no BarPopup shell around it, so a toast's only surface is
    // notifCardBg -- solid by design for the nested case, but never glass for
    // that one. Left for GLASS to decide; noted in the request below.
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

    // The volume track behind each player's slider. Same grey every track on
    // this bar uses, so a slider reads as one of the disk and monitor bars that
    // happens to be draggable.
    readonly property color mediaTrack: surfaceHover

    // ── audio popup ──────────────────────────────────────────
    // The volume and mic pills keep their own green and red so a glance along
    // the bar still tells muted from live, but the cards they open speak in
    // the main accent like every other popup -- once it's open it's the bar
    // talking, not the pill.
    readonly property color audioTitle: fg
    readonly property color audioBody: fgDim
    readonly property color audioMeta: fgMuted
    readonly property color audioCard: surfaceRaised
    readonly property color audioTrack: surfaceHover
    // Every meter in this shell names its own track role even where two of
    // them resolve to the same colour, so a later change to one does not
    // silently move the others.
    readonly property color brightnessTrack: surfaceHover
    readonly property color audioActive: popupAccent   // the device currently in use

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
    // Black only in the static theme, where the accent disc is always dark
    // enough for it (§7.2 light mode). matugen's dark scheme puts a light
    // tone on `accent`, so black text reads there -- but its light scheme
    // puts a darker, more saturated tone on it instead, where black text
    // loses most of its contrast. on_primary is M3's own answer to exactly
    // this inversion, read straight through Wal.onPrimary rather than
    // re-derived here.
    readonly property color calTodayFg: root.dynamic ? Wal.onPrimary : bg
    readonly property color calOutside: surfaceHover

    // Reminders share the card with the grid, so they wear the calendar's own
    // text colours; only the alarm glyph and the input outlines are new. The
    // brighter accent, not the disc's, so a pending alarm is not read as a
    // second "today" further down the same card.
    readonly property color calAlarm: accentBright
    readonly property color calField: surfaceRaised
    readonly property color calFieldBorder: surfaceHover

    // ── disk widget ──────────────────────────────────────────
    // diskColor stays green: DiskPopup's own per-filesystem bars still read it
    // directly as their usage() base, and that is the popup's detail view, not
    // the resting bar. diskIcon is the bar pill, which is resting chrome: it
    // goes to fgDim, and Bar.qml already wraps it in usage(Disk.percent, …), so
    // a disk under three quarters full now reads as neutral and only escalates
    // to accent and then error as it actually fills -- exactly the "colour
    // means something is happening" rule the rest of this pass is enforcing.
    // Was templateColor5, the palette's green. Wal.reshade() preserves hue and
    // only pulls saturation toward the wallpaper, so that green stayed green on
    // a blue wallpaper -- the disk and system popups were the one place the
    // shell visibly disagreed with the theme. They are popups like any other
    // and now read the shared popup accent, so their tabs, meters and bars move
    // with everything else. The green literal survives as the static fallback.
    readonly property color diskColor: root.dynamic ? popupAccent : "#7ec97e"
    readonly property color diskIcon: fgDim

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
    // The middle band was `accent`, which worked only while `base` was a green
    // that accent could be told apart from. Now that the system and disk bases
    // are the accent themselves, the warning step has to be its own colour or
    // three-quarters-full looks exactly like empty.
    function usage(percent, base) {
        return percent >= 90 ? error : percent >= 75 ? warn : base;
    }

    // ── network popup ────────────────────────────────────────
    // The pill keeps its deep orange out on the bar and the card heads in the
    // shared popup accent like every other one; what is new here is that the
    // card draws two series at once, and down has to be told from up before
    // either label has been read. So they are split warm against cool: download
    // takes the bright accent, since it is the number that actually moves and it
    // keeps the card in the pill's own family, and upload the coolest token in
    // the palette, which no other popup spends on a series.
    readonly property color networkTitle: fg
    readonly property color networkBody: fgDim
    readonly property color networkMeta: fgMuted
    readonly property color networkTrack: surfaceHover
    readonly property color networkDown: accentBright
    readonly property color networkUp: templateColor8

    // The workspace row. `dotActive` always followed the wallpaper because it
    // is `accent`, but these two were plain literals with no dynamic branch --
    // so the moment the dots became category glyphs, the one part of the bar
    // that shows most of its pixels was also the one part that never rethemed.
    // Occupied takes `fgDim` for the same reason every other resting glyph on
    // the bar does; empty takes the outline role, which is what a placeholder
    // is: present, addressable, and saying nothing. Wal exposes no outline
    // role, so empty borrows `surfaceHover` -- the same tone every border in
    // the shell is drawn in.
    readonly property color dotActive: accent
    readonly property color dotOccupied: root.dynamic ? fgDim : "#8a6a58"
    readonly property color dotEmpty: root.dynamic ? Wal.surfaceHover : "#3a3a3a"

    // ── spare theme colors for future widgets ────────────────
    // Rename these as they get used; numbering is stable so they can be
    // reassigned without touching anything already wired up. The chart series
    // that read from here are told apart by hue, so they reshade rather than
    // take palette roles -- twelve slots and a palette has nowhere near
    // twelve distinct roles to give them.
    readonly property color templateColor1: root.dynamic ? Wal.reshade("#f8ccab") : "#f8ccab"  // --accent-1  light orange
    readonly property color templateColor2: root.dynamic ? Wal.reshade("#e87d2c") : "#e87d2c"  // --accent-4  deep orange (= claudeColor)
    readonly property color templateColor3: root.dynamic ? Wal.reshade("#f16e65") : "#f16e65"  // --red-2     red
    readonly property color templateColor4: root.dynamic ? Wal.reshade("#f7b0ab") : "#f7b0ab"  // --red-1     light red
    readonly property color templateColor5: root.dynamic ? Wal.reshade("#7ec97e") : "#7ec97e"  // --green-2   green
    readonly property color templateColor6: root.dynamic ? Wal.reshade("#93c893") : "#93c893"  // --green-1   light green
    readonly property color templateColor7: root.dynamic ? Wal.reshade("#6c756f") : "#6c756f"  // --blue-2    muted teal
    readonly property color templateColor8: root.dynamic ? Wal.reshade("#98a49d") : "#98a49d"  // --blue-1    light teal
    readonly property color templateColor9: root.dynamic ? Wal.reshade("#c4a898") : "#c4a898"  // --purple-2  warm taupe
    readonly property color templateColor10: root.dynamic ? Wal.reshade("#dbcec7") : "#dbcec7"  // --purple-1  light taupe
    readonly property color templateColor11: root.dynamic ? Wal.reshade("#e9dfd8") : "#e9dfd8"  // --text-2    heading
    readonly property color templateColor12: root.dynamic ? Wal.reshade("#988881") : "#988881"  // --text-4    icon grey
}
