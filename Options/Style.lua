local _, ns = ...

-- The options window's look, the same as Forever Unit Frames': flat dark
-- panels, one accent colour, Friz Quadrata.
local Style = {}
ns.Style = Style

Style.COLORS = {
    bg = { 0.07, 0.07, 0.08, 0.96 }, panel = { 0.10, 0.10, 0.12, 1 },
    hover = { 1, 1, 1, 0.04 }, border = { 0, 0, 0, 1 },
    accent = { 0.31, 0.76, 0.97, 1 }, text = { 0.90, 0.90, 0.90, 1 },
    muted = { 0.55, 0.55, 0.58, 1 }, control = { 0.16, 0.16, 0.19, 1 },
    error = { 0.90, 0.30, 0.30, 1 },
}
Style.TEXTURE = "Interface\\Buttons\\WHITE8X8"

function Style.Fill(frame, colorKey, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    local c = Style.COLORS[colorKey]
    t:SetColorTexture(c[1], c[2], c[3], c[4])
    return t
end

function Style.Border(frame, colorKey)
    local c = Style.COLORS[colorKey or "border"]
    local edges = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], c[4])
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    frame.edges = edges
    return edges
end

function Style.SetBorderColor(frame, colorKey)
    local c = Style.COLORS[colorKey]
    for _, t in ipairs(frame.edges or {}) do t:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

function Style.Text(parent, size, colorKey, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(ns.Media.FontPath("Friz Quadrata"), size, "")
    local c = Style.COLORS[colorKey or "text"]
    fs:SetTextColor(c[1], c[2], c[3], c[4])
    fs:SetShadowOffset(1, -1)
    return fs
end

-- Recolours a font string or edit box with one of the COLORS.
function Style.Paint(textRegion, colorKey)
    local c = Style.COLORS[colorKey]
    textRegion:SetTextColor(c[1], c[2], c[3], c[4])
end
