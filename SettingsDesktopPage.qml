import QtQuick
import qs.Config
import qs.Services

// Settings-app page (see the scratchpad contract this round builds
// against): the two presentation-layer toggles that live on the desktop
// itself rather than on the bar -- DesktopWidgets.qml's own window, and the
// clipboard feedback ClipboardRipple.qml draws over everything. Both are
// plain Settings.* aliases with no validation step of their own (unlike
// BarStyles' id lists on SettingsBarPage.qml), so this page writes them
// directly, same as SettingsPopup.qml's own rows for the same two settings.
//
// Services/Settings.qml's own comments are the source for what each toggle
// actually shows -- "giant clock + now-playing card" for desktopWidgets
// (DesktopWidgets.qml's header adds sticky notes to that list), and "the
// clipboard-paste ripple" for clipboardRipple -- wording SettingsPopup.qml
// itself never spelled out because its rows there carry no caption at all.
SettingsPage {
    title: "Desktop"
    subtitle: "What floats over the wallpaper, and the feedback it gives you."

    SettingsCard {
        SettingsToggleRow {
            icon: "widgets"
            label: "Desktop widgets"
            caption: "The giant clock, now-playing card and sticky notes seen between windows"
            checked: Settings.desktopWidgets
            onToggled: Settings.desktopWidgets = !Settings.desktopWidgets
        }

        SettingsToggleRow {
            icon: "ink_highlighter"
            label: "Clipboard ripple"
            caption: "A faint accent ring at the cursor whenever you copy or paste text"
            checked: Settings.clipboardRipple
            onToggled: Settings.clipboardRipple = !Settings.clipboardRipple
        }
    }
}
