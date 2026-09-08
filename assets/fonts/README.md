# Bundled fonts

`Config/Colors.qml` and every label in the bar ask for the family **`caelusevka`**, a
custom [Iosevka](https://github.com/be5invis/Iosevka) build that exists on no distro
repository. The four faces Qt can actually select for that family are bundled here so
`install.sh` can put the bar's text on a friend's machine without a font hunt; the
`Extended` faces of the same build are a separate family (`caelusevka Extended`), never
requested by this config, and are not shipped.

Iosevka and its derived builds are licensed under the SIL Open Font License 1.1, which
is what makes a renamed redistribution like this one legitimate.

The other required font, **Material Symbols Rounded**, is not bundled: it is a 3MB
variable font that `install.sh` downloads from google/material-design-icons on demand.
