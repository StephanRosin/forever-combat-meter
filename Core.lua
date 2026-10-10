local ADDON, ns = ...
local L = ns.L

-- Small shared helpers: chat output, an event hub, combat deferral.

function ns.Print(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cff66ccff" .. L.ADDON_NAME .. "|r: " .. msg) end
end

-- fn(event, ...) per event. RegisterEvent throws on a name the client does
-- not know, which would stop the rest of the file: pcall it.
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end)

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(events.RegisterEvent, events, event)
    end
    table.insert(handlers[event], fn)
end

-- Runs fn now, or once combat ends when it touches secure frames.
local afterCombat = {}
function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    afterCombat[key] = fn
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local pending = afterCombat
    afterCombat = {}
    for _, fn in pairs(pending) do fn() end
end)

function ns.PendingAfterCombat()
    local n = 0
    for _ in pairs(afterCombat) do n = n + 1 end
    return n
end
