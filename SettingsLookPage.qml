import QtQuick
import qs.Config
import qs.Services

// The settings app's Appearance page (SettingsApp.pages' "look" entry) --
// the one place in the app that is actually about the wallpaper and the
// colours it drives, rather than a toggle for some other piece of the
// shell. Three cards, top to bottom: what is on screen right now and the
// palette it produced (SettingsLookHero.qml), a way to browse and change it
// (SettingsLookGrid.qml, plus the button down to the full-screen switcher),
// and the three colour toggles SettingsPopup.qml already carries -- lifted
// here verbatim, dependency and dimming semantics included, rather than
// reinvented, since a person who already learned what "Keep app colours"
// does from the bar pill should not have to relearn it here.
//
// Nothing on this page writes `Settings.*` through anything but a kit row's
// own signal, per the contract: SettingsToggleRow only ever emits `toggled()`
// and this page is the one that decides what that means.
SettingsPage {
    id: root

    title: "Appearance"
    subtitle: "The wallpaper on screen, the palette it drives, and how far that colour reaches."

    SettingsCard {
        title: "Wallpaper"

        SettingsLookHero {}
    }

    SettingsCard {
        title: "Browse"

        SettingsLookGrid {}

        SettingsButtonRow {
            icon: "auto_awesome_motion"
            label: "Full-screen switcher"
            caption: "The animated coverflow over the whole tree (Ctrl+Alt+F)"
            buttonText: "Open"
            buttonIcon: "open_in_full"

            onClicked: Wallpapers.togglePanel()
        }

        // How the next pick animates in. Random is the default; pinning one
        // is for anyone who finds a particular sweep distracting.
        SettingsChoiceRow {
            icon: "animation"
            label: "Transition"
            model: Wallpapers.transitions
            current: Wallpapers.transitionChoice
            onChosen: id => Wallpapers.applyTransition(id)
        }
    }

    SettingsCard {
        title: "Colour"

        // Whether the shell recolours itself from the wallpaper at all.
        // SettingsPopup.qml never carries this switch -- "colour simply
        // follows the wallpaper whenever dynamic colour is on" is that
        // file's own words for why -- so the caption here is new, but the
        // property and its effect are exactly `Caelus.dynamicColour`'s own
        // `Settings.dynamicColour` read.
        SettingsToggleRow {
            icon: "auto_awesome"
            label: "Dynamic colour"
            caption: Settings.dynamicColour
                ? "Recolouring the shell from your wallpaper"
                : "Fixed caelus theme -- the wallpaper is ignored"
            checked: Settings.dynamicColour

            onToggled: Settings.dynamicColour = !Settings.dynamicColour
        }

        // Only meaningful while dynamic colour is on -- same dependency
        // SettingsPopup.qml's own `wallpaperColoursRow` gates on -- so this
        // row dims and stops answering clicks when that is off, via the kit
        // row's own `enabled` dimming rather than a second opacity binding.
        SettingsToggleRow {
            icon: "colorize"
            label: "Wallpaper colours"
            caption: Settings.wallpaperColours
                ? "Colours taken straight from the wallpaper"
                : "Today's colours (default)"
            checked: Settings.wallpaperColours
            enabled: Settings.dynamicColour

            onToggled: Settings.wallpaperColours = !Settings.wallpaperColours
        }

        // One level further down: meaningless unless wallpaper colours is
        // both on and has actually resolved to monochrome, but (per
        // SettingsPopup.qml's own comment on `keepAppColoursRow`) that
        // second half can't be told apart from "colourful wallpaper, toggle
        // off" without re-running matugen just to check -- so this gates on
        // the same two dependencies that row does, one level down.
        SettingsToggleRow {
            icon: "terminal"
            label: "Keep app colours"
            caption: Settings.keepAppColours
                ? "nvim and bat keep syntax colours"
                : "nvim and bat follow the wallpaper too"
            checked: Settings.keepAppColours
            enabled: Settings.dynamicColour && Settings.wallpaperColours

            onToggled: Settings.keepAppColours = !Settings.keepAppColours
        }
    }

    SettingsCard {
        title: "OSD"

        // BrightnessOsd.qml/AudioOsd.qml read this straight off Settings --
        // see WavyArc.qml for what "wavy" actually draws (a Material 3
        // wavy linear progress indicator, not a ring: the OSD level meter
        // has always been a straight track).
        SettingsToggleRow {
            icon: "waves"
            label: "Wavy OSD progress"
            caption: Settings.osdWavy
                ? "Volume and brightness draw the M3 wavy progress line"
                : "Volume and brightness draw a plain filled bar"
            checked: Settings.osdWavy

            onToggled: Settings.osdWavy = !Settings.osdWavy
        }
    }
}
