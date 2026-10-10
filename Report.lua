local ADDON, ns = ...
local L, Settings, Meter, Format, Windows = ns.L, ns.Settings, ns.Meter, ns.Format, ns.Windows

-- Sends a window's ranking or one source's top spells to the chat: RAID in a
-- raid, PARTY in a group, SAY inside an instance (outside the client forbids
-- it), else printed locally. In combat the values are secret and cannot be
-- put into a chat message: the report is refused and the reason printed.
-- Lines are built from plain values only (the secret check comes first).
local Report = {}
ns.Report = Report

local issecret = issecretvalue or function() return false end
local format = string.format
local SEP = " \226\128\148 "  -- " — "

function Report.Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    local inInstance = IsInInstance and IsInInstance()
    if inInstance then return "SAY" end
    return nil
end

local function send(msg, channel)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, channel)
    else
        SendChatMessage(msg, channel)
    end
end

-- Lines go to the channel, or to the player's own chat when there is none.
local function deliver(lines)
    local channel = Report.Channel()
    for _, line in ipairs(lines) do
        if channel then
            send(line, channel)
        else
            ns.Print("%s", line)
        end
    end
    return true
end

local function refuse(message)
    ns.Print("%s", message)
    return false
end

local function anySecret(...)
    for k = 1, select("#", ...) do
        if issecret((select(k, ...))) then return true end
    end
    return false
end

local function limit(n, available)
    n = n or Settings.Get("reportLines")
    return math.max(0, math.min(n, available))
end

local function valueText(total, percent)
    if percent ~= nil then return format("%s (%s)", Format.Amount(total), Format.Percent(percent)) end
    return Format.Amount(total)
end

-- The ranking of window i: header line, then the first n rows.
function Report.Window(i, n)
    local mode, view = Windows.Mode(i), Windows.View(i)
    local data = Meter.Fetch(mode, view)
    if not data then return refuse(L.REPORT_EMPTY) end
    if data.secret then return refuse(L.REPORT_SECRET) end
    n = limit(n, #data.rows)
    if n == 0 then return refuse(L.REPORT_EMPTY) end
    for k = 1, n do
        local r = data.rows[k]
        if anySecret(r.name, r.total, r.percent) then return refuse(L.REPORT_SECRET) end
    end
    local frame = Windows.Frame(i)
    local title = frame and frame.header.title:GetText() or mode
    if issecret(title) then return refuse(L.REPORT_SECRET) end
    local lines = { format("%s: %s", L.ADDON_NAME, title) }
    for k = 1, n do
        local r = data.rows[k]
        local percent = mode ~= "deaths" and r.percent or nil
        lines[#lines + 1] = format("%s. %s  %s", k, r.name, valueText(r.total, percent))
    end
    return deliver(lines)
end

-- One source's top spells; source = Detail.Source().
function Report.Spells(source, n)
    if not source then return refuse(L.REPORT_EMPTY) end
    local data = Meter.Spells(source.mode, source.view, source.row)
    if not data or data.secret then return refuse(L.REPORT_SECRET) end
    n = limit(n, #data.rows)
    if n == 0 then return refuse(L.REPORT_EMPTY) end
    if issecret(source.name) then return refuse(L.REPORT_SECRET) end
    for k = 1, n do
        local sp = data.rows[k]
        if anySecret(sp.name, sp.total, sp.percentOfSource) then return refuse(L.REPORT_SECRET) end
    end
    local mode = L["MODE_" .. source.mode:upper()] or source.mode
    local lines = { format("%s%s%s", source.name, SEP, mode) }
    for k = 1, n do
        local sp = data.rows[k]
        local label = sp.creature and format("%s \194\183 %s", sp.name, sp.creature) or sp.name
        lines[#lines + 1] = format("%s. %s  %s", k, label, valueText(sp.total, sp.percentOfSource))
    end
    return deliver(lines)
end
