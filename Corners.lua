local _, ns = ...

-- Rounded corners, taken from Forever Unit Frames (Core/Corners.lua) so
-- both addons draw the same ring. One mask texture per rounded box: a
-- rounded rectangle (Media/RoundedNN.tga, tools/make_corners.py) drawn as a
-- shader nine-slice (SetTextureSliceMargins). The corner cells keep their
-- shape at any box size; only edges and middle stretch.
--
-- The client's rule for a sliced mask, measured in game for Forever Unit
-- Frames: a corner cell is drawn `margin` UI units wide and high, whatever
-- the file's size, the box's size or the mask's own scale. So the radius
-- picks the file: RoundedNN has arcs of NN texels and is sliced with
-- margins of NN. Radii are whole UI units.
--
-- The client allows three masks per texture: a texture here carries one.
local Corners = {}
ns.Corners = Corners

local MEDIA = "Interface\\AddOns\\ForeverCombatMeter\\Media\\"
-- Border ring corner piece (mirrored per corner with texture coordinates)
-- and its inner cut, a mask file per corner in Corners.POINTS order: masks
-- ignore texture coordinates in the client.
Corners.TEXTURE = MEDIA .. "Corner.tga"
Corners.INVERSE = {
    MEDIA .. "CornerInverseTopLeft.tga", MEDIA .. "CornerInverseTopRight.tga",
    MEDIA .. "CornerInverseBottomLeft.tga", MEDIA .. "CornerInverseBottomRight.tga",
}
Corners.MAX_RADIUS = 12
Corners.POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- left, right, top, bottom: mirrored copies of the top-left shape.
Corners.COORDS = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }

function Corners.MaskFile(radius)
    return ("%sRounded%02d.tga"):format(MEDIA, radius)
end

-- A whole radius between 0 and MAX_RADIUS, never more than half the
-- shorter side of a w x h box.
function Corners.Clamp(radius, w, h)
    radius = math.max(0, math.min(math.floor(radius or 0), Corners.MAX_RADIUS))
    if w and h then radius = math.min(radius, math.floor(math.min(w, h) / 2 + 1e-6)) end
    return radius
end

-- The inner-arc mask of corner i (1..4, Corners.POINTS order) on owner.
function Corners.NewInnerMask(owner, i)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(Corners.INVERSE[i], "CLAMP", "CLAMP")
    return mask
end

-- Puts mask on texture (on) or takes it off again; never twice. Which mask
-- a texture carries is remembered here, not on the texture.
local masked = setmetatable({}, { __mode = "k" })
function Corners.SetMasked(texture, mask, on)
    if on and masked[texture] ~= mask then
        texture:AddMaskTexture(mask)
        masked[texture] = mask
    elseif not on and masked[texture] == mask then
        texture:RemoveMaskTexture(mask)
        masked[texture] = nil
    end
end

-- Rounds the textures in `targets` to box with radius (0: square).
function Corners.Fit(clip, box, radius, targets)
    clip.mask = clip.mask or box:CreateMaskTexture()
    local mask, on = clip.mask, radius > 0
    mask:ClearAllPoints()
    mask:SetAllPoints(box)
    if on and clip.radius ~= radius then
        mask:SetTexture(Corners.MaskFile(radius), "CLAMP", "CLAMP")
        mask:SetTextureSliceMargins(radius, radius, radius, radius)
        mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    clip.radius = radius
    mask:SetShown(on)
    for _, texture in ipairs(targets) do Corners.SetMasked(texture, mask, on) end
end
