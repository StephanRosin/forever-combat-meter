local _, ns = ...
local Widgets = {}
ns.Widgets = Widgets
local Style, L = ns.Style, ns.L

-- Flat controls of the options window, taken over from Forever Unit Frames
-- so both addons look and work alike. Every constructor except Button and
-- TextArea returns a 30 px row: label at the left, control at CONTROL_X,
-- optional inherit marker / Reset button at the right edge. Rows expose
-- Refresh() (re-read opts.get()) and SetEnabled(bool).

Widgets.ROW_H, Widgets.CONTROL_X, Widgets.CONTROL_W = 30, 240, 260
local LABEL_X = 16
-- Label and hint end this far left of the control.
local LABEL_MAX_W = Widgets.CONTROL_X - LABEL_X - 12
local DISABLED_ALPHA = 0.45
local FONT = "Friz Quadrata"
local ERROR_FLASH_SECONDS = 0.6

local function fontPath() return ns.Media.FontPath(FONT) end

-- Row hover ---------------------------------------------------------------
-- Moving the mouse from a row onto one of its controls fires the row's
-- OnLeave, so the hover is only dropped once the pointer left the row area.

-- A label or hint cut off at the column's end is shown in full in a
-- tooltip while the row is hovered.
local function cutOff(fontString)
    return fontString ~= nil and fontString.IsTruncated ~= nil and fontString:IsTruncated()
end

local function showFullText(row)
    if not (cutOff(row.label) or cutOff(row.hintText)) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.label:GetText() or "", 1, 1, 1)
    if row.hintText then GameTooltip:AddLine(row.hintText:GetText() or "", nil, nil, nil, true) end
    GameTooltip:Show()
    row.fullTextShown = true
end

local function hideFullText(row)
    if row.fullTextShown and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    row.fullTextShown = nil
end

local function showHover(row)
    row.hover:Show()
    showFullText(row)
end
local function hideHoverIfOutside(row)
    if not row:IsMouseOver() then
        row.hover:Hide()
        hideFullText(row)
    end
end

local function trackHover(row, control)
    control:HookScript("OnEnter", function() showHover(row) end)
    control:HookScript("OnLeave", function() hideHoverIfOutside(row) end)
end

-- One line, left aligned, never running under the control. A clipped text
-- is a bug in the string: keep labels and hints short enough to fit.
local function fitLeftColumn(fontString, alwaysFull)
    fontString:SetWordWrap(false)
    fontString:SetJustifyH("LEFT")
    -- Width 0 is the natural width: a label whose text changes is measured
    -- afresh instead of keeping an earlier limit. A label keeps its
    -- natural width (the inherit marker follows it).
    fontString:SetWidth(0)
    if alwaysFull or fontString:GetStringWidth() > LABEL_MAX_W then
        fontString:SetWidth(LABEL_MAX_W)
    end
end
Widgets.LABEL_MAX_W = LABEL_MAX_W

local function newRow(parent, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Widgets.ROW_H)
    row.hover = Style.Fill(row, "hover")
    row.hover:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", showHover)
    row:SetScript("OnLeave", hideHoverIfOutside)
    row.label = Style.Text(row, 12, "text")
    row.label:SetPoint("LEFT", row, "LEFT", LABEL_X, opts.hint and 5 or 0)
    row.label:SetText(opts.label or "")
    fitLeftColumn(row.label)
    -- opts.hint: a string, or a function for a hint that follows the
    -- settings (read again on every refresh).
    local function hintValue()
        if type(opts.hint) == "function" then return opts.hint() or "" end
        return opts.hint
    end
    if opts.hint then
        row.hintText = Style.Text(row, 10, "muted")
        row.hintText:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -1)
        row.hintText:SetText(hintValue())
        fitLeftColumn(row.hintText, true)
    end
    if opts.inherit then
        row.inherited = Style.Text(row, 10, "muted")
        row.inherited:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        row.inherited:SetText(L.INHERITED)
        row.reset = CreateFrame("Button", nil, row)
        row.reset:SetSize(60, 18)
        row.reset:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.reset.text = Style.Text(row.reset, 11, "accent")
        row.reset.text:SetPoint("CENTER")
        row.reset.text:SetText(L.RESET_OVERRIDE)
        row.reset:SetScript("OnClick", function() opts.inherit.clear() end)
        trackHover(row, row.reset)
    end
    function row:SetLabel(text)
        row.label:SetText(text)
        fitLeftColumn(row.label)
    end
    function row:RefreshInherit()
        if type(opts.hint) == "function" then row.hintText:SetText(hintValue()) end
        if not opts.inherit then return end
        local over = opts.inherit.isOverridden()
        row.inherited:SetShown(not over)
        row.reset:SetShown(over)
    end
    return row
end
Widgets.NewRow = newRow

-- Dims the whole row and locks its Reset button; controls are handled by
-- each widget's own SetEnabled.
local function dimRow(row, on)
    row:SetAlpha(on and 1 or DISABLED_ALPHA)
    if row.reset then row.reset:SetEnabled(on) end
end

local function controlBox(frame)
    Style.Fill(frame, "control")
    Style.Border(frame)
end

-- Slider --------------------------------------------------------------------

local function round(v, step) return math.floor(v / step + 0.5) * step end

local function newSliderControl(row, opts, step)
    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(Widgets.CONTROL_W - 70, 16)
    s:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    s:SetMinMaxValues(opts.min, opts.max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(unpack(Style.COLORS.control))
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    -- Without a thumb texture a slider cannot be dragged.
    s:SetThumbTexture(Style.TEXTURE)
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(10, 16); thumb:SetVertexColor(unpack(Style.COLORS.accent)) end
    s:EnableMouseWheel(true)
    trackHover(row, s)
    return s
end

-- Hands a mouse wheel turn on to the nearest scroll frame above frame (the
-- options page), as if it had been turned there.
function Widgets.PassWheel(frame, delta)
    local parent = frame:GetParent()
    while parent do
        if parent:GetObjectType() == "ScrollFrame" then
            local handler = parent:GetScript("OnMouseWheel")
            if handler then handler(parent, delta) end
            return
        end
        parent = parent:GetParent()
    end
end

local function newNumberBox(row, anchor)
    local e = CreateFrame("EditBox", nil, row)
    e:SetSize(60, 20)
    e:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    e:SetAutoFocus(false)
    -- An edit box refuses SetText until it has a font.
    e:SetFont(fontPath(), 12, "")
    Style.Paint(e, "text")
    e:SetJustifyH("CENTER")
    e:SetMaxLetters(6)
    controlBox(e)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    trackHover(row, e)
    return e
end

-- Each flash gets a token so the timer of an earlier flash cannot end a
-- newer one early.
local function flashError(box)
    local token = {}
    box.flashToken = token
    Style.SetBorderColor(box, "error")
    C_Timer.After(ERROR_FLASH_SECONDS, function()
        if box.flashToken == token then Style.SetBorderColor(box, "border") end
    end)
end

-- opts.zeroText (optional): what the box shows for 0, e.g. "Auto"; typing
-- it (any case) sets 0.
function Widgets.Slider(parent, opts)
    local row = newRow(parent, opts)
    local step = opts.step or 1
    local s = newSliderControl(row, opts, step)
    local e = newNumberBox(row, s)
    row.slider, row.edit = s, e

    local zeroText = opts.zeroText
    local function display(v)
        if zeroText and v == 0 then return zeroText end
        return tostring(v)
    end
    local function parse(text)
        if zeroText and text:lower() == zeroText:lower() then return 0 end
        return tonumber(text)
    end

    local updating = false
    local function show(v, keepTyping)
        updating = true
        s:SetValue(v)
        -- A refresh must not wipe what is being typed into the box.
        if not (keepTyping and e:HasFocus()) then e:SetText(display(v)) end
        updating = false
    end
    local function commit(v)
        if v ~= opts.get() then opts.set(v) end
    end

    s:SetScript("OnValueChanged", function(_, v, userInput)
        if updating or userInput == false then return end
        local r = round(v, step)
        e:SetText(display(r))
        commit(r)
    end)
    -- The wheel scrolls the page, even over a slider (reported: scrolling
    -- down the page changed whatever slider passed under the cursor). With
    -- Shift held it moves the slider.
    s:SetScript("OnMouseWheel", function(_, delta)
        if not IsShiftKeyDown() then return Widgets.PassWheel(s, delta) end
        if not s:IsEnabled() then return end
        local v = math.max(opts.min, math.min(opts.max, opts.get() + delta * step))
        commit(v); show(opts.get())
    end)
    local function editCommit(self)
        local n = parse(self:GetText())
        if n and n == n and n >= opts.min and n <= opts.max then
            commit(round(n, step))
            show(opts.get())
        else
            show(opts.get())
            flashError(self)
        end
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", editCommit)
    e:SetScript("OnEditFocusLost", function(self)
        if self:GetText() ~= display(opts.get()) then editCommit(self) end
        self:HighlightText(0, 0)
    end)
    e:SetScript("OnEscapePressed", function(self) show(opts.get()); self:ClearFocus() end)

    function row:Refresh() show(opts.get(), true); row:RefreshInherit() end
    function row:SetEnabled(on) s:SetEnabled(on); e:SetEnabled(on); dimRow(row, on) end
    return row
end

-- Text input ------------------------------------------------------------------
-- One line of free text across the control column. Enter or leaving the
-- box commits; ESC puts the stored value back. opts.set returning false
-- (the value was refused) flashes the border and shows the stored value.

local TEXT_INPUT_H = 20

local function newTextBox(row, maxLetters)
    local e = CreateFrame("EditBox", nil, row)
    e:SetSize(Widgets.CONTROL_W, TEXT_INPUT_H)
    e:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    e:SetAutoFocus(false)
    e:SetFont(fontPath(), 12, "")
    Style.Paint(e, "text")
    e:SetJustifyH("LEFT")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetMaxLetters(maxLetters or 0)
    controlBox(e)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    trackHover(row, e)
    return e
end

function Widgets.TextInput(parent, opts)
    local row = newRow(parent, opts)
    local e = newTextBox(row, opts.maxLetters)
    row.edit = e

    local function show() e:SetText(opts.get() or "") end
    local function commit(self)
        local text = self:GetText() or ""
        if text ~= opts.get() and opts.set(text) == false then flashError(self) end
        show()
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") ~= opts.get() then commit(self) end
        self:HighlightText(0, 0)
    end)
    e:SetScript("OnEscapePressed", function(self) show(); self:ClearFocus() end)

    -- A refresh must not wipe what is being typed.
    function row:Refresh()
        if not e:HasFocus() then show() end
        row:RefreshInherit()
    end
    function row:SetEnabled(on)
        if not on then e:ClearFocus() end
        e:SetEnabled(on)
        dimRow(row, on)
    end
    return row
end

-- Checkbox ------------------------------------------------------------------

local CHECK_INSET = 4

local function newCheckBox(row)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    controlBox(box)
    box:SetCheckedTexture(Style.TEXTURE)
    local check = box:GetCheckedTexture()
    if check then
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", CHECK_INSET, -CHECK_INSET)
        check:SetPoint("BOTTOMRIGHT", -CHECK_INSET, CHECK_INSET)
        check:SetVertexColor(unpack(Style.COLORS.accent))
    end
    trackHover(row, box)
    return box
end

-- Makes the label clickable: an invisible button over the label area.
local function newLabelButton(row, onClick)
    local b = CreateFrame("Button", nil, row)
    b:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X, 0)
    b:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", Widgets.CONTROL_X - 8, 0)
    b:SetScript("OnClick", onClick)
    trackHover(row, b)
    return b
end

function Widgets.Checkbox(parent, opts)
    local row = newRow(parent, opts)
    local box = newCheckBox(row)
    row.box = box
    -- A CheckButton flips its own checked state before OnClick; the setting
    -- is the truth, so toggle from get() and redraw from it.
    local function toggle()
        if not box:IsEnabled() then return end
        opts.set(not opts.get())
        row:Refresh()
    end
    box:SetScript("OnClick", toggle)
    row.labelButton = newLabelButton(row, toggle)

    function row:Refresh() box:SetChecked(opts.get() and true or false); row:RefreshInherit() end
    function row:SetEnabled(on)
        box:SetEnabled(on); row.labelButton:SetEnabled(on); dimRow(row, on)
    end
    return row
end

-- Dropdown list (one shared list for all dropdowns) ---------------------------

local LIST_ROWS, LIST_ROW_H = 12, 22
local list

local function applyFont(fontString, fontName)
    fontString:SetFont(fontName and ns.Media.FontPath(fontName) or fontPath(), 12, "")
end

local function indexOf(items, value)
    for i, item in ipairs(items) do
        if item.value == value then return i end
    end
end

local function maxOffset() return math.max(0, #list.items - LIST_ROWS) end

local function renderScrollThumb()
    local total = #list.items
    if total <= LIST_ROWS then list.scrollThumb:Hide(); return end
    local trackH = LIST_ROWS * LIST_ROW_H
    local thumbH = trackH * LIST_ROWS / total
    list.scrollThumb:SetHeight(thumbH)
    list.scrollThumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1,
        -1 - (trackH - thumbH) * list.offset / maxOffset())
    list.scrollThumb:Show()
end

local function renderList()
    local current = list.owner.opts.get()
    for i, r in ipairs(list.rows) do
        local item = list.items[list.offset + i]
        r.item = item
        if item then
            r.text:SetText(item.text)
            applyFont(r.text, item.font)
            Style.Paint(r.text, item.value == current and "accent" or "text")
        end
        r:SetShown(item ~= nil)
    end
    list:SetHeight(math.min(#list.items, LIST_ROWS) * LIST_ROW_H + 2)
    renderScrollThumb()
end

-- Also the list's OnHide, so a hide from elsewhere cleans up the same way.
local function releaseList()
    list:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    list:EnableKeyboard(false)
    list.owner = nil
end

function Widgets.CloseList()
    if not list or not list:IsShown() then return false end
    list:Hide()
    releaseList()
    return true
end

local function selectItem(listRow)
    local owner, value = list.owner, listRow.item.value
    Widgets.CloseList()
    owner.opts.set(value)
    owner:Refresh()
end

local function newListRow(i)
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(LIST_ROW_H)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1 - (i - 1) * LIST_ROW_H)
    r:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -1 - (i - 1) * LIST_ROW_H)
    r.hover = Style.Fill(r, "hover", "ARTWORK")
    r.hover:Hide()
    r.text = Style.Text(r, 12, "text")
    r.text:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r:SetScript("OnEnter", function(self) self.hover:Show() end)
    r:SetScript("OnLeave", function(self) self.hover:Hide() end)
    r:SetScript("OnClick", selectItem)
    return r
end

local function scrollList(_, delta)
    list.offset = math.max(0, math.min(maxOffset(), list.offset - delta))
    renderList()
end

-- A click anywhere outside the list closes it. The owner's button is left
-- out: its own OnClick toggles the list.
local function closeOnOutsideClick()
    if list:IsMouseOver() or list.owner.button:IsMouseOver() then return end
    Widgets.CloseList()
end

-- ESC closes only the list (the window behind stays open); every other key
-- goes on to the game. Same technique as Blizzard's colour picker, and it
-- leaves Blizzard's ESC handler table untouched (no taint on that path).
-- SetPropagateKeyboardInput is restricted in combat, so the list is never
-- open in combat.
local function onListKeyDown(self, key)
    if GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
        Widgets.CloseList()
        self:SetPropagateKeyboardInput(false)
    else
        self:SetPropagateKeyboardInput(true)
    end
end

local function createList()
    list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    Style.Fill(list, "panel")
    Style.Border(list)
    list.scrollThumb = list:CreateTexture(nil, "ARTWORK")
    list.scrollThumb:SetColorTexture(unpack(Style.COLORS.accent))
    list.scrollThumb:SetWidth(2)
    list.rows = {}
    for i = 1, LIST_ROWS do list.rows[i] = newListRow(i) end
    list.items, list.offset = {}, 0
    list:SetScript("OnMouseWheel", scrollList)
    list:SetScript("OnEvent", closeOnOutsideClick)
    list:SetScript("OnKeyDown", onListKeyDown)
    list:SetScript("OnHide", releaseList)
    list:Hide()
    Widgets.list = list
end

local function openList(owner)
    list.owner = owner
    list.items = owner.opts.items()
    local index = indexOf(list.items, owner.opts.get()) or 1
    list.offset = math.max(0, math.min(maxOffset(), index - LIST_ROWS / 2))
    list:ClearAllPoints()
    -- opts.listAbove: a dropdown at the bottom of the window opens upwards.
    if owner.opts.listAbove then
        list:SetPoint("BOTTOMLEFT", owner.button, "TOPLEFT", 0, 2)
    else
        list:SetPoint("TOPLEFT", owner.button, "BOTTOMLEFT", 0, -2)
    end
    list:SetWidth(owner.button:GetWidth())
    renderList()
    list:Show()
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    list:EnableKeyboard(true)
end

local function toggleList(owner)
    if list:IsShown() and list.owner == owner then
        Widgets.CloseList()
    elseif not InCombatLockdown() then
        openList(owner)
    end
end

ns.On("PLAYER_REGEN_DISABLED", function() Widgets.CloseList() end)

-- Dropdown ------------------------------------------------------------------

local ARROW_WIDTHS = { 7, 5, 3, 1 }

-- The ▾ glyph is not in every game font, so the arrow is drawn from 1 px
-- lines of decreasing width.
local function drawArrow(button)
    for i, w in ipairs(ARROW_WIDTHS) do
        local line = button:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(unpack(Style.COLORS.text))
        line:SetSize(w, 1)
        line:SetPoint("CENTER", button, "RIGHT", -12, 2 - i)
    end
end

local function newDropdownButton(row)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(Widgets.CONTROL_W, 22)
    b:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    controlBox(b)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -24, 0)
    b.text:SetJustifyH("LEFT")
    drawArrow(b)
    b:SetScript("OnEnter", function(self) Style.SetBorderColor(self, "accent") end)
    b:SetScript("OnLeave", function(self) Style.SetBorderColor(self, "border") end)
    trackHover(row, b)
    return b
end

function Widgets.Dropdown(parent, opts)
    local row = newRow(parent, opts)
    if not list then createList() end
    row.opts, row.list = opts, list
    row.button = newDropdownButton(row)
    row.button:SetScript("OnClick", function() toggleList(row) end)
    -- Hiding the window (or the tab) closes a list this row opened.
    row:SetScript("OnHide", function(self)
        if list.owner == self then Widgets.CloseList() end
    end)

    function row:Refresh()
        local items = opts.items()
        local item = items[indexOf(items, opts.get()) or 0]
        row.button.text:SetText(item and item.text or "")
        applyFont(row.button.text, item and item.font)
        if list.owner == row then renderList() end
        row:RefreshInherit()
    end
    function row:SetEnabled(on)
        if not on and list.owner == row then Widgets.CloseList() end
        row.button:SetEnabled(on)
        dimRow(row, on)
    end
    return row
end

-- Color ---------------------------------------------------------------------

local function sameColor(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local SWATCH_W, SWATCH_H, CHECKER_CELL = 40, 16, 4

-- Alternating control/muted squares inside the 1 px border, so a dark or
-- transparent colour is still visible. Edge cells are clipped to fit.
local function drawChecker(s)
    s.checker = {}
    local innerW, innerH = SWATCH_W - 2, SWATCH_H - 2
    local row = 0
    for y = 0, innerH - 1, CHECKER_CELL do
        local col = 0
        for x = 0, innerW - 1, CHECKER_CELL do
            local cell = s:CreateTexture(nil, "BACKGROUND", nil, 1)
            local c = Style.COLORS[(row + col) % 2 == 0 and "control" or "muted"]
            cell:SetColorTexture(c[1], c[2], c[3], c[4])
            cell:SetSize(math.min(CHECKER_CELL, innerW - x), math.min(CHECKER_CELL, innerH - y))
            cell:SetPoint("TOPLEFT", s, "TOPLEFT", 1 + x, -1 - y)
            s.checker[#s.checker + 1] = cell
            col = col + 1
        end
        row = row + 1
    end
end

local function newSwatch(row)
    local s = CreateFrame("Button", nil, row)
    s:SetSize(SWATCH_W, SWATCH_H)
    s:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    Style.Fill(s, "control")
    Style.Border(s, "muted")
    drawChecker(s)
    s.color = s:CreateTexture(nil, "ARTWORK")
    s.color:SetPoint("TOPLEFT", 1, -1)
    s.color:SetPoint("BOTTOMRIGHT", -1, 1)
    s:SetScript("OnEnter", function(self) Style.SetBorderColor(self, "accent") end)
    s:SetScript("OnLeave", function(self) Style.SetBorderColor(self, "muted") end)
    trackHover(row, s)
    return s
end

-- The picker session we opened last. Its callbacks only act while it is
-- still the current one and never in combat (Config.Set would reach
-- secure frames); starting combat ends it.
local pickerInfo

local function pickerIsOurs()
    return pickerInfo ~= nil and ColorPickerFrame:IsShown()
        and ColorPickerFrame.swatchFunc == pickerInfo.swatchFunc
end

-- Hiding does not run the picker's cancelFunc: the colour previewed so far
-- stays (it was set before combat), and no callback writes in combat.
ns.On("PLAYER_REGEN_DISABLED", function()
    if pickerIsOurs() then
        pickerInfo = nil
        ColorPickerFrame:Hide()
    end
end)

local function openPicker(row, opts)
    local r, g, b, a = unpack(opts.get())
    a = a or 1
    local previous = { r, g, b, a }
    local info
    local function active() return pickerInfo == info and not InCombatLockdown() end
    -- Opening the picker sets its wheel, which already fires swatchFunc -
    -- before the alpha is set. Those calls are ignored.
    local opening = true
    local function apply()
        if opening or not active() then return end
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        -- opts.noOpacity: a colour without alpha (three values).
        local picked = opts.noOpacity and { nr, ng, nb } or { nr, ng, nb, ColorPickerFrame:GetColorAlpha() }
        if sameColor(picked, opts.get()) then return end
        opts.set(picked)
        row:Refresh()
    end
    info = {
        r = r, g = g, b = b, opacity = a, hasOpacity = not opts.noOpacity,
        swatchFunc = apply, opacityFunc = apply,
        cancelFunc = function()
            if not active() or sameColor(previous, opts.get()) then return end
            opts.set(opts.noOpacity and { previous[1], previous[2], previous[3] }
                or { previous[1], previous[2], previous[3], previous[4] })
            row:Refresh()
        end,
    }
    pickerInfo = info
    ColorPickerFrame:SetupColorPickerAndShow(info)
    opening = false
end

function Widgets.Color(parent, opts)
    local row = newRow(parent, opts)
    row.swatch = newSwatch(row)
    row.swatch:SetScript("OnClick", function() openPicker(row, opts) end)

    function row:Refresh()
        local c = opts.get()
        row.swatch.color:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        row:RefreshInherit()
    end
    function row:SetEnabled(on) row.swatch:SetEnabled(on); dimRow(row, on) end
    return row
end

-- Button --------------------------------------------------------------------

local function paintButton(button, hovered)
    if not button:IsEnabled() then
        Style.Paint(button.text, "muted"); Style.SetBorderColor(button, "border")
    elseif hovered then
        Style.Paint(button.text, "accent"); Style.SetBorderColor(button, "accent")
    else
        Style.Paint(button.text, "text"); Style.SetBorderColor(button, "border")
    end
end

function Widgets.Button(parent, opts)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(opts.width or 120, 24)
    controlBox(button)
    button.text = Style.Text(button, 12, "text")
    button.text:SetPoint("CENTER")
    button.text:SetText(opts.text)
    button:SetScript("OnClick", function() opts.onClick() end)
    button:SetScript("OnEnter", function(self) paintButton(self, true) end)
    button:SetScript("OnLeave", function(self) paintButton(self, false) end)
    -- Keep the native enable state (it blocks clicks) and repaint with it.
    local nativeSetEnabled = button.SetEnabled
    function button:SetEnabled(on)
        nativeSetEnabled(self, on)
        paintButton(self, false)
    end
    return button
end

-- TextArea ------------------------------------------------------------------

local AREA_PADDING = 6
local WHEEL_STEP = 20

-- Keeps the cursor line inside the visible part of the scroll frame.
local function followCursor(scroll, y, lineHeight)
    local top, view = -y, scroll:GetHeight()
    local current = scroll:GetVerticalScroll()
    if top < current then
        scroll:SetVerticalScroll(top)
    elseif top + lineHeight > current + view then
        scroll:SetVerticalScroll(top + lineHeight - view)
    end
end

local function newAreaScroll(area)
    local scroll = CreateFrame("ScrollFrame", nil, area)
    scroll:SetPoint("TOPLEFT", AREA_PADDING, -AREA_PADDING)
    scroll:SetPoint("BOTTOMRIGHT", -AREA_PADDING, AREA_PADDING)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), v)))
    end)
    return scroll
end

local function newAreaEdit(area, scroll, width)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetFont(fontPath(), 12, "")
    Style.Paint(edit, "text")
    edit:SetWidth(width - 2 * AREA_PADDING)
    edit:SetHeight(1)
    scroll:SetScrollChild(edit)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, h) followCursor(scroll, y, h) end)
    return edit
end

-- Read-only areas hold export strings: focus selects everything for a quick
-- copy, and typing is undone.
local function makeReadOnly(area, edit)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        self:SetText(area.value or "")
        self:HighlightText()
    end)
end

function Widgets.TextArea(parent, opts)
    local area = CreateFrame("Frame", nil, parent)
    area:SetSize(opts.width, opts.height)
    controlBox(area)
    local scroll = newAreaScroll(area)
    local edit = newAreaEdit(area, scroll, opts.width)
    area.scroll, area.edit = scroll, edit
    area:EnableMouse(true)
    area:SetScript("OnMouseDown", function() edit:SetFocus() end)
    if opts.readOnly then makeReadOnly(area, edit) end

    function area:SetText(s)
        area.value = s
        edit:SetText(s)
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
    end
    function area:GetText() return edit:GetText() end
    return area
end

-- Header --------------------------------------------------------------------

function Widgets.Header(parent, text)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Widgets.ROW_H)
    row.label = Style.Text(row, 14, "accent")
    row.label:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", LABEL_X, 6)
    row.label:SetText(text)
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetColorTexture(unpack(Style.COLORS.accent))
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", LABEL_X, 2)
    row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -LABEL_X, 2)
    function row:Refresh() end
    function row:SetEnabled() end
    return row
end
