-- A mock of the WoW API, just enough for Forever Combat Meter. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, timers = {}, fontStrings = {}, popups = {}, registered = {},
            calls = {}, menus = {} }

local function record(name, ...) M.calls[#M.calls + 1] = { name, ... } end
M.record = record

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name, kind)
    local w = setmetatable({ _name = name, _kind = kind, _scripts = {}, _events = {},
                             _w = 0, _h = 0, _shown = true, _attr = {}, _alpha = 1, _scale = 1 }, widget)
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end return fn(...) end
    end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:SetTextColor(r, g, b) self._textColor = { r, g, b } end
    function w:GetTextColor() local c = self._textColor or { 1, 1, 1 }; return c[1], c[2], c[3], 1 end
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:GetSize() return self._w, self._h end
    function w:Hide() self._shown = false end
    function w:Show() self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible()
        local f = self
        while f do
            if not f._shown then return false end
            f = f._parent
        end
        return true
    end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:GetFrameLevel() return self._level or 3 end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetEnabled(on) self._enabled = on and true or false end
    function w:IsEnabled() return self._enabled ~= false end
    function w:SetFrameLevel(v) self._level = v end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetEffectiveScale() return self._scale or 1 end
    function w:SetMovable(v) self._movable = v end
    function w:IsMovable() return self._movable end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:RegisterForDrag(...) self._drag = select("#", ...) > 0 end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:RegisterEvent(e)
        if M.validEvents and not M.validEvents[e] then error("unknown event " .. e) end
        self._events[e] = true
    end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._points = self._points or {}
        self._points[p] = { rel, p2, x, y }
        self._lastPoint = { p, rel, p2, x, y }
    end
    function w:ClearAllPoints() self._points = {} end
    function w:GetNumPoints() local n = 0; for _ in pairs(self._points or {}) do n = n + 1 end; return n end
    function w:GetPoint() local a = self._lastPoint; if a then return a[1], a[2], a[3], a[4], a[5] end end
    -- Screen rectangle: tests set _rect = { left, bottom, width, height }.
    function w:GetCenter()
        if not self._rect then return nil end
        return self._rect[1] + self._rect[3] / 2, self._rect[2] + self._rect[4] / 2
    end
    function w:GetLeft() return self._rect and self._rect[1] end
    function w:GetBottom() return self._rect and self._rect[2] end
    function w:GetRight() return self._rect and (self._rect[1] + self._rect[3]) end
    function w:GetTop() return self._rect and (self._rect[2] + self._rect[4]) end
    function w:SetColorTexture(r, g, b, a) self._texColor = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function w:SetTexture(t) self._texture = t end
    function w:GetTexture() return self._texture end
    function w:SetAtlas(a) self._atlas = a end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:AddMaskTexture(m) self._masks = (self._masks or 0) + 1 end
    function w:RemoveMaskTexture(m) self._masks = (self._masks or 1) - 1 end
    function w:CreateMaskTexture() return newWidget(nil, "MaskTexture") end
    function w:CreateTexture()
        local t = newWidget(nil, "Texture")
        t._parent = self
        return t
    end
    function w:StartMoving() self._moving = true end
    function w:StopMovingOrSizing() self._moving = false end
    function w:SetVerticalScroll(v) self._scroll = v end
    function w:GetVerticalScroll() return self._scroll or 0 end
    function w:GetVerticalScrollRange() return 0 end
    function w:SetScrollChild(c) self._child = c end
    function w:CreateFontString(_, _, template)
        local fs = newWidget(nil, "FontString")
        fs._parent = self
        -- As in the game: without a template a font string has no font until
        -- SetFont / SetFontObject, and SetText then raises "Font not set".
        if template then fs._font = { "Fonts\\FRIZQT__.TTF", 12, "" } end
        function fs:SetText(t)
            if not self._font then error("FontString:SetText(): Font not set") end
            self._text = t
        end
        function fs:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
        function fs:GetFont() if self._font then return self._font[1], self._font[2], self._font[3] end end
        function fs:SetFont(p, s, f) self._font = { p, s, f }; return true end
        function fs:SetFontObject() end
        function fs:GetStringWidth() return #(tostring(self._text or "")) * 6 end
        -- Wraps at the set width: one line per (width / 6) characters.
        function fs:GetStringHeight()
            local text = tostring(self._text or "")
            local perLine = (self._w and self._w > 0) and math.max(1, math.floor(self._w / 6)) or math.huge
            local n = math.max(1, math.ceil(#text / perLine))
            if self._maxLines and self._maxLines > 0 then n = math.min(n, self._maxLines) end
            return n * self._font[2]
        end
        function fs:SetMaxLines(n) self._maxLines = n end
        function fs:SetShadowOffset(x, y) self._shadow = { x, y } end
        function fs:GetShadowOffset() return (self._shadow or { 0, 0 })[1], (self._shadow or { 0, 0 })[2] end
        function fs:GetShadowColor() return 0, 0, 0, 1 end
        function fs:GetFontObject() return self._fontObject end
        M.fontStrings[#M.fontStrings + 1] = fs
        return fs
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    local f = newWidget(name, kind)
    f._parent, f._template = parent, template
    M.frames[#M.frames + 1] = f
    if name then M.byName[name] = f; _G[name] = f end
    if template == "SecureActionButtonTemplate" then f._secure = true end
    if template == "CooldownFrameTemplate" then
        function f:SetCooldown(s, d) self._cooldown = { s, d } end
        function f:Clear() self._cooldown = nil end
    end
    return f
end

-- Delivers an event to every frame that registered it, in creation order.
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function M.RunTimers()
    for _ = 1, 5 do
        local list = M.timers
        M.timers = {}
        for _, fn in ipairs(list) do fn() end
        if #M.timers == 0 then return end
    end
end

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
UIParent._rect = { 0, 0, 1920, 1080 }
Minimap = newWidget("Minimap")
Minimap._w, Minimap._h = 260, 260
Minimap._rect = { 1652, 767, 260, 260 }
function Minimap:GetCenter() return 1782, 897 end
GameTooltip = newWidget("GameTooltip")
function GameTooltip:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function GameTooltip:SetOwner() self._lines = {} end
function GameTooltip:IsOwned() return true end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
InterfaceOptions_AddCategory = function(panel) M.registered[#M.registered + 1] = panel.name end
PixelUtil = { GetNearestPixelSize = function(v) return v end, GetPixelToUIUnitFactor = function() return 1 end }
Enum = { UITextureSliceMode = { Stretched = 1 }, SpellBookSpellBank = { Player = 0 } }

M.locale = "enUS"
function GetLocale() return M.locale end
M.build = { "1.60.1", "70205", "Oct 2 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
M.state = { combat = false, money = 500, instance = nil, zone = "Stranglethorn Vale", ctrl = false, modified = {} }
function InCombatLockdown() return M.state.combat end
function IsControlKeyDown() return M.state.ctrl end
function IsModifiedClick(what) return M.state.modified[what] or false end
function IsInGroup() return M.state.group or false end
function GetMoney() return M.state.money end
function GetMoneyString(v) return v .. "c" end
function GetRealZoneText() return M.state.zone end
function GetCursorPosition() return M.state.cursorX or 0, M.state.cursorY or 0 end
function IsInInstance()
    if M.state.instance then return true, M.state.instance.kind end
    return false, "none"
end
function GetInstanceInfo() return M.state.instance and M.state.instance.name or "" end


-- Secret values ---------------------------------------------------------------
-- In combat the client hands addons "secret" names, GUIDs and amounts. Tainted
-- code may display them (SetText, string.format %s/%.Nf, AbbreviateLargeNumbers)
-- but must not compare, compute with, concatenate, index or %d-format them.
-- A secret here is a userdata (newproxy) sharing one metatable whose every
-- operator raises; the wrapped value lives in a weak side table. Mixed-type
-- comparisons (secret < 5) and arithmetic raise natively in Lua 5.1; the
-- metamethods catch secret-vs-secret and the rest.
local secretRaw = setmetatable({}, { __mode = "k" })
local secretProto = newproxy(true)
local secretMeta = getmetatable(secretProto)
local function forbid(what) return function() error("secret value: " .. what .. " is not allowed", 2) end end
for _, op in ipairs({ "lt", "le", "eq", "add", "sub", "mul", "div", "mod", "pow", "unm", "concat", "len",
    "index", "newindex", "call" }) do
    secretMeta["__" .. op] = forbid(op)
end
secretMeta.__tostring = function(u) return "<secret " .. tostring(secretRaw[u]) .. ">" end

function M.Secret(v)
    local u = newproxy(secretProto)
    secretRaw[u] = { v }
    return u
end
function M.IsSecret(v) return type(v) == "userdata" and secretRaw[v] ~= nil end
-- The plain value behind a secret (tests only; the addon never can).
function M.Reveal(v)
    if M.IsSecret(v) then return secretRaw[v][1] end
    return v
end
issecretvalue = M.IsSecret

-- Secrets may never become table keys (the client raises). Lua cannot trap a
-- key assignment, so tests walk everything the addon keeps and returns.
function M.FindSecretKey(root)
    local seen = {}
    local function walk(t, path)
        if seen[t] then return nil end
        seen[t] = true
        for k, v in pairs(t) do
            if M.IsSecret(k) then return path .. "[<secret>]" end
            if type(v) == "table" then
                local hit = walk(v, path .. "." .. tostring(k))
                if hit then return hit end
            end
        end
    end
    return walk(root, "root")
end

-- string.format as the client does it: a secret argument is fine for %s and
-- %f (with a precision), anything else raises; the result is itself secret.
local plainFormat = string.format
string.format = function(fmt, ...)
    local args, n, anySecret = { ... }, select("#", ...), false
    for i = 1, n do if M.IsSecret(args[i]) then anySecret = true end end
    if not anySecret then return plainFormat(fmt, ...) end
    if M.IsSecret(fmt) then error("secret value used as a format string", 2) end
    local i, pos = 0, 1
    while true do
        local s, e, spec, conv = fmt:find("%%([-+ #0]*%d*%.?%d*)(%a)", pos)
        local pct = fmt:find("%%%%", pos)
        if pct and (not s or pct < s) then
            pos = pct + 2
        elseif not s then
            break
        else
            i = i + 1
            if M.IsSecret(args[i]) then
                local ok = conv == "s" or (conv == "f" and spec:find("%.%d") ~= nil)
                if not ok then error("secret value with %" .. spec .. conv .. " in string.format", 2) end
                args[i] = secretRaw[args[i]][1]
            end
            pos = e + 1
        end
    end
    return M.Secret(plainFormat(fmt, unpack(args, 1, n)))
end

-- Simplified client abbreviation; accepts secrets and then returns a secret.
function AbbreviateLargeNumbers(v)
    if M.IsSecret(v) then return M.Secret(AbbreviateLargeNumbers(secretRaw[v][1])) end
    if v >= 1e6 then return plainFormat("%.1fM", v / 1e6) end
    if v >= 1e4 then return plainFormat("%.0fK", v / 1e3) end
    return plainFormat("%.0f", v)
end

-- C_DamageMeter -----------------------------------------------------------------
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5,
    Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }

-- Tests fill M.dm: byType[sessionType][meterType] and byID[sessionID][meterType]
-- hold sessions { combatSources = { {..., spells = {...}} }, totalAmount, durationSeconds };
-- sessions is GetAvailableCombatSessions(); duration[sessionType] GetSessionDurationSeconds.
M.dm = { available = true, reason = "", byType = {}, byID = {}, sessions = {}, duration = {}, resets = 0 }
-- Fields SecretWhenInCombat makes secret (NeverSecret ones stay plain).
local SECRET_FIELDS = { sourceGUID = true, sourceCreatureID = true, name = true, totalAmount = true,
    amountPerSecond = true, deathTimeSeconds = true, maxAmount = true, durationSeconds = true, spellID = true,
    creatureName = true }

local function copy(t, secret)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = copy(v, secret)
        elseif secret and SECRET_FIELDS[k] then
            out[k] = M.Secret(v)
        else
            out[k] = v
        end
    end
    return out
end

local function noSecretArgs(...)
    for i = 1, select("#", ...) do
        if M.IsSecret((select(i, ...))) then error("secret value passed to a C_DamageMeter function", 3) end
    end
end

local function sessionOf(store, key, meterType)
    local s = store[key] and store[key][meterType]
    if not s then return { combatSources = {}, maxAmount = 0, totalAmount = 0 } end
    local out = copy(s, M.state.combat)
    for _, src in ipairs(out.combatSources or {}) do src.spells = nil end
    return out
end

local function sourceOf(store, key, meterType, guid, creatureID)
    local s = store[key] and store[key][meterType]
    for _, src in ipairs(s and s.combatSources or {}) do
        if (guid ~= nil and src.sourceGUID == guid) or (guid == nil and creatureID ~= nil and src.sourceCreatureID == creatureID) then
            return copy({ combatSpells = src.spells or {}, totalAmount = src.totalAmount, maxAmount = 0 }, M.state.combat)
        end
    end
    return { combatSpells = {}, maxAmount = 0, totalAmount = 0 }
end

C_DamageMeter = {
    IsDamageMeterAvailable = function() return M.dm.available, M.dm.reason end,
    GetAvailableCombatSessions = function()
        local out = {}
        for i, s in ipairs(M.dm.sessions) do
            out[i] = { sessionID = s.sessionID, durationSeconds = s.durationSeconds,
                       name = (M.state.combat and s.secretName) and M.Secret(s.name) or s.name }
        end
        return out
    end,
    GetCombatSessionFromType = function(st, t) noSecretArgs(st, t); return sessionOf(M.dm.byType, st, t) end,
    GetCombatSessionFromID = function(id, t) noSecretArgs(id, t); return sessionOf(M.dm.byID, id, t) end,
    GetCombatSessionSourceFromType = function(st, t, guid, cid)
        noSecretArgs(st, t, guid, cid)
        return sourceOf(M.dm.byType, st, t, guid, cid)
    end,
    GetCombatSessionSourceFromID = function(id, t, guid, cid)
        noSecretArgs(id, t, guid, cid)
        return sourceOf(M.dm.byID, id, t, guid, cid)
    end,
    GetSessionDurationSeconds = function(st) return M.dm.duration[st] end,
    ResetAllCombatSessions = function() M.dm.resets = M.dm.resets + 1 end,
}

-- C_DeathRecap: M.recaps[id] = events, newest (the killing blow) first, as the
-- client returns them. In combat amounts, health, names and times are secret.
M.recaps = {}
local RECAP_SECRET = { amount = true, currentHP = true, sourceName = true, timestamp = true }
C_DeathRecap = {
    HasRecapEvents = function(id) return M.recaps[id] ~= nil and #M.recaps[id] > 0 end,
    GetRecapEvents = function(id)
        local out = {}
        for i, e in ipairs(M.recaps[id] or {}) do
            out[i] = {}
            for k, v in pairs(e) do out[i][k] = (M.state.combat and RECAP_SECRET[k]) and M.Secret(v) or v end
        end
        return out
    end,
}

-- C_Spell accepts secret IDs (AllowedWhenTainted) and then answers in secret.
M.spells = { [88163] = { "Attack", 132223 } }
C_Spell = {
    GetSpellName = function(id)
        if M.IsSecret(id) then
            local s = M.spells[secretRaw[id][1]]
            return s and M.Secret(s[1])
        end
        return M.spells[id] and M.spells[id][1]
    end,
    GetSpellTexture = function(id)
        if M.IsSecret(id) then
            local s = M.spells[secretRaw[id][1]]
            return s and M.Secret(s[2])
        end
        return M.spells[id] and M.spells[id][2]
    end,
}
ACTION_SWING = "Melee"
ACTION_ENVIRONMENTAL_DAMAGE_FALLING = "Falling"
M.state.playerGUID = "Player-1-0001"
function UnitGUID(unit) if unit == "player" then return M.state.playerGUID end end


return M
