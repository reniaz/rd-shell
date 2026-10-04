import QtQuick
import qs.Config
import qs.Services

// Settings-app page (see the scratchpad contract this round builds
// against): idea 9's accessibility pane, promoted from the three bare rows
// SettingsPopup.qml already carries under its own "Accessibility" label into
// a full page -- same three settings, same semantics, just the kit's richer
// row types and captions in place of that card's hand-rolled glyph-swap
// rows.
//
// `_setUiScale` mirrors SettingsPopup.qml's own `setUiScale(ratio)` exactly
// (0.85..1.5, step 0.05, both ends clamped) but takes the slider's already-
// snapped, already-clamped value instead of a raw 0..1 ratio -- that
// snap-and-clamp step is SettingsSliderRow's own job now (see its
// `applyRatio`), so this only has to guard against the control itself ever
// mis-stepping it, the same belt-and-braces clamp the popup's own assignment
// line carries.
SettingsPage {
    title: "Accessibility"
    subtitle: "Scale, contrast and focus visibility for the whole shell."

    function _setUiScale(value) {
        Settings.uiScale = Math.max(0.85, Math.min(1.5, value));
    }

    SettingsCard {
        SettingsSliderRow {
            icon: "text_increase"
            label: "UI scale"
            caption: "Scales every popup and settings page's text and spacing together"
            valueText: Settings.uiScale.toFixed(2) + "×"
            value: Settings.uiScale
            from: 0.85
            to: 1.5
            stepSize: 0.05
            onMoved: value => _setUiScale(value)
        }
    }

    SettingsCard {
        SettingsToggleRow {
            icon: "contrast"
            label: "High contrast"
            caption: "Darkens panels and brightens text and borders a step further apart"
            checked: Settings.highContrast
            onToggled: Settings.highContrast = !Settings.highContrast
        }

        SettingsToggleRow {
            icon: "center_focus_weak"
            label: "Visible focus ring"
            caption: "Draws an outline around whichever control Tab has landed on"
            checked: Settings.focusRing
            onToggled: Settings.focusRing = !Settings.focusRing
        }
    }

    // Idea hyprland-animation-preset-switcher: Hyprland's whole-desktop
    // motion, not just this shell's own. Living on this page rather than
    // Bar/Look -- it is Hyprland's window/workspace animation, not anything
    // the bar itself draws -- and a fitting neighbour for the two toggles
    // above: "Minimal" below is this page's actual reduced-motion option,
    // the same role High contrast and the focus ring play for contrast and
    // keyboard visibility. `caption` is set statically (rather than left to
    // fall back to each preset's own `description`, the way
    // SettingsBarPage.qml's bar-shape row does) specifically so that
    // cross-reference stays on screen no matter which preset happens to be
    // selected, not only while Minimal itself is.
    SettingsCard {
        title: "Animation"

        SettingsChoiceRow {
            icon: "animation"
            label: "Motion preset"
            caption: "How the whole desktop animates (Hyprland) -- Minimal is this page's reduced-motion option: fades only, no sliding or popping"
            model: AnimPresets.presets
            current: AnimPresets.current
            onChosen: id => AnimPresets.apply(id)
        }

        SettingsButtonRow {
            icon: "view_carousel"
            label: "Animated switcher"
            caption: "Cycle through every preset on a floating coverflow, each with a live preview (Ctrl+Alt+P)"
            buttonText: "Open"
            buttonIcon: "open_in_new"
            onClicked: AnimPresets.togglePanel()
        }
    }
}
