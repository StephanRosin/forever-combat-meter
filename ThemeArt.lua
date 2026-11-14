local _, ns = ...

-- The theme's art beyond settings (Themes.lua), as in Forever Unit Frames
-- (Elements/ThemeArt.lua): a tiled backdrop under the window reaching
-- `pad` beyond it (the border ring goes round that, so the backdrop frames
-- the bars like a plaque), ornaments at the ring's outer corners and a
-- solid shadow behind it. Plain textures only, nothing clickable. Made on
-- a window's first themed look: under CLASSIC a window has none of it.
-- The backdrop has a rounding mask of its own, concentric with the ring.
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local PATH = "Interface\\AddOns\\ForeverCombatMeter\\Media\\Themes\\"
local SHADOW_COLOR = { 0, 0, 0, 1 }
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
    box.shadow = box:CreateTexture(nil, "BACKGROUND", nil, -8)
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

-- Ornaments sit at the ring's outer corners, art.ornamentInset inwards
-- (negative: outwards); mirrored per corner, never rotated.
local function placeOrnaments(box, art, extent)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or DEFAULT_ORNAMENT_SIZE, (art.ornamentInset or 0) - extent
    local c = art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(box.ornaments) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, box, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(PATH .. art.ornament)
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

-- The solid shadow: the ring's outer box, moved down and right.
local function placeShadow(box, art, extent)
    local shadow, offset = box.shadow, art.hardShadow
    shadow:SetShown(offset ~= nil)
    if not offset then return end
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", box, "TOPLEFT", offset - extent, extent - offset)
    shadow:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", offset + extent, -offset - extent)
    shadow:SetColorTexture(SHADOW_COLOR[1], SHADOW_COLOR[2], SHADOW_COLOR[3], SHADOW_COLOR[4])
end

-- The title strip: no gold glow under a theme (its backdrop is the look),
-- a dark strip where the theme wants one, the line in the theme's colour.
local function styleHeader(h, art)
    h.shine:Hide()
    if art.darkTitle then h.dark:Show() end
    local c = art.line
    if c then h.line:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

-- Window f (a meter window or the breakdown panel) in theme spec, its
-- background rounded by radius, its ring reaching out by extent. Returns
-- the box the ring goes round and that box's radius: f itself under
-- CLASSIC.
function ThemeArt.Style(f, spec, radius, extent)
    local art = spec.art
    if not art then
        if f.header then f.header.line:SetColorTexture(unpack(ThemeArt.LINE)) end
        if f.themeBox then
            f.themeBox:Hide()
            f.themeBox.over:Hide()
        end
        return f, radius
    end
    local box = f.themeBox or build(f)
    local pad = art.pad or 0
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", -pad, pad)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", pad, -pad)
    box:Show()
    box.over:Show()
    local outer = radius > 0 and ns.Corners.Clamp(radius + pad) or 0
    paintBack(box.back, art)
    ns.Corners.Fit(box.clip, box, outer, { box.back })
    placeOrnaments(box, art, extent)
    placeShadow(box, art, extent)
    if f.header then styleHeader(f.header, art) end
    return box, outer
end
