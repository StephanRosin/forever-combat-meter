local _, ns = ...

-- The minimap button: left-click opens or closes the options window,
-- right-click locks or unlocks the bars, dragging moves it around the
-- minimap's edge. A plain button, not secure.
--
-- Built here rather than with LibDBIcon (not embedded), but placed the
-- way LibDBIcon places its buttons, so it sits with other addons'
-- buttons: on a circle of half the minimap's size plus RADIUS_OUT for a
-- round minimap; for a square one (a minimap addon defines
-- GetMinimapShape) the quadrants the shape squares off put the button on
-- a larger circle clamped to the square's edges.
--
-- When another addon provides LibDataBroker-1.1 through LibStub, a
-- launcher with the same clicks is registered too, for broker displays.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local Settings, L = ns.Settings, ns.L

MinimapButton.ICON = "Interface\\AddOns\\ForeverCombatMeter\\Media\\MinimapIcon.tga"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local LDB_NAME = "ForeverCombatMeter"

-- LibDBIcon's layout: a 31 px button, the tracking border's ring at its
-- top left, the icon inside.
local SIZE, BORDER_SIZE, BACKGROUND_SIZE, ICON_SIZE = 31, 53, 20, 18
-- How far outside the minimap's edge the button's centre sits, and how
-- much a square minimap's corner circle is pulled in (LibDBIcon's).
local RADIUS_OUT, CORNER_IN = 5, 10

-- Which quadrants (1 bottom right, 2 bottom left, 3 top right, 4 top
-- left) of each minimap shape are round.
local ROUND_QUADRANTS = {
    ROUND = { true, true, true, true },
    SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function minimapShape()
    local shape = GetMinimapShape and GetMinimapShape()
    return ROUND_QUADRANTS[shape] or ROUND_QUADRANTS.ROUND
end

-- The button's offset from the minimap's centre at angle degrees.
function MinimapButton.Offset(angle)
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local quadrant = 1
    if x < 0 then quadrant = quadrant + 1 end
    if y > 0 then quadrant = quadrant + 2 end
    local w = Minimap:GetWidth() / 2 + RADIUS_OUT
    local h = Minimap:GetHeight() / 2 + RADIUS_OUT
    if minimapShape()[quadrant] then return x * w, y * h end
    local diagonalW = math.sqrt(2 * w * w) - CORNER_IN
    local diagonalH = math.sqrt(2 * h * h) - CORNER_IN
    return math.max(-w, math.min(x * diagonalW, w)), math.max(-h, math.min(y * diagonalH, h))
end

local function moveTo(button, angle)
    local x, y = MinimapButton.Offset(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Out of combat or in: the button is not protected.
function MinimapButton.Place()
    local button = MinimapButton.button
    if not button then return end
    moveTo(button, Settings.Get("minimapAngle"))
    button:SetShown(Settings.Get("minimapShow"))
end

-- The cursor's angle around the minimap's centre, in whole degrees.
local function cursorAngle()
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(py / scale - cy, px / scale - cx)) % 360
    return math.floor(angle + 0.5) % 360
end

-- While dragging the button only moves; the angle is saved on release.
local function followCursor(button)
    button.dragAngle = cursorAngle()
    moveTo(button, button.dragAngle)
end

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.ToggleLock()
    else
        ns.Window.Toggle()
    end
end

-- The tooltip's lines; the minimap button adds the drag hint.
local function tooltipLines(tooltip)
    tooltip:AddLine(L.MINIMAP_LEFT_CLICK, 1, 1, 1)
    tooltip:AddLine(L.MINIMAP_RIGHT_CLICK, 1, 1, 1)
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    tooltipLines(GameTooltip)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 1, 1, 1)
    GameTooltip:Show()
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function texture(button, file, layer, size, x, y)
    local t = button:CreateTexture(nil, layer)
    t:SetTexture(file)
    t:SetSize(size, size)
    t:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
    return t
end

local function newButton()
    local button = CreateFrame("Button", "ForeverCombatMeterMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button.background = texture(button, BACKGROUND, "BACKGROUND", BACKGROUND_SIZE, 7, -5)
    button.icon = texture(button, MinimapButton.ICON, "ARTWORK", ICON_SIZE, 6.5, -6)
    button.border = texture(button, BORDER, "OVERLAY", BORDER_SIZE, 0, 0)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnDragStart", function(self)
        hideTooltip(self)
        self:SetScript("OnUpdate", followCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragAngle then Settings.Set("minimapAngle", self.dragAngle) end
        self.dragAngle = nil
    end)
    return button
end

-- A LibDataBroker launcher, if another addon provides the library.
local function registerLauncher()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if not ldb then return end
    MinimapButton.launcher = ldb:NewDataObject(LDB_NAME, {
        type = "launcher",
        label = L.ADDON_NAME,
        icon = MinimapButton.ICON,
        OnClick = onClick,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(L.ADDON_NAME)
            tooltipLines(tooltip)
        end,
    })
end

-- Once, at PLAYER_LOGIN.
function MinimapButton.Create()
    if MinimapButton.button or not Minimap then return end
    MinimapButton.button = newButton()
    MinimapButton.Place()
    -- The offset is fixed at placing: follow a minimap another addon resizes
    -- later (a square minimap does so in its own PLAYER_LOGIN, after ours).
    -- HookScript, not hooksecurefunc: Forever hides hooked frame methods
    -- from Blizzard's code.
    Minimap:HookScript("OnSizeChanged", MinimapButton.Place)
    registerLauncher()
end

Settings.OnChange(function(key)
    if key == nil or key == "minimapAngle" or key == "minimapShow" then MinimapButton.Place() end
end)

ns.On("PLAYER_LOGIN", function() MinimapButton.Create() end)

-- Blizzard's addon compartment (the button by the minimap that lists
-- addons) calls these global functions named in the TOC: the same clicks
-- and tooltip as the minimap button.
function ForeverCombatMeter_OnAddonCompartmentClick(_, mouseButton)
    onClick(nil, mouseButton)
end

function ForeverCombatMeter_OnAddonCompartmentEnter(_, menuButton)
    if not menuButton then return end
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    tooltipLines(GameTooltip)
    GameTooltip:Show()
end

function ForeverCombatMeter_OnAddonCompartmentLeave(_, menuButton)
    if menuButton and GameTooltip:IsOwned(menuButton) then GameTooltip:Hide() end
end
