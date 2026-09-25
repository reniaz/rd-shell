/**
 * caelus24 — CSS only, except for the wallpaper accent below.
 *
 * This file used to replace every one of spotify's inline SVG icons with a
 * glyph from an icon font, matching each icon on the first 26 characters of
 * its first <path>'s `d` attribute. It worked until it didn't: spotify
 * redraws an icon, the key stops matching, and the button either shows the
 * wrong picture or an empty box — and there is no way to notice except by
 * looking at every control in the app after every update. The icons are
 * spotify's own again, coloured by user.css through `currentColor`.
 *
 * The one runtime piece: matugen renders caelus-accent.css into xpui on every
 * wallpaper change (template: matugen/caelus-accent.css beside this file). A
 * <link> would be read once and kept for the session, so this fetches the
 * file itself and swaps its text into one <style> — a new wallpaper recolours
 * the running client within two seconds, no restart. It can only fail closed:
 * no file, and color.ini's orange stands.
 */
(function caelusAccent() {
  const style = document.createElement("style");
  style.id = "caelus-accent";
  document.head.append(style);

  let applied = null;
  async function sync() {
    try {
      const res = await fetch("/caelus-accent.css", { cache: "no-store" });
      const css = res.ok ? await res.text() : "";
      if (css !== applied) style.textContent = applied = css;
    } catch {
      // unreadable this tick; keep what is applied and try again on the next
    }
  }

  sync();
  setInterval(sync, 2000);
})();
