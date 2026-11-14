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
    f.themeBox = box
    return box
end

local function paintBack(texture, art)
    texture:SetTexture(PATH .. art.back, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    local tint = art.tint or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
end

-- Ornaments sit in the window's corners (the ring's outer corners),
-- art.ornamentInset further in; mirrored per corner, never rotated.
local function placeOrnaments(f, box, art)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or DEFAULT_ORNAMENT_SIZE, math.max(art.ornamentInset or 0, 0)
    local c = art.ornamentColor or { 1, 1, 1, 1 }
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

-- The title strip: no gold glow under a theme (its backdrop is the look),
-- a dark strip where the theme wants one, the line in the theme's colour.
local function styleHeader(h, art)
    h.shine:Hide()
    if art.darkTitle then h.dark:Show() end
    local c = art.line
    if c then h.line:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

-- The colour of a title icon: the theme's ink where it has one, else
-- color (the button's usual one for its state).
function ThemeArt.IconColor(color, hover)
    local spec = ns.Themes.Spec(ns.Settings.Get("theme"))
    if not spec.iconColor then return color end
    return hover and spec.iconHover or spec.iconColor
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
        if f.header then f.header.line:SetColorTexture(unpack(ThemeArt.LINE)) end
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
    if f.header then styleHeader(f.header, art) end
    return box
end
