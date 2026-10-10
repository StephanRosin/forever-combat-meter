local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

function ns.ToggleLock()
    Settings.SetLocked(not Settings.Get("locked"))
    ns.Print(Settings.Get("locked") and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

-- /fcm mode [window] <key>: a mode by its key (damage, healing, ..., threat).
local function setMode(args)
    local first, second = args[1], args[2]
    local index, key = 1, first
    if second then index, key = tonumber(first), second end
    key = key and key:lower()
    local known = false
    for _, k in ipairs(ns.Windows.ModeKeys()) do if k == key then known = true end end
    if not known or not index or index ~= math.floor(index) or index < 1 or index > Settings.Get("windowCount") then
        ns.Print(L.MSG_USAGE)
        return
    end
    ns.Windows.SetMode(index, key)
end

-- Opens or closes windows until there are n.
local function setWindows(n)
    local range = Settings.RANGES.windowCount
    if not n or n ~= math.floor(n) or n < range[1] or n > range[2] then
        ns.Print(L.MSG_USAGE)
        return
    end
    ns.Windows.SetCount(n)
end

-- /fcm report [n] [channel]: a given channel is stored as the last
-- chosen one; without one the stored channel is used.
local function report(args)
    local n, k = tonumber(args[1]), 1
    if n then k = 2 end
    local channel
    if args[k] then
        channel = ns.Report.ParseChannel(args[k])
        if not channel then
            ns.Print(L.MSG_USAGE)
            return
        end
        ns.Report.Choose(channel)
    end
    ns.Report.Window(1, n, channel)
end

local COMMANDS = {
    [""] = function() ns.Window.Toggle() end,
    lock = function() Settings.SetLocked(true); ns.Print(L.MSG_LOCKED) end,
    unlock = function() Settings.SetLocked(false); ns.Print(L.MSG_UNLOCKED) end,
    mode = setMode,
    windows = function(args) setWindows(tonumber(args[1])) end,
    report = report,
    reset = function() ns.Windows.AskReset() end,
    debug = function(args)
        if args[1] == "icon" then ns.Print(ns.Windows.IconDebug()) else ns.Print(L.MSG_USAGE) end
    end,
    toggle = function()
        ns.Print(ns.Windows.ToggleHidden() and L.MSG_WINDOWS_SHOWN or L.MSG_WINDOWS_HIDDEN)
    end,
}

SLASH_FOREVERCOMBATMETER1 = "/fcm"
SLASH_FOREVERCOMBATMETER2 = "/forevercombatmeter"
SlashCmdList["FOREVERCOMBATMETER"] = function(msg)
    local words = {}
    for word in (msg or ""):gmatch("%S+") do words[#words + 1] = word end
    local run = COMMANDS[(words[1] or ""):lower()]
    if not run then
        ns.Print(L.MSG_USAGE)
        return
    end
    run({ unpack(words, 2) })
end
