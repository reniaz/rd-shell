-- Animation presets for Hyprland's Lua config.
--
-- Four presets as data: a set of named curves (beziers, plus the one spring)
-- and the per-leaf hl.animation() calls that use them. apply(name) issues
-- every hl.curve/hl.animation call for one preset; it is deliberately
-- side-effect-only and idempotent -- calling it again just re-asserts that
-- preset's curves, never accumulating state of its own. Required from
-- hyprland.lua (see that file's own comment, right where the inline
-- curve/animation block used to sit) and from Services/AnimPresets.qml's
-- live switcher, over `hyprctl eval` -- see that file for why re-`require`ing
-- this module there is cheap rather than a re-parse.
--
-- "smooth" is an EXACT copy of what used to be inline in hyprland.lua --
-- every curve, every speed, every style, byte for byte -- so picking it (the
-- shipped default) must never change how the compositor already looked and
-- felt. The other three are new: "snappy" reuses smooth's own curve shapes
-- driven harder (no new geometry, just faster), "bouncy" is the one preset
-- with a real overshoot bezier, and "minimal" is reduced motion -- movement
-- disabled outright, fades only, pushed as fast as a curve can still read as
-- a fade rather than a flicker.
--
-- Adding a fifth preset: one entry in `presets` below, plus a matching entry
-- in Services/AnimPresets.qml's own `presets` list (same id, which --
-- exactly like Services/BarStyles.qml's style ids -- must never change once
-- shipped, since it is what settings.json stores) and AnimPresetSwitcher.qml's
-- `Preview` component. Nothing else branches on a preset id.

local M = {}

-- Defined in the original inline block and never referenced by any leaf
-- there either (no animation below uses bezier = "easy") -- kept here,
-- applied unconditionally alongside whichever preset is active, so a future
-- leaf that does reach for it finds it defined no matter which preset is
-- current, and "smooth" stays a byte-for-byte match of what this file
-- replaced.
local SHARED_CURVES = {
    easy = { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 },
}

M.presets = {
    -- Exact copy of hyprland.lua's old inline block (curves and
    -- hl.animation calls both) -- see this file's own header comment for why
    -- that has to hold.
    smooth = {
        curves = {
            easeOutQuint   = { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } },
            easeInOutCubic = { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } },
            linear         = { type = "bezier", points = { {0, 0},       {1, 1}       } },
            almostLinear   = { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } },
            quick          = { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } },
            snapSlide      = { type = "bezier", points = { {0.19, 1},    {0.22, 1}    } },
        },
        animations = {
            -- borderangle is deliberately absent, same reasoning as the
            -- inline block this replaced: it repaints the active border's
            -- gradient on a timer rather than in response to anything, so it
            -- either sweeps forever or sweeps once per focus change, and
            -- neither is information.
            { leaf = "global",        enabled = true,  speed = 10,   bezier = "default" },
            { leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" },
            { leaf = "windows",       enabled = true,  speed = 2.5,  bezier = "easeOutQuint" },
            { leaf = "windowsIn",     enabled = true,  speed = 1.5,  bezier = "easeOutQuint", style = "popin 100%" },
            { leaf = "windowsOut",    enabled = true,  speed = 1.2,  bezier = "linear",       style = "popin 100%" },
            { leaf = "windowsMove",   enabled = true,  speed = 2.5,  bezier = "easeOutQuint" },
            { leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" },
            { leaf = "fadeIn",        enabled = true,  speed = 1.5,  bezier = "almostLinear" },
            { leaf = "fadeOut",       enabled = true,  speed = 1.2,  bezier = "almostLinear" },
            { leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" },
            { leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" },
            { leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" },
            { leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" },
            { leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" },
            -- Workspace switch: horizontal slide, snapSlide curve covers most
            -- of the distance up front then eases out, so 250ms reads as
            -- smooth but not slow.
            { leaf = "workspaces",    enabled = true,  speed = 2.5,  bezier = "snapSlide", style = "slide" },
            { leaf = "workspacesIn",  enabled = true,  speed = 2.5,  bezier = "snapSlide", style = "slide" },
            { leaf = "workspacesOut", enabled = true,  speed = 2.5,  bezier = "snapSlide", style = "slide" },
            { leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" },
        },
    },

    -- Same curve shapes as smooth's easeOutQuint/linear/quick/snapSlide (plain
    -- deceleration, no overshoot) -- just driven harder: every speed below is
    -- roughly 1.6-1.8x smooth's own. Reusing smooth's own geometry rather than
    -- inventing a steeper curve is what keeps this reading as the same shell,
    -- only snappier, not as a different personality.
    snappy = {
        curves = {
            easeOutQuint = { type = "bezier", points = { {0.23, 1}, {0.32, 1} } },
            linear       = { type = "bezier", points = { {0, 0},    {1, 1}    } },
            quick        = { type = "bezier", points = { {0.15, 0}, {0.1, 1}  } },
            snapSlide    = { type = "bezier", points = { {0.19, 1}, {0.22, 1} } },
        },
        animations = {
            { leaf = "global",        enabled = true, speed = 10,   bezier = "default" },
            { leaf = "border",        enabled = true, speed = 9,    bezier = "easeOutQuint" },
            { leaf = "windows",       enabled = true, speed = 4.2,  bezier = "easeOutQuint" },
            { leaf = "windowsIn",     enabled = true, speed = 2.6,  bezier = "easeOutQuint", style = "popin 100%" },
            { leaf = "windowsOut",    enabled = true, speed = 2.2,  bezier = "linear",       style = "popin 100%" },
            { leaf = "windowsMove",   enabled = true, speed = 4.2,  bezier = "easeOutQuint" },
            { leaf = "fade",          enabled = true, speed = 5.5,  bezier = "quick" },
            { leaf = "fadeIn",        enabled = true, speed = 2.8,  bezier = "quick" },
            { leaf = "fadeOut",       enabled = true, speed = 2.2,  bezier = "quick" },
            { leaf = "layers",        enabled = true, speed = 6.5,  bezier = "easeOutQuint" },
            { leaf = "layersIn",      enabled = true, speed = 7,    bezier = "easeOutQuint", style = "fade" },
            { leaf = "layersOut",     enabled = true, speed = 2.6,  bezier = "linear",       style = "fade" },
            { leaf = "fadeLayersIn",  enabled = true, speed = 3.2,  bezier = "quick" },
            { leaf = "fadeLayersOut", enabled = true, speed = 2.5,  bezier = "quick" },
            { leaf = "workspaces",    enabled = true, speed = 4.2,  bezier = "snapSlide", style = "slide" },
            { leaf = "workspacesIn",  enabled = true, speed = 4.2,  bezier = "snapSlide", style = "slide" },
            { leaf = "workspacesOut", enabled = true, speed = 4.2,  bezier = "snapSlide", style = "slide" },
            { leaf = "zoomFactor",    enabled = true, speed = 12,   bezier = "quick" },
        },
    },

    -- The one preset with a real overshoot: "overshoot" is a classic
    -- easeOutBack cubic -- the first control point's y > 1 is what lets the
    -- traced curve cross 1 and settle back down to it, the same idea
    -- Config/Motion.qml's `enter`/`enterOvershoot` (Easing.OutBack) names for
    -- the shell's own popups. Used only where a window or workspace actually
    -- arrives somewhere (windows/windowsIn/windowsMove, layers/layersIn, the
    -- workspace slide) -- borders and fades stay on a plain decelerate,
    -- since a bouncing colour or opacity reads as a glitch, not as life.
    bouncy = {
        curves = {
            overshoot    = { type = "bezier", points = { {0.34, 1.56}, {0.64, 1} } },
            easeOutQuint = { type = "bezier", points = { {0.23, 1},    {0.32, 1} } },
            linear       = { type = "bezier", points = { {0, 0},       {1, 1}    } },
            quick        = { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } },
        },
        animations = {
            { leaf = "global",        enabled = true, speed = 10,   bezier = "default" },
            { leaf = "border",        enabled = true, speed = 5,    bezier = "easeOutQuint" },
            { leaf = "windows",       enabled = true, speed = 3,    bezier = "overshoot" },
            { leaf = "windowsIn",     enabled = true, speed = 2.2,  bezier = "overshoot", style = "popin 80%" },
            { leaf = "windowsOut",    enabled = true, speed = 1.4,  bezier = "linear",     style = "popin 100%" },
            { leaf = "windowsMove",   enabled = true, speed = 3,    bezier = "overshoot" },
            { leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" },
            { leaf = "fadeIn",        enabled = true, speed = 1.5,  bezier = "quick" },
            { leaf = "fadeOut",       enabled = true, speed = 1.2,  bezier = "quick" },
            { leaf = "layers",        enabled = true, speed = 3.5,  bezier = "overshoot" },
            { leaf = "layersIn",      enabled = true, speed = 3.2,  bezier = "overshoot", style = "fade" },
            { leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",     style = "fade" },
            { leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "quick" },
            { leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "quick" },
            { leaf = "workspaces",    enabled = true, speed = 2.2,  bezier = "overshoot", style = "slide" },
            { leaf = "workspacesIn",  enabled = true, speed = 2.2,  bezier = "overshoot", style = "slide" },
            { leaf = "workspacesOut", enabled = true, speed = 2.2,  bezier = "overshoot", style = "slide" },
            { leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" },
        },
    },

    -- Reduced motion. Every leaf that moves something across the screen or
    -- pops it in/out of place (global, windows/windowsIn/windowsOut/
    -- windowsMove, layers, workspaces*, zoomFactor) is disabled outright
    -- rather than merely sped up: "fast" still reads as motion, `enabled =
    -- false` is the only setting that reliably reads as *none* to someone who
    -- asked for reduced motion. Fades survive (nothing here touches the
    -- `animations.enabled` master switch in hyprland.lua's own hl.config
    -- block -- that one is a global kill switch for every leaf including
    -- these, and turning it off would take the fades too) but are pushed to
    -- the fastest speed a bezier can still trace, so a window or layer still
    -- visibly appears/disappears rather than cutting with a flicker. `style`
    -- is left unset on every surviving leaf -- "fade" is already its only
    -- motion, nothing here needs popin/slide on top of it.
    minimal = {
        curves = {
            quick  = { type = "bezier", points = { {0.15, 0}, {0.1, 1} } },
            linear = { type = "bezier", points = { {0, 0},    {1, 1}   } },
        },
        animations = {
            { leaf = "global",        enabled = false },
            { leaf = "border",        enabled = true,  speed = 8, bezier = "linear" },
            { leaf = "windows",       enabled = false },
            { leaf = "windowsIn",     enabled = false },
            { leaf = "windowsOut",    enabled = false },
            { leaf = "windowsMove",   enabled = false },
            { leaf = "fade",          enabled = true,  speed = 8, bezier = "quick" },
            { leaf = "fadeIn",        enabled = true,  speed = 6, bezier = "quick" },
            { leaf = "fadeOut",       enabled = true,  speed = 6, bezier = "quick" },
            { leaf = "layers",        enabled = false },
            { leaf = "layersIn",      enabled = true,  speed = 8, bezier = "quick" },
            { leaf = "layersOut",     enabled = true,  speed = 8, bezier = "quick" },
            { leaf = "fadeLayersIn",  enabled = true,  speed = 6, bezier = "quick" },
            { leaf = "fadeLayersOut", enabled = true,  speed = 6, bezier = "quick" },
            { leaf = "workspaces",    enabled = false },
            { leaf = "workspacesIn",  enabled = false },
            { leaf = "workspacesOut", enabled = false },
            { leaf = "zoomFactor",    enabled = false },
        },
    },
}

-- In switcher-card order (Services/AnimPresets.qml's own `presets` list, same
-- order). Not relied on by `apply` itself -- only the switcher walks this --
-- but kept here, next to the table it enumerates, rather than only in the QML
-- singleton, so the two cannot silently drift to different orders.
M.order = { "snappy", "smooth", "bouncy", "minimal" }

-- Issues every hl.curve/hl.animation call for one preset. Side-effect only,
-- safe to call as often as wanted -- see this file's header comment for who
-- calls it and why repeat calls are cheap. An unknown name falls back to
-- "smooth", the same tolerant-default shape Services/BarStyles.qml uses for
-- an id nothing in its own list answers to.
function M.apply(name)
    local preset = M.presets[name] or M.presets.smooth

    for id, def in pairs(SHARED_CURVES) do
        hl.curve(id, def)
    end
    for id, def in pairs(preset.curves) do
        hl.curve(id, def)
    end
    for _, anim in ipairs(preset.animations) do
        hl.animation(anim)
    end
end

return M
