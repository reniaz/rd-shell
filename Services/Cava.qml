pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.Config

// A live spectrum of Spotify's audio, and nothing else -- read from cava's
// own 'raw' output mode -- twelve numbers a frame, streamed on a pipe.
//
// This used to feed cava the mix of every playback stream but wayvibes; the
// user wants every visualizer -- bar strip, ring, desktop card -- to track
// Spotify alone, Firefox and anything else muted for cava's purposes even
// while they play at the same time as Spotify. So the isolation lives in the
// feed itself now, not a downstream gate: only Spotify's own stream(s) are
// ever linked into cava's capture node, and anything else that reaches it is
// unlinked again -- see `_spotifyStreams` / `_unfed` / `_stale` below.
//
// cava has to be told all of this through a config file; there is no flag for
// bar count or output format. That file is written here, at
// ~/.cache/rd-shell/cava.conf, rather than shipped as a dotfile under
// ~/.config/cava: Services/Wallpapers.qml already treats ~/.cache/rd-shell as
// this shell's own cache directory, and a config this file writes itself on
// every start is one a stale hand-edit -- the wrong bar count, a changed
// delimiter -- can never survive to break the parser below.
//
// Nothing here runs unless Spotify itself is actually playing. Raw mode is a
// continuous stream -- thirty frames a second below -- and a process left
// running with nothing to visualise is exactly the kind of thing that keeps a
// high-refresh compositor awake for no reason, so the Process is started and
// stopped off Media.spotify's own isPlaying directly, rather than off a timer,
// a visibility flag, or -- now -- whether anything else is playing.
//
// Every detail of the config below was checked against the cava actually
// installed on this machine (0.10.2, `rpm -q cava`), not just the example
// file it ships:
//   - this build links libpulse and libasound but not libpipewire
//     (`ldd /usr/bin/cava`), so `method = pipewire` fails outright
//     ("cava was built without 'pipewire' input support"). `method = pulse`
//     is what works here: PipeWire's own pulse-compatible server answers it
//     the same way a pulseaudio-only machine would.
//   - cava is not pointed at the default sink's monitor. That monitor is
//     the sink's finished mix, every other app's audio included, and no one
//     stream can be taken back out of it. `proc` instead starts cava's
//     capture stream with node.autoconnect=false, through PULSE_PROP --
//     pipewire-pulse copies the client's proplist onto its streams, checked
//     with `pw-cli ls Node` -- so WirePlumber does not link cava's *own*
//     stream anywhere on its own. It still links other apps' streams into
//     cava's input port the moment both exist, same as any other input --
//     autoconnect=false only opts cava's own stream out, not its ports out
//     of being a valid target -- which is why `_stale` below exists as well
//     as `_unfed`: `_unfed` links Spotify's own playback stream(s) into cava
//     by hand, matched the same loose way `Media.streamFor` matches a player
//     to its stream; `_stale` unlinks anything else WirePlumber or a leftover
//     link from before this cutover has fed in instead. PipeWire sums every
//     link into an input port, so several Spotify streams, if it ever opens
//     more than one, still read as one mix.
//   - raw_target = /dev/stdout needs no fifo of its own: cava only creates a
//     fifo when its target does not already exist, and /dev/stdout always
//     does, so the frames arrive on the same pipe Process already reads
//     everything else through.
//   - a captured run (`cava -p <this config>` piped to a file, killed after
//     three seconds) confirmed the exact frame shape used by `_parse` below:
//     `bars` ascii integers 0-100, EACH followed by ';' -- including the
//     last one -- then '\n'. Splitting a well-formed line on ';' therefore
//     yields bars+1 parts, the last one empty; that is the shape `_parse`
//     checks for, not the count the example config's comment implies.
//   - SIGTERM (what setting `running` to false sends) was confirmed to stop
//     the process cleanly with no leftover state.
Singleton {
    id: root

    readonly property int bars: 12

    // cava's own emitted rate. Named rather than left as the literal in
    // `_config` below because `level`'s envelope follower (further down)
    // needs the same number to convert Motion's millisecond durations into a
    // frame count -- one property keeps a future retune of either in sync
    // instead of letting them quietly drift apart.
    readonly property int framerate: 30

    // The contract this is written against treats "cava binary present" and
    // "process alive" as one flag, and here they really are the same fact:
    // the Process below is only ever asked to run while Spotify itself is
    // playing, and a missing binary means QProcess fails to start -- which
    // Quickshell folds back into `running` going false rather than firing
    // `exited`. Reading the process's own running state already answers
    // both halves without a separate "is cava on $PATH" check.
    // Latched on the first successful spawn rather than mirroring `running`.
    // `running` follows playback, so reading it here would make "cava is
    // installed" flip on every play and pause -- and MediaPopup reserves the
    // album-art cell off this, so the row would resize under the reader every
    // time the track was paused. A binary that has started once is installed
    // for the rest of the session; whether it is streaming right now is what
    // `active` is for.
    readonly property bool available: root._everRan

    property bool _everRan: false

    readonly property bool active: proc.running && (Media.spotify?.isPlaying ?? false)

    // Spotify's own playback stream(s) -- matched the same loose way
    // `Media.streamFor` matches a player to its stream, and through the same
    // function: `Media.namesFor`'s slugs against a stream's node.name /
    // application.name / application.process.binary, each side reduced to
    // letters and digits before either `includes` the other. Calling into
    // Media's own matcher rather than a second copy of it means a retune
    // there -- Spotify starting to answer to a new name -- reaches here too.
    // `.filter`, not `.find`: nothing here assumes Spotify opens exactly one
    // stream, so every stream that matches belongs in the mix cava reads.
    readonly property var _spotifyStreams: {
        const spotify = Media.spotify;
        if (!spotify) return [];
        const wanted = Media.namesFor(spotify);
        return Audio.sinkStreams.filter(s => [
            s.name,
            s.properties["application.name"],
            s.properties["application.process.binary"]
        ].map(Media.slug).some(k => k.length >= 3 && wanted.some(n => k.includes(n) || n.includes(k))));
    }

    // Every cava capture stream this shell feeds: its own, under the
    // node.name `proc` gives it, and any other started the same way under a
    // name with the same prefix (a terminal cava started with
    // PULSE_PROP node.name=rd-cava-<anything>), so its spectrum is the same
    // Spotify-only mix as the bar's. Empty whenever none is running.
    readonly property var _nodes: Pipewire.nodes.values.filter(n => (n.name ?? "").startsWith("rd-cava"))

    // Every [Spotify stream, cava] pair still to be linked: Spotify streams
    // routed to some sink but not yet into that cava. Keyed off link groups
    // rather than the node list alone: a stream's ports arrive after its
    // node does and pw-link fails on a node with no ports yet, while a
    // stream WirePlumber has already linked somewhere certainly has them.
    readonly property var _unfed: {
        const groups = Pipewire.linkGroups.values;
        const streams = root._spotifyStreams.filter(s => groups.some(g => g.source === s));
        const pairs = [];
        for (const cava of root._nodes)
            for (const s of streams)
                if (!groups.some(g => g.source === s && g.target === cava))
                    pairs.push([s, cava]);
        return pairs;
    }

    // Every [stream, cava] link that should not exist: something feeding a
    // cava capture node that is not one of `_spotifyStreams` right now --
    // Firefox, a stream left linked from before this file went Spotify-only,
    // or one WirePlumber made on its own the moment cava's port and some
    // other playback stream both existed (see the header comment: cava's
    // ports are ordinary targets, node.autoconnect=false only ever kept
    // WirePlumber from routing cava's *own* stream anywhere). Anything found
    // here gets pulled back out below instead of left to widen the mix cava
    // reads.
    readonly property var _stale: {
        const groups = Pipewire.linkGroups.values;
        const wanted = root._spotifyStreams;
        const pairs = [];
        for (const g of groups)
            if (root._nodes.includes(g.target) && !wanted.includes(g.source))
                pairs.push([g.source, g.target]);
        return pairs;
    }

    // pw-link's links outlive pw-link itself, so a detached one-shot per
    // pair is all either of these takes. A repeat connect for a link already
    // made -- `_unfed` re-evaluating before the first one lands -- only
    // fails "File exists"; a repeat disconnect for a link `_stale` already
    // cleared only fails "No such link", equally harmless.
    on_UnfedChanged: {
        for (const [s, cava] of root._unfed)
            Quickshell.execDetached(["pw-link", String(s.id), String(cava.id)]);
    }

    on_StaleChanged: {
        for (const [s, cava] of root._stale)
            Quickshell.execDetached(["pw-link", "-d", String(s.id), String(cava.id)]);
    }

    property var levels: root._zeros()

    function _zeros() {
        const z = new Array(root.bars);
        z.fill(0);
        return z;
    }

    // Frame-to-frame envelope coefficients for `level` below, solved from
    // the standard first-order EMA settle formula -- (1 - a)^frames = 0.05,
    // "reach 95% of a step within this many frames at cava's own rate" --
    // rather than picked by feel, so retiming either half is a one-token
    // change instead of a re-derivation. Attack borrows Motion.fast (a
    // hover, a colour swap: the shell's fastest "notice this now") because a
    // beat should register as a hit, not a fade-in; decay borrows
    // Motion.slow (a toast sliding in, a card leaving) so the reading coasts
    // back down between hits instead of chattering with every frame that
    // dips near zero, which is what a plain running average would do.
    readonly property real _levelAttack: 1 - Math.pow(0.05, 1 / (root.framerate * Motion.fast / 1000))
    readonly property real _levelDecay: 1 - Math.pow(0.05, 1 / (root.framerate * Motion.slow / 1000))

    property real _level: 0

    // The contract interface (S5.md, "Cava level"): 0..1, the smoothed mean
    // of whatever frame is current, so a consumer can read "how loud is it
    // right now" without knowing the bar count or touching `levels` at all.
    // Backed by a plain property rather than a binding on `levels` so
    // `_parse` can drive the envelope follower imperatively, frame by frame
    // -- the same shape `levels` itself already uses.
    readonly property real level: root._level

    readonly property string _configPath: `${Quickshell.env("HOME")}/.cache/rd-shell/cava.conf`

    property bool _configReady: false

    readonly property string _config:
        "[general]\n" +
        "bars = " + root.bars + "\n" +
        // Halves the wake-ups the start/stop logic below exists to bound in
        // the first place, for the time it genuinely is streaming: a
        // twelve-bar mini meter loses nothing visible between 60fps and 30.
        "framerate = " + root.framerate + "\n" +
        // Belt and braces next to that same logic: two seconds of true
        // silence -- a gap between tracks, not a pause -- and cava stops
        // running FFT and redraw on its own until sound returns.
        "sleep_timer = 2\n" +
        "\n" +
        "[input]\n" +
        "method = pulse\n" +
        "\n" +
        "[output]\n" +
        "method = raw\n" +
        "raw_target = /dev/stdout\n" +
        // One spectrum, low to high, left to right -- the flat `levels`
        // array this file promises. 'stereo' mirrors two spectrums into the
        // same bar count instead, which would leave every reader needing to
        // know which half of the array is which channel.
        "channels = mono\n" +
        "data_format = ascii\n" +
        "ascii_max_range = 100\n" +
        "bar_delimiter = 59\n" +
        "frame_delimiter = 10\n";

    Component.onCompleted: configFile.setText(root._config)

    FileView {
        id: configFile
        path: root._configPath
        // This view only ever writes -- `setText` below, never `text()` or
        // `data()` -- so the read preload triggers by default on every
        // `path` assignment is pure overhead here, and on a cold start, with
        // nothing at `_configPath` yet, it is also what logged "File does
        // not exist" on every single launch, before the write a few lines
        // down had a chance to run.
        preload: false
        onSaved: {
            root._configReady = true;
            root._sync();
        }
        // Left false on failure. An unwritten config means cava has nothing
        // valid to read even where the binary exists, and `available`
        // staying false already reads to every caller exactly like cava
        // being absent -- there is nothing more useful to do with the error.
        onSaveFailed: error => root._configReady = false
    }

    // Re-evaluated at every point any input to "should this be running"
    // changes, and nowhere else -- deliberately not a binding on
    // `proc.running` itself. A failed spawn (cava missing) makes Quickshell
    // write `running` back to false from the C++ side, and a property write
    // from any source clears a QML binding on it; a binding here would
    // therefore survive exactly one missing-binary attempt before going
    // inert, and never restart cava again even after it gets installed.
    // Re-running this function imperatively on each real change has no such
    // trap: every call just states the desired value fresh.
    function _sync() {
        proc.running = (Media.spotify?.isPlaying ?? false) && root._configReady;
    }

    Connections {
        target: Media
        // Spotify quitting outright -- rather than pausing on its way out --
        // is `spotify` turning null, not `isPlaying` passing through false;
        // the Connections below this one is what catches an isPlaying flip
        // on whatever player `spotify` currently is.
        function onSpotifyChanged() { root._sync(); }
    }

    // `target` re-binds to whichever MprisPlayer `Media.spotify` is right
    // now, Connections disconnecting and reconnecting on its own each time --
    // so this keeps following the right player's own isPlaying across
    // Spotify quitting and relaunching, and never picks up any other
    // player's play/pause the way reading `Media.playing` would.
    Connections {
        target: Media.spotify
        function onIsPlayingChanged() { root._sync(); }
    }

    // Cleared rather than left at its last frame: CavaBars is already
    // collapsing to nothing at the same moment (both read `active`), but a
    // stale non-zero frame sitting in `levels` would be what a reader saw if
    // it un-collapsed again before the next real frame arrived.
    onActiveChanged: if (!root.active) {
        root.levels = root._zeros();
        // Not left for the envelope follower to coast down on its own:
        // nothing drives `_parse` forward once the process behind it stops,
        // so without this `level` would freeze at whatever it last settled
        // on instead of reading "nothing playing" like every other exposed
        // value here does.
        root._level = 0;
    }

    Process {
        id: proc
        command: ["cava", "-p", root._configPath]
        // Named for `_nodes` to find, and left unlinked for `_unfed` to feed
        // and `_stale` to keep clean of anything else -- see the header
        // comment.
        environment: ({ PULSE_PROP: "node.name=rd-cava node.autoconnect=false" })

        // The one place `available` can be raised. A spawn that fails --
        // cava not installed -- never gets here, because Quickshell folds a
        // failed start back into `running` going false without it ever
        // having been true.
        onRunningChanged: if (proc.running) root._everRan = true;
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._parse(data)
        }
    }

    function _parse(line) {
        const parts = line.split(";");
        // A well-formed frame is `bars` numbers each followed by ';',
        // including the last -- see the header comment -- so it splits into
        // bars+1 parts. Anything shorter is a frame the pipe handed over
        // half-written and is worth dropping rather than drawing: taken at
        // face value it would read as a flicker to zero, which is exactly
        // what the smoothing in CavaBars exists to prevent.
        if (parts.length <= root.bars) return;

        const next = new Array(root.bars);
        let sum = 0;
        for (let i = 0; i < root.bars; i++) {
            const v = parseInt(parts[i], 10);
            const value = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
            next[i] = value;
            sum += value;
        }
        root.levels = next;

        // Envelope-follow the frame mean rather than assign it straight:
        // cava emits ~30 of these a second, and handing that mean straight
        // to `level` would repeat every bin-to-bin flicker as a jump at the
        // same rate -- exactly the noise this property exists to hide.
        const mean = sum / root.bars;
        const rate = mean > root._level ? root._levelAttack : root._levelDecay;
        root._level += (mean - root._level) * rate;
    }
}
