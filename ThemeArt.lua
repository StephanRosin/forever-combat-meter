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

local PATH = "Interface\\AddOns\\ForeverCombatMeter\\Media\\Themes\\"
-- The title's line without a theme: the quest log's gold.
ThemeArt.LINE = { 0.78, 0.59, 0.13, 0.45 }
-- The title's dark strip (COMPACT, darkTitle = true).
local DARK = { 0, 0, 0, 0.35 }
local DEFAULT_ORNAMENT_SIZE = 12
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
    f.themeBox = box
    return box
end

local function paintBack(texture, art)
    local back, tint = ns.Themes.Backdrop(art)
    texture:SetTexture(PATH .. back, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    tint = tint or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
end

-- Ornaments sit in the window's corners (the ring's outer corners),
-- art.ornamentInset further in; mirrored per corner, never rotated.
local function placeOrnaments(f, box, art)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or DEFAULT_ORNAMENT_SIZE, math.max(art.ornamentInset or 0, 0)
    local c = ns.Themes.Ornament(art.ornamentColor or { 1, 1, 1, 1 })
    for i, piece in ipairs(box.ornaments) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, f, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(PATH .. art.ornament)
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

local function placeBand(box, art)
    local band = art.band
    box.band:SetShown(band ~= nil)
    if not band then return end
    box.band:ClearAllPoints()
    box.band:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.band:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    box.band:SetHeight(band.height)
    box.band:SetColorTexture(band.color[1], band.color[2], band.color[3], band.color[4])
end

-- The wedge texture is square with the slanted piece in its left part:
-- that part only, as wide as high, as in every Forever addon. Its right
-- edge runs from 0.98 of the width at the top to 0.62 at the bottom; the
-- title starts TITLE_GAP past it at the title's middle.
local WEDGE_PART, TITLE_GAP = 0.53, 8

-- The wedge in the title strip inside the ring (inset by the ring's extent).
local function placeWedge(f, box, art, inset)
    box.wedge:SetShown(art.wedge ~= nil and f.header ~= nil)
    if not box.wedge:IsShown() then return end
    local h = f.header:GetHeight() - inset
    box.wedge:ClearAllPoints()
    box.wedge:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.wedge:SetSize(h, h)
    box.wedge:SetTexture(PATH .. art.wedge)
    box.wedge:SetTexCoord(0, WEDGE_PART, 0, 1)
    local c = ns.Themes.Ornament(art.wedgeColor)
    box.wedge:SetVertexColor(c[1], c[2], c[3], c[4])
end

-- How far from the header's left a title (or the grip before it) starts to
-- clear the theme's wedge in a header this high; 0 without a wedge.
function ThemeArt.TitleIndent(header)
    local art = ns.Themes.Spec(ns.Settings.Get("theme")).art
    if not (art and art.wedge) then return 0 end
    local inset = ns.Border.Extent({ style = ns.Settings.Get("borderStyle"), size = ns.Settings.Get("borderSize") })
    local h, mid = header - inset, header / 2 - inset
    return inset + math.floor(0.98 * h - 0.36 * mid + 0.5) + TITLE_GAP
end

-- The title strip: no gold glow under a theme (its backdrop is the look),
-- a dark strip where the theme wants one, the line in the theme's colour.
local function styleHeader(h, art)
    h.shine:Hide()
    local dark = type(art.darkTitle) == "table" and art.darkTitle or DARK
    h.dark:SetColorTexture(dark[1], dark[2], dark[3], dark[4])
    if art.darkTitle then h.dark:Show() end
    local c = art.line
    if c then h.line:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

-- The colour of a title icon: the theme's ink where it has one (COMIC; on
-- a dark comic paper the ink is light instead), under every other theme
-- the colour's accent (Themes.IconAccent), under a hover half way to white
-- as in every Forever addon; CLASSIC color (the button's usual one for its
-- state).
local LIGHT_IDLE, LIGHT_HOVER = { 0.85, 0.85, 0.85 }, { 1, 1, 1 }
local ICON_HOVER = 0.5

function ThemeArt.IconColor(color, hover)
    if ns.Themes.DarkPaper() then return hover and LIGHT_HOVER or LIGHT_IDLE end
    local spec = ns.Themes.Spec(ns.Settings.Get("theme"))
    if spec.iconColor then return hover and spec.iconHover or spec.iconColor end
    local a = ns.Themes.IconAccent()
    if not a then return color end
    if not hover then return a end
    return { a[1] + (1 - a[1]) * ICON_HOVER, a[2] + (1 - a[2]) * ICON_HOVER, a[3] + (1 - a[3]) * ICON_HOVER }
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
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", extent, -extent)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -extent, extent)
    box:Show()
    box.over:Show()
    -- The background colour behind the bars only: the padding shows the
    -- backdrop as a band (none with no padding, as in COMPACT).
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", padding, -padding)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -padding, padding)
    paintBack(box.back, art)
    ns.Corners.Fit(box.clip, box, radius, { box.back })
    placeOrnaments(f, box, art)
    placeBand(box, art)
    placeWedge(f, box, art, extent)
    if f.header then styleHeader(f.header, art) end
    return box
end
