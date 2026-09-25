import QtQuick
import qs.Services

// The contrast half of the edge panel has no service flag to hang an OSD on.
// Services/Ddc.qml is the hardware layer -- it knows a monitor's contrast
// moved and says so through `changed`, but "put a card on screen for a second
// and a half" is not a thing an i2c cache should have an opinion about, the
// same line BarOsdWatch.qml draws around Services/Audio.qml.
//
// One of these per bar, holding its own screen's pulse: contrast is a
// per-monitor property, so the card belongs on the monitor whose contrast
// changed and nowhere else. That is also why this needs no overlayScreen
// gate at the loader -- the screen name is the gate.
QtObject {
    id: root

    required property string screenName

    property bool pulse: false
    // Snapshotted at the pulse rather than read live off Ddc: the card
    // outlives the change by more than a second, and the next drag of the
    // same slider must replace what it says, not rewrite the card that is
    // already on its way out.
    property int percent: 0

    // Ddc's first report for a screen is its priming read -- the value the
    // monitor already had when the shell started, not something anyone just
    // did. Announcing that would put a contrast card on screen at login.
    property int _last: -1

    property Connections _watch: Connections {
        target: Ddc

        function onChanged(screenName) {
            if (screenName !== root.screenName)
                return;

            const v = Ddc.contrast(screenName);
            if (v < 0)
                return;

            const moved = v !== root._last;
            const primed = root._last >= 0;
            root._last = v;

            if (!primed || !moved)
                return;

            root.percent = v;
            root.pulse = true;
            root.hold.restart();
        }
    }

    property Timer hold: Timer {
        interval: 1200
        onTriggered: root.pulse = false
    }
}
