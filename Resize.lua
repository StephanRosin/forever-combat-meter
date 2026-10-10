local ADDON, ns = ...
local L, Media = ns.L, ns.Media

-- The four corner arrows of a resizable frame (meter windows, breakdown
-- panel). A drag grows or shrinks the frame towards the dragged corner, the
-- opposite corner stays where it is on screen. The result is always a TOP
-- anchor: x is the frame's centre, y its top edge, both as offsets from
-- UIParent in the frame's own units.
--
-- spec = {
--   locked    = function() -> bool        no grips, no resizing
--   width     = function() -> width       size now
--   rows      = function() -> rows
--   widthRange, rowsRange                 { min, max }
--   rowsFor   = function(height) -> rows  whole rows that fit a height
--   heightFor = function(rows) -> height
--   live      = function(f, r)            during the drag (f.resizing = r)
--   commit    = function(f, r)            once, on release, if it changed
--   done      = function(f)               after the drop
-- }
local Resize = {}
ns.Resize = Resize

local ACCENT = { 0.31, 0.76, 0.97 }
-- The arrows reach GRIP_IN into the frame: no further than a header's margin.
local GRIP_SIZE, GRIP_IN = 12, 3
Resize.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local function clamp(v, range)
    return math.max(range[1], math.min(range[2], math.floor(v + 0.5)))
end

local function cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function placement(spec, r, width, rows)
    local s = r.scale
    local w, h = width * s, spec.heightFor(rows) * s
    local fixedLeft = r.corner:find("RIGHT") ~= nil
    local top = r.corner:find("BOTTOM") and r.top or (r.bottom + h)
    local centre = fixedLeft and (r.left + w / 2) or (r.right - w / 2)
    return math.floor((centre - r.screenW / 2) / s + 0.5), math.floor((top - r.screenH) / s + 0.5)
end

local function follow(f, spec)
    local r = f.resizing
    if not r then return end
    -- A button released outside the grip may not reach OnMouseUp.
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        r.grip:GetScript("OnMouseUp")(r.grip, "LeftButton")
        return
    end
    local x, y = cursor()
    local dx, dy = (x - r.cursorX) / r.scale, (y - r.cursorY) / r.scale
    local width = clamp(r.width0 + (r.corner:find("RIGHT") and dx or -dx), spec.widthRange)
    local rows = math.max(spec.rowsRange[1], math.min(spec.rowsRange[2],
        spec.rowsFor(r.height0 + (r.corner:find("TOP") and dy or -dy))))
    if width == r.width and rows == r.rows then return end
    r.width, r.rows, r.moved = width, rows, true
    r.x, r.y = placement(spec, r, width, rows)
    spec.live(f, r)
end

local function start(f, spec, grip, button)
    if (button ~= nil and button ~= "LeftButton") or spec.locked() or f.resizing then return end
    local s = f:GetScale()
    local left, right, top, bottom = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not (left and top) then return end
    local x, y = cursor()
    f.resizing = {
        grip = grip, corner = grip.corner, scale = s, cursorX = x, cursorY = y,
        left = left * s, right = right * s, top = top * s, bottom = bottom * s,
        screenW = UIParent:GetWidth(), screenH = UIParent:GetHeight(),
        width0 = spec.width(), height0 = f:GetHeight(), width = spec.width(), rows = spec.rows(),
    }
    grip:SetScript("OnUpdate", function() follow(f, spec) end)
end

-- The drop: written once, so a plain click changes nothing.
local function stop(f, spec, grip)
    grip:SetScript("OnUpdate", nil)
    local r = f.resizing
    if not r or r.grip ~= grip then return end
    f.resizing = nil
    if r.moved then spec.commit(f, r) end
    spec.done(f)
end

local function paint(grip, hover)
    grip.art:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], hover and 1 or 0.55)
end

local function newGrip(f, spec, corner)
    local grip = CreateFrame("Button", nil, f)
    grip.corner = corner
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip.art = grip:CreateTexture(nil, "OVERLAY")
    grip.art:SetAllPoints()
    grip.art:SetTexture(Media.Icon("ArrowCorner"))
    -- The art points to the top right; mirrored for the other corners.
    local left, bottom = corner:find("LEFT") ~= nil, corner:find("BOTTOM") ~= nil
    grip.art:SetTexCoord(left and 1 or 0, left and 0 or 1, bottom and 1 or 0, bottom and 0 or 1)
    -- Mostly outside the corner; the part inside stays in the margin around
    -- the header buttons, so it covers neither them nor their clicks.
    local inner = (bottom and "TOP" or "BOTTOM") .. (left and "RIGHT" or "LEFT")
    grip:SetPoint(inner, f, corner, left and GRIP_IN or -GRIP_IN, bottom and GRIP_IN or -GRIP_IN)
    paint(grip, false)
    grip:SetScript("OnMouseDown", function(self, button) start(f, spec, self, button) end)
    grip:SetScript("OnMouseUp", function(self, button)
        if button == nil or button == "LeftButton" then stop(f, spec, self) end
    end)
    grip:SetScript("OnHide", function(self) stop(f, spec, self) end)
    grip:SetScript("OnEnter", function(self)
        paint(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TIP_RESIZE, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        paint(self, false)
        GameTooltip:Hide()
    end)
    return grip
end

-- Puts the four arrows on f; f.grips[corner].
function Resize.Attach(f, spec)
    f.grips = {}
    for _, corner in ipairs(Resize.CORNERS) do f.grips[corner] = newGrip(f, spec, corner) end
    return f.grips
end
