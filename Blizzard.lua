local ADDON, ns = ...
local Settings = ns.Settings

-- Hides Blizzard's own damage meter by switching off its CVar
-- (damageMeterEnabled, Blizzard_DamageMeter/DamageMeter.lua). The frame
-- itself is never touched. The value from before is kept in the account
-- data and put back when the option goes off.
local Blizzard = {}
ns.Blizzard = Blizzard

local CVAR = "damageMeterEnabled"

local function current()
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    return C_CVar.GetCVar(CVAR)
end

function Blizzard.Apply()
    local value = current()
    if value == nil then return end   -- this client has no such switch
    local store = ns.AccountDB()
    if Settings.Get("hideBlizzard") then
        if store.blizzardMeterBackup == nil then store.blizzardMeterBackup = value end
        if value ~= "0" then C_CVar.SetCVar(CVAR, "0") end
    elseif store.blizzardMeterBackup ~= nil then
        local backup = store.blizzardMeterBackup
        store.blizzardMeterBackup = nil
        if value ~= backup then C_CVar.SetCVar(CVAR, backup) end
    end
end

Settings.OnChange(function(key)
    if key == nil or key == "hideBlizzard" then Blizzard.Apply() end
end)

ns.On("PLAYER_LOGIN", function() Blizzard.Apply() end)
