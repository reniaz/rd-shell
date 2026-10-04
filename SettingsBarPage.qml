import QtQuick
import qs.Config
import qs.Services

// Settings-app page (see the scratchpad contract this round builds
// against): everything that changes the bar's own shape rather than the
// theme it is painted in -- that half lives on SettingsLookPage.qml instead.
//
// Three services back this page and the page writes none of them directly
// except Settings.bluetoothPill: BarStyles.apply()/applyWorkspaceSkin()
// already validate the id against their own `styles`/`workspaceSkins` list
// before writing Settings.barStyle/workspaceSkin, the same guard
// BarStyleSwitcher.qml leans on, so a stray id from a future model change
// here can never reach settings.json unvalidated. `BarStyles.apply()` also
// unconditionally closes `panelOpen` as a side effect (it is shared with the
// Ctrl+Alt+B switcher) -- harmless here since this page's own choice row is
// never open at the same time as that overlay, but worth knowing before
// reusing `apply` anywhere else.
//
// Round 4 additions (Clock/Pills/Look cards below) write Settings.* straight,
// the same way bluetoothPill's row always has -- none of them need a
// service's own id-validation first, since each one is either a plain bool
// or a slider that Config/Caelus.qml itself clamps on the way back out (so a
// hand-edited settings.json can't push a token out of range either).
SettingsPage {
    title: "Bar"
    subtitle: "The bar's shape, its clock, workspace dots, pills, and how it looks."

    SettingsCard {
        title: "Bar style"

        SettingsChoiceRow {
            icon: "toolbar"
            label: "Shape"
            model: BarStyles.styles
            current: BarStyles.current
            onChosen: id => BarStyles.apply(id)
        }

        SettingsButtonRow {
            icon: "view_carousel"
            label: "Animated switcher"
            caption: "Cycle through every bar style on a floating coverflow (Ctrl+Alt+B)"
            buttonText: "Open"
            buttonIcon: "open_in_new"
            onClicked: BarStyles.togglePanel()
        }
    }

    SettingsCard {
        title: "Workspace dots"

        SettingsChoiceRow {
            icon: "workspaces"
            label: "Skin"
            model: BarStyles.workspaceSkins
            current: BarStyles.workspaceSkin
            onChosen: id => BarStyles.applyWorkspaceSkin(id)
        }

        SettingsToggleRow {
            icon: "bolt"
            label: "Beat glow"
            caption: "The active workspace dot picks up a faint accent edge on the beat while something is playing"
            checked: Settings.workspaceBeatGlow
            onToggled: Settings.workspaceBeatGlow = !Settings.workspaceBeatGlow
        }
    }

    SettingsCard {
        title: "Clock"

        SettingsChoiceRow {
            icon: "schedule"
            label: "Format"
            // Global, not just this bar's pill -- see Services/Time.qml's
            // own comment on why the desktop clock and lock screen read the
            // same setting.
            model: [
                { id: "24h", name: "24h", description: "13:05" },
                { id: "12h", name: "12h", description: "1:05 PM" }
            ]
            current: Settings.clockFormat
            onChosen: id => Settings.clockFormat = id
        }

        SettingsToggleRow {
            icon: "timer"
            label: "Show seconds"
            caption: "Everywhere the clock reads -- bar, desktop, lock screen. The clock's own tick drops to once a second only while this is on"
            checked: Settings.clockSeconds
            onToggled: Settings.clockSeconds = !Settings.clockSeconds
        }
    }

    SettingsCard {
        title: "Pills"

        SettingsToggleRow {
            icon: "bluetooth"
            label: "Bluetooth pill"
            caption: "Shows the bar's Bluetooth icon (it still hides itself on a machine with no adapter)"
            checked: Settings.bluetoothPill
            onToggled: Settings.bluetoothPill = !Settings.bluetoothPill
        }

        SettingsToggleRow {
            icon: "apps"
            label: "Tray pill"
            caption: "Shows the systray icons (it still hides itself whenever nothing survives the tray's own filter)"
            checked: Settings.trayPill
            onToggled: Settings.trayPill = !Settings.trayPill
        }

        SettingsToggleRow {
            icon: "graphic_eq"
            label: "Cava EQ pill"
            caption: "The little audio-reactive bars beside the media pill"
            checked: Settings.cavaPill
            onToggled: Settings.cavaPill = !Settings.cavaPill
        }

        SettingsToggleRow {
            icon: "monitoring"
            label: "System stats pill"
            caption: "CPU/GPU/RAM readout (it still hides itself on a machine SysMon can't read)"
            checked: Settings.systemPill
            onToggled: Settings.systemPill = !Settings.systemPill
        }

        SettingsToggleRow {
            icon: "wifi"
            label: "Network pill"
            caption: "Online/offline status, and the throughput card it opens"
            checked: Settings.networkPill
            onToggled: Settings.networkPill = !Settings.networkPill
        }
    }

    SettingsCard {
        title: "Look"

        SettingsSliderRow {
            icon: "straighten"
            label: "Edge margin"
            caption: "The gap between the outer islands and the screen's left/right edges"
            valueText: Math.round(Settings.barMargin) + "px"
            value: Settings.barMargin
            from: 0
            to: 24
            stepSize: 1
            onMoved: v => Settings.barMargin = v
        }

        SettingsSliderRow {
            icon: "opacity"
            label: "Surface opacity"
            caption: "Translucency of every island and popup body -- kept well clear of the 0.2 hyprland uses to decide whether a surface still gets blurred"
            valueText: Math.round(Settings.barOpacity * 100) + "%"
            value: Settings.barOpacity
            from: 0.30
            to: 0.70
            stepSize: 0.01
            onMoved: v => Settings.barOpacity = v
        }

        SettingsToggleRow {
            icon: "touch_app"
            label: "Pill click ripple"
            caption: "A circle of ink spreading from wherever you pressed. Off falls back to the flat press wash every pill had before"
            checked: Settings.pillRipple
            onToggled: Settings.pillRipple = !Settings.pillRipple
        }
    }
}
