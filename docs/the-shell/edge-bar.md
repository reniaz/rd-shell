# Edge bar

`EdgeBar.qml` is a hover-revealed strip on a monitor's outer edge, inspired by
caelestia. It carries per-monitor brightness/contrast controls over DDC/CI
(`EdgeSlider.qml`, `Services/Ddc.qml`, driven by `ddcutil`) — useful for
desktop displays with no backlight device, where `brightnessctl` has nothing
to control.

`BarContrastWatch.qml` keeps its readout in sync with whatever the display
actually reports back over DDC.

Requires `ddcutil` (optional dependency in `install.sh`) and a monitor that
answers DDC/CI queries — not every display does, especially over some
docks/hubs.
