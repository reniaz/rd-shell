pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Merch drops found by ~/coding/dzuma_scraper, which checks dzuma.shop once per
// login. The scraper owns the state and the notifying; the bar reads what it
// left behind and offers the acknowledge that stops a drop being re-announced
// at every startup.
Singleton {
    id: root

    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/dzuma-watch`
    readonly property string watcher: `${Quickshell.env("HOME")}/coding/dzuma_scraper/dzuma_watch.py`

    // Unacknowledged events, newest first: {kind, name, price, url, media, ts}.
    property var drops: []
    readonly property int count: drops.length
    readonly property var latest: count > 0 ? drops[0] : null
    property bool panelOpen: false
    property bool checking: false
    property string lastSuccess: ""

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    function openShop(url) {
        Quickshell.execDetached(["xdg-open", url || "https://dzuma.shop/"]);
    }

    // Clearing the scraper's pending list is what makes it stop shouting at
    // every startup, so the button does that rather than only hiding the pill.
    // The list is emptied here too: the file reload lands a moment later.
    function ack() {
        acker.running = true;
        root.drops = [];
        root.panelOpen = false;
    }

    // A manual check, for when the machine has been up for days. The scraper
    // holds its own lock, so a second run while one is in flight is harmless.
    function check() {
        if (root.checking)
            return;

        root.checking = true;
        checker.running = true;
    }

    Process {
        id: acker

        command: [root.watcher, "--ack"]
        onExited: store.reload()
    }

    Process {
        id: checker

        command: [root.watcher, "--check"]
        onExited: {
            root.checking = false;
            store.reload();
        }
    }

    FileView {
        id: store

        path: `${root.stateDir}/state.json`
        // No file yet only means the scraper has not had its first run.
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._adopt(store.text())
    }

    function _adopt(text) {
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            return;
        }

        const pending = parsed.pending ?? [];
        root.drops = pending.slice().reverse().map(event => ({
            kind: event.kind ?? "new",
            name: event.name ?? "",
            price: event.price ?? "",
            url: event.url ?? "https://dzuma.shop/",
            ts: event.ts ?? "",
            media: root._poster(event.media ?? "")
        }));
        root.lastSuccess = parsed.last_success ?? "";
    }

    // The scraper caches each product's clip beside its state and cuts a still
    // from it; the still is what a popup can actually show.
    function _poster(media) {
        if (!media)
            return "";

        const file = media.split("/").pop();
        return `${root.stateDir}/media/${file.replace(/\.(mp4|webm|mov|m4v)$/i, ".poster.jpg")}`;
    }
}
