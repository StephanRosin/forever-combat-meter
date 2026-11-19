local _, ns = ...

-- The theme's art beyond settings (Themes.lua), as in Forever Unit Frames
-- (Elements/ThemeArt.lua): a tiled backdrop under the window and
-- ornaments at its corners. Plain textures only, nothing clickable. Made on
-- a window's first themed look: under CLASSIC a window has none of it.
--
-- Nothing reaches beyond the window (players stack windows edge to edge):
-- the border ring lies just inside its edge, the backdrop inside the ring,
-- and the window's own padding shows the backdrop round the bars (the
-- background colour only fills the inside). No solid shadow: it would
-- fall on the window below. The backdrop has a rounding mask of its own,
-- concentric with the ring.
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local Lib = LibForeverThemes
-- The title's line without a theme: the quest log's gold.
ThemeArt.LINE = { 0.78, 0.59, 0.13, 0.45 }
-- The title's dark strip (COMPACT, art.darkTitle).
local DARK = { 0, 0, 0, 0.35 }
local DEFAULT_ORNAMENT_SIZE = 12
-- Ornaments keep their colour: the theme colours paint only the wedge.
local WHITE = { 1, 1, 1, 1 }
-- Above the header, the bars and their texts.
local OVER_LEVELS = 12

local function build(f)
    -- Below the window's own level: under its background and bars.
    local box = CreateFrame("Frame", nil, f)
    box:SetFrameLevel(math.max(f:GetFrameLevel() - 1, 0))
    box.back = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    box.back:SetAllPoints(box)
    box.clip = {}
    box.over = CreateFrame("Frame", nil, f)
    box.over:SetAllPoints(f)
    box.over:SetFrameLevel(f:GetFrameLevel() + OVER_LEVELS)
    box.ornaments = {}
    for i = 1, 4 do box.ornaments[i] = box.over:CreateTexture(nil, "OVERLAY") end
    box.band = box.over:CreateTexture(nil, "ARTWORK")
    box.wedge = box.over:CreateTexture(nil, "OVERLAY")
    -- The banner under the header's title and icons, over the backdrop.
    box.banner = box:CreateTexture(nil, "BORDER", nil, 0)
    box.ends = {}
    for i = 1, 2 do box.ends[i] = box:CreateTexture(nil, "BORDER", nil, 1) end
    -- The frame outside the window, under its ornaments.
    box.frame = {}
    for i = 1, 4 do box.frame[i] = box.over:CreateTexture(nil, "BORDER") end
    f.themeBox = box
    return box
end

local function paintBack(texture, art)
    local back, tint = ns.Themes.Backdrop(art)
    texture:SetTexture(Lib.Texture(back), "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    tint = tint or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
end

-- Ornaments sit in the window's corners (the ring's outer corners; with a
-- frame its outer corners, `out` further out), art.ornamentInset further
-- in; mirrored per corner, never rotated.
local function placeOrnaments(f, box, art, out)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or DEFAULT_ORNAMENT_SIZE, math.max(art.ornamentInset or 0, 0) - out
    local c = art.ornamentColor or WHITE
    for i, piece in ipairs(box.ornaments) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, f, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(Lib.Texture(art.ornament))
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

-- Swiss's rule along the top (the library's rule, ruleSize thick).
local function placeBand(box, art)
    local rule = art.rule
    box.band:SetShown(rule ~= nil)
    if not rule then return end
    box.band:ClearAllPoints()
    box.band:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.band:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    box.band:SetHeight(art.ruleSize)
    box.band:SetColorTexture(rule[1], rule[2], rule[3], rule[4])
end

-- The frame (Azeroth's walnut, the goblins' copper): four strips of its
-- material round the window's outside, the top and bottom ones across the
-- corners, repeating at its own size. The one theme part beyond the window's
-- edge: the library's frames run round the ring, which here is the edge.
-- Returns how wide it is (0 without one).
-- The material frame's width (Azeroth, Goblin), 0 without one. It lies
-- inside the window's edge, the ring inside it: windows stacked edge to edge
-- stay flush with each other as under every other theme.
function ThemeArt.FrameWidth()
    local art = ns.Themes.Spec(ns.Settings.Get("theme")).art
    return art and art.frame and ns.Border.Snap(art.frameSize, 1) or 0
end

local function placeFrame(f, box, art)
    for _, s in ipairs(box.frame) do s:SetShown(art.frame ~= nil) end
    if not art.frame then return 0 end
    local w = ns.Border.Snap(art.frameSize, 1)
    local spots = {
        { "TOPLEFT", 0, 0, "TOPRIGHT", 0, -w },
        { "BOTTOMLEFT", 0, w, "BOTTOMRIGHT", 0, 0 },
        { "TOPLEFT", 0, -w, "BOTTOMLEFT", w, w },
        { "TOPRIGHT", -w, -w, "BOTTOMRIGHT", 0, w },
    }
    for i, s in ipairs(box.frame) do
        local p = spots[i]
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", f, p[1], p[2], p[3])
        s:SetPoint("BOTTOMRIGHT", f, p[4], p[5], p[6])
        s:SetTexture(Lib.Texture(art.frame), "REPEAT", "REPEAT")
        s:SetHorizTile(true)
        s:SetVertTile(true)
        s:SetVertexColor(1, 1, 1, 1)
    end
    return w
end

-- A banner end's width per height (the file is half as wide as high).
local BANNER_END = 0.5

-- The banner's height in a header this high, the ring `inset` thick:
-- art.bannerHeight (the goblins' thin stripes: text on them would not
-- read) or the header's inside the ring.
local function bannerHeight(art, header, inset)
    return art.bannerHeight or header - inset
end

-- How far in from the header's sides its contents start to clear the
-- banner's ends (the ring's inset with them); 0 without ends.
function ThemeArt.BannerEnd(header)
    local art = ns.Themes.Spec(ns.Settings.Get("theme")).art
    if not (art and art.banner and art.bannerEnd) then return 0 end
    local inset = ns.Border.Extent({ style = ns.Settings.Get("borderStyle"), size = ns.Settings.Get("borderSize") })
        + ThemeArt.FrameWidth()
    return inset + math.floor(bannerHeight(art, header, inset) * BANNER_END + 0.5)
end

-- The title band as the library's banner (art.banner): along the top inside
-- the ring, stretched between its two ends (left as drawn, right mirrored),
-- or repeating at its own size (bannerTile). Hidden at no height: a texture
-- set 0 high shows at its file's height in the client.
local function placeBanner(f, box, art, inset)
    local h = art.banner and f.header and bannerHeight(art, f.header:GetHeight(), inset) or 0
    local shown = h > 0
    box.banner:SetShown(shown)
    local withEnds = shown and art.bannerEnd ~= nil
    for _, e in ipairs(box.ends) do e:SetShown(withEnds) end
    if not shown then return end
    local w = withEnds and math.floor(h * BANNER_END + 0.5) or 0
    for i, e in ipairs(withEnds and box.ends or {}) do
        local point = i == 1 and "TOPLEFT" or "TOPRIGHT"
        e:ClearAllPoints()
        e:SetPoint(point, box, point, 0, 0)
        e:SetSize(w, h)
        e:SetTexture(Lib.Texture(art.bannerEnd))
        if i == 1 then e:SetTexCoord(0, 1, 0, 1) else e:SetTexCoord(1, 0, 0, 1) end
    end
    local tile = art.bannerTile == true
    local b = box.banner
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", box, "TOPLEFT", w, 0)
    b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -w, 0)
    b:SetHeight(h)
    b:SetTexture(Lib.Texture(art.banner), tile and "REPEAT" or nil, tile and "REPEAT" or nil)
    b:SetHorizTile(tile)
    b:SetVertTile(tile)
end

-- The wedge texture is square with the slanted piece in its left part:
-- that part only (Lib.WEDGE_PART), as wide as high, as in every Forever
-- addon; the title starts Lib.TITLE_GAP past it at the title's middle.
-- The wedge in the title strip inside the ring (inset by the ring's extent).
local function placeWedge(f, box, art, inset)
    box.wedge:SetShown(art.wedge ~= nil and f.header ~= nil)
    if not box.wedge:IsShown() then return end
    local h = f.header:GetHeight() - inset
    box.wedge:ClearAllPoints()
    box.wedge:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.wedge:SetSize(h, h)
    box.wedge:SetTexture(Lib.Texture(art.wedge))
    box.wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
    local c = Lib.WedgeColor(art, ns.Themes.Current(), ns.Themes.Color())
    box.wedge:SetVertexColor(c[1], c[2], c[3], c[4])
end

-- How far from the header's left a title (or the grip before it) starts to
-- clear the theme's wedge (or banner end) in a header this high; 0 without.
function ThemeArt.TitleIndent(header)
    local art = ns.Themes.Spec(ns.Settings.Get("theme")).art
    if art and art.banner and art.bannerEnd then return ThemeArt.BannerEnd(header) end
    if not (art and art.wedge) then return 0 end
    local inset = ns.Border.Extent({ style = ns.Settings.Get("borderStyle"), size = ns.Settings.Get("borderSize") })
    local h, mid = header - inset, header / 2 - inset
    return inset + Lib.WedgeReach(h, mid) + Lib.TITLE_GAP
end

-- The title strip: no gold glow under a theme (its backdrop is the look),
-- a dark strip where the theme wants one (Pitwall's in the library's strip
-- colour), the line in the theme's colour.
local function styleHeader(h, art)
    h.shine:Hide()
    local dark = art.strip or DARK
    h.dark:SetColorTexture(dark[1], dark[2], dark[3], dark[4])
    if art.strip or art.darkTitle then h.dark:Show() end
    local c = art.line
    if c then h.line:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

-- The colour of a title icon: the theme's ink where it has one (COMIC; on
-- a dark comic paper the ink is light instead), under every other theme
-- the colour's accent (Themes.IconAccent), under a hover half way to white
-- as in every Forever addon (Lib.IconTones); CLASSIC color (the button's
-- usual one for its state).
local LIGHT_IDLE, LIGHT_HOVER = { 0.85, 0.85, 0.85 }, { 1, 1, 1 }

function ThemeArt.IconColor(color, hover)
    if ns.Themes.DarkPaper() then return hover and LIGHT_HOVER or LIGHT_IDLE end
    local spec = ns.Themes.Spec(ns.Settings.Get("theme"))
    if spec.iconColor then return hover and spec.iconHoverColor or spec.iconColor end
    local a = ns.Themes.IconAccent()
    if not a then return color end
    return hover and Lib.IconTones(a).hover or a
end

-- Window f (a meter window or the breakdown panel) in theme spec, rounded
-- by radius, its ring `extent` thick, the bars `padding` in from its edge.
-- Returns the box the ring goes round: f itself under CLASSIC, where the
-- ring lies outside as it always did.
function ThemeArt.Style(f, spec, radius, extent, padding)
    local art = spec.art
    f.bg:ClearAllPoints()
    if not art then
        f.bg:SetAllPoints(f)
        if f.header then
            f.header.line:SetColorTexture(unpack(ThemeArt.LINE))
            f.header.dark:SetColorTexture(unpack(DARK))
        end
        if f.themeBox then
            f.themeBox:Hide()
            f.themeBox.over:Hide()
        end
        return f
    end
    local box = f.themeBox or build(f)
    local inset = extent + ThemeArt.FrameWidth()
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    box:Show()
    box.over:Show()
    -- The background colour behind the bars only: the padding shows the
    -- backdrop as a band (none with no padding, as in COMPACT).
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", padding, -padding)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -padding, padding)
    paintBack(box.back, art)
    ns.Corners.Fit(box.clip, box, radius, { box.back })
    placeFrame(f, box, art)
    placeOrnaments(f, box, art, 0)
    placeBanner(f, box, art, inset)
    placeBand(box, art)
    placeWedge(f, box, art, extent)
    if f.header then styleHeader(f.header, art) end
    return box
end
