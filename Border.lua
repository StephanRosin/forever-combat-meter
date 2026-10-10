local _, ns = ...

-- The frame's border and drop shadow, drawn like Forever Unit Frames'
-- (Core/Border.lua) so the meter matches the unit frames: a ring
-- `size` thick around a box, eight pieces (four edges, four corner squares).
-- With rounded corners each corner square shows the outer arc (Corner.tga)
-- masked by the inner arc (CornerInverse*.tga), both centred where the
-- box's own rounded corner is centred. The pieces are white; paint colours
-- them with vertex colours.
--
-- Styles: FLAT is one colour. GOLD is shaded like a bevel, lighter at the
-- top, darker at the bottom, with a dark one-pixel line along the inside.
--
-- Border.Draw(owner, box, look) with look = { style, size, color, radius,
-- shadow = true/false, shadowSize, shadowAlpha (0..1) }.
local Border = {}
ns.Border = Border

Border.SHADOW = "Interface\\AddOns\\ForeverCombatMeter\\Media\\Shadow.tga"
local SHADOW_WIDTH, CELL, CELLS = 512, 32, 16
local HALF_U, HALF_V = 0.5 / SHADOW_WIDTH, 0.5 / CELL
local EDGE_U, EDGE_V = (CELL - 0.5) / SHADOW_WIDTH, (CELL - 0.5) / CELL

-- Gold shades. LIGHT and MID are Blizzard's own gold gradient (the
-- animated dispel border, Blizzard_PrivateAurasUI.lua); SHADE, DARK and
-- LINE are the same hue, darker.
Border.GOLD = {
    LIGHT = { 1, 1, 0.557, 1 },
    MID = { 1, 0.792, 0.188, 1 },
    SHADE = { 0.78, 0.59, 0.13, 1 },
    DARK = { 0.55, 0.38, 0.07, 1 },
    LINE = { 0.2, 0.12, 0.02, 1 },
}

local OUT = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
local INNER = { "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" }

-- Whole physical pixels in UIParent's units (PixelUtil, Blizzard_SharedXML).
function Border.Snap(v, minPixels)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(v, UIParent:GetEffectiveScale(), minPixels)
    end
    return v
end

-- How far the border reaches out from its box.
function Border.Extent(look)
    if look.style == "NONE" then return 0 end
    return Border.Snap(look.size, 1)
end

-- Ring ------------------------------------------------------------------------

local function newRing(owner, sublevel)
    local ring = { corners = {}, inner = {} }
    for i = 1, 4 do
        ring[i] = owner:CreateTexture(nil, "OVERLAY", nil, sublevel)
        ring[i]:SetColorTexture(1, 1, 1, 1)
    end
    for i = 1, 4 do
        ring.corners[i] = owner:CreateTexture(nil, "OVERLAY", nil, sublevel)
        ring.inner[i] = ns.Corners.NewInnerMask(owner, i)
    end
    return ring
end

local function ringPieces(ring)
    return { ring[1], ring[2], ring[3], ring[4], ring.corners[1], ring.corners[2], ring.corners[3], ring.corners[4] }
end

local function placeEdges(ring, box, size, reach, corner)
    local inset = corner - reach
    ring[1]:ClearAllPoints()
    ring[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset, 0)
    ring[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset, 0)
    ring[1]:SetHeight(size)
    ring[2]:ClearAllPoints()
    ring[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset, 0)
    ring[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -inset, 0)
    ring[2]:SetHeight(size)
    ring[3]:ClearAllPoints()
    ring[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", 0, -inset)
    ring[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", 0, inset)
    ring[3]:SetWidth(size)
    ring[4]:ClearAllPoints()
    ring[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", 0, -inset)
    ring[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 0, inset)
    ring[4]:SetWidth(size)
end

local function cornerArt(piece, i, round)
    if not round then
        piece:SetColorTexture(1, 1, 1, 1)
        return
    end
    piece:SetTexture(ns.Corners.TEXTURE, "CLAMP", "CLAMP")
    local c = ns.Corners.COORDS[i]
    piece:SetTexCoord(c[1], c[2], c[3], c[4])
end

local function placeCorners(ring, box, size, reach, corner, round)
    for i, point in ipairs(ns.Corners.POINTS) do
        local piece, sx, sy = ring.corners[i], OUT[i][1], OUT[i][2]
        piece:ClearAllPoints()
        piece:SetPoint(point, box, point, sx * reach, sy * reach)
        piece:SetSize(corner, corner)
        cornerArt(piece, i, round)
        local inner = ring.inner[i]
        inner:ClearAllPoints()
        inner:SetPoint(point, piece, point, -sx * size, -sy * size)
        inner:SetSize(corner - size, corner - size)
        inner:SetShown(round)
        ns.Corners.SetMasked(piece, inner, round)
    end
end

-- A ring `size` thick right outside box, concentric with a box rounded by
-- radius. Returns the corner squares' size.
local function placeRing(ring, box, size, radius)
    local round = size > 0 and radius > 0
    local reach = size
    local corner = round and (radius + reach) or size
    placeEdges(ring, box, size, reach, corner)
    placeCorners(ring, box, size, reach, corner, round)
    return corner
end

-- The gold style's dark inner line: a ring one pixel thick, inset by the
-- border's size minus one pixel (the ring's innermost pixel).
local function placeLine(ring, box, size, pixel, radius)
    local round = radius > 0
    local reach = pixel
    local corner = round and (radius + reach) or pixel
    placeEdges(ring, box, pixel, reach, corner)
    placeCorners(ring, box, pixel, reach, corner, round)
end

local function showRing(ring, shown)
    for _, piece in ipairs(ringPieces(ring)) do piece:SetShown(shown) end
    if shown then return end
    for i = 1, 4 do ring.inner[i]:Hide() end
end

local function paintFlat(ring, c)
    for _, piece in ipairs(ringPieces(ring)) do piece:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

local function color(c) return CreateColor(c[1], c[2], c[3], c[4]) end

local function mix(from, to, share)
    local c = {}
    for i = 1, 4 do c[i] = from[i] + (to[i] - from[i]) * share end
    return c
end

-- Lit from above: one vertical shading, continuous over the whole ring.
local function goldShades(share)
    local G = Border.GOLD
    local function vertical(bottom, top) return { color(bottom), color(top) } end
    local top = vertical(mix(G.LIGHT, G.MID, share), G.LIGHT)
    local bottom = vertical(G.DARK, mix(G.DARK, G.SHADE, share))
    local side = vertical(G.SHADE, G.MID)
    local topCorner, bottomCorner = vertical(G.MID, G.LIGHT), vertical(G.DARK, G.SHADE)
    return { top, bottom, side, side, topCorner, topCorner, bottomCorner, bottomCorner }
end

local function paintGold(ring, share)
    local shades = goldShades(share)
    for i, piece in ipairs(ringPieces(ring)) do piece:SetGradient("VERTICAL", shades[i][1], shades[i][2]) end
end

-- Shadow ----------------------------------------------------------------------

local function newShadow(owner)
    local shadow = { corners = {}, inner = {} }
    local function piece()
        local texture = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetTexture(Border.SHADOW, "CLAMP", "CLAMP")
        return texture
    end
    for i = 1, 4 do shadow[i] = piece() end
    for i = 1, 4 do
        shadow.corners[i] = piece()
        shadow.inner[i] = ns.Corners.NewInnerMask(owner, i)
    end
    return shadow
end

local function placeShadowEdges(shadow, box, reach, radius, size)
    local inset = radius - reach
    shadow[1]:ClearAllPoints()
    shadow[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset, reach)
    shadow[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset, reach)
    shadow[1]:SetHeight(size)
    shadow[1]:SetTexCoord(EDGE_U, EDGE_U, 0, 1)
    shadow[2]:ClearAllPoints()
    shadow[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset, -reach)
    shadow[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -inset, -reach)
    shadow[2]:SetHeight(size)
    shadow[2]:SetTexCoord(EDGE_U, EDGE_U, 1, 0)
    shadow[3]:ClearAllPoints()
    shadow[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", -reach, -inset)
    shadow[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -reach, inset)
    shadow[3]:SetWidth(size)
    shadow[3]:SetTexCoord(0, EDGE_U, EDGE_V, EDGE_V)
    shadow[4]:ClearAllPoints()
    shadow[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", reach, -inset)
    shadow[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", reach, inset)
    shadow[4]:SetWidth(size)
    shadow[4]:SetTexCoord(EDGE_U, 0, EDGE_V, EDGE_V)
end

local function placeShadowCorners(shadow, box, reach, radius, size)
    local span = radius + size
    local cell = math.min(CELLS - 1, math.floor(radius / span * CELLS + 0.5))
    local left, right = (cell * CELL) / SHADOW_WIDTH + HALF_U, ((cell + 1) * CELL) / SHADOW_WIDTH - HALF_U
    local top, bottom = HALF_V, 1 - HALF_V
    local coords = { { left, right, top, bottom }, { right, left, top, bottom },
        { left, right, bottom, top }, { right, left, bottom, top } }
    local round = radius > 0
    for i, point in ipairs(ns.Corners.POINTS) do
        local piece, mask, out = shadow.corners[i], shadow.inner[i], reach + size
        piece:ClearAllPoints()
        piece:SetPoint(point, box, point, OUT[i][1] * out, OUT[i][2] * out)
        piece:SetSize(span, span)
        piece:SetTexCoord(coords[i][1], coords[i][2], coords[i][3], coords[i][4])
        mask:ClearAllPoints()
        mask:SetPoint(INNER[i], piece, INNER[i], 0, 0)
        mask:SetSize(radius, radius)
        mask:SetShown(round)
        ns.Corners.SetMasked(piece, mask, round)
    end
end

local function hideShadow(shadow)
    for _, piece in ipairs(ringPieces(shadow)) do piece:Hide() end
    for i = 1, 4 do shadow.inner[i]:Hide() end
end

local function drawShadow(shadow, box, look, reach, radius)
    if not look.shadow or look.shadowSize <= 0 then
        hideShadow(shadow)
        return
    end
    local size = Border.Snap(look.shadowSize, 1)
    for _, piece in ipairs(ringPieces(shadow)) do
        piece:Show()
        piece:SetVertexColor(0, 0, 0, look.shadowAlpha)
    end
    local outer = radius > 0 and radius + reach or 0
    placeShadowEdges(shadow, box, reach, outer, size)
    placeShadowCorners(shadow, box, reach, outer, size)
end

-- Drawing ---------------------------------------------------------------------

local parts = setmetatable({}, { __mode = "k" })

local function partsOf(owner)
    local p = parts[owner]
    if not p then
        p = { ring = newRing(owner, 0), line = newRing(owner, 1), shadow = newShadow(owner) }
        parts[owner] = p
    end
    return p
end

function Border.Draw(owner, box, look)
    local p = partsOf(owner)
    local hasRing = look.style ~= "NONE"
    local size = hasRing and Border.Snap(look.size, 1) or 0
    local radius = look.radius or 0
    if hasRing then
        local corner = placeRing(p.ring, box, size, radius)
        if look.style == "GOLD" then
            paintGold(p.ring, corner > 0 and size / corner or 1)
        else
            paintFlat(p.ring, look.color)
        end
    end
    showRing(p.ring, hasRing)
    local pixel = Border.Snap(1, 1)
    local hasLine = look.style == "GOLD" and size >= 2 * pixel
    if hasLine then
        placeLine(p.line, box, size, pixel, radius)
        paintFlat(p.line, Border.GOLD.LINE)
    end
    showRing(p.line, hasLine)
    drawShadow(p.shadow, box, look, size, radius)
end

-- For the tests: the eight ring pieces and whether the line shows.
function Border.Pieces(owner)
    local p = parts[owner]
    return p and ringPieces(p.ring) or {}, p and ringPieces(p.line) or {}
end
