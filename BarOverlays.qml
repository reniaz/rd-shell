import QtQuick
import qs.Config
import qs.Services

Item {
    id: root

    required property var modelData
    required property string overlayScreen

    // Forwarded from BarWindow.qml -- the four cross-group anchors it already
    // aggregates from a group's own x plus that group's pill-local offset.
    required property real systemAnchorX
    required property real mediaAnchorX
    required property real clockAnchorX
    required property real networkAnchorX

    // The three group instances themselves, for the pill-local anchors and
    // open flags they expose that the anchors above do not forward on their own.
    // Named `*Group` rather than `left`/`center`/`right`: those three collide
    // with FINAL properties Item already declares, and QML rejects the whole
    // type at load rather than shadowing them.
    required property Item leftGroup
    required property Item centerGroup
    required property Item rightGroup

    required property QtObject osdWatch

    // The eleven loaders below that hang a popup off the bar, named here so
    // `anyPopupOpen` and `cards` below have something bindable to stand on.
    // An earlier version walked `data` instead, on the argument that this
    // Item's own children are exactly the candidates and a list is one more
    // thing to forget to add to. QML will not have it: `data` is a list
    // property with no change signal, so an expression that reads it is
    // evaluated once, eagerly, and never again -- `QQmlExpression: ...
    // depends on non-bindable properties`, hundreds of times from startup
    // on. Evaluated once means evaluated while every LazyLoader is still
    // holding nothing, so every island would have sat at width 0 for the
    // life of the shell. Enumerating them by id is what makes each term of
    // the sum a real property path the engine can watch.
    readonly property var anchoredLoaders: [
        sysLoader, mediaLoader,
        calendarLoader,
        settingsLoader, notificationLoader, dzumaLoader, diskLoader,
        volumeLoader, micLoader, networkLoader, claudeLoader
    ]

    // Exported alongside `cards` below, both read by BarWindow.qml's `blob`.
    // `anyPopupOpen` is also the fused window's own mask/keyboardFocus gate,
    // replacing the per-window `mask: root.open ? null : closedMask` every
    // BarPopup used to set for itself.
    //
    // Any anchored loader whose popup reports itself open counts, same as
    // asking every window in the old world whether it was open: nothing here
    // restricts it to one at a time, and nothing needs to -- `cards` below
    // carries every one of them through to `blob` regardless.
    readonly property bool anyPopupOpen: root.anchoredLoaders.some(l => l.item?.open === true)

    // Every loaded popup with visible card material, as {x, y, w, h, r, a} in
    // window coordinates -- `blob`'s own input (BarWindow.qml), one entry per
    // open (or still-closing) card rather than one per island, because a card
    // finishing its exit hold while a different popup opens under the same
    // island must keep contributing a fill for both at once.
    // Capped at 4: more than that never happens today (nine popups, three
    // islands, at most one open per island plus one mid-exit each).
    //
    // Deliberately flat and in file order rather than grouped by island: a
    // card's own position is all `blob`'s smooth-min needs to find the
    // island it actually touches (see the comment on `foldCard` in
    // shaders/blob.frag) -- unlike the fillets and crescents this replaced,
    // nothing here has to say up front which card belongs to which island
    // for the two to merge correctly.
    //
    // `cardRect`/`cardAlpha` are undefined on any `Item` this loader might
    // ever hold that is not a `BarPopup` (there is none today, but nothing
    // stops one being added), so a loaded item missing them is filtered out
    // rather than treated as a card with every field undefined.
    readonly property var cards: {
        const list = [];
        for (let i = 0; i < root.anchoredLoaders.length && list.length < 4; i++) {
            const popup = root.anchoredLoaders[i].item;
            if (!popup || popup.cardRect === undefined || popup.cardAlpha === undefined)
                continue;

            const a = popup.cardAlpha;
            const r = popup.cardRect;
            if (a <= 0 || !r || r.width <= 0 || r.height <= 0)
                continue;

            list.push({ x: r.x, y: r.y, w: r.width, h: r.height, r: popup.cardRadius ?? 0, a: a });
        }
        return list;
    }

    // Every overlay below is held by a PopupLoader rather than a bare LazyLoader,
    // and the difference is the whole of the exit animation: a LazyLoader wired
    // straight to an open flag destroys its window on the frame that flag drops,
    // so the card never gets to play itself back into the icon it came out of.
    // PopupLoader keeps the window for one animation's worth of time after the
    // flag goes, and writes the flag into the window on the way down so it knows
    // to leave. Which of the two kinds of open state it is handed -- a Pill's,
    // or a service's -- it does not care; see PopupLoader.qml.

    // Settings and power are one merged menu now, kept open by Power.menuOpen
    // -- the existing service flag, so Super+M and the IPC call both keep
    // working unchanged. Hangs off its own pill like the readout popups do,
    // so it is anchored rather than centred.
    //
    // Gated on overlayScreen like every other service-flagged overlay. The
    // flag is one boolean for the whole shell, and the `✦` pill exists on
    // every bar, so without this every monitor opened its own copy of the
    // same menu at once. Hyprland runs follow_mouse = 1, so the screen whose
    // pill you just clicked is the focused one by the time you click it, and
    // the keybind and IPC paths open it where you are looking -- which is
    // what overlayScreen already means everywhere else in this file.
    PopupLoader {
        id: settingsLoader

        open: Power.menuOpen && root.modelData.name === root.overlayScreen

        SettingsPopup {
            anchorX: root.rightGroup.x + root.rightGroup.menuAnchorX
            onDismissed: Power.menuOpen = false
        }
    }

    // The same one-screen rule as the power menu, and for the same reason: it
    // takes the keyboard exclusively, so two of them would fight over it.
    PopupLoader {
        open: Apps.open && root.modelData.name === root.overlayScreen

        Launcher {
            screen: root.modelData
            onDismissed: Apps.open = false
        }
    }

    // The same one-screen rule as the power menu: the switcher takes the keyboard
    // exclusively, so two of them would fight over it, and a strip of wallpapers
    // is only wanted on the screen you are looking at. It closes itself through
    // the service rather than a dismissed signal, because applying a wallpaper
    // has to shut it too and only Wallpapers knows when that happened.
    PopupLoader {
        open: Wallpapers.panelOpen && root.modelData.name === root.overlayScreen

        WallpaperSwitcher {
            screen: root.modelData
        }
    }

    // Held open by the service and not by this loader alone, because Escape, the
    // bell and the IPC handler can all shut this panel and only one of them is
    // that window.
    PopupLoader {
        id: notificationLoader

        open: Notifications.panelOpen && root.modelData.name === root.overlayScreen

        NotificationPanel {
            anchorX: root.rightGroup.x + root.rightGroup.bellAnchorX
            onDismissed: Notifications.closePanel()
        }
    }

    // Not gated on overlayScreen the way the keybind-driven overlays are: this
    // one is opened by a click on a specific bar, so it belongs to that screen
    // whether or not the pointer left the focused one.
    PopupLoader {
        id: sysLoader

        open: SysMon.panelOpen && root.modelData.name === root.overlayScreen

        SysPopup {
            anchorX: root.systemAnchorX
            onDismissed: SysMon.panelOpen = false
        }
    }

    PopupLoader {
        id: dzumaLoader

        open: Dzuma.panelOpen

        DzumaPopup {
            anchorX: root.rightGroup.x + root.rightGroup.dzumaAnchorX
            onDismissed: Dzuma.panelOpen = false
        }
    }

    PopupLoader {
        id: diskLoader

        open: root.rightGroup.diskOpen

        DiskPopup {
            // Centre of the pill in bar coordinates. rightGroup sits directly in
            // the window, so its x plus the pill's is already window-relative,
            // and both stay live as the pills either side change width.
            anchorX: root.rightGroup.x + root.rightGroup.diskAnchorX
            onDismissed: root.rightGroup.diskOpen = false
        }
    }

    // Both of these are opened by a right-click on a specific bar, so they follow
    // the disk popup rather than the keybind-driven overlays: no overlayScreen
    // gate, and the open state lives on the pill that was clicked.
    PopupLoader {
        id: calendarLoader

        open: root.centerGroup.calendarOpen

        CalendarPopup {
            anchorX: root.clockAnchorX
            onDismissed: root.centerGroup.calendarOpen = false
        }
    }

    // Closed with the pill it hangs from: the last player quitting takes the
    // pill off the bar, and a card left pointing at a gap is not dismissable by
    // clicking the icon that opened it. A player merely reloading no longer
    // costs the card its window -- the loader's hold outlasts the blink, and
    // the card is handed back instead of being built again.
    PopupLoader {
        id: mediaLoader

        open: root.leftGroup.mediaOpen && Media.available

        MediaPopup {
            anchorX: root.mediaAnchorX
            onDismissed: root.leftGroup.mediaOpen = false
        }
    }

    // Same pill, same reasoning as the disk popup above: rightGroup sits
    // directly in the window, so its x plus the pill's is already
    // window-relative and stays live as the pills either side change width.
    PopupLoader {
        id: volumeLoader

        open: root.rightGroup.volumeOpen

        AudioPopup {
            anchorX: root.rightGroup.x + root.rightGroup.volumeAnchorX
            onDismissed: root.rightGroup.volumeOpen = false
        }
    }

    // Closed with the pill it hangs from, same as the media popup above: the
    // default source disappearing takes the pill off the bar, and a card
    // left pointing at a gap is not dismissable by clicking the icon that
    // opened it.
    PopupLoader {
        id: micLoader

        open: root.rightGroup.micOpen && Audio.micReady

        AudioPopup {
            capture: true
            anchorX: root.rightGroup.x + root.rightGroup.micAnchorX
            onDismissed: root.rightGroup.micOpen = false
        }
    }

    // What the link is actually carrying, which is the one thing the pill's own
    // name and icon cannot say. Opened by a click on a specific bar, so it is
    // ungated like the disk and calendar cards rather than following the focused
    // monitor.
    PopupLoader {
        id: networkLoader

        open: root.rightGroup.networkOpen

        NetworkPopup {
            anchorX: root.networkAnchorX
            onDismissed: root.rightGroup.networkOpen = false
        }
    }

    PopupLoader {
        open: KeyboardLayout.osdVisible && root.modelData.name === root.overlayScreen

        KeyboardLayoutOsd { screen: root.modelData }
    }

    // osdWatch is BarOsdWatch.qml's stand-in for the osdVisible flag Audio.qml
    // does not raise; see the comment there.
    PopupLoader {
        open: root.osdWatch.pulse && root.modelData.name === root.overlayScreen

        AudioOsd {
            screen: root.modelData
            mode: root.osdWatch.mode
        }
    }

    // Gated on Brightness.available too: on a machine with no backlight
    // device osdVisible never rises, but the && costs nothing to be sure this
    // window is never even asked for on one.
    PopupLoader {
        open: Brightness.available && Brightness.osdVisible && root.modelData.name === root.overlayScreen

        BrightnessOsd { screen: root.modelData }
    }

    // The same card in its contrast mode. No overlayScreen gate, unlike every
    // other OSD here: contrast is a property of one monitor, and this watch
    // only ever pulses for the monitor its own bar is on.
    BarContrastWatch {
        id: contrastWatch

        screenName: root.modelData.name
    }

    PopupLoader {
        open: contrastWatch.pulse

        BrightnessOsd {
            screen: root.modelData
            mode: "contrast"
            percent: contrastWatch.percent
        }
    }

    // The whole stack is retired at once by Notifications' own popup timer, so
    // this goes from several toasts to none in a single change. The loader holds
    // the window through the slide that takes them back off the right edge.
    PopupLoader {
        open: Notifications.popups.length > 0 && root.modelData.name === root.overlayScreen

        NotificationPopups { screen: root.modelData }
    }

    // Held open by the service and not by this loader alone, because Escape, the
    // pill, the panel's own close button and the IPC handler can all shut it and
    // only one of them is that window.
    PopupLoader {
        id: claudeLoader

        open: ClaudeSession.panelOpen && root.modelData.name === root.overlayScreen

        ClaudePanel {
            // Same reasoning as the disk popup above: rightGroup sits directly
            // in the window, so its x plus the pill's is already window-relative
            // and stays live as the pills either side change width.
            anchorX: root.rightGroup.x + root.rightGroup.claudeAnchorX
            onDismissed: ClaudeSession.closePanel()
        }
    }
}
