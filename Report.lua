local ADDON, ns = ...
local L, Settings, Meter, Format, Windows = ns.L, ns.Settings, ns.Meter, ns.Format, ns.Windows

-- Sends a window's ranking or one source's top spells to the chat: RAID in a
-- raid, PARTY in a group, SAY inside an instance (outside the client forbids
-- it), else printed locally. In combat the values are secret and cannot be
-- put into a chat message: the report is refused and the reason printed.
-- Lines are built from plain values only (the secret check comes first).
-- Sends a window's ranking or one source's top spells to the chat. The
-- channel is the one last chosen (profile setting reportChannel): AUTO (as
-- the client's chat box: instance chat, raid, party, say inside an
-- instance, else printed locally), or SAY, PARTY, RAID, INSTANCE_CHAT,
-- GUILD, WHISPER (the current target, if it is a player who can be whispered). SAY from
-- addon code is forbidden outside instances. In combat the values are
-- secret and cannot be put into a chat message: the report is refused and
-- the reason printed. Lines are built from plain values only (the secret
-- check comes first).
local Report = {}
ns.Report = Report

local issecret = issecretvalue or function() return false end
local format = string.format
local S = Settings.Get
local SEP = " \226\128\148 "  -- " — "
-- The client throttles chat from addons: at most one line per this many
-- seconds, the rest waits in a queue.
local LINE_INTERVAL = 0.2

Report.CHANNELS = { "AUTO", "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "WHISPER" }
local KNOWN = {}
for _, ch in ipairs(Report.CHANNELS) do KNOWN[ch] = true end

-- What /fcm report accepts as a channel word.
local WORDS = { auto = "AUTO", say = "SAY", party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT",
                instance_chat = "INSTANCE_CHAT", guild = "GUILD", whisper = "WHISPER", w = "WHISPER" }

function Report.ParseChannel(word)
    if type(word) ~= "string" then return nil end
    return WORDS[word:lower()]
end

function Report.ChannelLabel(channel)
    return L["REPORT_CH_" .. channel] or channel
end

local function home() return LE_PARTY_CATEGORY_HOME or 1 end
local function instanceCategory() return LE_PARTY_CATEGORY_INSTANCE or 2 end
local function inGroup(category) return (IsInGroup and IsInGroup(category)) and true or false end

-- As the client's chat box switches: a group made by the dungeon / raid
-- finder (instance category only) talks in INSTANCE_CHAT.
function Report.Channel()
    if inGroup(instanceCategory()) and not inGroup(home()) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    local inInstance = IsInInstance and IsInInstance()
    if inInstance then return "SAY" end
    return nil
end

-- Whether a channel works right now; false and a locale key saying why.
function Report.Usable(channel)
    if channel == "AUTO" or channel == "WHISPER" then return true end
    if channel == "SAY" then
        if IsInInstance and IsInInstance() then return true end
        return false, "REPORT_HINT_SAY"
    elseif channel == "PARTY" then
        if inGroup(home()) then return true end
        return false, "REPORT_HINT_GROUP"
    elseif channel == "RAID" then
        if inGroup(home()) and IsInRaid and IsInRaid(home()) then return true end
        return false, "REPORT_HINT_RAID"
    elseif channel == "INSTANCE_CHAT" then
        if inGroup(instanceCategory()) then return true end
        return false, "REPORT_HINT_INSTANCE"
    elseif channel == "GUILD" then
        if IsInGuild and IsInGuild() then return true end
        return false, "REPORT_HINT_GUILD"
    end
    return false
end

-- The stored channel; anything unknown counts as AUTO.
function Report.StoredChannel()
    local channel = S("reportChannel")
    if KNOWN[channel] then return channel end
    return "AUTO"
end

-- Remembers the chosen channel for the next report.
function Report.Choose(channel)
    if not KNOWN[channel] then return end
    Settings.Set("reportChannel", channel)
end

-- The current target's whisper name ("Name", or "Name-Realm" when the realm
-- is needed), when it is a player other than oneself who can be whispered
-- (friendly or of the own faction); nil otherwise (a secret name counts as
-- none).
function Report.WhisperTarget()
    if not (UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")) then return nil end
    if UnitIsUnit and UnitIsUnit("target", "player") then return nil end
    local friend = UnitIsFriend and UnitIsFriend("player", "target")
    if not friend then
        local mine, theirs = UnitFactionGroup and UnitFactionGroup("player"), UnitFactionGroup and UnitFactionGroup("target")
        if issecret(mine) or issecret(theirs) or mine == nil or mine ~= theirs then return nil end
    end
    local name = GetUnitName and GetUnitName("target", true)
    if issecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

local function send(msg, chatType, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType, nil, target)
    else
        SendChatMessage(msg, chatType, nil, target)
    end
end

local queue, sending = {}, false

-- Sends the next queued line and schedules the one after it.
local function pump()
    local item = table.remove(queue, 1)
    if not item then
        sending = false
        return
    end
    sending = true
    -- The next tick is scheduled first and a failing send is contained, so
    -- one error never leaves the queue stuck.
    C_Timer.After(LINE_INTERVAL, pump)
    pcall(send, item.msg, item.chatType, item.target)
end

-- Lines go out one by one, or to the player's own chat (no throttle there)
-- when chatType is nil.
local function enqueue(lines, chatType, target)
    for _, line in ipairs(lines) do
        if chatType then
            queue[#queue + 1] = { msg = line, chatType = chatType, target = target }
        else
            ns.Print("%s", line)
        end
    end
    if not sending then pump() end
end

-- Lines still waiting to be sent.
function Report.Pending() return #queue end

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

-- To `channel` (nil: the stored one); WHISPER goes to the current target,
-- and without one nothing is sent.
local function deliver(lines, channel)
    channel = channel or Report.StoredChannel()
    if channel == "AUTO" then
        enqueue(lines, Report.Channel())
        return true
    end
    if not Report.Usable(channel) then
        return refuse(L.REPORT_UNAVAILABLE:format(Report.ChannelLabel(channel)))
    end
    local target
    if channel == "WHISPER" then
        target = Report.WhisperTarget()
        if not target then return refuse(L.REPORT_NO_TARGET) end
    end
    enqueue(lines, channel, target)
    return true
end

local function limit(n, available)
    n = n or Settings.Get("reportLines")
    return math.max(0, math.min(n, available))
end

-- The ranking of window i: header line, then the first n rows. channel is
-- optional (nil: the stored one).
function Report.Window(i, n, channel)
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
    -- The title text may be a secret display string: checked before any test.
    local title
    if frame then title = frame.header.title:GetText() end
    if issecret(title) then return refuse(L.REPORT_SECRET) end
    if title == nil then title = mode end   -- plain: secret refused above
    local lines = { format("%s: %s", L.ADDON_NAME, title) }
    for k = 1, n do
        local r = data.rows[k]
        local percent
        if mode ~= "deaths" then percent = r.percent end
        lines[#lines + 1] = format("%s. %s  %s", k, r.name, Format.ValueText(r.total, percent))
    end
    return deliver(lines, channel)
end

-- One source's top spells; source = Detail.Source().
function Report.Spells(source, n, channel)
    if not source then return refuse(L.REPORT_EMPTY) end   -- plain: a table
    local data = Meter.Spells(source.mode, source.view, source.row)
    if not data or data.secret then return refuse(L.REPORT_SECRET) end
    n = limit(n, #data.rows)
    if n == 0 then return refuse(L.REPORT_EMPTY) end
    if issecret(source.name) then return refuse(L.REPORT_SECRET) end
    for k = 1, n do
        local sp = data.rows[k]
        if anySecret(sp.name, sp.creature, sp.total, sp.percentOfSource) then return refuse(L.REPORT_SECRET) end
    end
    local mode = L["MODE_" .. source.mode:upper()] or source.mode
    local lines = { format("%s%s%s", source.name, SEP, mode) }
    for k = 1, n do
        local sp = data.rows[k]
        lines[#lines + 1] = format("%s. %s  %s", k, Format.SpellLabel(sp), Format.ValueText(sp.total, sp.percentOfSource))
    end
    return deliver(lines, channel)
end

-- The report submenu (the gear menu's Report): one entry per channel, the
-- stored one checked; a channel that cannot work now is greyed out with the
-- reason as its tooltip. Whisper goes to the current target and is greyed
-- out without a player target. Picking one stores it and calls run(channel).
local function closeMenu() return MenuResponse and MenuResponse.Close end

function Report.AddMenu(parent, run)
    local function isStored(channel) return Report.StoredChannel() == channel end
    for _, channel in ipairs(Report.CHANNELS) do
        local label, usable, why = Report.ChannelLabel(channel), Report.Usable(channel)
        if channel == "WHISPER" then
            local name = Report.WhisperTarget()
            if name then   -- plain: WhisperTarget drops secret names
                label = L.REPORT_WHISPER_TO:format(name)
            else
                label, usable, why = L.REPORT_CH_WHISPER, false, "REPORT_HINT_WHISPER"
            end
        end
        local entry = parent:CreateRadio(label, isStored, function()
            Report.Choose(channel)
            run(channel)
            return closeMenu()
        end, channel)
        if not usable then
            if entry.SetEnabled then entry:SetEnabled(false) end
            if why and entry.SetTooltip then
                entry:SetTooltip(function(tooltip) tooltip:AddLine(L[why], 1, 1, 1, true) end)
            end
        end
    end
end
