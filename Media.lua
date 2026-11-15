local ADDON, ns = ...

-- Fonts, background textures and bar textures: the game's own, plus every
-- one another addon registers with LibSharedMedia (the library itself is
-- not shipped).
local Media = {}
ns.Media = Media

local ICONS = "Interface\\AddOns\\ForeverCombatMeter\\Media\\"
local FONTS, THEMES = ICONS .. "Fonts\\", ICONS .. "Themes\\"
function Media.Icon(name) return ICONS .. "Icon" .. name .. ".tga" end

Media.BLIZZARD = {
    font = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
        -- The themes' fonts (Themes.lua), shipped with the addon, Latin
        -- letters only; licences in Media/Fonts.
        { name = "Bangers",            path = FONTS .. "Bangers-Regular.ttf" },
        { name = "Cinzel",             path = FONTS .. "Cinzel-Bold.ttf" },
        { name = "IM Fell English SC", path = FONTS .. "IMFeENsc28P.ttf" },
        { name = "Julius Sans One",    path = FONTS .. "JuliusSansOne-Regular.ttf" },
        { name = "Marcellus",          path = FONTS .. "Marcellus-Regular.ttf" },
        { name = "Space Grotesk",      path = FONTS .. "SpaceGrotesk-Bold.ttf" },
        { name = "VT323",              path = FONTS .. "VT323-Regular.ttf" },
        { name = "Inter Tight Bold",   path = FONTS .. "InterTight-Bold.ttf" },
        { name = "Inter Tight",        path = FONTS .. "InterTight-Regular.ttf" },
        { name = "Inter Tight Light",  path = FONTS .. "InterTight-Light.ttf" },
        { name = "IBM Plex Sans Condensed Bold", path = FONTS .. "IBMPlexSansCondensed-Bold.ttf" },
        { name = "IBM Plex Mono",      path = FONTS .. "IBMPlexMono-Regular.ttf" },
        { name = "Titillium Web Bold Italic", path = FONTS .. "TitilliumWeb-BoldItalic.ttf" },
        { name = "Titillium Web SemiBold", path = FONTS .. "TitilliumWeb-SemiBold.ttf" },
    },
    background = {
        { name = "Blizzard Dialog Background Dark", path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
        { name = "Blizzard Dialog Background", path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
        { name = "Blizzard Dialog Background Gold", path = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background" },
        { name = "Blizzard Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
        { name = "Blizzard Parchment", path = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal" },
        { name = "Blizzard Rock", path = "Interface\\FrameGeneral\\UI-Background-Rock" },
        { name = "Blizzard Marble", path = "Interface\\FrameGeneral\\UI-Background-Marble" },
    },
    statusbar = {
        { name = "Solid", path = "Interface\\Buttons\\WHITE8X8" },
        { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { name = "Blizzard Raid Bar", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    },
}
-- The themes' bar textures (made by Forever Unit Frames' tools/make_themes.py). Console and
-- Pitwall use Swiss's: their dashed and LED bars looked broken in the meter.
for _, name in ipairs({ "Wood", "Tech", "Parchment", "Stone", "Glass", "Comic", "Frost", "Pixel", "Swiss" }) do
    table.insert(Media.BLIZZARD.statusbar, { name = "FCM " .. name, path = THEMES .. name .. "Bar.tga" })
end
Media.DEFAULT = {
    font = "Fonts\\FRIZQT__.TTF",
    background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    statusbar = "Interface\\Buttons\\WHITE8X8",
}

-- Our own font files loaded while the addon loads: a file used for the
-- first time can be refused (ApplyText tries again), so the first theme
-- switch should not be its first use.
do
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, f in ipairs(Media.BLIZZARD.font) do
        if f.path:find(FONTS, 1, true) then holder:CreateFontString():SetFont(f.path, 12, "") end
    end
end

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every name of a kind ("font", "background", "statusbar"), Blizzard's
-- first, then LibSharedMedia's sorted.
function Media.Names(kind)
    local names, seen = {}, {}
    for _, f in ipairs(Media.BLIZZARD[kind]) do
        names[#names + 1] = f.name
        seen[f.name] = true
    end
    local lsm = sharedMedia()
    if lsm then
        local extra = {}
        for _, name in ipairs(lsm:List(kind) or {}) do
            if not seen[name] then extra[#extra + 1] = name end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do names[#names + 1] = name end
    end
    return names
end

-- The file for a name; unknown names get the kind's default.
function Media.Path(kind, name)
    for _, f in ipairs(Media.BLIZZARD[kind]) do
        if f.name == name then return f.path end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch(kind, name, true)
    return path or Media.DEFAULT[kind]
end

function Media.FontNames() return Media.Names("font") end
function Media.FontPath(name) return Media.Path("font", name) end

-- Whether a text took the font file asked for (a refused one leaves the
-- old font, or none).
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    return plain(got) == plain(path)
end
-- How often, and how far apart, a refused font is tried again.
local FONT_TRIES, FONT_RETRY_DELAY = 40, 0.25
-- First use of a file can take seconds when many fonts load at once
-- (theme switch); report each file only once.
local refusedFonts = {}

-- A font file used for the first time can leave a text blank although
-- GetFont reports it (seen in game: empty texts until the theme was
-- chosen a second time). Setting it again a little later, through another
-- font, as that second choice did, draws them. Once per text and font.
local REDRAW_DELAYS = { 0.5, 2 }
local function redrawLater(fs, path, size, flags, wanted)
    if fs.fontDrawn == wanted then return end
    fs.fontDrawn = wanted
    for _, delay in ipairs(REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fs.fontWanted ~= wanted then return end
            fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
            fs:SetFont(path, size, flags)
            local text = fs:GetText()
            if text then fs:SetText(""); fs:SetText(text) end
        end)
    end
end

-- A text style (Settings.TextStyle) on a font string. SHADOW is a drop
-- shadow, OUTLINESHADOW an outline with it, the other flags are outlines. A font the client refuses (a file
-- of ours on its first use) gives way to the standard font meanwhile and
-- is tried again a few times.
function Media.ApplyText(fs, style, tries)
    local flag = style.flag
    local outline = (flag == "OUTLINE" or flag == "THICKOUTLINE") and flag or flag == "OUTLINESHADOW" and "OUTLINE" or ""
    local path = Media.FontPath(style.font)
    local wanted = path .. "|" .. style.size .. "|" .. outline
    fs.fontWanted = wanted
    if fs:SetFont(path, style.size, outline) and hasFont(fs, path) then
        redrawLater(fs, path, style.size, outline, wanted)
    else
        fs:SetFont(Media.DEFAULT.font, style.size, outline)
        tries = tries or FONT_TRIES
        if tries > 0 then
            C_Timer.After(FONT_RETRY_DELAY, function()
                -- Restyled since: that call has its own tries.
                if fs.fontWanted == wanted then Media.ApplyText(fs, style, tries - 1) end
            end)
        elseif not refusedFonts[path] then
            refusedFonts[path] = true
            ns.Print("Font could not be loaded: %s", tostring(style.font))
        end
    end
    if flag == "SHADOW" or flag == "OUTLINESHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    local c = style.color
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- A background texture: SOLID (colour), GRADIENT (colour fading down) or
-- TEXTURE (tiled, alpha only). alpha 0..1.
function Media.ApplyBackground(tex, mode, color, alpha, textureName)
    if mode == "TEXTURE" then
        tex:SetTexture(Media.Path("background", textureName), "REPEAT", "REPEAT")
        tex:SetHorizTile(true)
        tex:SetVertTile(true)
        tex:SetVertexColor(1, 1, 1, alpha)
        return
    end
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetColorTexture(1, 1, 1, 1)
    local c = color
    local top = CreateColor(c[1], c[2], c[3], alpha)
    local bottom = mode == "GRADIENT" and CreateColor(c[1], c[2], c[3], alpha * 0.35) or top
    tex:SetGradient("VERTICAL", bottom, top)
end

-- Blizzard's font on one of its font strings, remembered before we change
-- it, and put back. SetFontObject alone does not restore: after SetFont the
-- string still names the same font object, and setting that one again
-- changes nothing (seen in game). So file, size, flags and shadow go back
-- explicitly.
function Media.Snapshot(fs)
    local file, size, flags = fs:GetFont()
    local sx, sy = fs:GetShadowOffset()
    local r, g, b, a = fs:GetShadowColor()
    local tr, tg, tb, ta = fs:GetTextColor()
    return { object = fs:GetFontObject(), file = file, size = size, flags = flags or "",
             shadow = { sx or 0, sy or 0 }, shadowColor = { r or 0, g or 0, b or 0, a or 1 },
             color = { tr or 1, tg or 1, tb or 1, ta or 1 } }
end

function Media.Restore(fs, o, withColor)
    if o.file then fs:SetFont(o.file, o.size, o.flags) end
    if o.object then fs:SetFontObject(o.object) end
    fs:SetShadowOffset(o.shadow[1], o.shadow[2])
    fs:SetShadowColor(o.shadowColor[1], o.shadowColor[2], o.shadowColor[3], o.shadowColor[4])
    if withColor then fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4]) end
end
