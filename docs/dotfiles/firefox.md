# Firefox

`firefox/` themes Firefox's chrome and a few extension pages to follow the
wallpaper, same as the rest of the rice:

- `userChrome.css` — toolbar and tabs.
- `userContent.css` — `about:blank`/newtab/home, plus the Sidebery and
  Stylus extension pages (matched via `@-moz-document
  moz-extension://<uuid>`).
- `sidebery.css` — pasted into Sidebery's own Settings → Styles box.
- `stylus-global.user.css` — pasted into Stylus as a new global style.

All four `@import "matugen.css"` (or read the same `--mg-*` custom
properties), which resolves to `~/.cache/rd-shell/firefox-colors.css` —
rendered by matugen's `[templates.firefox]` from
`dotfiles/matugen/templates/firefox-colors.css` on every wallpaper switch.
Firefox only picks up new colours on its **next start** — chrome/content CSS
is parsed once, at window creation, no live reload.

## What install.sh wires up

Skipped entirely if no Firefox profile is found (checked in
`~/.config/mozilla/firefox` first, then the older `~/.mozilla/firefox`).

- Links the profile's `chrome/rd-shell` to the repo's `firefox/` directory.
- Links `chrome/matugen.css` to the rendered colours file in the cache —
  dangling until the first render happens.
- Writes `chrome/userChrome.css` and `chrome/userContent.css` as **stub**
  files (real files, not symlinks — Firefox won't follow an `@import` out of
  a symlinked sheet), each just two lines importing `matugen.css` and the
  matching `rd-shell/<sheet>`.
- Adds
  `user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);`
  to `user.js`, without which Firefox ignores `chrome/` entirely.

## What you still have to do by hand

`sidebery.css` and `stylus-global.user.css` live inside settings the browser
itself owns, so they're one-time pastes, not something `install.sh` can
write for you:

- Paste `firefox/sidebery.css` into Sidebery → Settings → Styles.
- Paste `firefox/stylus-global.user.css` into a new global style in Stylus.

Both keep following the wallpaper afterward without being re-pasted, since
they read the same `--mg-*` variables `userContent.css` does.

{% hint style="warning" %}
The Sidebery/Stylus extension UUIDs baked into `firefox/userContent.css` are
random per Firefox profile. Swap in your own from
`about:debugging#/runtime/this-firefox` before those two `@-moz-document`
blocks match anything on your machine.
{% endhint %}

Restart Firefox once after installing to load all of the above.
