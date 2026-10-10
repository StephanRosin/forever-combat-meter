local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

-- Hides Blizzard's own damage meter by switching off its CVar
-- (damageMeterEnabled, Blizzard_DamageMeter/DamageMeter.lua). The frame
-- itself is never touched. The value from before is kept in the account
-- data and put back when the option goes off. While ours is on, a change of
-- the CVar from elsewhere (the user in Blizzard's settings) becomes the
-- value to restore.
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

function Blizzard.Apply()
    local value = current()
    if value == nil then return end   -- this client has no such switch
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

Settings.OnChange(function(key)
    if key == nil or key == "hideBlizzard" then Blizzard.Apply() end
end)

ns.On("CVAR_UPDATE", function(_, name, value)
    if writing or name ~= CVAR or not Settings.Get("hideBlizzard") then return end
    if tostring(value) == known then return end
    known = tostring(value)
    local store = ns.AccountDB()
    if store.blizzardMeterBackup ~= nil and value ~= nil then store.blizzardMeterBackup = tostring(value) end
end)

ns.On("PLAYER_LOGIN", function() Blizzard.Apply() end)
