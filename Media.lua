local ADDON, ns = ...

-- Fonts, background textures and bar textures: the game's own, plus every
-- one another addon registers with LibSharedMedia (the library itself is
-- not shipped).
local Media = {}
ns.Media = Media

local ICONS = "Interface\\AddOns\\ForeverCombatMeter\\Media\\"
function Media.Icon(name) return ICONS .. "Icon" .. name .. ".tga" end

Media.BLIZZARD = {
    font = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
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
-- The themes' fonts (Latin letters only; SIL Open Font License, see its
-- Media/Fonts) and bar textures come with the embedded LibForeverThemes,
-- which also loads the fonts early. Read at use: a newer copy of the
-- library loading after us has other paths. Console and Pitwall use
-- Swiss's bar: their dashed and LED bars looked broken in the meter.
local Lib = LibForeverThemes
local BARS = { "Wood", "Tech", "Parchment", "Stone", "Glass", "Comic", "Frost", "Pixel", "Swiss" }
Media.OWN = setmetatable({ background = {} }, { __index = function(_, kind)
    if kind == "font" then return Lib.FONTS end
    if kind == "statusbar" then
        local list = {}
        for i, name in ipairs(BARS) do list[i] = { name = "FCM " .. name, path = Lib.Texture(name .. "Bar") } end
        return list
    end
end })
local SOURCES = { Media.BLIZZARD, Media.OWN }
Media.DEFAULT = {
    font = "Fonts\\FRIZQT__.TTF",
    background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    statusbar = "Interface\\Buttons\\WHITE8X8",
}

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every name of a kind ("font", "background", "statusbar"), Blizzard's
-- first, then ours, then LibSharedMedia's sorted.
function Media.Names(kind)
    local names, seen = {}, {}
    for _, source in ipairs(SOURCES) do
        for _, f in ipairs(source[kind]) do
            names[#names + 1] = f.name
            seen[f.name] = true
        end
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

-- The file for a name; unknown names get the kind's default. A font stored
-- under an older name (LibForeverThemes' aliases) finds its file there,
-- after ours and LibSharedMedia's.
function Media.Path(kind, name)
    for _, source in ipairs(SOURCES) do
        for _, f in ipairs(source[kind]) do
            if f.name == name then return f.path end
        end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch(kind, name, true)
    if not path and kind == "font" then path = Lib.FontPath(name) end
    return path or Media.DEFAULT[kind]
end

function Media.FontNames() return Media.Names("font") end
function Media.FontPath(name) return Media.Path("font", name) end

-- A font file draws only its own letters: Friz Quadrata and most others
-- have no Cyrillic, Hangul or Hanzi, so such names became squares. Blizzard's
-- own fonts are families, one file per alphabet (Fonts.xml); Media.Family
-- makes one around the chosen file, the rest from the client's files.
-- The _CYR files draw Latin a little differently, so not for Latin. nil
-- where the client cannot make families. As in ForeverUnitFrames.
local CYRILLIC = {
    ["fonts\\frizqt__.ttf"] = "Fonts\\FRIZQT___CYR.TTF",
    ["fonts\\morpheus.ttf"] = "Fonts\\MORPHEUS_CYR.TTF",
    ["fonts\\skurri.ttf"] = "Fonts\\SKURRI_CYR.TTF",
}
local HAS_CYRILLIC = { ["fonts\\arialn.ttf"] = true, ["fonts\\frizqt___cyr.ttf"] = true,
    ["fonts\\morpheus_cyr.ttf"] = true, ["fonts\\skurri_cyr.ttf"] = true }
local OTHER_ALPHABETS = {
    { alphabet = "korean", file = "Fonts\\2002.TTF" },
    { alphabet = "simplifiedchinese", file = "Fonts\\ARKai_T.ttf" },
    { alphabet = "traditionalchinese", file = "Fonts\\blei00d.TTF" },
}
local families, familyCount = {}, 0
local function plain(p) return (p:lower():gsub("/", "\\")) end

local function cyrillicFor(file)
    local p = plain(file)
    if HAS_CYRILLIC[p] then return file end
    return CYRILLIC[p] or "Fonts\\FRIZQT___CYR.TTF"
end

-- Whether path is one of the files a family around file draws with (the
-- client reports the file of the text's alphabet).
local function inFamily(file, path)
    if not next(families) then return false end
    path = plain(path)
    if path == plain(cyrillicFor(file)) then return true end
    for _, other in ipairs(OTHER_ALPHABETS) do
        if path == plain(other.file) then return true end
    end
    return false
end

local function forgetFamily(file, size, flags)
    local key = file .. "|" .. size .. "|" .. flags
    families[key .. "|"], families[key .. "|shadow"] = nil, nil
end

-- A font object hands its texts its own shadow, and CreateFontFamily takes
-- none: the family carries the text's.
local function shade(font, shadow)
    pcall(font.SetShadowOffset, font, shadow and 1 or 0, shadow and -1 or 0)
    pcall(font.SetShadowColor, font, 0, 0, 0, 1)
end

function Media.Family(file, size, flags, shadow)
    if type(CreateFontFamily) ~= "function" or type(file) ~= "string" then return nil end
    local key = file .. "|" .. size .. "|" .. flags .. "|" .. (shadow and "shadow" or "")
    local family = families[key]
    if family == nil then
        local members = {
            { alphabet = "roman", file = file, height = size, flags = flags },
            { alphabet = "russian", file = cyrillicFor(file), height = size, flags = flags },
        }
        for _, other in ipairs(OTHER_ALPHABETS) do
            members[#members + 1] = { alphabet = other.alphabet, file = other.file, height = size, flags = flags }
        end
        familyCount = familyCount + 1
        local ok, made = pcall(CreateFontFamily, ADDON .. "Font" .. familyCount, members)
        family = ok and made or false
        if family then
            shade(family, shadow)
            for _, member in ipairs(members) do
                local got, font = pcall(family.GetFontObjectForAlphabet, family, member.alphabet)
                if got and font then shade(font, shadow) end
            end
        end
        families[key] = family
    end
    return family or nil
end

-- A file onto a text, inside its family. Only the family: a file once set
-- with SetFont wins over any font object for good (seen in game). The
-- file alone where the client makes no families.
function Media.SetFont(fs, path, size, flags, shadow)
    local family = Media.Family(path, size, flags, shadow)
    if family and pcall(fs.SetFontObject, fs, family) then return true end
    local ok, took = pcall(fs.SetFont, fs, path, size, flags)
    return ok and took
end

-- Whether a text took the font file asked for (a refused one leaves the
-- old font, or none).
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    return plain(got) == plain(path) or inFamily(path, got)
end
-- How often, and how far apart, a refused font is tried again.
local FONT_TRIES, FONT_RETRY_DELAY = 40, 0.25
-- First use of a file can take seconds when many fonts load at once
-- (theme switch); report each file only once.
local refusedFonts = {}

local function setShadow(fs, shadow)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
end

-- A font file used for the first time can leave a text blank although
-- GetFont reports it (seen in game: empty texts until the theme was
-- chosen a second time). Setting it again a little later, through another
-- font, as that second choice did, draws them. Once per text and font.
local REDRAW_DELAYS = { 0.5, 2 }
local function redrawLater(fs, path, size, flags, shadow, wanted)
    if fs.fontDrawn == wanted then return end
    fs.fontDrawn = wanted
    for _, delay in ipairs(REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fs.fontWanted ~= wanted then return end
            Media.SetFont(fs, "Fonts\\FRIZQT__.TTF", size, flags, shadow)
            Media.SetFont(fs, path, size, flags, shadow)
            setShadow(fs, shadow)
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
    local shadow = flag == "SHADOW" or flag == "OUTLINESHADOW"
    local path = Media.FontPath(style.font)
    local wanted = path .. "|" .. style.size .. "|" .. outline .. "|" .. tostring(shadow)
    fs.fontWanted = wanted
    if Media.SetFont(fs, path, style.size, outline, shadow) and hasFont(fs, path) then
        redrawLater(fs, path, style.size, outline, shadow, wanted)
    else
        Media.SetFont(fs, Media.DEFAULT.font, style.size, outline, shadow)
        -- The next try makes a new family: this one may hold the refusal.
        forgetFamily(path, style.size, outline)
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
    setShadow(fs, shadow)
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
