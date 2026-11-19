--[[---------------------------------------------------------------------------
LibForeverThemes -- the Forever addons' themes in one place (DESIGN.md).

Embedded in every themed Forever addon under Libs/LibForeverThemes, listed
in its TOC before the addon's own files. Every copy is the same file; the
newest loaded (MINOR) wins: it fills the one table _G.LibForeverThemes in
place, so an addon that keeps `local Lib = LibForeverThemes` uses the
newest code and data even when that copy loads after it. An older copy
loading later does nothing.

What lives here: the theme ids, each theme's identity (backdrop, tint,
ornaments, wedge, ring colour, fonts), the theme colours, the textures and
fonts (Media/, under the winning copy's folder) and the helpers that turn a
theme and a colour into what to draw. What stays in each addon: its
settings per theme (look), its geometry (padding, ornament sizes), its
saved variables, theme sets, REVISION and seeding, and its options.
Nothing here keeps state; every helper takes the theme and colour ids.

Not to be confused with _G.ForeverThemes: that is the registry of the
addons for the cross-addon theme menu (Lib.Register fills it).
---------------------------------------------------------------------------]]
local FOLDER = ...
local MINOR = 9

local shared = _G.LibForeverThemes
-- `or 0`: a copy before MINOR 3 could throw half way and leave no MINOR.
if shared and (shared.MINOR or 0) >= MINOR then return end
-- Filled here first and moved into the shared table only at the end of the
-- file: a copy that throws on the way leaves the loaded one untouched.
local lib = {}
lib.FOLDER = FOLDER

-- This copy's media, in the addon folder that loaded it.
local MEDIA = "Interface\\AddOns\\" .. FOLDER .. "\\Libs\\LibForeverThemes\\Media\\"
function lib.Texture(name) return MEDIA .. "Themes\\" .. name end

-- Raised when a value addons copy into their theme sets (fonts, sizes,
-- ring colour) changes, so their stored sets are made anew (NeedsReseed).
-- SEED_STEP: only for addons before MINOR 3, which add SEED_REVISION *
-- SEED_STEP to their own REVISION at load.
lib.SEED_REVISION = 0
lib.SEED_STEP = 1000

-- Whether an addon's stored theme sets must be made anew: older than its
-- own revision or than the library's seeded values. Both kept apart and
-- compared with `<`, at call time: which copy won, or an addon with the
-- newest copy being turned off, does not reseed again and again.
function lib.NeedsReseed(sets, ownRevision)
    return (tonumber(sets.revision) or 0) < ownRevision
        or (tonumber(sets.seedRevision) or 0) < lib.SEED_REVISION
end

-- Notes on sets that they are made for ownRevision and this library.
function lib.MarkSeeded(sets, ownRevision)
    sets.revision, sets.seedRevision = ownRevision, lib.SEED_REVISION
end

lib.CLASSIC = "CLASSIC"
-- In the options' order; new themes go at the end.
lib.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL", "SWISS",
    "CONSOLE", "PITWALL", "WOOD_HD", "TECH_HD", "PARCHMENT_HD", "RUNESTONE_HD", "GLASS_HD", "COMIC_HD", "FROST_HD" }

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise a text keeps its font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }
function lib.LatinClient() return LATIN_CLIENTS[GetLocale()] == true end

-- Fonts (SIL Open Font License, Media/Fonts/OFL.txt and FONTS.txt), by the
-- name settings store. Names stay forever: saved variables hold them.
local FONT_FILES = {
    { "Bangers", "Bangers-Regular.ttf" },
    { "Cinzel", "Cinzel-Bold.ttf" },
    { "IBM Plex Mono", "IBMPlexMono-Regular.ttf" },
    { "IBM Plex Sans Condensed Bold", "IBMPlexSansCondensed-Bold.ttf" },
    { "IM Fell English SC", "IMFeENsc28P.ttf" },
    { "Inter Tight", "InterTight-Regular.ttf" },
    { "Inter Tight Bold", "InterTight-Bold.ttf" },
    { "Inter Tight Light", "InterTight-Light.ttf" },
    { "Julius Sans One", "JuliusSansOne-Regular.ttf" },
    { "Marcellus", "Marcellus-Regular.ttf" },
    { "Space Grotesk", "SpaceGrotesk-Bold.ttf" },
    { "Titillium Web Bold Italic", "TitilliumWeb-BoldItalic.ttf" },
    { "Titillium Web SemiBold", "TitilliumWeb-SemiBold.ttf" },
    { "VT323", "VT323-Regular.ttf" },
}
-- Older names some addons stored for the same files.
local FONT_ALIASES = {
    ["IBM Plex Sans Condensed"] = "IBM Plex Sans Condensed Bold",
    ["Titillium Web"] = "Titillium Web SemiBold",
}
-- { name, path } in the list's order, for an addon's font menu.
lib.FONTS = {}
for i, f in ipairs(FONT_FILES) do lib.FONTS[i] = { name = f[1], path = MEDIA .. "Fonts\\" .. f[2] } end

local function ourFont(name)
    for _, f in ipairs(lib.FONTS) do
        if f.name == name then return f end
    end
    return nil
end

-- A font LibSharedMedia knows under name (someone's own font of an alias's
-- name must not be swapped for ours).
local function sharedFont(name)
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return type(lsm) == "table" and type(lsm.Fetch) == "function" and lsm:Fetch("font", name, true) ~= nil
end

-- The name a stored font name stands for: an alias's file's name, unless
-- the name is otherwise known (LibSharedMedia). An addon with own fonts of
-- such a name looks them up first and asks this only as a fallback.
function lib.FontName(name)
    local alias = FONT_ALIASES[name]
    if alias and not sharedFont(name) then return alias end
    return name
end

-- The file of one of our fonts (an alias as FontName), or nil for any other.
function lib.FontPath(name)
    local f = ourFont(name) or ourFont(lib.FontName(name))
    return f and f.path or nil
end

-- Each theme's identity, the same in every Forever addon; an addon puts
-- its own settings (look) and geometry on top (lib.Specs).
-- back: backdrop file in Media/Themes, tinted `tint` (light papers toned
-- down, Frost dimmed at alpha 0.85); ornament: corner piece (corners in
-- the order top left, top right, bottom left, bottom right), tinted
-- ornamentColor; rule: a line ruleSize thick along the top (Swiss);
-- strip: the title's colour over the backdrop, wedge: a slanted band at its
-- left in wedgeColor (Pitwall); rim: the ring's colour (the same in every
-- addon, Quest Log's; Wood draws its gold ring instead); font: titles and
-- headings, fontSizeAdd: how much larger they must be to read like the
-- others; bodyFont: every other text's (nil: as it is); iconColor /
-- iconHoverColor: dark ink for icons on a light paper.
lib.THEMES = {
    CLASSIC = {},
    WOOD = { back = "WoodBack", tint = { 0.5, 0.5, 0.5, 1 }, ornament = "Rivet", corners = { 1, 2, 3, 4 },
        rim = { 0.906, 0.702, 0.161, 1 }, font = "Cinzel", bodyFont = "Friz Quadrata" },
    TECH = { back = "TechBack", rim = { 0.25, 0.88, 0.94, 0.9 }, font = "Space Grotesk" },
    PARCHMENT = { back = "ParchmentBack", tint = { 0.45, 0.45, 0.45, 1 }, ornament = "Seal", corners = { 3 },
        rim = { 0.29, 0.2, 0.12, 1 }, font = "IM Fell English SC", fontSizeAdd = 1, bodyFont = "Friz Quadrata" },
    RUNESTONE = { back = "StoneBack", tint = { 0.55, 0.55, 0.55, 1 }, ornament = "Rune", corners = { 1, 2 },
        ornamentColor = { 0.35, 0.95, 0.85, 1 }, rim = { 0.1, 0.1, 0.12, 1 }, font = "Marcellus", fontSizeAdd = 1 },
    GLASS = { back = "GlassBack", rim = { 0.07, 0.06, 0.05, 1 }, font = "Morpheus", fontSizeAdd = 1,
        bodyFont = "Friz Quadrata" },
    COMIC = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, rim = { 0.07, 0.07, 0.07, 1 }, font = "Bangers",
        fontSizeAdd = 2, bodyFont = "Friz Quadrata", iconColor = { 0.1, 0.1, 0.1 }, iconHoverColor = { 0.4, 0.4, 0.4 } },
    FROST = { back = "FrostBack", tint = { 0.55, 0.55, 0.55, 0.85 }, rim = { 0.86, 0.96, 1, 0.8 },
        font = "Julius Sans One", bodyFont = "Julius Sans One" },
    PIXEL = { back = "PixelBack", rim = { 1, 0.95, 0.91, 1 }, font = "VT323", fontSizeAdd = 4 },
    SWISS = { back = "SwissBack", rule = { 0.949, 0.949, 0.949, 1 }, ruleSize = 3, rim = { 0.165, 0.165, 0.165, 1 },
        font = "Inter Tight Bold", bodyFont = "Inter Tight" },
    CONSOLE = { back = "ConsoleBack", rim = { 0.306, 0.929, 0.69, 1 }, font = "IBM Plex Sans Condensed Bold",
        bodyFont = "IBM Plex Mono" },
    PITWALL = { back = "SwissBack", strip = { 0, 0, 0, 1 }, wedge = "PitwallWedge", wedgeColor = { 0.882, 0.024, 0, 1 },
        rim = { 0.043, 0.047, 0.055, 1 }, font = "Titillium Web Bold Italic", bodyFont = "Titillium Web SemiBold" },
}

-- The HD themes: each is its base theme (fonts, ornaments, ring) over a
-- finer backdrop of its own in every colour (Media/Themes/<Base>HD<Colour>,
-- TILE_HD texels square, made by tools/hd). Drawn as it is: no grey file,
-- no tint but the base's alpha. base: the theme an HD theme stands on.
lib.TILE_HD = 256
local function hd(base, back)
    local t = {}
    for k, v in pairs(lib.THEMES[base]) do t[k] = v end
    t.base, t.back, t.tint, t.tile = base, back, { 1, 1, 1, t.tint and t.tint[4] or 1 }, lib.TILE_HD
    return t
end
lib.THEMES.WOOD_HD = hd("WOOD", "WoodHDEbony")
lib.THEMES.TECH_HD = hd("TECH", "TechHDCarbon")
lib.THEMES.PARCHMENT_HD = hd("PARCHMENT", "ParchmentHDAsh")
lib.THEMES.RUNESTONE_HD = hd("RUNESTONE", "RunestoneHDSlate")
lib.THEMES.GLASS_HD = hd("GLASS", "GlassHDRuby")
lib.THEMES.COMIC_HD = hd("COMIC", "ComicHDNoir")
lib.THEMES.FROST_HD = hd("FROST", "FrostHDIce")

-- The theme an id stands on: an HD theme's base, else the id itself (for
-- an addon's own rules about one theme, e.g. Comic's ink).
function lib.BaseTheme(id)
    local t = lib.THEMES[id]
    return t and t.base or id
end

-- One spec: the addon's part over theme id's identity.
local function withIdentity(spec, id)
    if id ~= lib.CLASSIC then
        spec.art = setmetatable(spec.art or {}, { __index = function(_, k) return lib.THEMES[id][k] end })
    end
    return setmetatable(spec, { __index = function(_, k)
        if k == "art" then return nil end
        return lib.THEMES[id][k]
    end })
end

-- An addon's SPECS: its own part of each theme (look, art geometry, any
-- override) over the theme's identity. own[id].art falls back to the
-- identity's fields the same way; `false` in own drops an identity field.
-- Looked up at use, not copied: a newer copy loading later is seen.
-- pairs() over a spec or its art lists the addon's own fields only.
-- Only CLASSIC and the themes in own: a theme added to the library after
-- the addon was written has no look there, so the addon must not offer it.
-- withHd: also each HD theme whose base is in own, from a copy of the
-- base's part (its backdrop file the HD one). Only an addon that names the
-- HD themes in its texts asks for them.
local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = deepCopy(x) end
    return t
end

local function hdPart(own, id)
    local base = lib.THEMES[id].base
    if not (base and own[base]) then return nil end
    local part = deepCopy(own[base])
    if part.art and part.art.back then part.art.back = nil end
    return part
end

function lib.Specs(own, withHd)
    local specs = {}
    for _, id in ipairs(lib.IDS) do
        local spec = own[id] or (id == lib.CLASSIC and {}) or (withHd and hdPart(own, id)) or nil
        if spec then specs[id] = withIdentity(spec, id) end
    end
    return specs
end

-- The theme ids specs has, in the library's order (an addon's theme menu).
function lib.SpecIds(specs)
    local ids = {}
    for _, id in ipairs(lib.IDS) do
        if specs[id] then ids[#ids + 1] = id end
    end
    return ids
end

-- HD in the menus (MINOR 9): an HD theme is no entry of the theme menu but
-- a group of colours of its base ("Technology > HD Carbon"). Ids, stored
-- settings and the registry stay as they were: TECH_HD with CARBON is still
-- what is saved, so a choice made before shows at its new place, and
-- addons with an older copy keep working. A base and its HD theme share one
-- set of settings (SetKey): changing between their colours moves nothing.

-- Where a theme's settings are kept: the base's place for an HD theme.
function lib.SetKey(id)
    return lib.BaseTheme(id)
end

-- The theme menu's ids: ids (an addon's SpecIds) without the HD themes.
function lib.MenuIds(ids)
    local list = {}
    for _, id in ipairs(ids) do
        if lib.BaseTheme(id) == id then list[#list + 1] = id end
    end
    return list
end

-- The colour menu under theme id (base or HD) for an addon with specs:
-- { theme, color, hd } in order, the base's colours first, then its HD
-- theme's where specs has it. Choosing an entry is Switch(theme), then
-- SetColor(color, theme).
function lib.MenuColors(specs, id)
    local base, list = lib.BaseTheme(id), {}
    for _, themeId in ipairs(lib.IDS) do
        if specs[themeId] and lib.BaseTheme(themeId) == base then
            local hd = themeId ~= base
            for _, color in ipairs(lib.Colors(themeId)) do
                list[#list + 1] = { theme = themeId, color = color, hd = hd }
            end
        end
    end
    return list
end

-- One value for a menu entry and back: "TECH_HD:CARBON".
function lib.MenuValue(themeId, colorId) return themeId .. ":" .. tostring(colorId) end
function lib.ParseMenuValue(value)
    local themeId, colorId = tostring(value):match("^([^:]+):(.+)$")
    return themeId, colorId
end

-- Base and HD settings made one, once per profile (sets.hdMerged), for an
-- addon whose sets were kept per theme before. sets: the stored sets by id
-- (not the live one); current: the live theme; live: a copy of the live
-- settings; customised(hdId, set): whether set differs from what choosing
-- hdId afresh would make. The HD set wins when it was customised or the
-- base has none, else the base's stays. Returns the settings to make live
-- (theme field set) when they change, else nil; sets is changed in place.
function lib.MergeHD(sets, current, live, customised)
    if sets.hdMerged then return nil end
    sets.hdMerged = true
    local newLive
    for _, hdId in ipairs(lib.IDS) do
        local base = lib.BaseTheme(hdId)
        if base ~= hdId then
            local hdSet = current == hdId and live or sets[hdId]
            local baseSet = current == base and live or sets[base]
            if hdSet then
                local hdWins = not baseSet or customised(hdId, hdSet)
                local winner = hdWins and hdSet or baseSet
                if current == hdId or current == base then
                    if winner ~= live then
                        newLive = deepCopy(winner)
                        newLive.theme = current
                    end
                else
                    sets[base] = deepCopy(winner)
                    sets[base].theme = base
                end
                sets[hdId] = nil
                if current == hdId or current == base then sets[base] = nil end
            end
        end
    end
    return newLive
end


-- The font for other addons' and Blizzard's texts under spec: its body
-- font, but where that is Friz (Blizzard's own) its title font, else such
-- a switch would show nothing.
function lib.ForeignFont(spec)
    local body = spec.bodyFont
    return body and body ~= "Friz Quadrata" and body or spec.font
end

-- Each theme's colours (none for CLASSIC). The first is the theme as it
-- is. back: the backdrop drawn from the grey texture (<back>Grey) tinted so
-- its mean lands on back; accent: the titles' and icons' colour; rim: the
-- ring's (only Console's and Pixel's Handheld); wedge: Pitwall's wedge;
-- paper / dark: the comic's paper tint, dark = light ink on it.
local function colour(id, back, accent, rim, wedge)
    return { id = id, back = back, accent = accent, rim = rim, wedge = wedge }
end
local function paper(id, tint, accent, dark)
    return { id = id, paper = tint, accent = accent, dark = dark }
end
-- An HD colour: its backdrop file <Base>HD<Colour> (Wood, OAK -> WoodHDOak).
local function hdColour(base, id, accent, dark)
    local name = base:sub(1, 1) .. base:sub(2):lower() .. "HD" .. id:sub(1, 1) .. id:sub(2):lower()
    return { id = id, texture = name, accent = accent, dark = dark }
end
local PICO_YELLOW = { 1, 0.93, 0.15 }
local HANDHELD = { 0.784, 0.941, 0.439 }
local COMIC_YELLOW = { 1, 0.9, 0.1 }
local COMIC_BLUE = { 0.15, 0.45, 0.95 }
lib.COLORS = {
    WOOD = {
        colour("OAK"),
        colour("WALNUT", { 0.15, 0.09, 0.06 }),
        colour("BIRCH", { 0.38, 0.32, 0.22 }),
        colour("CHERRY", { 0.3, 0.12, 0.08 }),
        colour("EBONY", { 0.08, 0.07, 0.07 }),
        colour("DRIFTWOOD", { 0.25, 0.24, 0.22 }),
    },
    TECH = {
        colour("CYAN"),
        colour("GREEN", { 0.02, 0.1, 0.05 }, { 0.3, 0.95, 0.45 }),
        colour("AMBER", { 0.1, 0.07, 0.02 }, { 1, 0.75, 0.2 }),
        colour("MAGENTA", { 0.09, 0.03, 0.1 }, { 0.95, 0.4, 0.95 }),
        colour("BLUE", { 0.03, 0.05, 0.13 }, { 0.45, 0.65, 1 }),
        colour("GREY", { 0.07, 0.07, 0.08 }, { 0.85, 0.88, 0.9 }),
    },
    PARCHMENT = {
        colour("CLASSIC"),
        colour("AGED", { 0.32, 0.25, 0.15 }),
        colour("ASH", { 0.33, 0.33, 0.31 }),
        colour("SEA", { 0.25, 0.3, 0.33 }),
        colour("ROSE", { 0.36, 0.27, 0.26 }),
        colour("DARK", { 0.2, 0.17, 0.13 }),
    },
    RUNESTONE = {
        colour("GRANITE"),
        colour("SANDSTONE", { 0.33, 0.27, 0.18 }, { 1, 0.8, 0.35 }),
        colour("SLATE", { 0.15, 0.18, 0.25 }, { 0.55, 0.75, 1 }),
        colour("MOSS", { 0.15, 0.22, 0.14 }, { 0.5, 1, 0.45 }),
        colour("OBSIDIAN", { 0.07, 0.06, 0.09 }, { 0.75, 0.5, 1 }),
    },
    GLASS = {
        colour("CATHEDRAL"),
        colour("BLUE", { 0.08, 0.12, 0.28 }),
        colour("GREEN", { 0.07, 0.2, 0.1 }),
        colour("AMBER", { 0.28, 0.17, 0.05 }),
        colour("VIOLET", { 0.18, 0.08, 0.26 }),
        colour("RUBY", { 0.26, 0.05, 0.08 }),
    },
    COMIC = {
        paper("GREY", { 0.7, 0.7, 0.7 }),
        paper("DARKGREY", { 0.38, 0.38, 0.38 }, COMIC_YELLOW, true),
        paper("BLACK", { 0.16, 0.16, 0.16 }, COMIC_YELLOW, true),
        paper("WHITE", { 1, 1, 1 }, COMIC_BLUE),
        paper("YELLOW", { 0.86, 0.76, 0.36 }, COMIC_BLUE),
        paper("BLUE", { 0.45, 0.6, 0.86 }, COMIC_YELLOW),
        paper("RED", { 0.86, 0.44, 0.4 }, COMIC_YELLOW),
        paper("GREEN", { 0.5, 0.76, 0.46 }, COMIC_YELLOW),
        paper("PURPLE", { 0.7, 0.52, 0.84 }, COMIC_YELLOW),
    },
    FROST = {
        colour("ICE"),
        colour("DEEP", { 0.1, 0.18, 0.32 }, { 0.6, 0.85, 1 }),
        colour("AURORA", { 0.1, 0.27, 0.24 }, { 0.55, 1, 0.8 }),
        colour("VIOLET", { 0.22, 0.18, 0.33 }, { 0.85, 0.75, 1 }),
        colour("SILVER", { 0.3, 0.31, 0.33 }, { 0.92, 0.92, 0.95 }),
        colour("NIGHT", { 0.06, 0.08, 0.14 }, { 0.7, 0.85, 1 }),
    },
    -- PICO-8's palette.
    PIXEL = {
        colour("NAVY"),
        colour("PLUM", { 0.23, 0.08, 0.16 }, PICO_YELLOW),
        colour("FOREST", { 0, 0.2, 0.12 }, PICO_YELLOW),
        colour("BROWN", { 0.2, 0.12, 0.08 }, { 1, 0.64, 0 }),
        colour("GREY", { 0.18, 0.17, 0.16 }),
        colour("BLACK", { 0.03, 0.03, 0.04 }, { 0, 0.89, 0.21 }),
        colour("TEAL", { 0.02, 0.17, 0.22 }, { 0.16, 0.68, 1 }),
        colour("PURPLE", { 0.15, 0.1, 0.25 }, { 1, 0.47, 0.66 }),
        colour("HANDHELD", { 0.059, 0.122, 0.059 }, HANDHELD, { HANDHELD[1], HANDHELD[2], HANDHELD[3], 1 }),
    },
    -- One dark backdrop in every colour: only the accent changes.
    SWISS = {
        colour("RED"),
        colour("BLUE", nil, { 0.176, 0.42, 1 }),
        colour("YELLOW", nil, { 1, 0.82, 0 }),
        colour("WHITE", nil, { 0.949, 0.949, 0.949 }),
    },
    -- The ring follows the accent.
    CONSOLE = {
        colour("MINT"),
        colour("AMBER", nil, { 1, 0.69, 0 }, { 1, 0.69, 0, 1 }),
        colour("PHOSPHOR", nil, { 0.224, 1, 0.078 }, { 0.224, 1, 0.078, 1 }),
        colour("VIOLET", nil, { 0.627, 0.471, 1 }, { 0.627, 0.471, 1, 1 }),
    },
    -- HD: every colour its own finished backdrop (texture), no grey.
    WOOD_HD = {
        hdColour("WOOD", "EBONY"),
        hdColour("WOOD", "OAK"),
        hdColour("WOOD", "WALNUT"),
        hdColour("WOOD", "DRIFTWOOD"),
    },
    TECH_HD = {
        hdColour("TECH", "CARBON"),
        hdColour("TECH", "STEEL", { 0.45, 0.65, 1 }),
    },
    PARCHMENT_HD = {
        hdColour("PARCHMENT", "ASH"),
        hdColour("PARCHMENT", "CLASSIC"),
        hdColour("PARCHMENT", "AGED"),
    },
    RUNESTONE_HD = {
        hdColour("RUNESTONE", "SLATE", { 0.55, 0.75, 1 }),
        hdColour("RUNESTONE", "GRANITE"),
        hdColour("RUNESTONE", "SANDSTONE", { 1, 0.8, 0.35 }),
        hdColour("RUNESTONE", "OBSIDIAN", { 0.75, 0.5, 1 }),
    },
    GLASS_HD = {
        hdColour("GLASS", "RUBY"),
        hdColour("GLASS", "CATHEDRAL"),
        hdColour("GLASS", "SAPPHIRE"),
        hdColour("GLASS", "EMERALD"),
    },
    COMIC_HD = {
        hdColour("COMIC", "NOIR", COMIC_YELLOW, true),
        hdColour("COMIC", "NEWSPRINT"),
        hdColour("COMIC", "PULP", COMIC_BLUE),
        hdColour("COMIC", "POP", COMIC_YELLOW),
    },
    FROST_HD = {
        hdColour("FROST", "ICE"),
        hdColour("FROST", "DEEP", { 0.6, 0.85, 1 }),
        hdColour("FROST", "AURORA", { 0.55, 1, 0.8 }),
    },
    -- The wedge's colour.
    PITWALL = {
        colour("RED"),
        colour("ORANGE", nil, nil, nil, { 1, 0.541, 0, 1 }),
        colour("TEAL", nil, nil, nil, { 0, 0.631, 0.612, 1 }),
        colour("SILVER", nil, nil, nil, { 0.788, 0.808, 0.839, 1 }),
    },
}

-- The mean grey of each <back>Grey.tga: a colour's back is drawn as vertex
-- colour back / mean (at most 1).
lib.GREY_MEAN = { WoodBack = 0.800, TechBack = 0.705, ParchmentBack = 0.799, StoneBack = 0.800, GlassBack = 0.777,
    FrostBack = 0.796, PixelBack = 0.800 }

-- A theme's colour ids in order (none for CLASSIC or an unknown theme).
function lib.Colors(themeId)
    local list = {}
    for i, c in ipairs(lib.COLORS[themeId] or {}) do list[i] = c.id end
    return list
end

-- A theme's colour entry, or nil for an id it does not have.
function lib.Colour(themeId, colorId)
    for _, c in ipairs(lib.COLORS[themeId] or {}) do
        if c.id == colorId then return c end
    end
    return nil
end

-- The colour id that stands: a known one, else the theme's first; nil for
-- a theme without colours.
function lib.ValidColor(themeId, colorId)
    local colours = lib.COLORS[themeId]
    if not colours then return nil end
    return lib.Colour(themeId, colorId) and colorId or colours[1].id
end

-- The colour entry in use when it is not the theme's own look, else nil.
-- An HD colour is never the theme's own look: the first (the default) wears
-- its backdrop, accent and paper like the others.
function lib.Paint(themeId, colorId)
    local c = lib.Colour(themeId, colorId)
    return c and (c.texture or c ~= lib.COLORS[themeId][1]) and c or nil
end

-- A copy of colour c: what the helpers return is the caller's to change,
-- the library's tables stay as they are.
local function copy(c)
    return c and { c[1], c[2], c[3], c[4] } or c
end

-- The vertex colour { r, g, b } that turns the grey backdrop of back (a
-- file name in GREY_MEAN) into colour rgb, or nil for a back without one.
function lib.GreyTint(back, rgb)
    local mean = back and lib.GREY_MEAN[back]
    if not (mean and rgb) then return nil end
    return { math.min(1, rgb[1] / mean), math.min(1, rgb[2] / mean), math.min(1, rgb[3] / mean) }
end

-- The colour's back where it can be drawn on art (its grey exists), else nil.
local function greyBack(art, themeId, colorId)
    local c = lib.Paint(themeId, colorId)
    return c and c.back and art.back and lib.GREY_MEAN[art.back] and c.back or nil
end

-- The backdrop's texture name (art: the spec's; nil or false: none): the
-- grey one under a colour that tints it.
function lib.Back(art, themeId, colorId)
    local c = art.back and lib.Paint(themeId, colorId)
    if c and c.texture then return c.texture end
    return greyBack(art, themeId, colorId) and art.back .. "Grey" or art.back
end

-- The backdrop's tint { r, g, b, a } (art: the spec's; nil: none): the
-- comic's paper in its colour, or the grey texture tinted to the colour at
-- the theme's alpha.
function lib.Tint(art, themeId, colorId)
    if themeId == "COMIC" and art.tint then
        local p = (lib.Colour(themeId, colorId) or lib.COLORS.COMIC[1]).paper
        return { p[1], p[2], p[3], art.tint[4] }
    end
    local back = greyBack(art, themeId, colorId)
    if back then
        local t = lib.GreyTint(art.back, back)
        t[4] = art.tint and art.tint[4] or 1
        return t
    end
    return copy(art.tint)
end

-- The titles' colour the theme's colour sets, else nil (the addon's own).
function lib.Accent(themeId, colorId)
    local c = lib.Paint(themeId, colorId)
    return copy(c and c.accent)
end

-- The ring's colour the theme's colour sets, else nil (the addon's own).
function lib.Rim(themeId, colorId)
    local c = lib.Paint(themeId, colorId)
    return copy(c and c.rim)
end

-- The wedge's colour (art: the spec's): the colour's, else the theme's.
function lib.WedgeColor(art, themeId, colorId)
    local c = lib.Paint(themeId, colorId)
    return copy(c and c.wedge or art.wedgeColor)
end

-- Whether the comic's paper in use is dark (light ink on it).
function lib.DarkPaper(themeId, colorId)
    local c = lib.BaseTheme(themeId) == "COMIC" and lib.Paint(themeId, colorId)
    return c and c.dark == true or false
end

-- Pitwall's wedge, as in every Forever addon: the texture's left
-- WEDGE_PART, as wide as the strip is high; its right edge runs from 0.98
-- of that width at the top to 0.62 at the bottom. The grip or title starts
-- TITLE_GAP past it.
lib.WEDGE_PART, lib.TITLE_GAP = 0.53, 8
-- How far the wedge reaches at height y of a strip h high.
function lib.WedgeReach(h, y) return math.floor(0.98 * h - 0.36 * y + 0.5) end

-- Icons in the accent c: idle and on in it, hovered half way to white,
-- off 40 % darker, as in every Forever addon.
local ICON_HOVER, ICON_OFF = 0.5, 0.4
local function mix(c, to, f)
    return { c[1] + (to - c[1]) * f, c[2] + (to - c[2]) * f, c[3] + (to - c[3]) * f }
end
function lib.IconTones(c)
    local a = { c[1], c[2], c[3] }
    return { idle = a, on = a, hover = mix(a, 1, ICON_HOVER), off = mix(a, 0, ICON_OFF) }
end

-- The icons' colour under a theme (spec: its spec; title: the addon's
-- title colour): the wedge's on Pitwall (the colour changes it there),
-- else the colour's accent, else title. nil under CLASSIC and a theme with
-- its own ink (iconColor).
function lib.IconColor(spec, themeId, colorId, title)
    if themeId == lib.CLASSIC or spec.iconColor then return nil end
    local art = spec.art or {}
    return art.wedge and lib.WedgeColor(art, themeId, colorId) or lib.Accent(themeId, colorId) or title
end

-- The cross-addon theme menu: _G.ForeverThemes[folder] = { title, Current,
-- Switch, Colors, Color, SetColor }. Addons that do not use this library
-- yet write the same entries themselves; both read each other's.
function lib.Register(folder, entry)
    _G.ForeverThemes = _G.ForeverThemes or {}
    _G.ForeverThemes[folder] = entry
end

-- The registered addons other than folder that can switch: { folder,
-- entry } by folder. Entries without Current and Switch (or no table) are
-- not addons to switch.
local function others(folder)
    local list = {}
    for name, entry in pairs(_G.ForeverThemes or {}) do
        if name ~= folder and type(entry) == "table" and type(entry.Current) == "function"
            and type(entry.Switch) == "function" then
            list[#list + 1] = { folder = name, entry = entry }
        end
    end
    table.sort(list, function(a, b) return tostring(a.folder) < tostring(b.folder) end)
    return list
end

-- The registered addons other than folder (their entries).
function lib.Others(folder)
    local list = {}
    for i, o in ipairs(others(folder)) do list[i] = o.entry end
    return list
end

local function titleOf(o) return tostring(o.entry.title or o.folder) end   -- plain: an addon's title

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- One other addon onto theme and, where it has it, color. Its error stops
-- no other addon; it goes to the error handler (shown, not swallowed).
local function applyTo(o, theme, color)
    local e = o.entry
    local ok, switched = pcall(e.Switch, theme)
    if ok and switched and color and type(e.Colors) == "function" and type(e.SetColor) == "function" then
        ok, switched = pcall(function()
            if listed(e.Colors(theme), color) then e.SetColor(color, theme) end
            return true
        end)
    end
    if not ok then geterrorhandler()(("%s: %s"):format(titleOf(o), tostring(switched))) end
    return ok, ok and switched
end

-- "Apply to all Forever addons": every other addon onto theme and, where
-- that theme has it, color (else it keeps its own). One without the theme
-- refuses the switch and is skipped; one that follows the hub is the hub's
-- to theme (it would switch it back) and is skipped too. Returns how many
-- switched and the titles of those that raised an error.
function lib.ApplyToAll(folder, theme, color)
    local switched, failed = 0, {}
    for _, o in ipairs(others(folder)) do
        if not lib.Follows(o.folder) then
            local ok, done = applyTo(o, theme, color)
            if not ok then failed[#failed + 1] = titleOf(o) end
            if done then switched = switched + 1 end
        end
    end
    return switched, failed
end

-- The optional addon Forever Themes (the hub): one theme and colour for
-- every Forever addon, each addon following it or keeping its own (DESIGN.md
-- §2.12). Lib.Hub() is nil without it, else
--   Follows(folder)    true while the hub sets that addon's theme (its own
--                      theme setting is then the hub's to change)
--   Theme(), Color()   the central theme id and colour id (nil: none)
--   OpenMenu(anchor)   the theme and colour menu at anchor
--   OpenOptions()      the hub's options window
--   Sync()             (optional) every following addon onto the hub's theme
-- While the hub is loaded it owns the theme font on Blizzard's texts and on
-- Platynator's nameplates; an addon's own bridge for those stands down.
-- Kept in a global of its own, not in this table: a newer copy loading
-- after the hub empties this table.
function lib.SetHub(api) _G.ForeverThemesHub = api end
function lib.Hub() return _G.ForeverThemesHub end

-- Whether the hub is there and sets folder's theme.
function lib.Follows(folder)
    local hub = lib.Hub()
    return hub ~= nil and type(hub.Follows) == "function" and hub.Follows(folder) == true
end

-- The hub puts its theme on the following addons again (after an addon's
-- profile switch, reset or import replaced its theme). Nothing without it.
function lib.HubSync()
    local hub = lib.Hub()
    if hub and type(hub.Sync) == "function" then hub.Sync() end
end

-- The texts every addon shows about the hub, in the client's language.
local TEXTS = {
    enUS = { HUB_FOLLOWS = "Follows Forever Themes", HUB_OPEN = "Open Forever Themes",
        HUB_MISSING = "Theme all Forever addons at once: Forever Themes", HUB_LINK = "Download link",
        HUB_COPY = "Copy the link (Ctrl+C) and open it in your browser:" },
    deDE = { HUB_FOLLOWS = "Folgt Forever Themes", HUB_OPEN = "Forever Themes öffnen",
        HUB_MISSING = "Alle Forever-Addons auf einmal einstellen: Forever Themes", HUB_LINK = "Download-Link",
        HUB_COPY = "Link kopieren (Strg+C) und im Browser öffnen:" },
    esES = { HUB_FOLLOWS = "Sigue a Forever Themes", HUB_OPEN = "Abrir Forever Themes",
        HUB_MISSING = "Ajusta todos los addons Forever a la vez: Forever Themes", HUB_LINK = "Enlace de descarga",
        HUB_COPY = "Copia el enlace (Ctrl+C) y ábrelo en tu navegador:" },
    frFR = { HUB_FOLLOWS = "Suit Forever Themes", HUB_OPEN = "Ouvrir Forever Themes",
        HUB_MISSING = "Réglez tous les addons Forever d’un coup : Forever Themes",
        HUB_LINK = "Lien de téléchargement",
        HUB_COPY = "Copiez le lien (Ctrl+C) et ouvrez-le dans votre navigateur :" },
    koKR = { HUB_FOLLOWS = "Forever Themes를 따름", HUB_OPEN = "Forever Themes 열기",
        HUB_MISSING = "모든 Forever 애드온을 한 번에: Forever Themes", HUB_LINK = "다운로드 링크",
        HUB_COPY = "링크를 복사(Ctrl+C)해 브라우저에서 여세요:" },
}
TEXTS.esMX = TEXTS.esES

-- A hub text (HUB_FOLLOWS, HUB_OPEN, HUB_MISSING, HUB_LINK, HUB_COPY) in
-- locale (an addon's own language setting, e.g. "deDE"), else the client's
-- language, else English.
function lib.Text(key, locale)
    local texts = TEXTS[locale] or TEXTS[GetLocale()] or TEXTS.enUS
    return texts[key] or TEXTS.enUS[key]
end

lib.HUB_URL = "https://www.curseforge.com/wow/addons/forever-themes"
local HUB_POPUP = "LIBFOREVERTHEMES_HUB_LINK"

-- The hub's download link in Blizzard's text popup, selected for copying
-- (WoW opens no browser). text: the prompt, default Text("HUB_COPY", locale).
-- Defined at use: the newest copy's dialog is the one shown.
function lib.ShowHubLink(text, locale)
    StaticPopupDialogs[HUB_POPUP] = {
        text = text or lib.Text("HUB_COPY", locale), button1 = OKAY or "OK", hasEditBox = 1, editBoxWidth = 350,
        maxLetters = 0,   -- the edit box is shared; another dialog may leave its limit behind
        OnShow = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
            if box then box:SetText(lib.HUB_URL); box:HighlightText(); box:SetFocus() end
        end,
        EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    return StaticPopup_Show(HUB_POPUP)
end

-- Complete: into the one shared table, emptied first, so an addon that
-- captured it (local Lib = LibForeverThemes) gets this copy. MINOR last.
shared = shared or {}
for k in pairs(shared) do shared[k] = nil end
for k, v in pairs(lib) do shared[k] = v end
lib = shared   -- the functions above read through the shared table from now on
_G.LibForeverThemes = shared
shared.MINOR = MINOR

-- Our font files loaded while the addons load: a file used for the first
-- time can be refused, so the first restyle should not be its first use.
-- Each winning copy loads its own files (their paths are its folder's).
do
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, f in ipairs(lib.FONTS) do holder:CreateFontString():SetFont(f.path, 12, "") end
end
