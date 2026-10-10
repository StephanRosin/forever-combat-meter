local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The options window, built like Forever Unit Frames' (Style.lua and
-- Widgets.lua are the same): a title bar, the pages on the left with the
-- language at the bottom, the chosen page on the right, a footer. Opened
-- from the minimap button or /fcm; the page under
-- Interface Options -> AddOns only has a button to open it.
local Window = {}
ns.Window = Window

local Style, Widgets = ns.Style, ns.Widgets

local function num(key, label, unit, step)
    local range = Settings.RANGES[key]
    return {
        key = key, label = label, min = range[1], max = range[2], step = step or 1, unit = unit or "px",
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function check(key, label)
    return {
        key = key, type = "check", label = label,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

-- A dropdown over fixed values, labelled prefix .. value.
local function choice(key, label, values, prefix)
    return {
        key = key, type = "select", label = label,
        choices = function()
            local list = {}
            for _, v in ipairs(values) do list[#list + 1] = { label = L[prefix .. v], value = v } end
            return list
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

-- A dropdown over the media of a kind (Blizzard's and LibSharedMedia's).
local function media(key, label, kind)
    return {
        key = key, type = "select", label = label,
        choices = function()
            local list = {}
            for _, name in ipairs(ns.Media.Names(kind)) do
                list[#list + 1] = { label = name, value = name, font = kind == "font" and name or nil }
            end
            return list
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function colorRow(key, label, noOpacity)
    return {
        key = key, type = "color", label = label, noOpacity = noOpacity,
        get = function()
            local c = S(key)
            return { c[1], c[2], c[3], c[4] or 1 }
        end,
        set = function(c)
            Settings.Set(key, noOpacity and { c[1], c[2], c[3] } or { c[1], c[2], c[3], c[4] })
        end,
    }
end

-- Shows the row only while cond() holds (the page closes up around it).
local function visibleIf(row, cond)
    row.visible = cond
    return row
end

local function append(rows, more)
    for _, r in ipairs(more) do rows[#rows + 1] = r end
    return rows
end

-- Font, size, outline and colour of the text style `key` under a header.
local function textStyleRows(key, header)
    return {
        { type = "header", label = header },
        media(key .. "Font", "OPT_FONT", "font"),
        num(key .. "Size", "OPT_FONT_SIZE"),
        {
            key = key .. "Flag", type = "select", label = "OPT_OUTLINE",
            choices = function()
                return {
                    { label = L.OUTLINE_NONE, value = "" },
                    { label = L.OUTLINE_SHADOW, value = "SHADOW" },
                    { label = L.OUTLINE_NORMAL, value = "OUTLINE" },
                    { label = L.OUTLINE_THICK, value = "THICKOUTLINE" },
                }
            end,
            get = function() return S(key .. "Flag") end,
            set = function(v) Settings.Set(key .. "Flag", v) end,
        },
        colorRow(key .. "Color", "OPT_COLOR", true),
    }
end

-- General: style, update rate, Blizzard's meter, minimap, report.
local function generalRows()
    local style = choice("style", "OPT_STYLE", { "FOREVER", "COMPACT" }, "STYLE_")
    -- Picking a style also takes its bar preset once (they stay editable).
    style.set = function(v)
        ns.Windows.ApplyStylePreset(v)
        Settings.Set("style", v)
    end
    return {
        { type = "header", label = "OPT_GENERAL" },
        style,
        num("refresh", "OPT_REFRESH", "s", Settings.STEPS.refresh),
        { type = "header", label = "OPT_BLIZZARD" },
        { type = "text", label = "OPT_BLIZZARD_HINT", height = 40 },
        check("hideBlizzard", "OPT_HIDE_BLIZZARD"),
        { type = "header", label = "OPT_REPORT" },
        num("reportLines", "OPT_REPORT_LINES", ""),
        { type = "header", label = "OPT_MINIMAP" },
        check("minimapShow", "OPT_MINIMAP_SHOW"),
    }
end

-- One window's setting as a row; the get/set go through Windows.
local function windowRow(i, field, row)
    row.window, row.field = i, field
    row.visible = function() return S("windowCount") >= i end
    return row
end

local function windowRows(i)
    return {
        windowRow(i, "header", { type = "header", label = function() return L.OPT_WINDOW_N:format(i) end }),
        windowRow(i, "mode", {
            type = "select", label = "OPT_MODE",
            choices = function()
                local list = {}
                for _, key in ipairs(ns.Windows.ModeKeys()) do
                    list[#list + 1] = { label = ns.Windows.ModeLabel(key), value = key }
                end
                return list
            end,
            get = function() return ns.Windows.Mode(i) end,
            set = function(v) ns.Windows.SetMode(i, v) end,
        }),
        windowRow(i, "view", {
            type = "select", label = "OPT_SESSION",
            choices = function()
                return { { label = L.SESSION_CURRENT, value = "current" }, { label = L.SESSION_OVERALL, value = "overall" } }
            end,
            get = function() return ns.Windows.Config(i).view end,
            set = function(v) ns.Windows.SetView(i, v) end,
        }),
        i > 1 and windowRow(i, "close", { type = "buttons", buttons = {
            { label = "MENU_CLOSE_WINDOW", width = 150, onClick = function() ns.Windows.Close(i) end },
        } }) or nil,
    }
end

local function windowsRows()
    local rows = {
        { type = "header", label = "OPT_WINDOWS" },
        num("windowCount", "OPT_WINDOW_COUNT", ""),
        check("locked", "OPT_LOCK"),
        { type = "buttons", buttons = {
            { label = "MENU_NEW_WINDOW", width = 150, onClick = function() ns.Windows.Add() end },
        } },
    }
    for i = 1, Settings.RANGES.windowCount[2] do append(rows, windowRows(i)) end
    return rows
end

-- Layout: the quest log's position-and-size page, for the window picked
-- at the top (the pick is only the page's state, not a setting).
local layoutWindow = 1
local function pickedWindow()
    local i = math.min(layoutWindow, S("windowCount"))
    return i
end

local function windowField(row, field)
    row.field = field
    return row
end

-- The window select shared by the Layout and Bars pages.
local function windowPick()
    return windowField(visibleIf({
        type = "select", label = "OPT_LAYOUT_WINDOW",
        choices = function()
            local list = {}
            for i = 1, S("windowCount") do list[#list + 1] = { label = L.OPT_WINDOW_N:format(i), value = i } end
            return list
        end,
        get = function() return pickedWindow() end,
        set = function(v) layoutWindow = v; Window.Refresh() end,
    }, function() return S("windowCount") > 1 end), "window")
end

local function layoutRows()
    local function cfg() return ns.Windows.Config(pickedWindow()) end
    local pos = ns.Position.WindowRows(pickedWindow)
    local range = ns.Windows.RANGES
    local function windowNum(field, label, unit)
        return windowField({
            label = label, min = range[field][1], max = range[field][2], step = unit == "%" and 5 or 1,
            unit = unit or "",
            get = function() return cfg()[field] end,
            set = function(v) ns.Windows.SetConfig(pickedWindow(), { [field] = v }) end,
        }, field)
    end
    local scale = windowNum("scale", "OPT_SCALE", "%")
    scale.set = function(v) ns.Windows.SetScale(pickedWindow(), v) end
    return {
        windowPick(),
        { type = "header", label = "OPT_POSITION" },
        windowField({
            type = "check", label = "OPT_LOCK",
            get = function() return cfg().locked end,
            set = function(v) ns.Windows.SetConfig(pickedWindow(), { locked = v }) end,
        }, "locked"),
        { type = "text", label = "OPT_MOVE_HINT", height = 40 },
        windowField(pos[1], "x"), windowField(pos[2], "y"),
        windowNum("width", "OPT_WIDTH"),
        windowNum("rows", "OPT_ROWS"),
        { type = "buttons", buttons = {
            { label = "OPT_SNAP_MINIMAP", width = 170, onClick = function() ns.Windows.SnapBelowMinimap(pickedWindow()) end },
            { label = "OPT_RESET_POSITION", width = 150, onClick = function() ns.Windows.ResetPosition(pickedWindow()) end },
        } },
        { type = "header", label = "OPT_SCALE" },
        scale,
        { type = "header", label = "OPT_SPACING" },
        num("padding", "OPT_PADDING"),
        num("barSpacing", "OPT_BAR_SPACING"),
        { type = "header", label = "OPT_FADE" },
        num("fadeAlpha", "OPT_FADE_ALPHA", "%"),
        { type = "header", label = "OPT_DETAIL" },
        num("detailWidth", "OPT_WIDTH"),
        num("detailRows", "OPT_ROWS", ""),
        { type = "buttons", buttons = {
            { label = "OPT_RESET_POSITION", width = 150, onClick = function()
                local D = Settings.DEFAULTS
                Settings.SetMany({ detailPoint = D.detailPoint, detailX = D.detailX, detailY = D.detailY })
            end },
        } },
    }
end

local function barRows()
    local function useClass() return ns.Windows.Config(pickedWindow()).classColor end
    return {
        windowPick(),
        { type = "header", label = "OPT_COLORS" },
        windowField({
            type = "check", label = "OPT_BAR_CLASS_COLOR",
            get = useClass,
            set = function(v) ns.Windows.SetConfig(pickedWindow(), { classColor = v }) end,
        }, "classColor"),
        visibleIf(windowField({
            type = "color", label = "OPT_BAR_COLOR", noOpacity = true,
            get = function() local c = ns.Windows.Config(pickedWindow()).barColor; return { c[1], c[2], c[3], 1 } end,
            set = function(c) ns.Windows.SetConfig(pickedWindow(), { barColor = { c[1], c[2], c[3] } }) end,
        }, "barColor"), function() return not useClass() end),
        { type = "header", label = "OPT_DETAIL" },
        check("detailClassColor", "OPT_BAR_CLASS_COLOR"),
        visibleIf(colorRow("detailBarColor", "OPT_BAR_COLOR", true), function() return not S("detailClassColor") end),
        { type = "header", label = "OPT_BARS" },
        num("barHeight", "OPT_BAR_HEIGHT"),
        media("barTexture", "OPT_BAR_TEXTURE", "statusbar"),
        num("barBgAlpha", "OPT_BAR_BG_ALPHA", "%"),
        check("showIcon", "OPT_SHOW_ICON"),
        check("showRank", "OPT_SHOW_RANK"),
        check("animate", "OPT_ANIMATE"),
        { type = "header", label = "OPT_COLUMNS" },
        check("showTotal", "OPT_SHOW_TOTAL"),
        check("showPerSecond", "OPT_SHOW_PERSEC"),
        check("showPercent", "OPT_SHOW_PERCENT"),
    }
end

-- Appearance: background, border, corners, shadow, fading.
local function appearanceRows()
    return {
        { type = "header", label = "OPT_BACKGROUND" },
        choice("bgMode", "OPT_BG_MODE", { "SOLID", "GRADIENT", "TEXTURE" }, "BG_"),
        visibleIf(colorRow("bgColor", "OPT_BG_COLOR", true), function() return S("bgMode") ~= "TEXTURE" end),
        visibleIf(media("bgTexture", "OPT_BG_TEXTURE", "background"), function() return S("bgMode") == "TEXTURE" end),
        num("bgAlpha", "OPT_BG_ALPHA", "%"),
        check("headerLine", "OPT_HEADER_LINE"),
        { type = "header", label = "OPT_BORDER" },
        choice("borderStyle", "OPT_BORDER_STYLE", { "GOLD", "FLAT", "NONE" }, "BORDER_"),
        visibleIf(num("borderSize", "OPT_BORDER_SIZE"), function() return S("borderStyle") ~= "NONE" end),
        visibleIf(colorRow("borderColor", "OPT_BORDER_COLOR"), function() return S("borderStyle") == "FLAT" end),
        num("cornerRadius", "OPT_CORNER_RADIUS"),
        { type = "header", label = "OPT_SHADOW" },
        check("shadowEnabled", "OPT_SHADOW_SHOW"),
        visibleIf(num("shadowSize", "OPT_SHADOW_SIZE"), function() return S("shadowEnabled") end),
        visibleIf(num("shadowAlpha", "OPT_SHADOW_ALPHA", "%"), function() return S("shadowEnabled") end),
    }
end

local function textRows()
    local rows = {}
    for _, name in ipairs(Settings.TEXT_STYLES) do append(rows, textStyleRows(name, "STYLE_" .. name:upper())) end
    return rows
end

local function threatRows()
    return {
        { type = "header", label = "OPT_THREAT" },
        check("threatWarn", "OPT_THREAT_WARN"),
        visibleIf(num("threatWarnPct", "OPT_THREAT_PCT", "%"), function() return S("threatWarn") end),
        visibleIf(check("threatSound", "OPT_THREAT_SOUND"), function() return S("threatWarn") end),
        check("showPets", "OPT_SHOW_PETS"),
    }
end

-- The export/import field; Window.shareField for the tests.
local shareField = {}
Window.shareField = shareField

local function profileRows()
    return {
        { type = "header", label = "OPT_PROFILES" },
        {
            type = "select", label = "OPT_PROFILE_ACTIVE",
            choices = function()
                local list = {}
                for _, name in ipairs(ns.ProfileList()) do
                    list[#list + 1] = { label = name, value = name }
                end
                return list
            end,
            get = function() return ns.ActiveProfile() end,
            set = function(v)
                ns.SwitchProfile(v)
                Window.Refresh()
            end,
        },
        { type = "buttons", buttons = {
            { label = "OPT_PROFILE_SAVE_AS", width = 150, onClick = function() ns.AskProfileName() end },
            { label = "OPT_PROFILE_DELETE", width = 110, onClick = function() ns.AskDeleteProfile() end },
        } },
        { type = "header", label = "OPT_SHARE" },
        { type = "text", label = "OPT_SHARE_HINT", height = 40 },
        { type = "edit", ref = shareField },
        { type = "buttons", buttons = {
            { label = "OPT_EXPORT", width = 130, onClick = function()
                local box = shareField.box
                box:SetText(ns.Share.Export())
                box:SetFocus()
                box:HighlightText()
            end },
            { label = "OPT_IMPORT", width = 130, onClick = function()
                local ok = ns.Share.Import(shareField.box:GetText())
                ns.Print(ok and L.MSG_IMPORTED or L.MSG_IMPORT_FAILED)
                if ok then Window.Refresh() end
            end },
        } },
        { type = "header", label = "OPT_RESET" },
        { type = "text", label = "OPT_RESET_HINT" },
        { type = "buttons", buttons = {
            { label = "OPT_RESET_BUTTON", width = 200, onClick = function()
                Settings.ResetProfile()
                Window.Refresh()
            end },
        } },
    }
end

Window.PAGES = {
    { id = "general", label = "PAGE_GENERAL", rows = generalRows },
    { id = "windows", label = "PAGE_WINDOWS", rows = windowsRows },
    { id = "layout", label = "PAGE_LAYOUT", rows = layoutRows },
    { id = "bars", label = "PAGE_BARS", rows = barRows },
    { id = "appearance", label = "PAGE_APPEARANCE", rows = appearanceRows },
    { id = "text", label = "PAGE_TEXT", rows = textRows },
    { id = "threat", label = "PAGE_THREAT", rows = threatRows },
    { id = "profiles", label = "PAGE_PROFILES", rows = profileRows },
}

-- --------------------------------------------------------------------------
-- Spec rows into widgets
-- --------------------------------------------------------------------------
local WIDTH, HEIGHT = 780, 560
local TITLE_H, NAV_W, FOOTER_H = 32, 160, 40
local NAV_ROW_H, NAV_TOP, NAV_BAR_W = 28, 8, 3
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, HINT_ROW_H = 70, 26
local BUTTON_H, BUTTON_W, BUTTON_GAP = 24, 140, 8

-- A label: a locale key or a function (read again on refresh).
local function labelText(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- Stacks rows top to bottom; a header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + (height or row:GetHeight())
    end
    return stack
end

-- A muted line of explanation.
local function hintRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    row.text = Style.Text(row, 11, "muted")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    row.text:SetPoint("RIGHT", row, "RIGHT", -INSET, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetText(labelText(opt.label))
    function row:Refresh() end
    function row:SetEnabled() end
    return row, opt.height or HINT_ROW_H
end

-- Several buttons side by side.
local function buttonsRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local x = INSET
    row.buttons = {}
    for _, b in ipairs(opt.buttons) do
        local button = Widgets.Button(row, { text = labelText(b.label), width = b.width or BUTTON_W,
            onClick = b.onClick })
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + (b.width or BUTTON_W) + BUTTON_GAP
        row.buttons[#row.buttons + 1] = button
    end
    function row:Refresh() end
    function row:SetEnabled(on) for _, button in ipairs(row.buttons) do button:SetEnabled(on) end end
    return row, BUTTON_H + 12
end

-- A text area to copy from or paste into (export / import).
local function editRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local area = Widgets.TextArea(row, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H })
    area:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    -- The buttons use it like an edit box.
    function area:SetFocus() area.edit:SetFocus() end
    function area:HighlightText() area.edit:HighlightText() end
    if opt.ref then opt.ref.box = area end
    function row:Refresh() end
    function row:SetEnabled() end
    return row, TEXT_AREA_H + 12
end

-- The widget for one spec row, and its height (nil: the widget's own).
local function widgetFor(page, opt)
    local kind = opt.type or "slider"
    if kind == "header" then
        local row = Widgets.Header(page, labelText(opt.label))
        row.isSection = true
        return row
    elseif kind == "text" then
        return hintRow(page, opt)
    elseif kind == "buttons" then
        return buttonsRow(page, opt)
    elseif kind == "edit" then
        return editRow(page, opt)
    end
    local o = { label = labelText(opt.label), get = opt.get, set = opt.set }
    local row
    if kind == "check" then
        row = Widgets.Checkbox(page, o)
    elseif kind == "select" then
        o.items = function()
            local items = {}
            for _, c in ipairs(opt.choices()) do
                items[#items + 1] = { value = c.value, text = c.label, font = c.font }
            end
            return items
        end
        row = Widgets.Dropdown(page, o)
    elseif kind == "color" then
        o.noOpacity = opt.noOpacity
        row = Widgets.Color(page, o)
    else
        o.min, o.max, o.step = opt.min, opt.max, opt.step or 1
        row = Widgets.Slider(page, o)
    end
    -- A label that follows the settings (e.g. "X" for a free level).
    if type(opt.label) == "function" then
        local refresh = row.Refresh
        function row:Refresh()
            row:SetLabel(opt.label())
            refresh(self)
        end
    end
    return row
end

local function buildRows(page, spec)
    local stack = newStack(page)
    page.allRows = {}
    for _, opt in ipairs(spec) do
        local row, height = widgetFor(page, opt)
        stack.add(row, height)
        row.stackHeight, row.visibleIf = height or row:GetHeight(), opt.visible
        page.allRows[#page.allRows + 1] = row
    end
    page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
end

-- Rows with a `visible` condition (e.g. the texture only for a texture
-- background) come and go; the rows below close up.
local function stackVisible(page)
    if not page.allRows then return end
    local y, rows = PAGE_TOP, {}
    for _, row in ipairs(page.allRows) do
        local shown = not row.visibleIf or row.visibleIf()
        row:SetShown(shown)
        if shown then
            if row.isSection and #rows > 0 then y = y + SECTION_GAP end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
            rows[#rows + 1] = row
            y = y + row.stackHeight
        end
    end
    page.rows, page.height = rows, y + PAGE_BOTTOM
    page:SetHeight(page.height)
end

-- --------------------------------------------------------------------------
-- The window
-- --------------------------------------------------------------------------
local frame, current
local pages = {}

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function pageFor(id)
    if pages[id] then return pages[id] end
    local spec
    for _, p in ipairs(Window.PAGES) do if p.id == id then spec = p end end
    if not spec then return nil end
    local page = CreateFrame("Frame", "ForeverCombatMeterPage" .. id, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if spec.build then spec.build(page) else buildRows(page, spec.rows()) end
    page:SetHeight(page.height)
    page:Hide()
    pages[id] = page
    return page
end

-- Scrolling: a thin accent thumb, as in Forever Unit Frames.
local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3,
        -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", "ForeverCombatMeterOptionsScroll", body)
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    local thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(2)
    thumb:Hide()
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Navigation ----------------------------------------------------------------------
local function paintNav()
    for id, b in pairs(frame.navButtons) do
        local selected = id == current
        Style.Paint(b.text, selected and "accent" or "text")
        b.selected = selected
        b.bar:SetShown(selected)
    end
end

local function navButton(nav, page, y)
    local b = CreateFrame("Button", "ForeverCombatMeterNav" .. page.id, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(L[page.label])
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnClick", function() Window.ShowPage(page.id) end)
    frame.navButtons[page.id] = b
end

-- The language, at the bottom of the navigation: a label above a dropdown
-- as wide as the column; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.OPT_LANGUAGE,
        items = function()
            local list = { { value = "AUTO", text = L.LANGUAGE_AUTO } }
            for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = { value = c.value, text = c.label } end
            return list
        end,
        get = function() return ns.Locale.Setting() end,
        set = function(v) ns.Locale.Set(v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    frame.languageRow = row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    frame.navButtons = {}
    for i, page in ipairs(Window.PAGES) do navButton(nav, page, NAV_TOP + (i - 1) * NAV_ROW_H) end
    languageRow(nav)
    return nav
end

-- Footer: lock or unlock the strip (drag it while unlocked).
local function refreshFooter()
    if frame and frame.lockButton then
        frame.lockButton.text:SetText(S("locked") and L.OPT_UNLOCK_FRAME or L.OPT_LOCK_FRAME)
    end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local lock = Widgets.Button(footer, { text = L.OPT_UNLOCK_FRAME, width = 160,
        onClick = function() Settings.SetLocked(not S("locked")) end })
    lock:SetPoint("LEFT", footer, "LEFT", 12, 0)
    frame.lockButton = lock
    refreshFooter()
    return footer
end

-- Title bar with the version and a drawn close cross.
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.ADDON_NAME)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ((getMetadata and getMetadata(ADDON, "Version")) or ""))
    bar.close = closeButton(bar)
    return bar
end

local WINDOW_NAME = "ForeverCombatMeterOptions"

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    local footer = createFooter(frame)
    local nav = createNav(frame)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    createScroll(body)
    -- Hiding the window (ESC, the cross) takes an open dropdown list along.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:SetScript("OnShow", function() Window.Refresh() end)
    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == WINDOW_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, WINDOW_NAME) end
    end
end

local function ensureWindow()
    if not frame then createWindow() end
end

-- Public API ----------------------------------------------------------------------

function Window.ShowPage(id)
    ensureWindow()
    local page = pageFor(id)
    if not page then return end
    Widgets.CloseList()
    for _, p in pairs(pages) do if p ~= page then p:Hide() end end
    current = id
    if page.rebuild then
        page.rebuild()
        page:SetHeight(page.height)
    end
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    stackVisible(page)
    frame.scrollChild:SetHeight(page.height)
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    paintNav()
    updateScrollbar()
end

-- Fetches every value on the visible page again.
function Window.Refresh()
    if not frame or not current then return end
    local page = pages[current]
    if not page then return end
    stackVisible(page)
    frame.scrollChild:SetHeight(page.height)
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    updateScrollbar()
    if frame.languageRow then frame.languageRow:Refresh() end
    refreshFooter()
end
ns.RefreshOptions = Window.Refresh

function Window.Open(pageID)
    ensureWindow()
    frame:Show()
    Window.ShowPage(pageID or current or "general")
end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- A change from elsewhere (dragging, a slash command, a profile) shows on
-- the page.
Settings.OnChange(function()
    if frame and frame:IsShown() then Window.Refresh() end
end)

-- Every label is set when its widget is built: a new language gets a new
-- window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name and page.
ns.Locale.OnChange(function()
    if not frame then return end
    local wasOpen, page = frame:IsShown(), current
    frame:Hide()
    frame, pages = nil, {}
    if wasOpen then Window.Open(page) end
end)
