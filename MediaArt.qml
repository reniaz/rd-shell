import QtQuick
import QtQuick.Effects
import qs.Config

// Circular album art with a graceful miss: no track, no art, or a decode
// that fails all fall back to the same glyph the row would otherwise show
// bare, rather than a blank or black circle standing in for a picture
// that never arrived. The circular clip is a mask, not `clip: true` on a
// rounded Rectangle -- clipping only ever follows an item's bounding box
// in Qt Quick, never its radius, so a masked MultiEffect is what Wallpaper
// .qml reaches for too, for its own (differently-shaped) reveal mask.
//
// Extracted out of MediaPopup.qml -- it used to be an inline `component
// CircularArt` there -- once DesktopMedia.qml needed the same fallback-glyph
// circle at a different size. Nothing about it was popup-specific to begin
// with, so this is a straight lift.
Item {
    id: art

    property url source
    property string fallbackGlyph: "music_note"
    property color glyphColor: Colors.mediaMeta
    // Lets a caller stop any load being in flight while the art can't be
    // seen anyway -- DesktopMedia's card is idle far more than it's shown,
    // and there is no reason to hold an https reply (and the QQuickPixmap it
    // lands in) open for a circle nobody is looking at. Default true so
    // MediaPopup, which never sets this, keeps loading exactly as before.
    property bool active: true

    readonly property bool ready: artImage.status === Image.Ready

    // One retry for a load that came back Error -- a dropped connection or
    // a Spotify CDN hiccup, not a genuinely broken URL -- so a track like
    // "Fliegt" that happened to catch one bad fetch doesn't sit on the
    // glyph for the rest of its playtime. Counted per source (reset in
    // onSourceChanged below) so a URL that keeps failing still settles on
    // the glyph instead of retrying forever.
    property int _retries: 0

    onSourceChanged: art._retries = 0

    // Read only as a texture by the effect below. Opacity 0, not
    // `visible: false`: an invisible item stops producing a texture
    // entirely, the same reasoning Wallpaper.qml's revealShape spells
    // out for its own mask source.
    Image {
        id: artImage

        anchors.fill: parent
        // Gated on `active`, not bound straight to art.source: an Image
        // starts fetching the instant `source` is non-empty, so this is
        // what actually stops the load while idle (see `active` above).
        source: art.active ? art.source : ""
        fillMode: Image.PreserveAspectCrop
        // Synchronous, not asynchronous: an async Image hands the decode to
        // QQuickPixmapReader's own worker thread, and this session hit that
        // thread cross-parenting a QObject back onto the main one during a
        // hot reload -- a "Cannot create children for a parent that is in a
        // different thread" warning in `qs log`. Album art is a small
        // thumbnail; decoding it on the main thread is imperceptible and
        // removes the thread entirely.
        asynchronous: false
        // `cache: true` was the actual cause of three quickshell segfaults
        // in one evening (coredumpctl confirms all three stacks), not the
        // decode thread above. It puts this pixmap in Qt's process-global
        // QQuickPixmap cache, shared and refcounted across every QML engine
        // in the process. A save-triggered live reload rebuilds the whole
        // object graph in a *new* engine (RootWrapper::reloadGraph ->
        // Variants::updateVariants -> QQmlObjectCreator::finalize ->
        // loadPixmap -> QQuickPixmap::connectFinished -> QMetaObject::
        // connect) while an in-flight https reply from the *old* engine's
        // copy of this Image is still running against that shared cache
        // entry -- and a plain track change does the same thing to itself,
        // one engine, old url vs new url (loadPixmap -> QQuickPixmap::clear
        // -> QObject::disconnect). Either way it's a connect/disconnect
        // racing a teardown of an object the cache is still sharing.
        // Dropping out of the cache means every load owns its own
        // QQuickPixmap, decoded fresh each time `source` changes -- which
        // this thumbnail is cheap enough to afford, and it's also why the
        // retry below can just reassign `source` instead of fighting a
        // stale cache entry.
        cache: false
        opacity: 0

        onStatusChanged: {
            if (status === Image.Error && art._retries < 1) {
                art._retries += 1;
                // Re-assigning the same url is a no-op in QML, so the
                // retry has to clear `source` before setting it back. That
                // also happens to be exactly what makes a *new* track's art
                // (or the glyph, once retries are spent) always replace
                // whatever this Image was showing before: `art.ready` below
                // tracks `status`, and status leaves Ready the moment
                // `source` does, so the old picture never lingers under a
                // failed or in-flight new one.
                const retryUrl = art.source;
                artImage.source = "";
                artImage.source = art.active ? retryUrl : "";
            }
        }
    }

    Item {
        id: circleMask

        anchors.fill: parent
        opacity: 0
        layer.enabled: true

        Rectangle { anchors.fill: parent; radius: width / 2; color: "white" }
    }

    MultiEffect {
        anchors.fill: parent
        source: artImage
        visible: art.ready
        maskEnabled: true
        maskSource: circleMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.04
    }

    Text {
        anchors.centerIn: parent
        visible: !art.ready
        text: art.fallbackGlyph
        color: art.glyphColor
        font.family: Caelus.symbolFamily
        font.pixelSize: Caelus.sizeTitle
    }
}
