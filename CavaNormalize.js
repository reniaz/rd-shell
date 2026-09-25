.pragma library

// Shared per-band equalisation for CavaRing and CavaBars -- the "ring-local
// normalisation" the desktop contract asks for, factored out once two
// files needed the exact same maths. Kept as plain functions rather than a
// QtObject: the state they advance (`ref`, `display`) is owned by each
// caller, not by this file, which is what makes it "ring-local" in the
// first place -- two rings reading the same Cava.levels each keep their
// own arrays, so one player's ring never drives another's, or the bar
// strip's.
//
// This deliberately does NOT chase each band toward its own recent peak --
// an earlier version did, and at any volume it read as "basically always
// full size": cava's own autosens (Services/Cava.qml's config) already
// globally rescales toward peaks, so a band sitting near its own recent
// ceiling is the normal state, not a loud one, and dividing by it a second
// time just re-discovers "yes, still near its ceiling" every frame
// regardless of how loud the player actually is.
//
// What this does instead is EQUALISE the spectrum, not amplify it: `ref`
// is a slow (multi-second) running average per band, used only to compare
// one band against the others -- `gain` boosts a band that reads quiet
// next to the overall average (treble against a bass-heavy mix) and never
// touches one that is already at or above it (`opts.gainMin` clamps the
// gain to 1, so this can only lift a band up, never push one down). The
// actual amplitude that reaches `display` still comes from `raw[i]`
// itself, so overall loudness keeps following the player's own volume;
// `opts.headroom` and `opts.lift` (a pow < 1) then set how much of the
// bar's length a typical, un-equalised hit reaches, so only a genuine peak
// -- not just "on beat" -- ever reads full-scale.
function zeros(n, fill) {
    const z = new Array(n);
    z.fill(fill ?? 0);
    return z;
}

// Advances one caller's own state by one frame of raw Cava levels.
// `ref` is mutated in place (nothing outside this file ever reads it, so
// it needs no change notification); the caller's `display` is left
// untouched and the new array is returned instead, so a QML `property var`
// assigned from it is a genuine value change QML will notice and rebind
// on -- mutating an existing array in place would not be.
function step(raw, ref, display, opts) {
    const n = raw.length;

    for (let i = 0; i < n; i++)
        ref[i] += (raw[i] - ref[i]) * opts.refRate;

    let globalRef = 0;
    for (let i = 0; i < n; i++) globalRef += ref[i];
    globalRef /= n;

    const next = display.slice();
    for (let i = 0; i < n; i++) {
        const gain = Math.min(opts.gainMax, Math.max(opts.gainMin, globalRef / Math.max(ref[i], opts.refFloor)));
        const equalised = Math.min(1, raw[i] * gain);
        const shaped = Math.pow(Math.min(1, equalised * opts.headroom), opts.lift);

        const rate = shaped > next[i] ? opts.attack : opts.release;
        next[i] += (shaped - next[i]) * rate;
    }
    return next;
}
