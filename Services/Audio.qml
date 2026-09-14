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

    // Every node the audio popups can show or move: devices for the "Devices"
    // list, streams for "Apps". Split by isSink/isStream rather than filtered
    // once, since sinks/sources and their streams live in different sections.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var sinkStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)
    readonly property var sourceStreams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink)

    // One tracker for every node a popup might read or write, including the
    // current default sink/source themselves. Media used to bind its own
    // streams; that job moved here so there is a single owner of PipeWire.
    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks, root.sources, root.sinkStreams, root.sourceStreams) }

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

    // Changing the default only takes effect for the node PipeWire picks
    // next; it does not move what is already flowing through the old one.
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setNodeVolume(node, v) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function stepNodeVolume(node, delta) {
        if (node?.audio) setNodeVolume(node, node.audio.volume + delta);
    }

    function toggleNodeMute(node) {
        if (node?.audio) node.audio.muted = !node.audio.muted;
    }

    // Devices only ever carry a description/nickname some of the time, so
    // fall back down to the raw PipeWire name rather than show nothing.
    function nodeLabel(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

    // Streams rarely set a description worth showing; the owning app's own
    // name is what the user recognises.
    function appLabel(node) {
        return node?.properties?.["application.name"] || node?.description || node?.name || "";
    }
}
