local ADDON, ns = ...
local L = ns.L

-- The page under Interface Options -> AddOns: the name and a button that
-- opens the addon's own options window.
local function Register(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name, panel.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            return category
        end
    end
    if InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory, panel) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local panel = CreateFrame("Frame", "ForeverCombatMeterInterfacePanel", UIParent)
    panel.name = L.ADDON_NAME
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ADDON_NAME)
    local button = CreateFrame("Button", "ForeverCombatMeterInterfaceOpen", panel, "UIPanelButtonTemplate")
    button:SetSize(220, 24)
    button:SetPoint("TOPLEFT", 16, -52)
    button:SetScript("OnClick", function()
        if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame.Hide then InterfaceOptionsFrame:Hide() end
        ns.Window.Open()
    end)
    local function relabel() button:SetText(L.OPEN_OPTIONS) end
    ns.Locale.OnChange(relabel)
    relabel()
    ns.optionsCategory = Register(panel)
end)
