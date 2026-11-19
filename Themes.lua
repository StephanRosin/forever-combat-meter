local ADDON, ns = ...
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

local Lib = LibForeverThemes
Themes.CLASSIC = Lib.CLASSIC
local SETS = "themeSets"

-- Each theme's identity (backdrop, tint, ornament, rule, strip, wedge, ring
-- colour, fonts) is LibForeverThemes'; here only the meter's part on top.
-- look: settings the theme sets (borderColor: the family's ring colour).
-- bar: its bar texture (a Media name). font is for the title (DISPLAY),
-- bodyFont for the rows' names and values (nil: font too); fontSizeAdd:
-- how much larger the theme's font must be to read like the others (not
-- for a standard bodyFont). Text outline is the client's OUTLINE (never a
-- hand-made soft one: with these fonts that showed black text in Forever
-- Unit Frames); Frost's is a soft drop shadow (SHADOW) without an outline.
-- bodyOutline: the rows' flag instead (Runestone: OUTLINESHADOW, so white
-- names read on a white bar). ink: the page is light (Azeroth), notes
-- written straight on it in dark ink.
-- art (ThemeArt.lua, all of it inside the window's edge but the library's
-- frame round it), the library's back, tint, ornament, corners,
-- ornamentColor, rule, strip, wedge, frame and banner with:
-- bannerHeight = the banner this high (nil: the header's inside the ring),
-- ornamentSize, ornamentInset = how far in from the window's corner, line =
-- colour of the title's line, darkTitle = the plain dark strip behind the
-- title.
-- iconColor, iconHoverColor (the library's comic ink): the title's icon
-- buttons in ink, every state (nil: the colour's accent, Themes.IconAccent).
-- Old-style figures and small caps (or Bangers' weight) do not read at row
-- sizes: those themes keep the client's standard font in the rows (the
-- library's bodyFont).
-- Text styles that show the theme's own font; the others are body text.
local DISPLAY = { header = true }

Themes.SPECS = Lib.Specs({
    -- Oak boards round the bars, a gold rim, brass rivets.
    WOOD = {
        bar = "FCM Wood",
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 3, bgMode = "SOLID",
            bgColor = { 0.1, 0.06, 0.02 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60, shadowSize = 6 },
        art = { ornamentSize = 8, ornamentInset = 0, line = { 0.85, 0.65, 0.3, 0.6 } },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        bar = "FCM Tech",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.TECH.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.02, 0.05, 0.08 }, bgAlpha = 0, shadowEnabled = false },
        art = { line = { 0.25, 0.88, 0.94, 0.6 } },
    },
    -- Parchment round the bars, a brown ink line, a wax seal.
    PARCHMENT = {
        bar = "FCM Parchment",
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.PARCHMENT.rim, cornerRadius = 2,
            bgMode = "SOLID", bgColor = { 0.22, 0.15, 0.07 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 45,
            shadowSize = 5 },
        art = { ornamentSize = 12, ornamentInset = 0, line = { 0.29, 0.2, 0.12, 0.8 } },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        bar = "FCM Stone", bodyOutline = "OUTLINESHADOW",
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.RUNESTONE.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.04, 0.05, 0.06 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 70,
            shadowSize = 6 },
        art = { ornamentSize = 9, ornamentInset = 1, line = { 0.35, 0.95, 0.85, 0.5 } },
    },
    -- A mosaic of coloured glass round the bars, dark lead, a dark title.
    GLASS = {
        bar = "FCM Glass",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.GLASS.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.04, 0.06 }, bgAlpha = 90, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 6 },
        art = { darkTitle = true, line = { 0.07, 0.06, 0.05, 1 } },
    },
    -- Thick ink line, halftone paper. The paper is the
    -- backdrop alone, grey as in the other Forever addons: no fill over it.
    -- Light icons vanish on the grey paper: the library's dark ink.
    COMIC = {
        bar = "FCM Comic", outline = "OUTLINE",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.COMIC.rim, cornerRadius = 0,
            bgAlpha = 0, shadowEnabled = false },
        art = { line = { 0.07, 0.07, 0.07, 1 } },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        bar = "FCM Frost", outline = "SHADOW",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.FROST.rim, cornerRadius = 6,
            bgMode = "SOLID", bgColor = { 0.02, 0.07, 0.15 }, bgAlpha = 45, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 8 },
        art = { line = { 0.86, 0.96, 1, 0.5 } },
    },
    -- A light pixel frame, scan lines.
    PIXEL = {
        bar = "FCM Pixel",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.PIXEL.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = false },
        art = { line = { 1, 0.95, 0.91, 0.6 } },
    },
    -- Swiss style: flat black, a white rule along the top, grey hairlines,
    -- one red accent.
    SWISS = {
        bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.SWISS.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false,
            headerColor = { 1, 0.176, 0.125 }, nameColor = { 0.949, 0.949, 0.949 },
            valueColor = { 0.949, 0.949, 0.949 } },
        art = { line = { 0.165, 0.165, 0.165, 1 } },
    },
    -- A terminal: near black, a mint line. The rows in the narrow title
    -- face, not the library's monospaced body font: more of a name fits.
    CONSOLE = {
        bodyFont = "IBM Plex Sans Condensed Bold", bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.CONSOLE.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.059, 0.059, 0.075 }, bgAlpha = 0, shadowEnabled = false,
            headerColor = { 0.306, 0.929, 0.69 }, nameColor = { 0.902, 0.91, 0.933 },
            valueColor = { 0.902, 0.91, 0.933 } },
        art = { line = { 0.545, 0.565, 0.627, 0.5 } },
    },
    -- A motorsport timing screen: flat black with a carbon hairline, a black title strip with
    -- a red wedge, the bars on black.
    PITWALL = {
        bar = "FCM Swiss",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.PITWALL.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false, headerColor = { 0.949, 0.953, 0.961 },
            nameColor = { 0.949, 0.953, 0.961 }, valueColor = { 0.949, 0.953, 0.961 } },
        art = { line = { 0, 0, 0, 1 } },
    },
    -- A window of the game's own world: light parchment in a walnut frame,
    -- a gold ring and corners, the title in gold on a red banner. The rows
    -- keep their light outlined text: it stands on the bars.
    AZEROTH = {
        bar = "FCM Parchment", ink = true,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.AZEROTH.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 8, headerColor = { 1, 0.82, 0 }, headerLine = false, barBgAlpha = 40 },
        art = { ornamentSize = 14, ornamentInset = 0 },
    },
    -- A goblin workshop: sooty sheet metal in a copper frame with rivets, a
    -- thin strip of warning stripes along the top (no text on it).
    GOBLIN = {
        -- Bungee runs wide: a point smaller keeps the title from cutting short.
        bar = "FCM Tech", fontSizeAdd = -1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.GOBLIN.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 8, headerColor = { 0.95, 0.76, 0.19 } },
        art = { ornamentSize = 8, ornamentInset = 0, bannerHeight = 5, line = { 0.72, 0.45, 0.2, 0.6 } },
    },
}, true) -- the HD themes too, each from its base theme's part here
-- Glass HD is there to show its glass: the dark fill over it at 60 % (Glass: 90 %).
Themes.SPECS.GLASS_HD.look.bgAlpha = 60

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched. The library's part counts too: a change
-- there to what seeding copies (fonts, sizes, ring colour) raises it.
local OWN_REVISION = 15

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

-- Comic's first colour was GREY before new Comic sets started in BLACK
-- (AUTHOR_COLORS): a profile that wears or keeps a Comic set without a
-- stored colour has it pinned to GREY once, so a later reseed (which makes
-- the Comic set anew) never turns its paper black.
local function pinComicGrey(db, sets)
    if sets.comicGreyPinned then return end
    sets.themeColors = sets.themeColors or {}
    local colors = sets.themeColors
    if not (colors.COMIC or sets.comicColor) and (db.theme == "COMIC" or sets.COMIC) then colors.COMIC = "GREY" end
    sets.comicGreyPinned = true
end

-- The active profile's stored theme sets; stale ones (an older revision)
-- dropped.
local function storedSets()
    local db = ns.DB()
    if type(db[SETS]) ~= "table" then db[SETS] = {} end
    local sets = db[SETS]
    pinComicGrey(db, sets)
    if Lib.NeedsReseed(sets, OWN_REVISION) then
        for _, id in ipairs(Lib.SpecIds(Themes.SPECS)) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        Lib.MarkSeeded(sets, OWN_REVISION)
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

-- Theme colours: a backdrop colour and an accent per theme, the library's
-- (Lib.COLORS), the same in every Forever addon; picked apart from the
-- theme sets: kept next to them per profile (themeColors = { [theme] =
-- colour id }), so switching themes never loses them and the stored looks
-- stay as they are (applied when drawn). The first colour of each theme is
-- the theme as it was (nothing applied).

-- The colour ids of themeId (default the current theme) in menu order;
-- none for CLASSIC.
function Themes.Colors(themeId)
    return Lib.Colors(themeId or Themes.Current())
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
    if not Lib.COLORS[themeId] then return nil end
    return Lib.ValidColor(themeId, chosen()[themeId])
end

-- Picks colour id for themeId (default the current theme); repaints at once
-- while that theme is in use. true, or nil and why not.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    chosen()[themeId] = id
    if themeId == Themes.Current() then Settings.Changed(nil) end
    return true
end

-- The backdrop's file (a library texture name) and tint { r, g, b, a } for
-- art: a comic colour tints the paper; any other colour takes the grey
-- file, tinted to its mean colour, at the theme's alpha; the first colour
-- leaves art as it is.
function Themes.Backdrop(art)
    local id, color = Themes.Current(), Themes.Color()
    return Lib.Back(art, id, color), Lib.Tint(art, id, color)
end

-- Whether COMIC is in use on a dark paper.
function Themes.DarkPaper()
    return Lib.DarkPaper(Themes.Current(), Themes.Color())
end

-- The title colour to draw: the colour's accent, or color as stored.
function Themes.Accent(color)
    return Lib.Accent(Themes.Current(), Themes.Color()) or color
end

-- The border colour to draw: the colour's rim, or color as stored.
function Themes.Rim(color)
    return Lib.Rim(Themes.Current(), Themes.Color()) or color
end

-- The colour the title's icons take (ThemeArt.IconColor): the colour's
-- accent (the title's), on Pitwall the wedge's, as the colour changes it
-- there; nil under CLASSIC and the comic (its own ink).
function Themes.IconAccent()
    local id = Themes.Current()
    local c = Lib.IconColor(Themes.Spec(id), id, Themes.Color(), Settings.Get("headerColor"))
    return c and { c[1], c[2], c[3] }
end

-- The author's look in every theme on top of the specs' (new in 1.3.0):
-- bars without a track, the breakdown's bars in one grey. Only for theme
-- sets made from now on; CLASSIC keeps the defaults. Not counted in
-- the revision: sets made before stay as they are.
local AUTHOR_LOOK = { barBgAlpha = 0, detailClassColor = false, detailBarColor = { 0.329, 0.322, 0.318 } }
-- The colour a theme starts in the first time where the author's differs
-- from the theme's first (Themes.Switch).
local AUTHOR_COLORS = { COMIC = "BLACK" }

-- A new theme's settings: the base set (CLASSIC) with the theme's look.
local function seed(id, base)
    local spec, D = Themes.Spec(id), Settings.DEFAULTS
    local p = copy(base)
    for key, value in pairs(AUTHOR_LOOK) do p[key] = copy(value) end
    for key, value in pairs(spec.look or {}) do p[key] = copy(value) end
    p.barTexture = spec.bar
    local latin = Lib.LatinClient()
    for _, name in ipairs(Settings.TEXT_STYLES) do
        local font = DISPLAY[name] and spec.font or spec.bodyFont or spec.font
        if latin then p[name .. "Font"] = font end
        p[name .. "Flag"] = not DISPLAY[name] and spec.bodyOutline or spec.outline or "OUTLINE"
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

-- p as write stores it (no defaults, no theme): to compare sets.
local function stored(p)
    local t, D = {}, Settings.DEFAULTS
    for k, v in pairs(p) do
        if k ~= SETS and k ~= "theme" and not (D[k] ~= nil and Settings.SameValue(v, D[k])) then t[k] = v end
    end
    return t
end

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
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
    -- A base and its HD theme share their settings: only the look changes.
    if Lib.SetKey(id) == Lib.SetKey(current) then
        ns.DB().theme = id
        Settings.Changed(nil)
        return true
    end
    local sets = storedSets()
    sets[Lib.SetKey(current)] = settingsOf(ns.DB())
    local nextSet = sets[Lib.SetKey(id)]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile imported with a theme) the settings stay as they are.
        local base = sets[Themes.CLASSIC] or sets[current]
        nextSet = id == Themes.CLASSIC and copy(base) or seed(id, base)
        local colors = chosen()
        colors[id] = colors[id] or AUTHOR_COLORS[id]
    end
    nextSet.theme = id
    -- The live set is the profile: no stale copy stays behind.
    sets[Lib.SetKey(id)] = nil
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

-- The themes with stored settings to copy from, in the menu's order; an HD
-- theme's are its base's.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Lib.MenuIds(Lib.SpecIds(Themes.SPECS))) do
        if sets[id] and id ~= Lib.SetKey(Themes.Current()) then list[#list + 1] = id end
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
-- revision is made anew from CLASSIC, quietly (nothing listens yet).
function Themes.Upgrade()
    local sets = ns.DB()[SETS]
    -- Before LibForeverThemes 9 a base and its HD theme had a set each:
    -- made one; a customised HD set wins.
    if type(sets) == "table" then
        local current = Themes.Current()
        local merged = Lib.MergeHD(sets, current, settingsOf(ns.DB()), function(hdId, set)
            local classic = sets[Themes.CLASSIC] or (current == Themes.CLASSIC and settingsOf(ns.DB()))
            return not (classic and same(stored(set), stored(seed(hdId, classic))))
        end)
        if merged then write(merged) end
    end
    if type(sets) == "table" and not Lib.NeedsReseed(sets, OWN_REVISION) then return end
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
Lib.Register(ADDON, {
    title = "Forever Combat Meter",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    -- After another addon (the InfoPanel's right column) wrote the stored
    -- settings: apply them as after a change in the options.
    Refresh = function() Settings.Changed(nil) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
})

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- registered above.
function Themes.HasOthers() return #Lib.Others(ADDON) > 0 end

-- Every other addon onto this theme and, where that theme has it, this
-- colour. Returns how many switched.
function Themes.ApplyToAll()
    return Lib.ApplyToAll(ADDON, Themes.Current(), Themes.Color())
end
