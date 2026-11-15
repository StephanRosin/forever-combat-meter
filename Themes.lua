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
-- one: with these fonts that showed black text in Forever Unit Frames); Frost's is
-- a soft drop shadow (SHADOW) without an outline.
-- art (ThemeArt.lua, all of it inside the window's edge): back = backdrop
-- file in Media/Themes,
-- tint = its colour, ornament = corner piece, corners = which ones
-- (Corners.POINTS order: 1 top left, 2 top right, 3 bottom left, 4 bottom
-- right), ornamentInset = how far in from the window's corner, line =
-- colour of the title's line, darkTitle = a dark strip behind the title
-- (true, or its colour), band = a strip { color, height } along the top
-- edge. wedge = a piece at the title strip's start in wedgeColor (the
-- title begins after it, ThemeArt.TitleIndent).
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
        font = "Cinzel", bodyFont = STANDARD, bar = "FCM Wood",
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
        font = "Cinzel", bodyFont = STANDARD, bar = "FCM Frost", outline = "SHADOW",
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
    -- Swiss style: flat black, a white rule along the top, grey hairlines,
    -- one red accent.
    SWISS = {
        font = "Inter Tight Bold", bodyFont = "Inter Tight", bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.165, 0.165, 0.165, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false,
            headerColor = { 1, 0.176, 0.125 }, nameColor = { 0.949, 0.949, 0.949 },
            valueColor = { 0.949, 0.949, 0.949 } },
        art = { back = "SwissBack", line = { 0.165, 0.165, 0.165, 1 },
            band = { color = { 0.949, 0.949, 0.949, 1 }, height = 3 } },
    },
    -- A terminal: near black, a mint line, monospaced figures.
    CONSOLE = {
        font = "IBM Plex Sans Condensed Bold", bodyFont = "IBM Plex Mono", bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.306, 0.929, 0.69, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.059, 0.059, 0.075 }, bgAlpha = 92, shadowEnabled = false,
            headerColor = { 0.306, 0.929, 0.69 }, nameColor = { 0.902, 0.91, 0.933 },
            valueColor = { 0.902, 0.91, 0.933 } },
        art = { back = "ConsoleBack", line = { 0.545, 0.565, 0.627, 0.5 } },
    },
    -- A motorsport timing screen: flat black with a carbon hairline, a black title strip with
    -- a red wedge, the bars on black.
    PITWALL = {
        font = "Titillium Web Bold Italic", bodyFont = "Titillium Web SemiBold", bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.043, 0.047, 0.055, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false, headerColor = { 0.949, 0.953, 0.961 },
            nameColor = { 0.949, 0.953, 0.961 }, valueColor = { 0.949, 0.953, 0.961 } },
        art = { back = "SwissBack", darkTitle = { 0, 0, 0, 1 }, line = { 0, 0, 0, 1 },
            wedge = "PitwallWedge", wedgeColor = { 0.882, 0.024, 0, 1 } },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 9

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

-- Theme colours: a backdrop colour and an accent per theme, picked apart
-- from the theme sets: kept next to them per profile (themeColors =
-- { [theme] = colour id }), so switching themes never loses them and the
-- stored looks stay as they are (applied when drawn). The first colour of
-- each theme is the theme as it was (nothing applied). Same ids and values
-- in every Forever addon.
-- paper (COMIC): the tint of the theme's own light paper; dark: on a dark
-- paper what is dark ink elsewhere is drawn light. back (every other
-- theme): the mean colour the backdrop is drawn in, from a grey version of
-- the theme's texture (<Name>BackGrey.tga). accent: the heading colour
-- instead of the theme's; none = the theme's. rim: the border colour
-- instead of the stored one (only Console's colours and Handheld: every
-- Forever addon draws the same ring per theme and colour); ornament: the
-- ornaments' colour.
local YELLOW_ACCENT = { 1.00, 0.90, 0.10 }
local BLUE_ACCENT = { 0.15, 0.45, 0.95 }
local PICO_YELLOW = { 1, 0.93, 0.15 }
local HANDHELD_GREEN = { 0.784, 0.941, 0.439, 1 }
Themes.COLORS = {
    WOOD = {
        { id = "OAK" },
        { id = "WALNUT", back = { 0.15, 0.09, 0.06 } },
        { id = "BIRCH", back = { 0.38, 0.32, 0.22 } },
        { id = "CHERRY", back = { 0.30, 0.12, 0.08 } },
        { id = "EBONY", back = { 0.08, 0.07, 0.07 } },
        { id = "DRIFTWOOD", back = { 0.25, 0.24, 0.22 } },
    },
    TECH = {
        { id = "CYAN" },
        { id = "GREEN", back = { 0.02, 0.10, 0.05 }, accent = { 0.30, 0.95, 0.45 } },
        { id = "AMBER", back = { 0.10, 0.07, 0.02 }, accent = { 1, 0.75, 0.20 } },
        { id = "MAGENTA", back = { 0.09, 0.03, 0.10 }, accent = { 0.95, 0.40, 0.95 } },
        { id = "BLUE", back = { 0.03, 0.05, 0.13 }, accent = { 0.45, 0.65, 1 } },
        { id = "GREY", back = { 0.07, 0.07, 0.08 }, accent = { 0.85, 0.88, 0.90 } },
    },
    PARCHMENT = {
        { id = "CLASSIC" },
        { id = "AGED", back = { 0.32, 0.25, 0.15 } },
        { id = "ASH", back = { 0.33, 0.33, 0.31 } },
        { id = "SEA", back = { 0.25, 0.30, 0.33 } },
        { id = "ROSE", back = { 0.36, 0.27, 0.26 } },
        { id = "DARK", back = { 0.20, 0.17, 0.13 } },
    },
    RUNESTONE = {
        { id = "GRANITE" },
        { id = "SANDSTONE", back = { 0.33, 0.27, 0.18 }, accent = { 1, 0.80, 0.35 } },
        { id = "SLATE", back = { 0.15, 0.18, 0.25 }, accent = { 0.55, 0.75, 1 } },
        { id = "MOSS", back = { 0.15, 0.22, 0.14 }, accent = { 0.50, 1, 0.45 } },
        { id = "OBSIDIAN", back = { 0.07, 0.06, 0.09 }, accent = { 0.75, 0.50, 1 } },
    },
    GLASS = {
        { id = "CATHEDRAL" },
        { id = "BLUE", back = { 0.08, 0.12, 0.28 } },
        { id = "GREEN", back = { 0.07, 0.20, 0.10 } },
        { id = "AMBER", back = { 0.28, 0.17, 0.05 } },
        { id = "VIOLET", back = { 0.18, 0.08, 0.26 } },
        { id = "RUBY", back = { 0.26, 0.05, 0.08 } },
    },
    COMIC = {
        { id = "GREY" },
        { id = "DARKGREY", paper = { 0.38, 0.38, 0.38 }, accent = YELLOW_ACCENT, dark = true },
        { id = "BLACK", paper = { 0.16, 0.16, 0.16 }, accent = YELLOW_ACCENT, dark = true },
        { id = "WHITE", paper = { 1.00, 1.00, 1.00 }, accent = BLUE_ACCENT },
        { id = "YELLOW", paper = { 0.86, 0.76, 0.36 }, accent = BLUE_ACCENT },
        { id = "BLUE", paper = { 0.45, 0.60, 0.86 }, accent = YELLOW_ACCENT },
        { id = "RED", paper = { 0.86, 0.44, 0.40 }, accent = YELLOW_ACCENT },
        { id = "GREEN", paper = { 0.50, 0.76, 0.46 }, accent = YELLOW_ACCENT },
        { id = "PURPLE", paper = { 0.70, 0.52, 0.84 }, accent = YELLOW_ACCENT },
    },
    FROST = {
        { id = "ICE" },
        { id = "DEEP", back = { 0.10, 0.18, 0.32 }, accent = { 0.60, 0.85, 1 } },
        { id = "AURORA", back = { 0.10, 0.27, 0.24 }, accent = { 0.55, 1, 0.80 } },
        { id = "VIOLET", back = { 0.22, 0.18, 0.33 }, accent = { 0.85, 0.75, 1 } },
        { id = "SILVER", back = { 0.30, 0.31, 0.33 }, accent = { 0.92, 0.92, 0.95 } },
        { id = "NIGHT", back = { 0.06, 0.08, 0.14 }, accent = { 0.70, 0.85, 1 } },
    },
    -- PICO-8's palette.
    PIXEL = {
        { id = "NAVY" },
        { id = "PLUM", back = { 0.23, 0.08, 0.16 }, accent = PICO_YELLOW },
        { id = "FOREST", back = { 0.00, 0.20, 0.12 }, accent = PICO_YELLOW },
        { id = "BROWN", back = { 0.20, 0.12, 0.08 }, accent = { 1, 0.64, 0.00 } },
        { id = "GREY", back = { 0.18, 0.17, 0.16 } },
        { id = "BLACK", back = { 0.03, 0.03, 0.04 }, accent = { 0, 0.89, 0.21 } },
        { id = "TEAL", back = { 0.02, 0.17, 0.22 }, accent = { 0.16, 0.68, 1 } },
        { id = "PURPLE", back = { 0.15, 0.10, 0.25 }, accent = { 1, 0.47, 0.66 } },
        { id = "HANDHELD", back = { 0.059, 0.122, 0.059 }, accent = HANDHELD_GREEN, rim = HANDHELD_GREEN },
    },
    -- The backdrop stays in every colour of the last three.
    SWISS = {
        { id = "RED" },
        { id = "BLUE", accent = { 0.176, 0.42, 1 } },
        { id = "YELLOW", accent = { 1, 0.82, 0 } },
        { id = "WHITE", accent = { 0.949, 0.949, 0.949 } },
    },
    -- The line follows the accent.
    CONSOLE = {
        { id = "MINT" },
        { id = "AMBER", accent = { 1, 0.69, 0 }, rim = { 1, 0.69, 0, 1 } },
        { id = "PHOSPHOR", accent = { 0.224, 1, 0.078 }, rim = { 0.224, 1, 0.078, 1 } },
        { id = "VIOLET", accent = { 0.627, 0.471, 1 }, rim = { 0.627, 0.471, 1, 1 } },
    },
    -- The wedge's colour.
    PITWALL = {
        { id = "RED" },
        { id = "ORANGE", ornament = { 1, 0.541, 0, 1 } },
        { id = "TEAL", ornament = { 0, 0.631, 0.612, 1 } },
        { id = "SILVER", ornament = { 0.788, 0.808, 0.839, 1 } },
    },
}
-- The mean grey of each <Name>BackGrey.tga: a backdrop colour is drawn as
-- vertex colour back / mean (at most 1). Swiss, Console and Pitwall have
-- no back colours, so no grey file.
Themes.GREY_MEAN = { Wood = 0.800, Tech = 0.705, Parchment = 0.799, Stone = 0.800, Glass = 0.777, Frost = 0.796,
    Pixel = 0.800 }

-- The colour ids of themeId (default the current theme) in menu order;
-- none for CLASSIC.
function Themes.Colors(themeId)
    local list = {}
    for _, c in ipairs(Themes.COLORS[themeId or Themes.Current()] or {}) do list[#list + 1] = c.id end
    return list
end

local function colorOf(themeId, id)
    for _, c in ipairs(Themes.COLORS[themeId] or {}) do
        if c.id == id then return c end
    end
end

-- The stored choices; a comicColor from before them moved in once.
local function chosen()
    local sets = storedSets()
    sets.themeColors = sets.themeColors or {}
    if sets.comicColor then
        sets.themeColors.COMIC = sets.themeColors.COMIC or sets.comicColor
        sets.comicColor = nil
    end
    return sets.themeColors
end

-- The colour id of themeId (default the current theme): the stored one or
-- the theme's first; nil for CLASSIC.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local list = Themes.COLORS[themeId]
    if not list then return nil end
    local id = chosen()[themeId]
    return colorOf(themeId, id) and id or list[1].id
end

-- Picks colour id for themeId (default the current theme); repaints at once
-- while that theme is in use. true, or nil and why not.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not colorOf(themeId, id) then return nil, "UNKNOWN" end
    chosen()[themeId] = id
    if themeId == Themes.Current() then Settings.Changed(nil) end
    return true
end

-- The colour in use, nil while it is the theme's first (the theme as it is).
local function palette()
    local themeId = Themes.Current()
    local id = Themes.Color(themeId)
    if not id or id == Themes.COLORS[themeId][1].id then return nil end
    return colorOf(themeId, id)
end

-- The backdrop's file (in Media/Themes) and tint { r, g, b, a } for art:
-- a comic colour tints the paper; any other colour takes the grey file,
-- tinted to its mean colour (back / the grey's mean, at most 1), at the
-- theme's alpha; the first colour leaves art as it is.
function Themes.Backdrop(art)
    local p = palette()
    if p and p.paper then return art.back, { p.paper[1], p.paper[2], p.paper[3], 1 } end
    local mean = p and p.back and Themes.GREY_MEAN[art.back:match("^(%a+)Back$")]
    if not mean then return art.back, art.tint end
    local b = p.back
    return art.back .. "Grey", { math.min(1, b[1] / mean), math.min(1, b[2] / mean), math.min(1, b[3] / mean),
        art.tint and art.tint[4] or 1 }
end

-- Whether COMIC is in use on a dark paper.
function Themes.DarkPaper()
    local p = palette()
    return p ~= nil and p.dark == true
end

-- The title colour to draw: the colour's accent, or color as stored.
function Themes.Accent(color)
    local p = palette()
    return p and p.accent or color
end

-- The border colour to draw: the colour's rim, or color as stored.
function Themes.Rim(color)
    local p = palette()
    return p and p.rim or color
end

-- The ornaments' colour to draw: the colour's, or color (the theme's).
function Themes.Ornament(color)
    local p = palette()
    return p and p.ornament or color
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
    -- After another addon (the InfoPanel's right column) wrote the stored
    -- settings: apply them as after a change in the options.
    Refresh = function() Settings.Changed(nil) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
}

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- in the list above. Each Forever addon has its own copy of this.
local function otherThemes()
    local list = {}
    for folder, entry in pairs(_G.ForeverThemes) do
        if folder ~= "ForeverCombatMeter" and type(entry) == "table" and type(entry.Switch) == "function" then
            list[#list + 1] = entry
        end
    end
    return list
end

function Themes.HasOthers() return #otherThemes() > 0 end

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- Every other addon onto this theme and, where that theme has it, this
-- colour (else it keeps its own). One without the theme refuses the switch
-- and is skipped. Returns how many switched.
function Themes.ApplyToAll()
    local theme, color, switched = Themes.Current(), Themes.Color(), 0
    for _, entry in ipairs(otherThemes()) do
        if entry.Switch(theme) then
            switched = switched + 1
            if color and type(entry.Colors) == "function" and type(entry.SetColor) == "function"
                and listed(entry.Colors(theme), color) then
                entry.SetColor(color, theme)
            end
        end
    end
    return switched
end
