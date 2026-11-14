local _, ns = ...
local Settings = ns.Settings

-- Themes: a look for the meter, and a whole set of settings each, as in
-- Forever Unit Frames (Core/Themes.lua). The setting `theme` names the one
-- in use; the profile holds its settings. The others wait in the
-- profile's `themeSets`, one copy per theme. CLASSIC is the player's own
-- look as it was before themes: no other theme changes it, so going back
-- to it restores every setting.
--
-- A theme chosen the first time starts from the CLASSIC set (windows,
-- positions, sizes, modes: everything the player set up) with the theme's
-- look on top. Its art beyond settings (backdrop, ornaments)
-- is ThemeArt.lua's. Nothing here is protected: switching works in combat.
local Themes = {}
ns.Themes = Themes

Themes.CLASSIC = "CLASSIC"
Themes.IDS = Settings.THEMES
local SETS = "themeSets"

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise the texts keep their font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets. font, bar: its font and bar texture (Media
-- names); font is for the title (DISPLAY), bodyFont for the rows' names and
-- values (nil: font too); fontSizeAdd: how much larger the theme's font
-- must be to read like the others (not for a standard bodyFont). Text outline is the client's OUTLINE (never a hand-made soft
-- one: with these fonts that showed black text in Forever Unit Frames).
-- art (ThemeArt.lua, all of it inside the window's edge): back = backdrop
-- file in Media/Themes,
-- tint = its colour, ornament = corner piece, corners = which ones
-- (Corners.POINTS order: 1 top left, 2 top right, 3 bottom left, 4 bottom
-- right), ornamentInset = how far in from the window's corner, line =
-- colour of the title's line, darkTitle = a dark strip behind the title.
-- iconColor, iconHover: the title's icon buttons, every state (nil: their
-- usual gold and blue).
-- Old-style figures and small caps (or Bangers' weight) do not read at row
-- sizes: those themes keep the client's standard font in the rows.
local STANDARD = "Friz Quadrata"
-- Text styles that show the theme's own font; the others are body text.
local DISPLAY = { header = true }

Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the bars, a gold rim, brass rivets.
    WOOD = {
        font = "Cinzel", bar = "FCM Wood",
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 3, bgMode = "SOLID",
            bgColor = { 0.1, 0.06, 0.02 }, bgAlpha = 85, shadowEnabled = true, shadowAlpha = 60, shadowSize = 6 },
        art = { back = "WoodBack", ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 8,
            ornamentInset = 0, line = { 0.85, 0.65, 0.3, 0.6 } },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk", bar = "FCM Tech",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.02, 0.05, 0.08 }, bgAlpha = 92, shadowEnabled = false },
        art = { back = "TechBack", line = { 0.25, 0.88, 0.94, 0.6 } },
    },
    -- Parchment round the bars, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bodyFont = STANDARD, bar = "FCM Parchment", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
            bgMode = "SOLID", bgColor = { 0.22, 0.15, 0.07 }, bgAlpha = 72, shadowEnabled = true, shadowAlpha = 45,
            shadowSize = 5 },
        art = { back = "ParchmentBack", ornament = "Seal", corners = { 3 }, ornamentSize = 12,
            ornamentInset = 0, line = { 0.29, 0.2, 0.12, 0.8 } },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", bar = "FCM Stone", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.04, 0.05, 0.06 }, bgAlpha = 92, shadowEnabled = true, shadowAlpha = 70,
            shadowSize = 6 },
        art = { back = "StoneBack", ornament = "Rune", corners = { 1, 2 }, ornamentSize = 9,
            ornamentInset = 1, ornamentColor = { 0.35, 0.95, 0.85, 1 }, line = { 0.35, 0.95, 0.85, 0.5 } },
    },
    -- A mosaic of coloured glass round the bars, dark lead, a dark title.
    GLASS = {
        font = "Morpheus", bodyFont = STANDARD, bar = "FCM Glass", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.04, 0.06 }, bgAlpha = 90, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 6 },
        art = { back = "GlassBack", darkTitle = true, line = { 0.07, 0.06, 0.05, 1 } },
    },
    -- Thick ink line, halftone paper. The paper is the
    -- backdrop alone, grey as in the other Forever addons: no fill over it.
    COMIC = {
        font = "Bangers", bodyFont = STANDARD, bar = "FCM Comic", fontSizeAdd = 2, outline = "OUTLINE",
        -- Light icons vanish on the grey paper: dark ink, lighter on hover.
        iconColor = { 0.1, 0.1, 0.1 }, iconHover = { 0.4, 0.4, 0.4 },
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 }, cornerRadius = 0,
            bgAlpha = 0, shadowEnabled = false },
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, line = { 0.07, 0.07, 0.07, 1 } },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        font = "Cormorant SC", bodyFont = STANDARD, bar = "FCM Frost", fontSizeAdd = 2,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 }, cornerRadius = 6,
            bgMode = "SOLID", bgColor = { 0.04, 0.12, 0.22 }, bgAlpha = 75, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 8 },
        art = { back = "FrostBack", tint = { 1, 1, 1, 0.75 }, line = { 0.86, 0.96, 1, 0.5 } },
    },
    -- A light pixel frame, scan lines.
    PIXEL = {
        font = "VT323", bar = "FCM Pixel", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 100, shadowEnabled = false },
        art = { back = "PixelBack", line = { 1, 0.95, 0.91, 0.6 } },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 4

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

-- The profile's settings without the theme sets.
local function settingsOf(db)
    local t = {}
    for k, v in pairs(db) do
        if k ~= SETS then t[k] = copy(v) end
    end
    return t
end

-- The active profile's stored theme sets; stale ones (an older REVISION)
-- dropped.
local function storedSets()
    local db = ns.DB()
    if type(db[SETS]) ~= "table" then db[SETS] = {} end
    local sets = db[SETS]
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

function Themes.Current()
    local id = Settings.Get("theme")
    return Themes.SPECS[id] and id or Themes.CLASSIC
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- A new theme's settings: the base set (CLASSIC) with the theme's look.
local function seed(id, base)
    local spec, D = Themes.Spec(id), Settings.DEFAULTS
    local p = copy(base)
    for key, value in pairs(spec.look or {}) do p[key] = copy(value) end
    p.barTexture = spec.bar
    local latin = LATIN_CLIENTS[GetLocale()]
    for _, name in ipairs(Settings.TEXT_STYLES) do
        local font = DISPLAY[name] and spec.font or spec.bodyFont or spec.font
        if latin then p[name .. "Font"] = font end
        p[name .. "Flag"] = spec.outline or "OUTLINE"
        local size = p[name .. "Size"] or D[name .. "Size"]
        local add = font == spec.font and spec.fontSizeAdd or 0
        p[name .. "Size"] = Settings.Clamp(name .. "Size", size + add)
    end
    p.theme = id
    return p
end

-- The profile's settings replaced by p (the theme sets stay), defaults not
-- stored, as Settings.Set does.
local function write(p)
    local db, D = ns.DB(), Settings.DEFAULTS
    for k in pairs(db) do
        if k ~= SETS then db[k] = nil end
    end
    for k, v in pairs(p) do
        if k ~= SETS and not (D[k] ~= nil and Settings.SameValue(v, D[k])) then db[k] = v end
    end
end

local function use(p)
    write(p)
    Settings.Changed(nil)
end

-- Moves to theme id: the current settings are kept for the current theme,
-- id's come back (or are made, the first time). true, or nil and why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = settingsOf(ns.DB())
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile imported with a theme) the settings stay as they are.
        local base = sets[Themes.CLASSIC] or sets[current]
        nextSet = id == Themes.CLASSIC and copy(base) or seed(id, base)
    end
    nextSet.theme = id
    -- The live set is the profile: no stale copy stays behind.
    sets[id] = nil
    use(nextSet)
    return true
end

-- The current theme made anew from CLASSIC (its look, the player's
-- settings). Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == Themes.CLASSIC then return nil, "CLASSIC" end
    local base = storedSets()[Themes.CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(seed(id, base))
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- What places something: each window's anchor and offsets, the breakdown
-- panel's, the minimap button's angle. Sizes and scale stay the theme's.
local PLACEMENT = { "detailPoint", "detailX", "detailY", "minimapAngle" }
local WINDOW_PLACEMENT = { "point", "x", "y" }
local MAX_WINDOWS = Settings.RANGES.windowCount[2]

local function placementOf(p)
    local out = { windows = {} }
    for _, key in ipairs(PLACEMENT) do out[key] = copy(p[key]) end
    local own = type(p.windows) == "table" and p.windows or {}
    for i = 1, MAX_WINDOWS do
        local w = type(own[i]) == "table" and own[i] or {}
        out.windows[i] = {}
        for _, key in ipairs(WINDOW_PLACEMENT) do out.windows[i][key] = w[key] end
    end
    return out
end

-- Windows store only what differs from their defaults, which are the same
-- in every theme: a value missing here is the default there too.
local function place(values)
    local db = ns.DB()
    for _, key in ipairs(PLACEMENT) do db[key] = copy(values[key]) end
    local all = type(db.windows) == "table" and db.windows or {}
    for i, w in ipairs(values.windows) do
        local own = all[i] or {}
        for _, key in ipairs(WINDOW_PLACEMENT) do own[key] = w[key] end
        all[i] = next(own) and own or nil
    end
    db.windows = next(all) and all or nil
    Settings.Changed(nil)
end

-- The positions of theme `from` taken over into the current one. Returns
-- what it replaced (Themes.Restore puts it back), or nil and why not.
function Themes.CopyPlacement(from)
    local source = storedSets()[from]
    if not source then return nil, "GONE" end
    local undo = placementOf(ns.DB())
    place(placementOf(source))
    return undo
end

function Themes.Restore(undo)
    place(undo)
    return true
end

-- At login, before any window exists: a theme in use made under an older
-- REVISION is made anew from CLASSIC, quietly (nothing listens yet).
function Themes.Upgrade()
    local sets = ns.DB()[SETS]
    if type(sets) == "table" and sets.revision == Themes.REVISION then return end
    local base = type(sets) == "table" and sets[Themes.CLASSIC] or nil
    storedSets()
    local current = Themes.Current()
    if current == Themes.CLASSIC or not base then return end
    write(seed(current, base))
end

-- Runs before Windows.lua's login handler (TOC order).
ns.On("PLAYER_LOGIN", Themes.Upgrade)

-- For a theme picker in another addon: the same as choosing a theme in the
-- options (the options window follows through Settings.Changed).
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes["ForeverCombatMeter"] = {
    title = "Forever Combat Meter",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
}
