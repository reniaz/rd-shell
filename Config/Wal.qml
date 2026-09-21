pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the desktop looks like, for the one thing that has to match it: the bar.
//
// pywal is what turns a wallpaper into colours here, and `wal -i <image>` is
// what runs it; this only notices that it did. Two files come out of that run
// and both are read -- the palette, and the path of the picture it came from.
Singleton {
    id: root

    property var palette: null
    property string wallpaper: ""

    // The wallpaper's most common pixel, once the sampler has answered.
    property string sampled: ""

    readonly property bool known: root.sampled !== "" || root.palette !== null

    // pywal's own background, which is not the wallpaper's colour and does not
    // try to be. On anything near black it is manufactured: generic_adjust()
    // reads the first hex digit of each channel, and where all three are the
    // character "0" -- every colour darker than #101010 -- it decides the
    // colour is not saturated enough, lightens it 3% and saturates it 40%.
    // rd.png's #0d0f0e comes back #0c1d15, a green that is in no pixel of the
    // picture.
    readonly property color pywalBackground: root.palette !== null
        ? root.palette.special.background
        : "transparent"

    // So the wallpaper is asked directly and pywal is only the fallback -- with
    // the strength it invented capped, because a hue it made up has no business
    // being the loudest thing on the bar.
    readonly property color background: root.sampled !== ""
        ? root.sampled
        : Qt.hsva(root.pywalBackground.hsvHue,
                  Math.min(root.pywalBackground.hsvSaturation, 0.15),
                  root.pywalBackground.hsvValue,
                  root.pywalBackground.a)

    FileView {
        path: `${Quickshell.env("HOME")}/.cache/wal/colors.json`
        watchChanges: true
        // Replaced rather than edited: pywal writes the file out whole, so the
        // watch reports a change and the read has to be asked for again.
        onFileChanged: reload()
        onLoaded: {
            // pywal rewrites this file in place, so a read can land mid-write
            // and see truncated JSON. Caught rather than left to throw out of
            // this handler -- root.palette just keeps its last good value
            // until the next write lands whole. The `.special` check guards
            // `background` below against a parse that succeeded but produced
            // a shape pywal never actually writes.
            try {
                const parsed = JSON.parse(text());
                if (parsed && parsed.special) root.palette = parsed;
            } catch (e) {
            }
        }
        onLoadFailed: root.palette = null
    }

    // The picture pywal last read, written beside the palette by pywal itself.
    // Watching it is what carries a new wallpaper to the bar: the path changes,
    // the sample is taken again. The sample is fired from here rather than
    // from an onWallpaperChanged handler, because re-applying the SAME
    // wallpaper writes this file again without changing its text -- a QML
    // property assigned its own value emits no change signal, so that would
    // otherwise be the one case nothing ever re-samples, including a retry
    // after a sample that failed transiently.
    FileView {
        path: `${Quickshell.env("HOME")}/.cache/wal/wal`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.wallpaper = text().trim();
            if (root.wallpaper !== "") root._resample();
        }
        onLoadFailed: root.wallpaper = ""
    }

    // Stops the previous run before starting the next rather than just
    // assigning `running = true`: that assignment is a no-op on a Process
    // already running, so a wallpaper change landing inside the ~0.3s magick
    // run below would be silently dropped and the bar would keep the
    // previous wallpaper's colour indefinitely.
    function _resample() {
        sample.running = false;
        sample.running = true;
    }

    Process {
        id: sample

        command: ["sh", Quickshell.shellPath("scripts/wallpaper-tone.sh")]
        // Empty on a machine without ImageMagick, or with no wallpaper cached,
        // which is exactly the condition the pywal fallback above answers.
        stdout: StdioCollector {
            onStreamFinished: root.sampled = this.text.trim()
        }
    }
}
