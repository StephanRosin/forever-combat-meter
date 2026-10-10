local ADDON, ns = ...

-- Threat list for the current target and the warning when the player is about
-- to pull it.
--
-- UnitDetailedThreatSituation is secret when the client restricts threat
-- values (boss targets in combat): every return, isTanking and status
-- included. Each unit's results are checked with issecretvalue before any
-- compare or arithmetic; one secret result marks the whole list unavailable.

local Threat = {}
ns.Threat = Threat

local issecret = issecretvalue or function() return false end

local MIN_INTERVAL = 0.2 -- samples closer together reuse the last rate
local DEFAULT_SOUND = 8959

local samples = {} -- unit -> { value, time, rate }
local armed = true -- the sound has not played for this target yet

-- Forgets the per-second history (roster change).
local function clearSamples()
    samples = {}
end

-- Target change: forgets the history and re-arms the warning sound.
function Threat.Reset()
    clearSamples()
    armed = true
end

ns.On("PLAYER_TARGET_CHANGED", Threat.Reset)
ns.On("GROUP_ROSTER_UPDATE", clearSamples)

-- Group member tokens (and pets when wanted), the player first in a party.
local function groupUnits()
    local units = {}
    local pets = ns.Settings.Get("showPets")
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
            if pets then units[#units + 1] = "raidpet" .. i end
        end
    else
        units[1] = "player"
        if pets then units[2] = "pet" end
        for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
            units[#units + 1] = "party" .. i
            if pets then units[#units + 1] = "partypet" .. i end
        end
    end
    return units
end

-- Per second from the change since the last sample of this unit.
local function rateFor(unit, value, now)
    local last = samples[unit]
    if not last then
        samples[unit] = { value = value, time = now, rate = 0 }
        return 0
    end
    local dt = now - last.time
    if dt >= MIN_INTERVAL then
        local rate = (value - last.value) / dt
        last.value, last.time = value, now
        last.rate = rate > 0 and rate or 0
    end
    return last.rate
end

local function classOf(unit)
    local _, file = UnitClass(unit)
    return file
end

-- Returns rows, or nil when a value was secret.
local function collect()
    local now = GetTime()
    local rows = {}
    for _, unit in ipairs(groupUnits()) do
        if UnitExists(unit) then
            local tanking, status, scaled, raw, value = UnitDetailedThreatSituation(unit, "target")
            if issecret(tanking) or issecret(status) or issecret(scaled) or issecret(raw) or issecret(value) then
                return nil
            end
            if status ~= nil then
                rows[#rows + 1] = {
                    name = UnitName(unit),
                    class = classOf(unit),
                    unit = unit,
                    pct = tanking and 100 or raw or scaled or 0,
                    perSecond = rateFor(unit, value or 0, now),
                    tanking = tanking and true or false,
                    isPlayer = UnitIsUnit(unit, "player") and true or false,
                }
            end
        end
    end
    return rows
end

local function order(a, b)
    if a.tanking ~= b.tanking then return a.tanking end
    if a.pct ~= b.pct then return a.pct > b.pct end
    return tostring(a.name) < tostring(b.name)
end

function Threat.List()
    if not (UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")) then
        return { unavailable = false, rows = {} }
    end
    local ok, rows = pcall(collect)
    if not ok or not rows then return { unavailable = true, rows = {} } end
    table.sort(rows, order)
    return { unavailable = false, rows = rows }
end

-- True while the player is at or above the warning threshold without holding
-- the target; plays the sound once per target. `list` may be passed in when
-- the caller has just built it.
function Threat.CheckWarning(list)
    if not ns.Settings.Get("threatWarn") then return false end
    list = list or Threat.List()
    if list.unavailable then return false end
    for _, row in ipairs(list.rows) do
        if row.isPlayer and not row.unit:find("pet", 1, true) then
            if row.tanking or row.pct < ns.Settings.Get("threatWarnPct") then return false end
            if armed then
                armed = false
                if ns.Settings.Get("threatSound") then
                    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or DEFAULT_SOUND, "Master")
                end
            end
            return true
        end
    end
    return false
end
