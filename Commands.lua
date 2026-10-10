local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

function ns.ToggleLock()
    Settings.SetLocked(not Settings.Get("locked"))
    ns.Print(Settings.Get("locked") and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

SLASH_FOREVERCOMBATMETER1 = "/fcm"
SLASH_FOREVERCOMBATMETER2 = "/forevercombatmeter"
SlashCmdList["FOREVERCOMBATMETER"] = function(msg)
    local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
    if cmd == "" then
        ns.Window.Toggle()
    elseif cmd == "lock" then
        Settings.SetLocked(true)
        ns.Print(L.MSG_LOCKED)
    elseif cmd == "unlock" then
        Settings.SetLocked(false)
        ns.Print(L.MSG_UNLOCKED)
    else
        ns.Print(L.MSG_USAGE)
    end
end
