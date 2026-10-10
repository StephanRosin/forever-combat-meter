local ADDON, ns = ...
local L, Settings, Media, Meter, Threat, Format = ns.L, ns.Settings, ns.Media, ns.Meter, ns.Threat, ns.Format
local S = Settings.Get

-- The meter windows: up to four, each with the quest log's header (title,
-- icon buttons, gold glow) and a list of bars. Ordinary frames only; nothing
-- here is protected.
--
-- Per window settings live in the profile as `windows[i]` (only what differs
-- from windowDefaults(i)); the number of windows is the setting windowCount.
-- A past fight's session ID does not survive a reload, so only "current" /
-- "overall" are stored; a past fight is kept in the runtime state.
--
-- Secret values (in combat): rows come from Meter.Fetch; names and amounts
-- may be secret. They only reach SetText (through Format and string.format
-- with %s), StatusBar:SetMinMaxValues and SetValue; never a comparison,
-- arithmetic, ".." or a table key. Only plain values are animated.
local Windows = {}
ns.Windows = Windows

local issecret = issecretvalue or function() return false end

local MAX_WINDOWS = 4
-- The two looks. FOREVER is the quest log's header; COMPACT is a slim title
-- bar with bars edge to edge (the user's "like ForeverMeter / Details!").
local LOOKS = {
    FOREVER = { header = 24, button = 16, icon = 12, pad = 4, glow = true, titleDelta = 0, allButtons = true },
    COMPACT = { header = 18, button = 12, icon = 10, pad = 0, glow = false, titleDelta = 3, allButtons = false },
}
local WIDTH_RANGE, ROWS_RANGE, POS_RANGE = { 120, 600 }, { 1, 40 }, { -4000, 4000 }
local GRIP = 12
local AFTER_COMBAT = 3   -- seconds of redraws after combat (amounts turn readable)
local FONT_RETRY = 0.5   -- the client loads a font file lazily: lay out again
local ANIM_RATE = 10     -- share of the remaining distance per second
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local ACCENT = { 0.31, 0.76, 0.97 }
local IDLE = { 0.73, 0.64, 0.48 }
local HOVER = { 1, 0.88, 0.54 }
local GREY = { 0.6, 0.6, 0.6 }
-- Per second of counts keeps a decimal even when secret.
local PRECISE = { interrupts = true, dispels = true, deaths = true }
local POINTS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
                 TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local frames, state = {}, {}
local ready = false
local tickWait, burstLeft = 0, 0
local fontKey

local function look() return LOOKS[S("style")] or LOOKS.FOREVER end

local function clamp(v, range)
    return math.max(range[1], math.min(range[2], math.floor(v + 0.5)))
end

local function present(v) return issecret(v) or v ~= nil end

-- Window settings -------------------------------------------------------------

-- New windows sit side by side to the left of the first one.
local function windowDefaults(i)
    return { mode = "damage", view = "current", point = "CENTER", x = 300 - (i - 1) * 230, y = 0,
             width = 220, rows = 8, locked = false }
end

function Windows.Config(i)
    local c = windowDefaults(i)
    local all = ns.DB().windows
    local own = all and all[i]
    if type(own) == "table" then
        for k, v in pairs(own) do
            if c[k] ~= nil then c[k] = v end
        end
    end
    return c
end

-- Stores values for window i, keeping only what differs from its defaults.
local function write(i, values)
    local db = ns.DB()
    local all = db.windows or {}
    local own = all[i] or {}
    local def = windowDefaults(i)
    for k, v in pairs(values) do
        if def[k] ~= nil then
            if v == def[k] then own[k] = nil else own[k] = v end
        end
    end
    all[i] = next(own) and own or nil
    db.windows = next(all) and all or nil
    if frames[i] then frames[i].cfg = Windows.Config(i) end
end

local function modeKeys()
    local keys = {}
    for _, m in ipairs(Meter.MODES) do keys[#keys + 1] = m.key end
    keys[#keys + 1] = "threat"
    return keys
end

local function validMode(key)
    return key == "threat" or (type(key) == "string" and Meter.ModeType(key) ~= nil)
end

local function modeLabel(key) return L["MODE_" .. key:upper()] end

-- What an imported `windows` value may keep (Share.RegisterTable).
local function number(range)
    return function(v)
        if type(v) ~= "number" or v ~= v then return nil end
        return clamp(v, range)
    end
end
local CLEAN = {
    mode = function(v) return validMode(v) and v or nil end,
    view = function(v) return (v == "current" or v == "overall") and v or nil end,
    point = function(v) return type(v) == "string" and POINTS[v] and v or nil end,
    x = number(POS_RANGE), y = number(POS_RANGE), width = number(WIDTH_RANGE), rows = number(ROWS_RANGE),
    locked = function(v) return v == true or nil end,
}

function Windows.Clean(value)
    if type(value) ~= "table" then return nil end
    local out = {}
    for i, w in pairs(value) do
        if type(i) == "number" and i >= 1 and i <= MAX_WINDOWS and i == math.floor(i) and type(w) == "table" then
            local own, def = {}, windowDefaults(i)
            for k, clean in pairs(CLEAN) do
                local v = w[k] ~= nil and clean(w[k]) or nil
                if v ~= nil and v ~= def[k] then own[k] = v end
            end
            if next(own) then out[i] = own end
        end
    end
    return next(out) and out or nil
end
ns.Share.RegisterTable("windows", Windows.Clean)

local function st(i)
    state[i] = state[i] or { offset = 0, dirty = true, count = 0 }
    return state[i]
end

function Windows.Frame(i) return frames[i] end
function Windows.Data(i) return state[i] and state[i].data end

function Windows.Mode(i)
    local key = (frames[i] and frames[i].cfg or Windows.Config(i)).mode
    return validMode(key) and key or "damage"
end

function Windows.View(i)
    return st(i).pastView or (frames[i] and frames[i].cfg or Windows.Config(i)).view
end

local function markAll()
    for i in pairs(frames) do st(i).dirty = true end
end

-- Placement ---------------------------------------------------------------------

local function place(f)
    local c = f.cfg
    f:ClearAllPoints()
    f:SetPoint(c.point, UIParent, c.point, c.x, c.y)
end

-- After a drag: the top edge's centre, so a change of rows keeps the top.
local function savePosition(f)
    local x, y = ns.Position.Read(f, "TOP")
    if x then write(f.index, { point = "TOP", x = x, y = y }) end
end

local function cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

-- Look -----------------------------------------------------------------------------

local function paint(button, color)
    button.icon:SetVertexColor(color[1], color[2], color[3])
end

local function buttonColor(b)
    if b.active and b.active() then return ACCENT end
    return IDLE
end

local function classColor(class)
    if S("barClassColor") and not issecret(class) and type(class) == "string" and RAID_CLASS_COLORS then
        local c = RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end
    local c = S("barColor")
    return c[1], c[2], c[3]
end

local function applyLook(f, lk)
    Media.ApplyBackground(f.bg, S("bgMode"), S("bgColor"), S("bgAlpha") / 100, S("bgTexture"))
    -- COMPACT is square unless the player chose a radius himself.
    local radius = lk.glow and S("cornerRadius") or (ns.DB().cornerRadius or 0)
    radius = ns.Corners.Clamp(radius, f:GetWidth(), f:GetHeight())
    ns.Corners.Fit(f.clip, f, radius, { f.bg, f.header.shine })
    ns.Border.Draw(f, f, {
        style = S("borderStyle"), size = S("borderSize"), color = S("borderColor"), radius = radius,
        shadow = S("shadowEnabled"), shadowSize = S("shadowSize"), shadowAlpha = S("shadowAlpha") / 100,
    })
end

local function layoutHeader(f, lk)
    local h, cfg = f.header, f.cfg
    h:SetHeight(lk.header)
    h.shine:SetShown(lk.glow)
    h.dark:SetShown(not lk.glow)
    h.line:SetShown(S("headerLine") and true or false)
    local style = Settings.TextStyle("header")
    style.size = math.max(8, style.size - lk.titleDelta)
    Media.ApplyText(h.title, style)
    local unlocked = not cfg.locked
    h.grip:SetShown(unlocked and lk.glow)
    local b = h.buttons
    local order = lk.allButtons and { b.menu, b.reset, b.lock, b.session, b.mode } or { b.menu, b.lock }
    for _, button in pairs(b) do button:Hide() end
    for k, button in ipairs(order) do
        button:SetSize(lk.button, lk.button)
        button.icon:SetSize(lk.icon, lk.icon)
        button:ClearAllPoints()
        if k == 1 then
            button:SetPoint("RIGHT", h, "RIGHT", lk.glow and -4 or -2, 0)
        else
            button:SetPoint("RIGHT", order[k - 1], "LEFT", -1, 0)
        end
        button:Show()
    end
    b.lock.icon:SetTexture(Media.Icon(cfg.locked and "Lock" or "Unlock"))
    for _, button in pairs(b) do paint(button, buttonColor(button)) end
    h.title:ClearAllPoints()
    h.title:SetPoint("LEFT", h, "LEFT", lk.glow and (unlocked and 24 or 8) or 4, 0)
    h.title:SetPoint("RIGHT", order[#order], "LEFT", -4, 0)
end

local function layoutBars(f, lk)
    local cfg = f.cfg
    local barH, spacing = S("barHeight"), S("barSpacing")
    local inner = cfg.width - 2 * lk.pad
    local texture = Media.Path("statusbar", S("barTexture"))
    local nameStyle, valueStyle = Settings.TextStyle("name"), Settings.TextStyle("value")
    local showIcon = S("showIcon")
    for k = 1, cfg.rows do
        local bar = f.bars[k] or Windows.NewBar(f, k)
        bar:SetSize(inner, barH)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", f.body, "TOPLEFT", lk.pad, -(lk.pad + (k - 1) * (barH + spacing)))
        bar:SetStatusBarTexture(texture)
        bar.icon:SetSize(barH, barH)
        bar.icon:SetShown(showIcon and true or false)
        bar.name:ClearAllPoints()
        if showIcon then
            bar.name:SetPoint("LEFT", bar.icon, "RIGHT", 3, 0)
        else
            bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
        end
        bar.name:SetPoint("RIGHT", bar.value, "LEFT", -4, 0)
        Media.ApplyText(bar.name, nameStyle)
        Media.ApplyText(bar.value, valueStyle)
        -- A font string redraws only for a different text: the next render
        -- writes them again in the new font.
        bar.name:SetText("")
        bar.value:SetText("")
    end
    for k = cfg.rows + 1, #f.bars do f.bars[k]:Hide() end
end

local function layout(i)
    local f = frames[i]
    if not f then return end
    f.cfg = Windows.Config(i)
    local lk, cfg = look(), f.cfg
    local barH, spacing = S("barHeight"), S("barSpacing")
    f:SetWidth(cfg.width)
    f:SetHeight(lk.header + 2 * lk.pad + cfg.rows * barH + (cfg.rows - 1) * spacing)
    if not (f.moving or f.resizing) then place(f) end
    layoutHeader(f, lk)
    layoutBars(f, lk)
    f.grips.left:SetShown(not cfg.locked)
    f.grips.right:SetShown(not cfg.locked)
    applyLook(f, lk)
    st(i).dirty = true
end

local function currentFontKey()
    local parts = {}
    for _, name in ipairs(Settings.TEXT_STYLES) do
        parts[#parts + 1] = tostring(S(name .. "Font")) .. "/" .. tostring(S(name .. "Size"))
    end
    return table.concat(parts, ",")
end

local function layoutAll()
    for i = 1, S("windowCount") do layout(i) end
    local key = currentFontKey()
    if key ~= fontKey then
        fontKey = key
        C_Timer.After(FONT_RETRY, function()
            for i = 1, S("windowCount") do layout(i) end
        end)
    end
end

-- Rows ------------------------------------------------------------------------------

local function setIcon(bar, specIcon, class)
    if not S("showIcon") then return end
    local icon = bar.icon
    if not issecret(specIcon) and type(specIcon) == "number" and specIcon > 0 then
        icon:SetTexture(specIcon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:Show()
        return
    end
    local coords = not issecret(class) and type(class) == "string" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        icon:SetTexture(CLASS_ICONS)
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        icon:Show()
    else
        icon:Hide()
    end
end

-- "a", "a (b)", "a (b, c)": the first column, the rest in brackets. The
-- pieces may be secret display strings: string.format with %s only.
local FORMATS = { "%s", "%s (%s)", "%s (%s, %s)" }
local function columns(list)
    if #list == 0 then return "" end
    return string.format(FORMATS[#list], unpack(list, 1, #list))
end

local function meterValues(row, mode)
    local list = {}
    if mode == "deaths" then
        if present(row.deathTime) then list[#list + 1] = Format.Duration(row.deathTime) end
        if S("showTotal") then list[#list + 1] = Format.Amount(row.total) end
    else
        if S("showTotal") then list[#list + 1] = Format.Amount(row.total) end
        if S("showPerSecond") then list[#list + 1] = Format.PerSecond(row.perSecond, PRECISE[mode]) end
    end
    if S("showPercent") and present(row.percent) then list[#list + 1] = Format.Percent(row.percent) end
    return columns(list)
end

-- The fill: secret values go to the bar as they are; plain ones may move
-- toward their value (Tick).
local function setFill(bar, max, value)
    if issecret(max) or issecret(value) then
        bar.target, bar.current, bar.wasSecret = nil, nil, true
        bar:SetMinMaxValues(0, max or 1)
        bar:SetValue(value or 0)
        return
    end
    max = (type(max) == "number" and max > 0) and max or 1
    value = type(value) == "number" and value or 0
    bar.maxValue = max
    bar:SetMinMaxValues(0, max)
    -- Out of combat a bar that showed a secret value starts where it is.
    local from = bar.current or (bar.wasSecret and value or 0)
    bar.wasSecret = nil
    if S("animate") then
        bar.target = value
        bar.current = from
        bar:SetValue(bar.current)
    else
        bar.target, bar.current = nil, nil
        bar:SetValue(value)
    end
end

local function paintBar(bar, class)
    local r, g, b = classColor(class)
    bar:SetStatusBarColor(r, g, b, 1)
    bar.bg:SetColorTexture(r, g, b, S("barBgAlpha") / 100)
end

local function showEmpty(f, text)
    for _, bar in ipairs(f.bars) do bar:Hide() end
    f.empty:SetText(text)
    f.empty:Show()
end

local function sessionLabel(view)
    if view == "current" then return L.SESSION_CURRENT end
    if view == "overall" then return L.SESSION_OVERALL end
    for _, s in ipairs(Meter.Sessions()) do
        if not issecret(s.id) and s.id == view and present(s.name) then return s.name end
    end
    return L.SESSION_FIGHT:format(tostring(view))
end

local function visibleRows(f, s, count)
    s.count = count
    s.offset = math.max(0, math.min(s.offset, count - f.cfg.rows))
    return math.min(f.cfg.rows, count - s.offset)
end

local function renderMeter(f, s, mode, view)
    f.header.title:SetText(string.format("%s · %s", modeLabel(mode), sessionLabel(view)))
    local available, why = Meter.Available()
    if not available then
        s.data = nil
        showEmpty(f, (type(why) == "string" and why ~= "") and why or L.METER_UNAVAILABLE)
        return
    end
    local data = Meter.Fetch(mode, view) or { rows = {} }
    s.data = data
    local rows = data.rows
    if #rows == 0 then
        visibleRows(f, s, 0)
        showEmpty(f, L.EMPTY_NO_DATA)
        return
    end
    f.empty:Hide()
    local shown = visibleRows(f, s, #rows)
    local rank = S("showRank")
    for k = 1, #f.bars do
        local bar, n = f.bars[k], k + s.offset
        local row = k <= shown and rows[n]
        if row then
            bar.row, bar.rank = row, n
            paintBar(bar, row.class)
            setIcon(bar, row.specIcon, row.class)
            bar.name:SetText(Format.Name(rank and n or nil, row.name))
            bar.value:SetText(meterValues(row, mode))
            setFill(bar, data.max, row.total)
            bar.glow:Hide()
            bar:Show()
        else
            bar:Hide()
        end
    end
end

-- One threat sample (and warning check) per tick for every threat window.
local function sampleThreat()
    local list = Threat.List()
    return { list = list, warning = Threat.CheckWarning(list) }
end

local function threatValues(row)
    local list = { Format.Percent(row.pct) }
    if S("showPerSecond") then list[2] = Format.PerSecond(row.perSecond) end
    return columns(list)
end

local function renderThreat(f, s, sample)
    f.header.title:SetText(modeLabel("threat"))
    sample = sample or sampleThreat()
    s.data = sample.list
    local rows = sample.list.rows
    if sample.list.unavailable or #rows == 0 then
        visibleRows(f, s, 0)
        local text = sample.list.unavailable and L.THREAT_UNAVAILABLE
            or (UnitExists("target") and L.EMPTY_NO_DATA or L.THREAT_NO_TARGET)
        showEmpty(f, text)
        return
    end
    f.empty:Hide()
    local shown = visibleRows(f, s, #rows)
    local rank = S("showRank")
    for k = 1, #f.bars do
        local bar, n = f.bars[k], k + s.offset
        local row = k <= shown and rows[n]
        if row then
            bar.row, bar.rank = row, n
            paintBar(bar, row.class)
            setIcon(bar, nil, row.class)
            local name = Format.Name(rank and n or nil, row.name)
            if row.tanking then name = string.format("%s (%s)", name, L.THREAT_TANK) end
            bar.name:SetText(name)
            bar.value:SetText(threatValues(row))
            -- rawPct passes 100 before the pull (110 % melee, 130 % ranged).
            setFill(bar, 100, math.min(row.pct or 0, 100))
            local own = row.isPlayer and not tostring(row.unit):find("pet", 1, true)
            bar.glow:SetShown((own and sample.warning) and true or false)
            bar:Show()
        else
            bar:Hide()
        end
    end
end

local function render(i, sample)
    local f = frames[i]
    if not f or not f:IsShown() then return end
    local s = st(i)
    s.dirty = false
    local mode = Windows.Mode(i)
    if mode == "threat" then
        renderThreat(f, s, sample)
    else
        renderMeter(f, s, mode, Windows.View(i))
    end
end

-- Redraws window i now, or every shown window (one threat sample for all).
function Windows.Refresh(i)
    if i then return render(i) end
    local sample
    for n = 1, S("windowCount") do
        if Windows.Mode(n) == "threat" then sample = sample or sampleThreat() end
        render(n, sample)
    end
end

-- Moving and resizing -------------------------------------------------------------

local function rowsFor(height)
    local lk = look()
    local barH, spacing = S("barHeight"), S("barSpacing")
    return clamp((height - lk.header - 2 * lk.pad + spacing) / (barH + spacing), ROWS_RANGE)
end

local function followCursor(f)
    local r = f.resizing
    if not r then return end
    local x, y = cursor()
    local dx, dy = x - r.x0, y - r.y0
    local width = clamp(r.w0 + (r.fromLeft and -dx or dx), WIDTH_RANGE)
    local rows = rowsFor(r.h0 - dy)
    if width ~= r.width or rows ~= r.rows then
        r.width, r.rows = width, rows
        write(f.index, { width = width, rows = rows })
        layout(f.index)
        render(f.index)
    end
end

-- By hand: StartSizing fires no OnSizeChanged on this client. The top
-- corner opposite the grip stays where it is.
local function startResize(f, grip, fromLeft)
    if f.cfg.locked then return end
    local left, right, top = f:GetLeft(), f:GetRight(), f:GetTop()
    if not left then return end
    local x, y = cursor()
    f.resizing = { fromLeft = fromLeft, x0 = x, y0 = y, w0 = f:GetWidth(), h0 = f:GetHeight(),
                   width = f.cfg.width, rows = f.cfg.rows }
    f:ClearAllPoints()
    if fromLeft then
        f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
    else
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    grip:SetScript("OnUpdate", function() followCursor(f) end)
end

local function stopResize(f, grip)
    grip:SetScript("OnUpdate", nil)
    if not f.resizing then return end
    f.resizing = nil
    savePosition(f)
    Settings.Changed("windows")
    layout(f.index)
end

local function newGrip(f, fromLeft)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(GRIP, GRIP)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip:SetPoint(fromLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", f, fromLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
    grip.icon = grip:CreateTexture(nil, "OVERLAY")
    grip.icon:SetAllPoints()
    grip.icon:SetTexture(Media.Icon("Resize"))
    grip.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    if fromLeft then grip.icon:SetTexCoord(1, 0, 0, 1) end
    grip:SetScript("OnMouseDown", function() startResize(f, grip, fromLeft) end)
    grip:SetScript("OnMouseUp", function() stopResize(f, grip) end)
    grip:SetScript("OnHide", function() stopResize(f, grip) end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.TIP_RESIZE, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return grip
end

local function startMoving(f)
    if f.cfg.locked then return end
    f:StartMoving()
    f.moving = true
end

local function stopMoving(f)
    if not f.moving then return end
    f:StopMovingOrSizing()
    f.moving = nil
    -- StopMovingOrSizing marks the frame user placed; the position is ours.
    if f.SetUserPlaced then f:SetUserPlaced(false) end
    savePosition(f)
    Settings.Changed("windows")
    layout(f.index)
end

-- Menus ---------------------------------------------------------------------------

local function addModes(parent, i)
    for _, key in ipairs(modeKeys()) do
        parent:CreateRadio(modeLabel(key), function(k) return Windows.Mode(i) == k end,
            function(k) Windows.SetMode(i, k) end, key)
    end
end

local function sessionText(s, n)
    local name = (issecret(s.name) or type(s.name) ~= "string") and L.SESSION_FIGHT:format(tostring(n)) or s.name
    if issecret(s.duration) or type(s.duration) ~= "number" then return name end
    return string.format("%s (%s)", name, Format.Duration(s.duration))
end

local function addSessions(parent, i)
    local function isView(v) return Windows.View(i) == v end
    local function setView(v) Windows.SetView(i, v) end
    parent:CreateRadio(L.SESSION_CURRENT, isView, setView, "current")
    parent:CreateRadio(L.SESSION_OVERALL, isView, setView, "overall")
    parent:CreateDivider()
    local any = false
    for n, s in ipairs(Meter.Sessions()) do
        if not issecret(s.id) and s.id ~= nil then
            any = true
            parent:CreateRadio(sessionText(s, n), isView, setView, s.id)
        end
    end
    if not any then parent:CreateTitle(L.SESSION_NONE) end
end

local function contextMenu(owner, build)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root) build(root) end)
    end
end

function Windows.OpenModeMenu(i, owner)
    contextMenu(owner, function(root) addModes(root, i) end)
end

function Windows.OpenSessionMenu(i, owner)
    contextMenu(owner, function(root) addSessions(root, i) end)
end

function Windows.OpenMenu(i, owner)
    contextMenu(owner, function(root)
        root:CreateTitle(L.ADDON_NAME)
        addModes(root:CreateButton(L.MENU_MODE), i)
        addSessions(root:CreateButton(L.MENU_SESSION), i)
        root:CreateDivider()
        local new = root:CreateButton(L.MENU_NEW_WINDOW, function() Windows.Add() end)
        if S("windowCount") >= MAX_WINDOWS and new.SetEnabled then new:SetEnabled(false) end
        local close = root:CreateButton(L.MENU_CLOSE_WINDOW, function() Windows.Close(i) end)
        if i == 1 and close.SetEnabled then close:SetEnabled(false) end
        root:CreateButton(Windows.Config(i).locked and L.MENU_UNLOCK or L.MENU_LOCK,
            function() Windows.ToggleLock(i) end)
        root:CreateButton(L.MENU_RESET, function() Windows.AskReset() end)
        root:CreateDivider()
        root:CreateButton(L.MENU_OPTIONS, function() ns.Window.Open() end)
    end)
end

StaticPopupDialogs.FOREVERCOMBATMETER_RESET = {
    text = "", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function()
        Meter.Reset()
        markAll()
    end,
}

-- Out of combat after a confirmation; in combat not at all.
function Windows.AskReset()
    if InCombatLockdown() then
        ns.Print(L.MSG_RESET_COMBAT)
        return
    end
    StaticPopupDialogs.FOREVERCOMBATMETER_RESET.text = L.POPUP_RESET
    StaticPopup_Show("FOREVERCOMBATMETER_RESET")
end

-- Building -------------------------------------------------------------------------

local function tooltip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function headerButton(f, icon, tip, onClick, active)
    local b = CreateFrame("Button", nil, f.header)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(Media.Icon(icon))
    b.active = active
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        paint(self, HOVER)
        tooltip(self, type(tip) == "function" and tip() or tip)
    end)
    b:SetScript("OnLeave", function(self)
        paint(self, buttonColor(self))
        GameTooltip:Hide()
    end)
    return b
end

local function createHeader(f)
    local i = f.index
    local h = CreateFrame("Button", nil, f)
    f.header = h
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:RegisterForClicks("RightButtonUp")
    h:EnableMouse(true)
    h:EnableMouseWheel(true)
    -- The quest log's gold glow and line.
    h.shine = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    h.shine:SetAllPoints()
    h.shine:SetColorTexture(1, 1, 1, 1)
    h.shine:SetGradient("VERTICAL", CreateColor(1, 0.79, 0.19, 0), CreateColor(1, 0.79, 0.19, 0.10))
    -- COMPACT: a plain darker strip instead.
    h.dark = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    h.dark:SetAllPoints()
    h.dark:SetColorTexture(0, 0, 0, 0.35)
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT")
    h.line:SetPoint("BOTTOMRIGHT")
    h.line:SetColorTexture(0.78, 0.59, 0.13, 0.45)
    h.grip = h:CreateTexture(nil, "OVERLAY")
    h.grip:SetSize(12, 12)
    h.grip:SetPoint("LEFT", 8, 0)
    h.grip:SetTexture(Media.Icon("Grip"))
    h.grip:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3])
    h.title = h:CreateFontString(nil, "OVERLAY")
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)

    h.buttons = {
        menu = headerButton(f, "Gear", L.TIP_MENU, function(self) Windows.OpenMenu(i, self) end),
        reset = headerButton(f, "Reset", L.TIP_RESET, function() Windows.AskReset() end),
        lock = headerButton(f, "Lock", function()
            return f.cfg.locked and L.TIP_UNLOCK_WINDOW or L.TIP_LOCK_WINDOW
        end, function() Windows.ToggleLock(i) end, function() return not f.cfg.locked end),
        session = headerButton(f, "Session", L.TIP_SESSION, function(self, mouse)
            if mouse == "RightButton" then
                Windows.OpenSessionMenu(i, self)
            else
                Windows.SetView(i, Windows.View(i) == "current" and "overall" or "current")
            end
        end),
        mode = headerButton(f, "Mode", L.TIP_MODE, function(self) Windows.OpenModeMenu(i, self) end),
    }

    h:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then startMoving(f) end
    end)
    h:SetScript("OnMouseUp", function() stopMoving(f) end)
    h:SetScript("OnHide", function() stopMoving(f) end)
    h:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then Windows.OpenMenu(i, self) end
    end)
    h:SetScript("OnMouseWheel", function(_, delta) Windows.CycleMode(i, delta < 0 and 1 or -1) end)
end

-- Task 5 fills these (tooltip, breakdown): function(bar, windowIndex).
Windows.BarScripts = {}

function Windows.NewBar(f, k)
    local bar = CreateFrame("StatusBar", nil, f.body)
    bar.index = k
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.value = bar:CreateFontString(nil, "OVERLAY")
    bar.value:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    bar.value:SetJustifyH("RIGHT")
    bar.value:SetWordWrap(false)
    bar.name = bar:CreateFontString(nil, "OVERLAY")
    bar.name:SetJustifyH("LEFT")
    bar.name:SetWordWrap(false)
    bar.glow = bar:CreateTexture(nil, "OVERLAY")
    bar.glow:SetAllPoints()
    bar.glow:SetColorTexture(1, 0.1, 0.1, 0.35)
    bar.glow:Hide()
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta) Windows.Scroll(f.index, delta) end)
    for script, key in pairs({ OnEnter = "enter", OnLeave = "leave", OnMouseUp = "click" }) do
        bar:SetScript(script, function(self, ...)
            local fn = Windows.BarScripts[key]
            if fn then fn(self, f.index, ...) end
        end)
    end
    bar:Hide()
    f.bars[k] = bar
    return bar
end

function Windows.Create(i)
    if frames[i] then return frames[i] end
    local f = CreateFrame("Frame", "ForeverCombatMeterWindow" .. i, UIParent)
    f.index = i
    f.cfg = Windows.Config(i)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    -- The position is ours (the profile); the client's layout cache stays out.
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.clip = {}
    createHeader(f)
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, 0)
    f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.body:EnableMouseWheel(true)
    f.body:SetScript("OnMouseWheel", function(_, delta) Windows.Scroll(i, delta) end)
    f.empty = f.body:CreateFontString(nil, "OVERLAY")
    f.empty:SetFont(Media.FontPath("Arial Narrow"), 12, "")
    f.empty:SetTextColor(GREY[1], GREY[2], GREY[3])
    f.empty:SetPoint("TOPLEFT", f.body, "TOPLEFT", 8, -6)
    f.empty:Hide()
    f.bars = {}
    f.grips = { left = newGrip(f, true), right = newGrip(f, false) }
    frames[i] = f
    layout(i)
    return f
end

-- Shows windows 1..windowCount, hides the rest.
local function sync()
    if not ready then return end
    local count = S("windowCount")
    for i = 1, MAX_WINDOWS do
        if i <= count then
            Windows.Create(i)
            frames[i]:Show()
        elseif frames[i] then
            frames[i]:Hide()
        end
    end
    layoutAll()
end

-- Public actions --------------------------------------------------------------------

function Windows.SetConfig(i, values)
    local clean = {}
    for k, v in pairs(values) do
        local fn = CLEAN[k]
        if fn then clean[k] = fn(v) end
        if k == "locked" then clean[k] = v and true or false end
    end
    write(i, clean)
    layout(i)
    Settings.Changed("windows")
end

function Windows.SetMode(i, key)
    if not validMode(key) then return end
    write(i, { mode = key })
    st(i).offset = 0
    Settings.Changed("windows")
    render(i)
end

-- view: "current", "overall" or a past fight's session ID (not stored).
function Windows.SetView(i, view)
    local s = st(i)
    if type(view) == "number" then
        s.pastView = view
        write(i, { view = "current" })
    elseif view == "current" or view == "overall" then
        s.pastView = nil
        write(i, { view = view })
    else
        return
    end
    s.offset = 0
    Settings.Changed("windows")
    render(i)
end

function Windows.CycleMode(i, delta)
    local keys, current = modeKeys(), Windows.Mode(i)
    local at = 1
    for n, key in ipairs(keys) do
        if key == current then at = n end
    end
    Windows.SetMode(i, keys[(at - 1 + delta) % #keys + 1])
end

-- delta > 0 (wheel up) shows earlier rows.
function Windows.Scroll(i, delta)
    local f, s = frames[i], st(i)
    if not f then return end
    s.offset = math.max(0, math.min(s.offset - delta, (s.count or 0) - f.cfg.rows))
    render(i)
end

-- The global "locked" (options footer, minimap, /fcm lock) is true while
-- every window is locked.
local function syncGlobalLock()
    local all = true
    for i = 1, S("windowCount") do
        if not Windows.Config(i).locked then all = false end
    end
    ns.DB().locked = all or nil
end

function Windows.ToggleLock(i)
    write(i, { locked = not Windows.Config(i).locked })
    syncGlobalLock()
    layout(i)
    Settings.Changed("windows")
end

function Windows.Add()
    local n = S("windowCount")
    if n >= MAX_WINDOWS then return nil end
    -- A new window starts from its defaults, not from a closed one's leftovers.
    local all = ns.DB().windows
    if all then
        all[n + 1] = nil
        if not next(all) then ns.DB().windows = nil end
    end
    state[n + 1] = nil
    Settings.Set("windowCount", n + 1)
    return n + 1
end

function Windows.Close(i)
    local n = S("windowCount")
    if i <= 1 or i > n then return false end
    -- Later windows move up one place and keep where they are on screen.
    for j = i, n - 1 do
        local next_ = Windows.Config(j + 1)
        local all = ns.DB().windows
        if all then all[j] = nil end
        write(j, next_)
        state[j] = state[j + 1]
    end
    local all = ns.DB().windows
    if all then
        all[n] = nil
        if not next(all) then ns.DB().windows = nil end
    end
    state[n] = nil
    Settings.Set("windowCount", n - 1)
    return true
end

-- Picking a style in the options: COMPACT also takes the compact bar
-- height and spacing once (they stay editable); FOREVER the defaults.
function Windows.ApplyStylePreset(style)
    if style == "COMPACT" then
        Settings.SetMany({ style = "COMPACT", barHeight = 14, barSpacing = 0 })
    else
        local D = Settings.DEFAULTS
        Settings.SetMany({ style = "FOREVER", barHeight = D.barHeight, barSpacing = D.barSpacing })
    end
end

-- Render loop ------------------------------------------------------------------------

local function animate(f, elapsed)
    local step = math.min(1, elapsed * ANIM_RATE)
    for _, bar in ipairs(f.bars) do
        local target = bar.target
        if target and bar.current and bar:IsShown() then
            local c = bar.current
            local d = target - c
            if d == 0 then
                -- arrived
            elseif math.abs(d) <= (bar.maxValue or 1) * 0.001 then
                c = target
            else
                c = c + d * step
            end
            if c ~= bar.current then
                bar.current = c
                bar:SetValue(c)
            end
        end
    end
end

local function fade(f)
    local alpha = 1
    if f.cfg.locked and not f:IsMouseOver() then alpha = S("fadeAlpha") / 100 end
    if f:GetAlpha() ~= alpha then f:SetAlpha(alpha) end
end

-- Every frame: animation and fading; every `refresh` seconds: dirty windows,
-- threat windows and (for a few seconds after combat) all windows redraw.
function Windows.Tick(elapsed)
    local count = S("windowCount")
    for i = 1, count do
        local f = frames[i]
        if f and f:IsShown() then
            if S("animate") then animate(f, elapsed) end
            fade(f)
        end
    end
    burstLeft = burstLeft - elapsed
    tickWait = tickWait + elapsed
    if tickWait + 1e-9 < S("refresh") then return end
    tickWait = 0
    local burst, sample = burstLeft > 0, nil
    for i = 1, count do
        local f = frames[i]
        if f and f:IsShown() then
            local threat = Windows.Mode(i) == "threat"
            if threat or burst or st(i).dirty then
                if threat then sample = sample or sampleThreat() end
                render(i, sample)
            end
        end
    end
end

function Windows.Init()
    if ready then return end
    ready = true
    sync()
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, elapsed) Windows.Tick(elapsed) end)
    Windows.driver = driver
end

-- Events ----------------------------------------------------------------------------

ns.On("PLAYER_LOGIN", function() Windows.Init() end)
for _, event in ipairs({ "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED" }) do
    ns.On(event, markAll)
end
-- Amounts can stay secret for a moment after combat: redraw for a while.
ns.On("PLAYER_REGEN_ENABLED", function()
    burstLeft = AFTER_COMBAT
    markAll()
end)
-- Past fights are gone after a reset: those windows go back to current.
ns.On("DAMAGE_METER_RESET", function()
    for _, s in pairs(state) do
        s.pastView, s.offset = nil, 0
    end
    markAll()
end)

Settings.OnChange(function(key)
    if not ready or key == "minimapShow" or key == "minimapAngle" then return end
    if key == "windows" then
        markAll()
        return
    end
    if key == "locked" then
        local locked = S("locked") and true or false
        for i = 1, S("windowCount") do write(i, { locked = locked }) end
    end
    sync()
end)
