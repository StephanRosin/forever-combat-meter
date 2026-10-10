local ADDON, ns = ...
local L, Settings, Media, Meter, Format, Windows = ns.L, ns.Settings, ns.Media, ns.Meter, ns.Format, ns.Windows
local S = Settings.Get

-- The tooltip over a bar, the breakdown panel (a click on a bar) and the death
-- recap (the same panel in the deaths mode).
--
-- Secret values (in combat): names and amounts may be secret. They only reach
-- font strings, StatusBar values and GameTooltip lines through Format and
-- string.format with %s; never a comparison, arithmetic, ".." or a table key.
-- Others' spells are not readable in combat (Meter.Spells returns nil): the
-- tooltip and panel then say "Details after combat".
local Detail = {}
ns.Detail = Detail

local issecret = issecretvalue or function() return false end
local format = string.format

local TOOLTIP_SPELLS = 5
local MAX_ENTRIES = 100     -- spells kept for scrolling
local QUESTION_MARK = 134400  -- INV_Misc_QuestionMark
local VALUE_SHARE, TEXT_INSET, ICON_GAP = 0.5, 5, 4
local TICK = 0.5             -- seconds between panel redraws
local FONT_RETRY = 0.5       -- fonts load lazily: lay out once more
local SPEC_CROP = { 0.08, 0.92, 0.08, 0.92 }
local ACCENT = { 0.31, 0.76, 0.97 }
local IDLE = { 0.73, 0.64, 0.48 }
local HOVER = { 1, 0.88, 0.54 }
local GREY = { 0.6, 0.6, 0.6 }
local GOLD = { 1, 0.82, 0.29 }
local PRECISE = { interrupts = true, dispels = true }
local SEP = " \226\128\148 "  -- " — "

local panel
local current   -- { window, mode, view, row } of the open panel
local shownRows = 0     -- entries drawn
local lastCount = 1     -- entries in the list (the panel is sized for them)
local offset = 0        -- first entry shown, for scrolling

local function modeLabel(key) return L["MODE_" .. key:upper()] or key end

local spellLabel = Format.SpellLabel

local function recapLabel(e)
    if Format.Present(e.time) then return format("%.0fs  %s", e.time, e.spell) end
    return format("%s", e.spell)
end

local function recapValue(e)
    return format("%s (%s HP)", Format.Amount(e.amount), Format.Amount(e.hp))
end

local function unreadable()
    if InCombatLockdown() then return L.DETAIL_AFTER_COMBAT end
    return L.DETAIL_EMPTY
end

-- Tooltip ----------------------------------------------------------------------------

-- The tooltip as data: { left, right|nil, dim, recap, title, class }.
function Detail.Lines(modeKey, view, row)
    local lines = {}
    local function add(left, extra)
        local line = extra or {}
        line.left = left
        lines[#lines + 1] = line
    end
    -- Left and right text: a flag says so, the texts may be secret.
    local function addPair(left, right, extra)
        local line = extra or {}
        line.left, line.right, line.double = left, right, true
        lines[#lines + 1] = line
    end
    add(Format.Name(nil, row.name), { title = true, class = row.class })
    if modeKey == "deaths" then
        addPair(L.DETAIL_DEATHS, Format.Amount(row.total))
        if Format.Present(row.deathTime) then
            add(format(L.DETAIL_DIED_AT, Format.Duration(row.deathTime)))
        end
        local recap = Meter.Recap(row.recapID)
        if not recap then
            add(L.DETAIL_NO_RECAP, { dim = true })
        elseif recap.secret then
            add(L.DETAIL_AFTER_COMBAT, { dim = true })
        else
            for _, e in ipairs(recap) do
                addPair(recapLabel(e), Format.Amount(e.amount), { recap = true })
            end
        end
    else
        addPair(L.DETAIL_TOTAL, Format.Amount(row.total))
        addPair(L.DETAIL_PER_SECOND, Format.PerSecond(row.perSecond, PRECISE[modeKey]))
        if Format.Present(row.percent) then addPair(L.DETAIL_SHARE, Format.Percent(row.percent)) end
        local data = Meter.Spells(modeKey, view, row)
        if not data then
            add(unreadable(), { dim = true })
        elseif #data.rows == 0 then
            add(L.DETAIL_EMPTY, { dim = true })
        else
            for k = 1, math.min(TOOLTIP_SPELLS, #data.rows) do
                local sp = data.rows[k]
                addPair(spellLabel(sp), Format.ValueText(sp.total, sp.percentOfSource))
            end
        end
    end
    add(L.DETAIL_HINT, { dim = true })
    return lines
end

local function lineColor(line)
    if line.dim then return GREY[1], GREY[2], GREY[3] end
    if line.title then   -- plain: a flag
        local r, g, b = Windows.ClassColor(line.class, true, { 1, 1, 1 })
        return r, g, b
    end
    return 1, 1, 1
end

function Detail.ShowTooltip(bar, windowIndex)
    local row = bar.row
    if not row then return end
    GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
    for _, line in ipairs(Detail.Lines(Windows.Mode(windowIndex), Windows.View(windowIndex), row)) do
        local r, g, b = lineColor(line)
        if line.double then
            GameTooltip:AddDoubleLine(line.left, line.right, 1, 0.82, 0.29, 1, 1, 1)
        else
            GameTooltip:AddLine(line.left, r, g, b)
        end
    end
    GameTooltip:Show()
end

function Detail.HideTooltip(bar)
    if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
end

-- Panel ------------------------------------------------------------------------------

-- Size and place now: the live drag while resizing, else the settings.
local function liveSize()
    local r = panel and panel.resizing
    if r and r.moved then return r.width, r.rows, r.x, r.y end
    return S("detailWidth"), S("detailRows")
end

local function place(f)
    local _, _, x, y = liveSize()
    f:ClearAllPoints()
    if x then
        f:SetPoint("TOP", UIParent, "TOP", x, y)
    else
        local point = S("detailPoint")
        f:SetPoint(point, UIParent, point, S("detailX"), S("detailY"))
    end
end

-- Height in bars: the chosen rows while unlocked (what is being sized),
-- else only as many as there are entries.
local function visibleRows(listCount)
    local _, rows = liveSize()
    if not S("locked") then return rows end
    return math.max(1, math.min(listCount, rows))
end

local function heightFor(rows)
    local lk = Windows.Look()
    local barH, spacing = S("barHeight"), S("barSpacing")
    return lk.header + 2 * S("padding") + rows * barH + (rows - 1) * spacing
end

local function rowsFor(height)
    local lk = Windows.Look()
    local barH, spacing = S("barHeight"), S("barSpacing")
    return math.floor((height - lk.header - 2 * S("padding") + spacing) / (barH + spacing) + 1e-6)
end

local function stopMoving(f)
    if not f.moving then return end
    f:StopMovingOrSizing()
    f.moving = nil
    -- StopMovingOrSizing marks the frame user placed; the position is ours.
    if f.SetUserPlaced then f:SetUserPlaced(false) end
    local x, y = ns.Position.Read(f, "TOP")
    if x then Settings.SetMany({ detailPoint = "TOP", detailX = x, detailY = y }) end
end

local function newRow(f, k)
    local row = CreateFrame("StatusBar", nil, f.body)
    row:SetMinMaxValues(0, 1)
    row:SetValue(0)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    -- The spell's icon: a square in front of the bar, outside it.
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.value = row:CreateFontString(nil, "OVERLAY")
    row.value:SetPoint("RIGHT", row, "RIGHT", -TEXT_INSET, 0)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:Hide()
    f.rows[k] = row
    return row
end

local function layoutRows(f, lk, count, width)
    local barH, spacing, pad = S("barHeight"), S("barSpacing"), S("padding")
    local inner = width - 2 * pad
    local barWidth = inner - barH - ICON_GAP
    local texture = Media.Path("statusbar", S("barTexture"))
    local nameStyle, valueStyle = Settings.TextStyle("name"), Settings.TextStyle("value")
    local valueWidth = math.floor(barWidth * VALUE_SHARE)
    for k = 1, count do
        local row = f.rows[k] or newRow(f, k)
        row:SetSize(barWidth, barH)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.body, "TOPLEFT", pad + barH + ICON_GAP, -(pad + (k - 1) * (barH + spacing)))
        row:SetStatusBarTexture(texture)
        row.icon:SetSize(barH, barH)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("RIGHT", row, "LEFT", -ICON_GAP, 0)
        row.value:SetWidth(valueWidth)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", TEXT_INSET, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -(TEXT_INSET + valueWidth + ICON_GAP), 0)
        Media.ApplyText(row.name, nameStyle)
        Media.ApplyText(row.value, valueStyle)
    end
end

-- Header, size, look, for `listCount` entries.
local function layout(f, listCount)
    local lk = Windows.Look()
    local width = liveSize()
    local count = visibleRows(listCount)
    f:SetWidth(width)
    f:SetHeight(heightFor(count))
    place(f)
    local h = f.header
    h:SetHeight(lk.header)
    h.shine:SetShown(lk.glow)
    h.dark:SetShown(not lk.glow)
    h.line:SetShown(S("headerLine") and true or false)
    local style = Settings.TextStyle("header")
    style.size = math.max(8, style.size - lk.titleDelta)
    Media.ApplyText(h.title, style)
    f.close:SetSize(lk.button, lk.button)
    f.close:ClearAllPoints()
    f.close:SetPoint("RIGHT", h, "RIGHT", lk.glow and -4 or -2, 0)
    f.lock:SetSize(lk.button, lk.button)
    f.lock.icon:SetSize(lk.icon, lk.icon)
    f.lock:ClearAllPoints()
    f.lock:SetPoint("RIGHT", f.close, "LEFT", -1, 0)
    f.lock.icon:SetTexture(Media.Icon(S("locked") and "Lock" or "Unlock"))
    f.lock.icon:SetVertexColor(unpack(S("locked") and IDLE or ACCENT))
    h.title:ClearAllPoints()
    h.title:SetPoint("LEFT", h, "LEFT", lk.glow and 8 or 4, 0)
    h.title:SetPoint("RIGHT", f.lock, "LEFT", -4, 0)
    layoutRows(f, lk, count, width)
    for _, g in pairs(f.grips) do g:SetShown(not S("locked")) end
    Windows.ApplyLook(f, lk)
    f.laidRows = count
end

local function createHeader(f)
    local h = CreateFrame("Button", nil, f)
    f.header = h
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:RegisterForClicks("RightButtonUp")
    h:EnableMouse(true)
    h.shine = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    h.shine:SetAllPoints()
    h.shine:SetColorTexture(1, 1, 1, 1)
    h.shine:SetGradient("VERTICAL", CreateColor(1, 0.79, 0.19, 0), CreateColor(1, 0.79, 0.19, 0.10))
    h.dark = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    h.dark:SetAllPoints()
    h.dark:SetColorTexture(0, 0, 0, 0.35)
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT")
    h.line:SetPoint("BOTTOMRIGHT")
    h.line:SetColorTexture(0.78, 0.59, 0.13, 0.45)
    h.title = h:CreateFontString(nil, "OVERLAY")
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    h:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then
            f:StartMoving()
            f.moving = true
        end
    end)
    h:SetScript("OnMouseUp", function() stopMoving(f) end)
    h:SetScript("OnHide", function() stopMoving(f) end)
    h:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then Detail.ReportSpells() end
    end)
    h:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.DETAIL_REPORT_HINT, 1, 1, 1)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local close = CreateFrame("Button", nil, h)
    f.close = close
    close.label = close:CreateFontString(nil, "OVERLAY")
    close.label:SetFont(Media.FontPath("Arial Narrow"), 14, "")
    close.label:SetPoint("CENTER")
    close.label:SetText("X")
    close.label:SetTextColor(IDLE[1], IDLE[2], IDLE[3])
    close:SetScript("OnClick", function() Detail.Close() end)
    close:SetScript("OnEnter", function(self)
        self.label:SetTextColor(HOVER[1], HOVER[2], HOVER[3])
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.DETAIL_CLOSE, 1, 1, 1)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function(self)
        self.label:SetTextColor(IDLE[1], IDLE[2], IDLE[3])
        GameTooltip:Hide()
    end)

    -- Locks or unlocks all windows (the corner arrows show while unlocked).
    local lock = CreateFrame("Button", nil, h)
    f.lock = lock
    lock.icon = lock:CreateTexture(nil, "ARTWORK")
    lock.icon:SetPoint("CENTER")
    lock.icon:SetTexture(Media.Icon("Unlock"))
    lock:SetScript("OnClick", function() Settings.SetLocked(not S("locked")) end)
    lock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(S("locked") and L.OPT_UNLOCK_FRAME or L.OPT_LOCK_FRAME, 1, 1, 1)
        GameTooltip:Show()
    end)
    lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local elapsedTick = 0

local function create()
    local f = CreateFrame("Frame", "ForeverCombatMeterDetail", UIParent)
    panel = f
    f.rows = {}
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.clip = {}
    createHeader(f)
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, 0)
    f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.body:EnableMouseWheel(true)
    f.body:SetScript("OnMouseWheel", function(_, delta) Detail.Scroll(delta) end)
    ns.Resize.Attach(f, {
        locked = function() return S("locked") end,
        width = function() return S("detailWidth") end,
        rows = function() return S("detailRows") end,
        widthRange = Settings.RANGES.detailWidth, rowsRange = Settings.RANGES.detailRows,
        rowsFor = rowsFor, heightFor = heightFor,
        live = function() layout(f, lastCount); Detail.Refresh() end,
        commit = function(_, r)
            Settings.SetMany({ detailWidth = r.width, detailRows = r.rows, detailPoint = "TOP",
                               detailX = r.x, detailY = r.y })
        end,
        done = function() layout(f, lastCount); Detail.Refresh() end,
    })
    f:SetScript("OnUpdate", function(_, elapsed)
        elapsedTick = elapsedTick + elapsed
        if elapsedTick < TICK then return end
        elapsedTick = 0
        Detail.Refresh()
    end)
    f:Hide()
    layout(f, 1)
    C_Timer.After(FONT_RETRY, function()
        if panel and panel:IsShown() then layout(panel, lastCount) end
    end)
    return f
end

function Detail.Frame() return panel end
function Detail.Count() return shownRows end
function Detail.IsOpen() return current ~= nil and panel ~= nil and panel:IsShown() end

-- { name, mode, view, row } of the open panel (for Report.Spells), or nil.
function Detail.Source()
    if not current then return nil end
    return { name = current.row.name, mode = current.mode, view = current.view, row = current.row }
end

-- The entries to show: { icon, name, value, total } per row.
local function entries(mode, view, row)
    local list = {}
    if mode == "deaths" then
        local recap = Meter.Recap(row.recapID)
        if not recap then
            list[1] = { name = L.DETAIL_NO_RECAP, value = "", noIcon = true }
        elseif recap.secret then
            list[1] = { name = L.DETAIL_AFTER_COMBAT, value = "", noIcon = true }
        else
            for k, e in ipairs(recap) do
                list[k] = { icon = e.icon, name = recapLabel(e), value = recapValue(e) }
            end
        end
        return list
    end
    local data = Meter.Spells(mode, view, row)
    if not data then return { { name = unreadable(), value = "", noIcon = true } } end
    if #data.rows == 0 then return { { name = L.DETAIL_EMPTY, value = "", noIcon = true } } end
    for k = 1, math.min(MAX_ENTRIES, #data.rows) do
        local sp = data.rows[k]
        local value
        local ps = Format.PerSecond(sp.perSecond, PRECISE[mode])
        if Format.Present(sp.percentOfSource) then
            value = format("%s (%s, %s)", Format.Amount(sp.total), ps, Format.Percent(sp.percentOfSource))
        else
            value = format("%s (%s)", Format.Amount(sp.total), ps)
        end
        list[k] = { icon = sp.icon, name = spellLabel(sp), value = value, total = sp.total }
    end
    return list
end

local function fillRow(row, entry, max, r, g, b)
    row.name:SetText(entry.name)
    row.value:SetText(entry.value)
    if entry.noIcon then
        row.icon:Hide()
    else
        -- A secret icon goes to SetTexture as it is (even "== nil" on a
        -- secret raises); a plain missing icon becomes the question mark.
        local icon = entry.icon
        if not issecret(icon) and icon == nil then icon = QUESTION_MARK end
        row.icon:SetTexture(icon)
        row.icon:SetTexCoord(SPEC_CROP[1], SPEC_CROP[2], SPEC_CROP[3], SPEC_CROP[4])
        row.icon:Show()
    end
    local m, v = Windows.FillArgs(max, entry.total)
    row:SetMinMaxValues(0, m)
    row:SetValue(v)
    row:SetStatusBarColor(r, g, b, 1)
    row.bg:SetColorTexture(r, g, b, S("barBgAlpha") / 100)
    row:Show()
end

-- Another player's row opened in combat has no GUID and a secret name; no
-- plain key identifies them later, so the panel never guesses the row: after
-- combat it asks for a new click on the bar. Own rows and creatures resolve.
local function unidentified(row)
    return row.guid == nil and row.creatureID == nil and not row.isPlayer   -- plain: Meter.Fetch keeps only plain IDs
end

function Detail.Refresh()
    if not current or not panel or not panel:IsShown() then return end
    local row = current.row
    local list
    if current.unknown and not InCombatLockdown() then
        panel.header.title:SetText(format("%s", modeLabel(current.mode)))
        list = { { name = L.DETAIL_REOPEN, value = "", noIcon = true } }
    else
        panel.header.title:SetText(format("%s%s%s", Format.Name(nil, row.name), SEP, modeLabel(current.mode)))
        list = entries(current.mode, current.view, row)
    end
    lastCount = #list
    local visible = visibleRows(#list)
    if panel.laidRows ~= visible then layout(panel, #list) end
    offset = math.max(0, math.min(offset, #list - visible))
    shownRows = math.min(visible, #list)
    local r, g, b = Windows.ClassColor(row.class, S("detailClassColor"), S("detailBarColor"))
    local max = list[1] and list[1].total
    for k = 1, shownRows do fillRow(panel.rows[k], list[offset + k], max, r, g, b) end
    for k = shownRows + 1, #panel.rows do panel.rows[k]:Hide() end
end

function Detail.Open(windowIndex, row)
    if not row then return end
    current = { window = windowIndex, mode = Windows.Mode(windowIndex), view = Windows.View(windowIndex), row = row,
                unknown = unidentified(row) }
    local frame = panel or create()
    frame:Show()
    elapsedTick = 0
    offset = 0
    Detail.Refresh()
end

-- delta > 0 (wheel up) shows earlier entries.
function Detail.Scroll(delta)
    if not panel or not current then return end
    local before = offset
    offset = math.max(0, math.min(offset - delta, lastCount - visibleRows(lastCount)))
    if offset ~= before then Detail.Refresh() end
end

function Detail.Offset() return offset end

function Detail.Close()
    current = nil
    shownRows, lastCount, offset = 0, 1, 0
    if panel then panel:Hide() end
end

-- Right click on the panel's title: its top spells into the chat.
function Detail.ReportSpells()
    local source = Detail.Source()
    if not source or source.mode == "deaths" or current.unknown then return end   -- plain: a table
    if ns.Report then ns.Report.Spells(source, S("reportLines")) end
end

Windows.BarScripts.enter = function(bar, windowIndex) Detail.ShowTooltip(bar, windowIndex) end
Windows.BarScripts.leave = function(bar) Detail.HideTooltip(bar) end
Windows.BarScripts.click = function(bar, windowIndex, button)
    if button == "LeftButton" and bar.row then Detail.Open(windowIndex, bar.row) end
end

Settings.OnChange(function()
    if panel and panel:IsShown() then
        layout(panel, lastCount)
        Detail.Refresh()
    end
end)
