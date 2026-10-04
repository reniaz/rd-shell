import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services

// Settings app page (see the scratchpad contract this round builds against):
// "About". The one page that is read-only by nature -- nothing here is a
// `Settings.*` property, so there is nothing to bind live the way every
// other page does. What it shows instead is the shell's own identity and
// build state, re-read every time the page is opened rather than cached at
// startup: the repo's HEAD and the installed Quickshell both change between
// one open of this window and the next (a `git pull`, a package update) far
// more plausibly than, say, Colors.qml's palette does, and a stale commit
// hash on an About page is a worse failure than the one extra process spawn
// per visit costs.
//
// `InfoRow` below is this file's own read-only sibling to the kit's
// SettingsButtonRow/ToggleRow/etc: label + caption on the left, a plain value
// instead of a control on the right. It is declared here rather than as a
// shared `SettingsAbout*.qml` helper because this file is the only page with
// anything to show that way -- every other page's rows are interactive kit
// components. (Inline components -- the `component Name: Base { ... }`
// syntax -- are already this repo's idiom for a one-file-only delegate; see
// PowerMenu.qml's `Tile`.)
SettingsPage {
    id: root

    title: "About"
    subtitle: "What this build of rd-shell is, and a few places to jump from here."

    // A plain info row: icon, label (+ optional caption under it), value at
    // the right. Not a kit component -- it owns no control, emits no
    // signal, and is never keyboard-focusable, which is exactly why it does
    // not belong in SettingsToggleRow/SliderRow/ChoiceRow/ButtonRow's family
    // (the contract's "every control is keyboard reachable" rule is about
    // controls; a fact on a label is not one).
    component InfoRow: Item {
        id: infoRow

        property string icon: ""
        property string label: ""
        property string caption: ""
        property string value: ""

        Layout.fillWidth: true
        implicitHeight: Math.max(52 * Caelus.uiScale, inner.implicitHeight + Caelus.spaceWide * 2)

        RowLayout {
            id: inner

            anchors.fill: parent
            anchors.margins: Caelus.spaceWide
            spacing: Caelus.space

            Text {
                visible: infoRow.icon !== ""
                text: infoRow.icon
                color: Colors.fgDim
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeTitle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: infoRow.label
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    Layout.fillWidth: true
                    visible: infoRow.caption !== ""
                    text: infoRow.caption
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Text {
                Layout.maximumWidth: 260 * Caelus.uiScale
                horizontalAlignment: Text.AlignRight
                text: infoRow.value
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                elide: Text.ElideMiddle
            }
        }
    }

    // --- Hero: the shell's own mark, same star SettingsWindow.qml's own
    // header and the bar's ✦ pill use (caelusevka, Colors.popupAccent) --
    // this page is the one place that gets to say the shell's full name out
    // loud instead of just showing its glyph.
    SettingsCard {
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.spaceWide

            Text {
                text: "✦"
                color: Colors.popupAccent
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeTitle * 2.2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Caelus.spaceTight

                Text {
                    Layout.fillWidth: true
                    text: "rd ✦ shell"
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLead * 1.3
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "A Quickshell + Hyprland desktop, recoloured live by matugen."
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // --- Build state: repo HEAD, the Quickshell binary running it, where
    // its config lives, and whether the palette on screen right now is
    // matugen's or the fixed caelus one. Every value here is either a
    // Process already pointed at this exact repo (git, qs --version) or a
    // service this shell already keeps around (Settings.dynamicColour,
    // Wal.known) -- no new script, per the contract.
    SettingsCard {
        title: "Build"

        InfoRow {
            icon: "commit"
            label: "Commit"
            caption: root._commitSubject
            value: root._commitSubject !== "" ? `${root._commitHash} · ${root._commitRel}` : "Reading…"
        }

        InfoRow {
            icon: "terminal"
            label: "Quickshell"
            value: root._qsVersion !== "" ? root._qsVersion : "Reading…"
        }

        InfoRow {
            icon: "folder"
            label: "Config directory"
            value: root._configDir
        }

        InfoRow {
            icon: "palette"
            label: "Colours"
            value: !Settings.dynamicColour
                ? "Fixed palette"
                : (Wal.known ? "Dynamic (matugen)" : "Dynamic — matugen hasn't run yet")
        }
    }

    // --- Quick actions: the three things someone reaching for an About
    // page actually wants to *do* -- restart the shell after pulling a
    // change, get to the repo in a file manager, or jump to every bind
    // without leaving the keyboard.
    SettingsCard {
        title: "Actions"

        SettingsButtonRow {
            icon: "refresh"
            label: "Reload shell"
            caption: "Restarts rd-shell in place, the same reload a saved file in the repo already triggers"
            buttonText: "Reload"
            onClicked: Quickshell.reload(false)
        }

        SettingsButtonRow {
            icon: "folder_open"
            label: "Open config folder"
            caption: root._configDir
            buttonText: "Open"
            onClicked: Quickshell.execDetached(["xdg-open", root._configDir])
        }

        SettingsButtonRow {
            icon: "keyboard"
            label: "Keybind overview"
            caption: "Every Hyprland bind, searchable and runnable (SUPER + K)"
            buttonText: "Open"
            onClicked: Keybinds.toggle()
        }
    }

    // --- State backing the Build card above. `Quickshell.shellPath("")` is
    // this repo's own root (the live config at ~/.config/quickshell/rd-shell
    // is a symlink onto it) -- the same helper every script-launching
    // service in Services/ already calls with a real relative path.
    readonly property string _configDir: Quickshell.shellPath("")

    property string _commitHash: ""
    property string _commitSubject: ""
    property string _commitRel: ""
    property string _qsVersion: ""

    Process {
        running: true
        command: ["git", "-C", root._configDir, "log", "-1", "--format=%h%x09%s%x09%cr"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("\t");
                if (parts.length < 3) return; // detached HEAD with no commits, or git missing -- leave "Reading…"
                root._commitHash = parts[0];
                root._commitSubject = parts[1];
                root._commitRel = parts[2];
            }
        }
    }

    Process {
        running: true
        command: ["qs", "--version"]

        stdout: StdioCollector {
            onStreamFinished: root._qsVersion = this.text.split("\n")[0].trim()
        }
    }
}
