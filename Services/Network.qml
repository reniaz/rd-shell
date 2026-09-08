pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "ethernet", "wifi", or "" when nothing is up
    property string type: ""
    property string name: ""

    readonly property bool connected: type !== ""
    readonly property bool wired: type === "ethernet"

    // TYPE and STATE never contain ":", so the connection name is simply
    // everything after the first two fields. nmcli escapes ":" inside a name
    // as "\\:", which the rejoin preserves and the replace unescapes.
    // plasma-nm's NetworkManager editor -- nm-connection-editor is not installed
    function openSettings() {
        Quickshell.execDetached(["kcmshell6", "kcm_networkmanagement"]);
    }

    function _parse(text) {
        const rows = text.trim().split("\n").map(line => {
            const f = line.split(":");
            return { type: f[0], state: f[1], name: f.slice(2).join(":").replace(/\\:/g, ":") };
        });

        const up = rows.filter(r => r.state?.startsWith("connected"));
        const dev = up.find(r => r.type === "ethernet") ?? up.find(r => r.type === "wifi");

        root.type = dev?.type ?? "";
        root.name = dev?.name ?? "";
    }

    Process {
        id: query
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    // NetworkManager pushes a line on every state change; re-query on each.
    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: query.running = true
        }
    }
}
