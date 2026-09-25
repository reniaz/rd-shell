import QtQuick
import qs.Services

// Audio exposes PipeWire's live state (Services/Audio.qml), not an event
// of its own the way KeyboardLayout.qml raises osdVisible -- and
// Audio.qml is not this fan-out's file to add one to. The pulse has to
// live somewhere that outlives the volume OSD's own window, which
// PopupLoader tears down between pulses, so it lives in its own file
// rather than folded into BarOverlays.qml, the loader it drives -- the
// same way diskPill.open and volumePill.open carry their own popups'
// open state on BarRight.qml rather than on a service.
QtObject {
    id: root

    property bool pulse: false

    // Which of the two levels this pulse is about. One window shows both,
    // so muting the microphone while the volume card is still up replaces
    // it rather than landing a second card on top of it.
    property string mode: "sink"

    // PipeWire's first report of a node on startup is not a change to
    // announce -- the same trap KeyboardLayout.qml guards against on its
    // first devices query, reproduced here since Audio.qml has no guard
    // of its own to reuse.
    //
    // Armed after the event loop settles rather than by swallowing one
    // signal per node. Two separate signals arrive for the same node --
    // percent and muted -- and a machine that boots muted at a non-zero
    // level fires both at once; a one-shot flag eats the first and lets
    // the second through as a spurious card at login. Nothing that lands
    // in the startup window gets through this.
    property bool _armed: false

    Component.onCompleted: Qt.callLater(() => root._armed = true)

    function _trigger(which) {
        if (!root._armed)
            return;

        root.mode = which;
        root.pulse = true;
        root.hold.restart();
    }

    property Connections _watch: Connections {
        target: Audio
        function onPercentChanged() { root._trigger("sink"); }
        function onMutedChanged() { root._trigger("sink"); }
        function onMicPercentChanged() { root._trigger("source"); }
        function onMicMutedChanged() { root._trigger("source"); }
    }

    property Timer hold: Timer {
        interval: 1200
        onTriggered: root.pulse = false
    }
}
