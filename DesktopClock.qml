import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Services

// The giant desktop clock -- caelestia-shell's own desktop widget, the thing
// actually seen on an empty workspace or through the gap between tiled
// windows, since the bar's own clock pill is a glance-sized readout for
// everywhere else. Pure display: no click target, nothing for
// DesktopWidgets.qml's mask to ever need to include.
ColumnLayout {
    id: root

    spacing: Caelus.spaceTight

    Text {
        id: clock

        Layout.alignment: Qt.AlignRight
        text: Time.time
        color: Colors.fg
        font.family: Caelus.fontFamily
        font.pixelSize: 128

        // A bright wallpaper (snow, a sunlit render) can wash a plain glyph
        // out completely -- there is no card behind this the way an OSD has
        // one to hold a fixed, opaque background. BarContrastWatch.qml turns
        // out to be Ddc's per-monitor hardware contrast pulse, nothing to do
        // with wallpaper luminance, so there is nothing there to reuse. This
        // is the same MultiEffect drop shadow OsdCard.qml already lifts its
        // card with -- cheap insurance that costs nothing on a dark image.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.6
            shadowOpacity: 0.5
            shadowVerticalOffset: 2
        }
    }

    Text {
        id: date

        Layout.alignment: Qt.AlignRight
        // Time.qml's own `date` role is the bar's compact "ddd d MMM" --
        // this widget has the room to spell the day and month out in full.
        text: Qt.formatDateTime(Time.now, "dddd, d MMMM")
        color: Colors.popupAccent
        font.family: Caelus.fontFamily
        font.pixelSize: 20

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.6
            shadowOpacity: 0.5
            shadowVerticalOffset: 1
        }
    }
}
