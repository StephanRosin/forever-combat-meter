local ADDON, ns = ...

-- The only reader of C_DamageMeter and C_DeathRecap. It turns the client's
-- sessions into plain Lua tables for the UI.
--
-- Secret values: in combat the session getters return secret names, GUIDs
-- and amounts (classFilename, specIconID, isLocalPlayer and deathRecapID stay
-- readable). This file never compares, computes with, concatenates or keys a
-- table by a value before checking IsSecret. With secret amounts the rows keep
-- the API's order and carry no percent; the UI formats them through Format.

local Meter = {}
ns.Meter = Meter

local issecret = issecretvalue or function() return false end
local sort = table.sort

local RECAP_LINES = 6
local MELEE_SPELL = 88163
local UNKNOWN_ICON = 134400 -- INV_Misc_QuestionMark

-- Mode key -> Enum.DamageMeterType field, in menu order. The Dps/Hps types are
-- not needed: every source carries amountPerSecond.
local MODE_ENUMS = {
    { "damage", "DamageDone" },
    { "healing", "HealingDone" },
    { "absorbs", "Absorbs" },
    { "taken", "DamageTaken" },
    { "enemytaken", "EnemyDamageTaken" },
    { "avoidable", "AvoidableDamageTaken" },
    { "interrupts", "Interrupts" },
    { "dispels", "Dispels" },
    { "deaths", "Deaths" },
}

-- Only the modes whose enum value this client knows.
function Meter.BuildModes(enum)
    local list = {}
    if not enum then return list end
    for _, pair in ipairs(MODE_ENUMS) do
        local value = enum[pair[2]]
        if value ~= nil then list[#list + 1] = { key = pair[1], type = value } end
    end
    return list
end

Meter.MODES = Meter.BuildModes(Enum and Enum.DamageMeterType)

function Meter.ModeType(key)
    for _, mode in ipairs(Meter.MODES) do
        if mode.key == key then return mode.type end
    end
end

local function api() return C_DamageMeter end

local function sessionTypes()
    local e = Enum and Enum.DamageMeterSessionType or {}
    return { current = e.Current or 1, overall = e.Overall or 0 }
end

-- A readable, positive number (plain and > 0).
local function positive(v)
    return not issecret(v) and type(v) == "number" and v > 0
end

-- A value that is there: secret counts as present without being touched.
local function present(v)
    return issecret(v) or v ~= nil
end

function Meter.Available()
    local dm = api()
    if not dm or not dm.IsDamageMeterAvailable then return false, "" end
    local ok, available, reason = pcall(dm.IsDamageMeterAvailable)
    if not ok then return false, "" end
    return available and true or false, reason or ""
end

-- Past fights { id, name, duration }; name may be secret (instance creatures).
function Meter.Sessions()
    local dm = api()
    local list = {}
    if not dm or not dm.GetAvailableCombatSessions then return list end
    local ok, sessions = pcall(dm.GetAvailableCombatSessions)
    if not ok or type(sessions) ~= "table" then return list end
    for _, s in ipairs(sessions) do
        list[#list + 1] = { id = s.sessionID, name = s.name, duration = s.durationSeconds }
    end
    return list
end

function Meter.Reset()
    local dm = api()
    if dm and dm.ResetAllCombatSessions then pcall(dm.ResetAllCombatSessions) end
end

-- The session table for a view: "current", "overall" or a session ID.
local function readSession(meterType, view)
    local dm = api()
    if not dm then return nil end
    local st = sessionTypes()[view]
    local ok, session
    if st then
        ok, session = pcall(dm.GetCombatSessionFromType, st, meterType)
    elseif type(view) == "number" then
        ok, session = pcall(dm.GetCombatSessionFromID, view, meterType)
    end
    if ok and type(session) == "table" then return session end
end

local function readSource(meterType, view, guid, creatureID)
    local dm = api()
    if not dm then return nil end
    local st = sessionTypes()[view]
    local ok, source
    if st then
        ok, source = pcall(dm.GetCombatSessionSourceFromType, st, meterType, guid, creatureID)
    elseif type(view) == "number" then
        ok, source = pcall(dm.GetCombatSessionSourceFromID, view, meterType, guid, creatureID)
    end
    if ok and type(source) == "table" then return source end
end

-- Session length: the session's own field, else the client's per-type timer,
-- else (past fights) the length from the session list. May be secret or nil.
local function sessionDuration(session, view)
    local d = session and session.durationSeconds
    if present(d) then return d end
    local dm = api()
    local st = sessionTypes()[view]
    if st and dm and dm.GetSessionDurationSeconds then
        local ok, value = pcall(dm.GetSessionDurationSeconds, st)
        if ok then return value end
    elseif type(view) == "number" then
        for _, s in ipairs(Meter.Sessions()) do
            if not issecret(s.id) and s.id == view then return s.duration end
        end
    end
end

-- The rate the API gives; out of combat total / duration when it says 0.
local function perSecond(entry, duration, secret)
    local ps = entry.amountPerSecond
    if secret then return ps end
    ps = ps or 0
    if ps == 0 and positive(entry.totalAmount) and positive(duration) then
        return entry.totalAmount / duration
    end
    return ps
end

-- The denominator for percentages: the API total, or the sum of the rows.
local function grandTotal(apiTotal, rows)
    if positive(apiTotal) then return apiTotal end
    local sum = 0
    for _, r in ipairs(rows) do sum = sum + (r.total or 0) end
    return sum
end

local function byTotal(a, b) return (a.total or 0) > (b.total or 0) end

-- An ID worth keeping: readable and not the client's 0 / -1 for "none".
local function idOrNil(v)
    if issecret(v) or v == nil or v == 0 or v == -1 then return nil end
    return v
end

local function plainOrNil(v)
    if issecret(v) then return nil end
    return v
end

function Meter.Fetch(modeKey, view)
    local meterType = Meter.ModeType(modeKey)
    if meterType == nil then return nil end
    local session = readSession(meterType, view)
    if not session then return { secret = false, total = 0, rows = {} } end
    local sources = session.combatSources or {}
    local first = sources[1]
    local secret = issecret(session.totalAmount) or (first ~= nil and issecret(first.totalAmount))
    local duration = sessionDuration(session, view)
    local rows = {}
    for i, s in ipairs(sources) do
        local deathTime = s.deathTimeSeconds
        if not issecret(deathTime) and deathTime == -1 then deathTime = nil end
        rows[i] = {
            name = s.name,
            class = s.classFilename,
            specIcon = s.specIconID,
            total = s.totalAmount,
            perSecond = perSecond(s, duration, secret),
            isPlayer = s.isLocalPlayer and true or false,
            guid = plainOrNil(s.sourceGUID),
            creatureID = plainOrNil(s.sourceCreatureID),
            recapID = idOrNil(s.deathRecapID),
            deathTime = deathTime,
        }
    end
    local total = session.totalAmount
    if not secret then
        total = grandTotal(total, rows)
        sort(rows, byTotal)
        for _, r in ipairs(rows) do
            r.percent = total > 0 and (r.total or 0) / total * 100 or 0
        end
    end
    return { secret = secret, total = total, duration = duration, rows = rows }
end

local function spellName(id)
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
    if not present(name) and GetSpellInfo and not issecret(id) then name = GetSpellInfo(id) end
    if not present(name) then name = string.format("#%s", id) end
    return name
end

local function spellIcon(id)
    local icon
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(id) end
    if not present(icon) then icon = UNKNOWN_ICON end
    return icon
end

-- A readable, non-empty creature name for "Spell · Creature".
local function creatureOf(spell)
    local c = spell.creatureName
    if issecret(c) or type(c) ~= "string" or c == "" then return nil end
    return c
end

-- The source's spells. Others' GUIDs are secret in combat; the own row is
-- asked for by UnitGUID("player"). nil when the source cannot be addressed.
function Meter.Spells(modeKey, view, row)
    local meterType = Meter.ModeType(modeKey)
    if meterType == nil or not row then return nil end
    local guid, creatureID = row.guid, row.creatureID
    if guid == nil and row.isPlayer and UnitGUID then guid = UnitGUID("player") end
    if issecret(guid) then guid = nil end
    if issecret(creatureID) then creatureID = nil end
    if guid == nil and creatureID == nil then return nil end
    local source = readSource(meterType, view, guid, creatureID)
    if not source then return nil end
    local spells = source.combatSpells or {}
    local first = spells[1]
    local secret = issecret(source.totalAmount) or (first ~= nil and issecret(first.totalAmount))
    local duration = not secret and sessionDuration(readSession(meterType, view), view) or nil
    local rows = {}
    for i, sp in ipairs(spells) do
        rows[i] = {
            spellID = sp.spellID,
            name = spellName(sp.spellID),
            icon = spellIcon(sp.spellID),
            total = sp.totalAmount,
            perSecond = perSecond(sp, duration, secret),
            creature = creatureOf(sp),
        }
    end
    if not secret then
        local total = grandTotal(source.totalAmount, rows)
        sort(rows, byTotal)
        for _, r in ipairs(rows) do
            r.percentOfSource = total > 0 and (r.total or 0) / total * 100 or 0
        end
    end
    return { secret = secret, rows = rows }
end

-- Name and icon of one recap event (melee and environment have no spell).
local function recapSpell(e)
    local event = e.event
    if not issecret(event) and event == "SWING_DAMAGE" then
        local name = spellName(MELEE_SPELL)
        if ACTION_SWING then name = ACTION_SWING end
        return name, spellIcon(MELEE_SPELL)
    end
    if not issecret(event) and event == "ENVIRONMENTAL_DAMAGE" then
        local env = e.environmentalType
        if issecret(env) or type(env) ~= "string" then return env, UNKNOWN_ICON end
        return _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. env:upper()] or env, UNKNOWN_ICON
    end
    local id = e.spellId
    local name = e.spellName
    if not present(id) then
        if not present(name) then name = "?" end
        return name, UNKNOWN_ICON
    end
    if not present(name) then name = spellName(id) end
    return name, spellIcon(id)
end

-- The client lists recap events newest (the killing blow) first. Returns the
-- last RECAP_LINES events oldest -> newest; time is seconds before death.
local function chronological(events)
    local readable = true
    for _, e in ipairs(events) do
        if issecret(e.timestamp) or type(e.timestamp) ~= "number" then readable = false end
    end
    local list = {}
    for i = #events, 1, -1 do list[#list + 1] = { e = events[i], n = #list + 1 } end
    if readable then
        sort(list, function(a, b)
            if a.e.timestamp ~= b.e.timestamp then return a.e.timestamp < b.e.timestamp end
            return a.n < b.n
        end)
    end
    return list, readable
end

function Meter.Recap(recapID)
    if issecret(recapID) or recapID == nil or recapID == 0 or recapID == -1 then return nil end
    local dr = C_DeathRecap
    if not dr or not dr.GetRecapEvents then return nil end
    if dr.HasRecapEvents then
        local ok, has = pcall(dr.HasRecapEvents, recapID)
        if not ok or not has then return nil end
    end
    local ok, events = pcall(dr.GetRecapEvents, recapID)
    if not ok or type(events) ~= "table" or #events == 0 then return nil end
    local list, readable = chronological(events)
    local last = readable and list[#list].e.timestamp or nil
    local out = { secret = false }
    for i = math.max(1, #list - RECAP_LINES + 1), #list do
        local e = list[i].e
        local spell, icon = recapSpell(e)
        if issecret(e.amount) or issecret(e.currentHP) then out.secret = true end
        out[#out + 1] = {
            time = last and (e.timestamp - last) or nil,
            spell = spell,
            icon = icon,
            source = e.sourceName,
            amount = e.amount,
            hp = e.currentHP,
        }
    end
    return out
end
