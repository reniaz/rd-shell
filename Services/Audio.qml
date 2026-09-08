pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(volume * 100)
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micReady: source?.ready ?? false

    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property int micPercent: Math.round(micVolume * 100)
    readonly property bool micMuted: source?.audio?.muted ?? false

    PwObjectTracker { objects: [root.sink, root.source] }

    // pavucontrol tabs: 3 = Output Devices, 4 = Input Devices
    function openSettings(tab) {
        Quickshell.execDetached(["pavucontrol", "-t", String(tab)]);
    }

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }
}
