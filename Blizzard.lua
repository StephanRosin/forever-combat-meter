local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

-- Hides Blizzard's own damage meter by switching off its CVar
-- (damageMeterEnabled, Blizzard_DamageMeter/DamageMeter.lua). The frame
-- itself is never touched. The value from before is kept in the account
-- data and put back when the option goes off. While ours is on, a change of
-- the CVar from elsewhere (the user in Blizzard's settings) becomes the
-- value to restore.
--
-- Combat: Blizzard's meter is an Edit Mode system frame that reacts to the
-- CVar inside the SetCVar call (CVAR_UPDATE is synchronous). A write from
-- addon code in combat would run that reaction tainted, so every write goes
-- through ns.AfterCombat; the CVAR_UPDATE handler only records the value.
local Blizzard = {}
ns.Blizzard = Blizzard

local CVAR = "damageMeterEnabled"
local writing, noted = false, false
local known   -- the value we last saw or wrote; an event with it is our own echo

local function current()
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    return C_CVar.GetCVar(CVAR)
end

-- True when the client took the value.
local function write(value)
    writing = true
    local ok, result = pcall(C_CVar.SetCVar, CVAR, value)
    writing = false
    if ok and result ~= false then known = value; return true end
    if not noted then
        noted = true
        ns.Print(L.MSG_BLIZZARD_FAILED)
    end
    return false
end

local function apply()
    local value = current()
    if value == nil then return end   -- plain: a CVar; nil: this client has no such switch
    known = value
    local store = ns.AccountDB()
    if Settings.Get("hideBlizzard") then
        if store.blizzardMeterBackup == nil then store.blizzardMeterBackup = value end
        if value ~= "0" then write("0") end
    elseif store.blizzardMeterBackup ~= nil then
        local backup = store.blizzardMeterBackup
        if value == backup or write(backup) then store.blizzardMeterBackup = nil end
    end
end

-- Login, the option, a profile switch: now, or once combat has ended.
function Blizzard.Apply()
    ns.AfterCombat("blizzard", apply)
end

Settings.OnChange(function(key)
    if key == nil or key == "hideBlizzard" then Blizzard.Apply() end
end)

-- Records the value only: no write, no call into the UI.
ns.On("CVAR_UPDATE", function(_, name, value)
    if writing or name ~= CVAR or value == nil or not Settings.Get("hideBlizzard") then return end   -- plain: a CVar
    value = tostring(value)
    if value == known then return end
    known = value
    local store = ns.AccountDB()
    if store.blizzardMeterBackup ~= nil then store.blizzardMeterBackup = value end
end)

ns.On("PLAYER_LOGIN", function() Blizzard.Apply() end)
