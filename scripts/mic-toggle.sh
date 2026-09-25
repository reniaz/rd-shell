#!/usr/bin/env bash
# Toggle the default audio source. Bound to CTRL+SHIFT+M and XF86AudioMicMute
# in hyprland.lua.
#
# This used to post a notification saying which way it went, closing the
# previous one first so a toast appeared on every press. The shell now has an
# OSD for it -- the same card the volume and keyboard-layout changes use --
# driven straight off PipeWire's mute state in Services/Audio.qml, so the
# notification was saying a second time what the screen already said, and
# leaving an entry in the notification panel for something that is not an
# event anyone needs to go back and read.
set -euo pipefail

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
