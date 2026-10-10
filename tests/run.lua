-- Tests for Forever Combat Meter. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
-- Events the client knows: registering any other name throws, as in the game.
M.validEvents = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true, GLOBAL_MOUSE_DOWN = true,
    PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true, DAMAGE_METER_CURRENT_SESSION_UPDATED = true,
    DAMAGE_METER_COMBAT_SESSION_UPDATED = true, DAMAGE_METER_RESET = true, ADDON_RESTRICTION_STATE_CHANGED = true,
    PLAYER_REGEN_DISABLED = true, CVAR_UPDATE = true }
local ROOT = ADDONDIR
local ADDON = "ForeverCombatMeter"

local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-58s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end

local S, Settings = ns.Settings.Get, ns.Settings

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()

section("Load")
check("TOC lists existing files only", (function()
    for _, f in ipairs(tocFiles()) do
        if not io.open(ROOT .. "/" .. f) then return f end
    end
    return true
end)(), true)
check("Interface", io.open(ROOT .. "/" .. ADDON .. ".toc"):read("*l"), "## Interface: 16001")
for _, name in ipairs({ "L", "Locale", "On", "Print", "AfterCombat", "DB", "AccountDB", "ActiveProfile",
    "SwitchProfile", "DeleteProfile", "CopyProfileFrom", "ProfileList", "Settings", "Share", "Media",
    "Position", "Corners", "Border", "Window", "MinimapButton", "Style", "Widgets", "Format", "Meter", "Threat",
    "Windows", "Detail", "Report" }) do
    check("ns." .. name, ns[name] ~= nil, true)
end
check("saved variables (account)", type(ForeverCombatMeterProfiles), "table")
check("saved variables (character)", type(ForeverCombatMeterChar), "table")
check("default profile", ns.ActiveProfile(), "Default")

section("Shipped defaults")
local D = Settings.DEFAULTS
check("refresh", D.refresh, 0.2)
check("style", D.style, "FOREVER")
check("hideBlizzard", D.hideBlizzard, false)
check("minimapAngle", D.minimapAngle, 200)
check("windowCount", D.windowCount, 1)
check("barHeight", D.barHeight, 18)
check("barTexture", D.barTexture, "Blizzard")
check("old global barColor gone", D.barColor, nil)
check("old global barClassColor gone", D.barClassColor, nil)
check("window default colour", ns.Windows.Defaults(1).barColor[3], 0.75)
check("panel default colour", D.detailBarColor[3], 0.75)
check("panel class colour default", D.detailClassColor, true)
check("bgAlpha", D.bgAlpha, 70)
check("headerSize", D.headerSize, 14)
check("valueFont", D.valueFont, "Arial Narrow")
check("threatWarnPct", D.threatWarnPct, 90)
check("reportLines", D.reportLines, 5)
check("no quest keys", D.groupByZone, nil)

section("Settings")
Settings.Set("barHeight", 30)
check("set and get", S("barHeight"), 30)
check("stored", ns.DB().barHeight, 30)
Settings.Set("barHeight", D.barHeight)
check("default is not stored", ns.DB().barHeight, nil)
check("get falls back", S("barHeight"), 18)
Settings.Set("barHeight", 500)
check("clamped to the range", S("barHeight"), 40)
Settings.Set("refresh", 0.33)
check("step: 0.05", S("refresh"), 0.35)
Settings.Set("refresh", 0.2)
check("step: back to default is not stored", ns.DB().refresh, nil)
Settings.Set("refresh", 0.01)
check("range minimum", S("refresh"), 0.05)
Settings.ResetProfile()
local seen = {}
Settings.OnChange(function(key) seen[#seen + 1] = tostring(key) end)
Settings.SetMany({ barSpacing = 3, barHeight = 22 })
check("SetMany: one change", table.concat(seen, ","), "nil")
check("SetMany values", S("barSpacing") + S("barHeight"), 25)
check("text style", Settings.TextStyle("name").size, 11)
Settings.SetLocked(true)
check("lock", S("locked"), true)
Settings.SetLocked(false)
check("unlock", S("locked"), false)
check("unlocked stores nothing (default: windows start unlocked)", ns.DB().locked, nil)
Settings.ResetProfile()

section("Profiles")
Settings.Set("barHeight", 25)
ns.SwitchProfile("Raid")
check("new profile starts from the current", S("barHeight"), 25)
check("two profiles", #ns.ProfileList(), 2)
Settings.Set("barHeight", 12)
ns.SwitchProfile("Default")
check("other profile unchanged", S("barHeight"), 25)
check("character stores the name", ForeverCombatMeterChar.active, "Default")
check("copy from", ns.CopyProfileFrom("Raid"), true)
check("copied", S("barHeight"), 12)
ns.SwitchProfile("Raid")
check("delete the active one", ns.DeleteProfile("Raid"), true)
check("falls back to Default", ns.ActiveProfile(), "Default")
check("delete unknown", ns.DeleteProfile("nope"), false)
M.chat = {}
ns.AskDeleteProfile()
check("last profile refused", M.chat[1] ~= nil and M.chat[1]:find("last profile", 1, true) ~= nil, true)
Settings.ResetProfile()

section("Export and import")
Settings.Set("barHeight", 17)
Settings.Set("detailBarColor", { 0.1, 0.2, 0.3 })
Settings.Set("refresh", 0.35)
local text = ns.Share.Export()
check("prefix", text:sub(1, 5), "FCM1:")
Settings.ResetProfile()
check("reset", S("barHeight"), D.barHeight)
check("import", ns.Share.Import(text), true)
check("number back", S("barHeight"), 17)
check("colour back", S("detailBarColor")[3], 0.3)
check("fraction back", S("refresh"), 0.35)
check("garbage refused", ns.Share.Import("hello"), nil)
check("a quest log string is refused", ns.Share.Import("FQL1:t}"), nil)
check("code is never run", ns.Share.Import("FCM1:s5:os.ex"), nil)
check("unknown keys skipped", ns.Share.Import("FCM1:ts6:bogus!b1}"), true)
check("unknown key not stored", ns.DB().bogus, nil)
Settings.ResetProfile()
check("bad enum values skipped", ns.Share.Import("FCM1:ts5:styles5:WRONGs11:borderStyles3:BAD"
    .. "s6:bgModes5:SOLIDs10:headerFlags6:Italic}"), true)
check("bad style not stored", ns.DB().style, nil)
check("bad borderStyle not stored", ns.DB().borderStyle, nil)
check("bad flag not stored", ns.DB().headerFlag, nil)
check("good enum kept", ns.Share.Import("FCM1:ts5:styles7:COMPACTs8:nameFlags7:OUTLINE}"), true)
check("style imported", S("style"), "COMPACT")
check("flag imported", S("nameFlag"), "OUTLINE")
Settings.ResetProfile()

section("Options window")
ns.Window.Open()
check("window shown", ns.Window.IsShown(), true)
local function rowFor(label, field)
    for _, f in ipairs(M.frames) do
        if f[field] and f.label and f.label._text and f.label._text:find(label, 1, true) and f:IsVisible() then
            return f
        end
    end
end
local pageIds = {}
for _, page in ipairs(ns.Window.PAGES) do pageIds[#pageIds + 1] = page.id end
check("pages", table.concat(pageIds, ","), "general,windows,layout,bars,appearance,text,threat,profiles")
for _, page in ipairs(ns.Window.PAGES) do
    local ok, err = pcall(ns.Window.ShowPage, page.id)
    check("page " .. page.id .. " builds", ok, true)
    if not ok then print(err) end
end
check("nav buttons", M.byName["ForeverCombatMeterNavgeneral"] ~= nil and M.byName["ForeverCombatMeterNavprofiles"] ~= nil, true)
ns.Window.ShowPage("general")
local refresh = rowFor("Update interval", "slider")
check("refresh slider", refresh ~= nil, true)
refresh.slider:GetScript("OnValueChanged")(refresh.slider, 0.5, true)
check("slider sets the interval", S("refresh"), 0.5)
Settings.Set("refresh", nil)
check("style row", rowFor("Style", "button") ~= nil, true)
check("minimap row", rowFor("Minimap button", "box") ~= nil, true)
check("language dropdown in the nav", ns.Window.languageRow ~= nil or rowFor("Language", "button") ~= nil, true)
ns.Window.ShowPage("profiles")
check("profile row", rowFor("Active profile", "button") ~= nil, true)
ns.Window.Toggle()
check("closed", ns.Window.IsShown(), false)
check("interface options page", M.registered[1], "Forever Combat Meter")

section("Minimap button, compartment and slash command")
local mb = M.byName["ForeverCombatMeterMinimapButton"]
check("minimap button", mb ~= nil, true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click locks", S("locked"), true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click unlocks", S("locked"), false)
Settings.Set("minimapShow", false)
check("minimap button hidden by the setting", mb:IsShown(), false)
Settings.Set("minimapShow", nil)
check("compartment click", type(ForeverCombatMeter_OnAddonCompartmentClick), "function")
check("compartment enter", type(ForeverCombatMeter_OnAddonCompartmentEnter), "function")
check("compartment leave", type(ForeverCombatMeter_OnAddonCompartmentLeave), "function")
ForeverCombatMeter_OnAddonCompartmentClick(nil, "LeftButton")
check("compartment click opens the options", ns.Window.IsShown(), true)
ns.Window.Toggle()
check("/fcm slash", SLASH_FOREVERCOMBATMETER1, "/fcm")
check("/forevercombatmeter slash", SLASH_FOREVERCOMBATMETER2, "/forevercombatmeter")
SlashCmdList["FOREVERCOMBATMETER"]("")
check("/fcm opens the options", ns.Window.IsShown(), true)
SlashCmdList["FOREVERCOMBATMETER"]("")
check("/fcm again closes", ns.Window.IsShown(), false)
SlashCmdList["FOREVERCOMBATMETER"]("unlock")
check("/fcm unlock", S("locked"), false)
SlashCmdList["FOREVERCOMBATMETER"]("lock")
check("/fcm lock", S("locked"), true)
M.chat = {}
SlashCmdList["FOREVERCOMBATMETER"]("what")
check("usage", M.chat[1] ~= nil and M.chat[1]:find("/fcm", 1, true) ~= nil, true)

section("Events and combat")
local fired = 0
check("the client would reject the event", pcall(CreateFrame("Frame").RegisterEvent, CreateFrame("Frame"), "SOME_UNKNOWN_EVENT"), false)
check("ns.On survives an unknown event", (pcall(ns.On, "SOME_UNKNOWN_EVENT", function() fired = fired + 1 end)), true)
ns.On("PLAYER_ENTERING_WORLD", function() fired = fired + 1 end)
M.Fire("PLAYER_ENTERING_WORLD")
check("ns.On delivers", fired, 1)
M.state.combat = true
local ran = 0
ns.AfterCombat("k", function() ran = ran + 1 end)
check("deferred in combat", ran, 0)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("runs after combat", ran, 1)

section("Mock secrets")
local sv = M.Secret(5)
check("issecretvalue", issecretvalue(sv), true)
check("plain is not secret", issecretvalue(5), false)
check("compare raises", pcall(function() return sv < 3 end), false)
check("secret vs secret raises", pcall(function() return sv == M.Secret(5) end), false)
check("arithmetic raises", pcall(function() return sv + 1 end), false)
check("concatenation raises", pcall(function() return "x" .. sv end), false)
check("%d raises", pcall(string.format, "%d", sv), false)
check("%.0f is allowed", M.Reveal(string.format("%.0f", sv)), "5")
check("%s is allowed", M.Reveal(("<%s>"):format(M.Secret("Bob"))), "<Bob>")
check("a formatted secret stays secret", issecretvalue(string.format("%s", M.Secret("Bob"))), true)
check("secret key found", M.FindSecretKey({ a = { [sv] = 1 } }) ~= nil, true)

local Format, Meter = ns.Format, ns.Meter
local function revealed(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok then return "ERROR: " .. tostring(v) end
    return M.Reveal(v)
end

section("Format")
check("amount small", Format.Amount(950), "950")
check("amount k", Format.Amount(1234), "1.2k")
check("amount M", Format.Amount(1234567), "1.23M")
check("amount B", Format.Amount(2500000000), "2.50B")
check("amount nil", Format.Amount(nil), "0")
check("amount secret", revealed(Format.Amount, M.Secret(123456)), "123K")
check("amount secret result is secret", issecretvalue(Format.Amount(M.Secret(5))), true)
check("per second small", Format.PerSecond(5.26), "5.3")
check("per second large", Format.PerSecond(12345), "12.3k")
check("per second secret", revealed(Format.PerSecond, M.Secret(950)), "950")
check("per second secret, precise", revealed(Format.PerSecond, M.Secret(0.34), true), "0.3")
check("per second plain, precise", Format.PerSecond(0.34, true), "0.3")
check("percent", Format.Percent(33.333), "33.3%")
check("percent nil", Format.Percent(nil), "")
check("percent secret", revealed(Format.Percent, M.Secret(12.5)), "12.5%")
check("name with rank", Format.Name(3, "Bob"), "3. Bob")
check("name without rank", Format.Name(nil, "Bob"), "Bob")
check("name nil", Format.Name(1, nil), "1. ?")
check("name secret", revealed(Format.Name, 2, M.Secret("Bob")), "2. Bob")
check("duration seconds", Format.Duration(9), "0:09")
check("duration minutes", Format.Duration(65.7), "1:05")
check("duration hours", Format.Duration(3725), "1:02:05")
check("duration nil", Format.Duration(nil), "")
check("duration secret", revealed(Format.Duration, M.Secret(65)), "65s")
check("IsSecret", Format.IsSecret(M.Secret(1)), true)
check("IsSecret plain", Format.IsSecret("x"), false)

section("Meter: modes")
local T = Enum.DamageMeterType
local wantModes = { damage = T.DamageDone, healing = T.HealingDone, absorbs = T.Absorbs, taken = T.DamageTaken,
    enemytaken = T.EnemyDamageTaken, avoidable = T.AvoidableDamageTaken, interrupts = T.Interrupts,
    dispels = T.Dispels, deaths = T.Deaths }
local order = {}
for i, m in ipairs(Meter.MODES) do
    order[i] = m.key
    check("mode " .. m.key .. " type", m.type, wantModes[m.key])
end
check("mode order", table.concat(order, ","), "damage,healing,absorbs,taken,enemytaken,avoidable,interrupts,dispels,deaths")
local reduced = {}
for k, v in pairs(T) do reduced[k] = v end
reduced.EnemyDamageTaken, reduced.AvoidableDamageTaken = nil, nil
local short = {}
for i, m in ipairs(Meter.BuildModes(reduced)) do short[i] = m.key end
check("older client: no enemytaken/avoidable", table.concat(short, ","), "damage,healing,absorbs,taken,interrupts,dispels,deaths")
check("no enum: no modes", #Meter.BuildModes(nil), 0)
check("type of", Meter.ModeType("healing"), T.HealingDone)
check("type of unknown", Meter.ModeType("threat"), nil)

section("Meter: availability, sessions, reset")
check("available", Meter.Available(), true)
M.dm.available, M.dm.reason = false, "Not in this zone"
local okA, why = Meter.Available()
check("unavailable", okA, false)
check("reason", why, "Not in this zone")
M.dm.available, M.dm.reason = true, ""
local savedDM = C_DamageMeter
C_DamageMeter = nil
check("no API: unavailable", (Meter.Available()), false)
check("no API: no sessions", #Meter.Sessions(), 0)
check("no API: Fetch empty", #Meter.Fetch("damage", "current").rows, 0)
C_DamageMeter = savedDM
M.dm.sessions = { { sessionID = 4, name = "Hogger", durationSeconds = 42 },
                  { sessionID = 5, name = "Boss", durationSeconds = 95, secretName = true } }
local sess = Meter.Sessions()
check("sessions", #sess, 2)
check("session fields", sess[1].id .. "|" .. sess[1].name .. "|" .. sess[1].duration, "4|Hogger|42")
Meter.Reset()
check("reset", M.dm.resets, 1)

section("Meter: Fetch out of combat")
local CUR, OVR = Enum.DamageMeterSessionType.Current, Enum.DamageMeterSessionType.Overall
local function source(name, guid, total, ps, extra)
    local s = { name = name, sourceGUID = guid, totalAmount = total, amountPerSecond = ps, classFilename = "WARRIOR",
                specIconID = 0, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = -1 }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
M.dm.byType[CUR] = { [T.DamageDone] = { totalAmount = 1000, combatSources = {
    source("Bob", "Player-2", 300, 30, { classFilename = "MAGE", specIconID = 135932,
        spells = { { spellID = 133, totalAmount = 100, amountPerSecond = 10, creatureName = "" },
                   { spellID = 116, totalAmount = 200, amountPerSecond = 0, creatureName = "" } } }),
    source("Me", "Player-1-0001", 500, 0, { isLocalPlayer = true,
        spells = { { spellID = 78, totalAmount = 500, amountPerSecond = 10, creatureName = "" } } }),
    source("Wolf", nil, 200, 4, { sourceCreatureID = 69, classFilename = "",
        spells = { { spellID = 17253, totalAmount = 200, amountPerSecond = 4, creatureName = "" } } }),
} } }
M.dm.byType[CUR][T.DamageTaken] = { totalAmount = 400, combatSources = {
    source("Me", "Player-1-0001", 400, 8, { isLocalPlayer = true,
        spells = { { spellID = 88163, totalAmount = 400, amountPerSecond = 8, creatureName = "Ogre" },
                   { spellID = 999, totalAmount = 0, amountPerSecond = 0, creatureName = "" } } }) } }
M.dm.duration[CUR] = 50
M.spells[133], M.spells[116], M.spells[78] = { "Fireball", 135812 }, { "Frostbolt", 135846 }, { "Heroic Strike", 132282 }
local data = Meter.Fetch("damage", "current")
check("not secret", data.secret, false)
check("rows", #data.rows, 3)
check("sorted by total", data.rows[1].name .. "," .. data.rows[2].name .. "," .. data.rows[3].name, "Me,Bob,Wolf")
check("percent", data.rows[1].percent, 50)
check("percent 2", data.rows[3].percent, 20)
check("total", data.total, 1000)
check("max: the top row out of combat", data.max, 500)
check("duration from GetSessionDurationSeconds", data.duration, 50)
check("per second from the API", data.rows[2].perSecond, 30)
check("per second fallback total/duration", data.rows[1].perSecond, 10)
check("class", data.rows[2].class, "MAGE")
check("spec icon", data.rows[2].specIcon, 135932)
check("own row", data.rows[1].isPlayer, true)
check("guid", data.rows[2].guid, "Player-2")
check("creature id", data.rows[3].creatureID, 69)
check("no recap", data.rows[1].recapID, nil)
check("no death time", data.rows[1].deathTime, nil)
check("unknown mode", Meter.Fetch("threat", "current"), nil)
check("empty session", #Meter.Fetch("healing", "current").rows, 0)
M.dm.byType[OVR] = { [T.DamageDone] = { totalAmount = 0, durationSeconds = 20, combatSources = {
    source("Bob", "Player-2", 60, 0), source("Me", "Player-1-0001", 140, 0, { isLocalPlayer = true }) } } }
local ov = Meter.Fetch("damage", "overall")
check("overall: total from the rows when the API says 0", ov.total, 200)
check("overall: percent", ov.rows[1].percent, 70)
check("overall: duration from the session", ov.rows[2].perSecond, 3)
M.dm.byID[5] = { [T.DamageDone] = { totalAmount = 90, combatSources = { source("Me", "Player-1-0001", 90, 0, { isLocalPlayer = true }) } } }
local past = Meter.Fetch("damage", 5)
check("past session by id", past.rows[1].total, 90)
check("past session duration from the session list", past.duration, 95)
check("past session per second", past.rows[1].perSecond, 90 / 95)
M.dm.byType[CUR][T.Deaths] = { totalAmount = 2, combatSources = {
    source("Bob", "Player-2", 1, 0, { deathRecapID = 7, deathTimeSeconds = 31 }),
    source("Me", "Player-1-0001", 1, 0, { isLocalPlayer = true, deathRecapID = -1, deathTimeSeconds = -1 }) } }
local deaths = Meter.Fetch("deaths", "current")
check("deaths: recap id", deaths.rows[1].recapID, 7)
check("deaths: death time", deaths.rows[1].deathTime, 31)
check("deaths: -1 means none", deaths.rows[2].recapID, nil)

section("Meter: Spells out of combat")
local sp = Meter.Spells("damage", "current", data.rows[2])
check("spells of another player", sp ~= nil and #sp.rows, 2)
check("spells sorted", sp.rows[1].name, "Frostbolt")
check("spell icon", sp.rows[1].icon, 135846)
check("spell id", sp.rows[1].spellID, 116)
check("percent of source", sp.rows[1].percentOfSource, 200 / 300 * 100)
check("spell per second fallback", sp.rows[1].perSecond, 4)
check("not secret", sp.secret, false)
local creature = Meter.Spells("damage", "current", data.rows[3])
check("creature by id", creature ~= nil and creature.rows[1].total, 200)
local takenRow = Meter.Fetch("taken", "current").rows[1]
local taken = Meter.Spells("taken", "current", takenRow)
check("taken: creature", taken.rows[1].creature, "Ogre")
check("taken: empty creature is nil", taken.rows[2].creature, nil)
check("taken: melee name", taken.rows[1].name, "Attack")
check("unknown spell name", taken.rows[2].name, "#999")
check("unknown spell icon", taken.rows[2].icon, 134400)
check("no guid, no creature: nil", Meter.Spells("damage", "current", { name = "X" }), nil)

section("Meter: in combat (secret values)")
M.state.combat = true
local okF, cdata = pcall(Meter.Fetch, "damage", "current")
check("Fetch raises nothing", okF, true)
if not okF then print(cdata) end
cdata = okF and cdata or { rows = {} }
check("secret", cdata.secret, true)
check("API order kept", M.Reveal(cdata.rows[1] and cdata.rows[1].name), "Bob")
check("API order kept 2", M.Reveal(cdata.rows[3] and cdata.rows[3].name), "Wolf")
check("no percent", cdata.rows[1] and cdata.rows[1].percent, nil)
check("max in combat: the first row without maxAmount", M.Reveal(cdata.max), 300)
check("total is the API's", M.Reveal(cdata.rows[2] and cdata.rows[2].total), 500)
check("per second is the API's (no fallback)", M.Reveal(cdata.rows[2] and cdata.rows[2].perSecond), 0)
check("own row readable", cdata.rows[2] and cdata.rows[2].isPlayer, true)
check("secret guid dropped", cdata.rows[1] and cdata.rows[1].guid, nil)
check("secret creature id dropped", cdata.rows[3] and cdata.rows[3].creatureID, nil)
check("class stays plain", cdata.rows[1] and cdata.rows[1].class, "MAGE")
check("nothing secret used as a key (result)", M.FindSecretKey(cdata), nil)
check("formats in combat", revealed(function() return Format.Name(1, cdata.rows[1].name) end), "1. Bob")
check("amount formats in combat", revealed(function() return Format.Amount(cdata.rows[2].total) end), "500")
local okS, own = pcall(Meter.Spells, "damage", "current", cdata.rows[2] or {})
check("own spells in combat raise nothing", okS, true)
if not okS then print(own) end
check("own spells via UnitGUID", okS and own and #own.rows, 1)
check("own spells secret", okS and own and own.secret, true)
check("own spell name (secret id)", okS and own and M.Reveal(own.rows[1].name), "Heroic Strike")
check("own spell no percent", okS and own and own.rows[1].percentOfSource, nil)
check("others not readable in combat", select(2, pcall(Meter.Spells, "damage", "current", cdata.rows[1] or {})), nil)
check("creatures not readable in combat", select(2, pcall(Meter.Spells, "damage", "current", cdata.rows[3] or {})), nil)
local okT, ctaken = pcall(Meter.Spells, "taken", "current", (Meter.Fetch("taken", "current").rows[1]))
check("taken in combat raises nothing", okT, true)
check("taken in combat: creature omitted", okT and ctaken and ctaken.rows[1].creature, nil)
local okD, cdeaths = pcall(Meter.Fetch, "deaths", "current")
check("deaths in combat raise nothing", okD, true)
check("deaths: recap id readable in combat", okD and cdeaths.rows[1].recapID, 7)
local okP, cpast = pcall(Meter.Fetch, "damage", 5)
check("past session in combat raises nothing", okP, true)
if not okP then print(cpast) end
local okSe, csess = pcall(Meter.Sessions)
check("sessions in combat raise nothing", okSe, true)
check("secret session name passed through", okSe and M.Reveal(csess[2].name), "Boss")
check("formatted session name", okSe and revealed(Format.Name, nil, csess[2].name), "Boss")
check("nothing secret kept as a key (ns)", M.FindSecretKey(ns), nil)
M.state.combat = false

section("Meter: death recap")
local function hit(ts, extra)
    local e = { timestamp = ts, event = "SPELL_DAMAGE", spellId = 133, amount = 100, currentHP = 1000, sourceName = "Ogre" }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
M.recaps[7] = { hit(110, { amount = 900, currentHP = 0 }), hit(109, { event = "SWING_DAMAGE", spellId = nil }),
    hit(108, { event = "ENVIRONMENTAL_DAMAGE", spellId = nil, environmentalType = "Falling" }),
    hit(107), hit(106), hit(105), hit(104, { amount = 1 }), hit(103, { amount = 2 }) }
local recap = Meter.Recap(7)
check("recap: six events", recap and #recap, 6)
check("recap: oldest first", recap and recap[1].time, -5)
check("recap: killing blow last", recap and recap[6].amount, 900)
check("recap: killing blow time", recap and recap[6].time, 0)
check("recap: hp", recap and recap[6].hp, 0)
check("recap: spell", recap and recap[6].spell, "Fireball")
check("recap: icon", recap and recap[6].icon, 135812)
check("recap: source", recap and recap[6].source, "Ogre")
check("recap: melee", recap and recap[5].spell, "Melee")
check("recap: environment", recap and recap[4].spell, "Falling")
check("recap: not secret", recap and recap.secret, false)
check("recap: none for 0", Meter.Recap(0), nil)
check("recap: none for nil", Meter.Recap(nil), nil)
check("recap: none without events", Meter.Recap(8), nil)
M.state.combat = true
local okR, crecap = pcall(Meter.Recap, 7)
check("recap in combat raises nothing", okR, true)
if not okR then print(crecap) end
check("recap in combat: secret", okR and crecap and crecap.secret, true)
check("recap in combat: order from the API", okR and crecap and M.Reveal(crecap[6].amount), 900)
check("recap in combat: no time", okR and crecap and crecap[6].time, nil)
M.state.combat = false

section("Secret-safe sources")
for _, f in ipairs({ "Format.lua", "Meter.lua", "Windows.lua", "Detail.lua", "Report.lua" }) do
    local src = io.open(ROOT .. "/" .. f):read("*a"):gsub("%-%-[^\n]*", "")
    check("no %d format in " .. f, src:find("%%d"), nil)
end
for _, f in ipairs(tocFiles()) do
    if f ~= "Meter.lua" then
        local code = io.open(ROOT .. "/" .. f):read("*a"):gsub("%-%-[^\n]*", "")
        check("only Meter.lua reads C_DamageMeter (" .. f .. ")", code:find("C_DamageMeter", 1, true), nil)
    end
end

section("Languages")
local base = ns.Locales.enUS
local count = 0
for code, strings in pairs(ns.Locales) do
    count = count + 1
    for key in pairs(base) do check(code .. " has " .. key, strings[key] ~= nil, true) end
    for key in pairs(strings) do check(code .. ": " .. key .. " is known", base[key] ~= nil, true) end
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
    end
end
check("four languages", count, 4)
check("style labels", ns.Locales.deDE.STYLE_FOREVER .. "|" .. ns.Locales.deDE.STYLE_COMPACT, "Forever (wie Questlog)|Kompakt")
check("style label es", ns.Locales.esES.OPT_STYLE, "Estilo")
for key, value in pairs(ns.Locales.deDE) do
    for _, bad in ipairs({ "oess", "oesch", "oehe", "aende", "ueber", "fuer", "Rueck", "schliess" }) do
        check("no umlaut workaround in " .. key .. " (" .. bad .. ")", value:find(bad), nil)
    end
end
for _, strings in pairs(ns.Locales) do
    for key, value in pairs(strings) do
        check("no quest log leftovers in " .. key, value:find("Quest Log", 1, true) or value:find("/fql", 1, true), nil)
    end
end
-- Every key the code uses exists in English.
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    for key in src:gmatch("L%.([A-Z][A-Z0-9_]+)") do check(f .. " uses known L." .. key, base[key] ~= nil, true) end
    local found = 0
    for key in src:gmatch('"([A-Z]+_[A-Z0-9_]+)"') do
        local prefix = key:match("^(%u+)_")
        if prefix == "OPT" or prefix == "PAGE" or prefix == "STYLE" or prefix == "TIP" or prefix == "MSG" then
            found = found + 1
            check(f .. " uses known " .. key, base[key] ~= nil, true)
        end
    end
    if f == "Options/Window.lua" then check("label keys are found in " .. f, found > 10, true) end
end
section("Threat")
local Threat = ns.Threat
local world = { time = 100, raid = false, members = {}, sounds = {}, target = { exists = true, attack = true, dead = false } }
-- members: unit -> { name, class, tank, raw, value, secret, self }
GetTime = function() return world.time end
IsInRaid = function() return world.raid end
GetNumGroupMembers = function()
    local n = 0
    for u in pairs(world.members) do if u:match("^raid%d+$") or u:match("^party%d+$") or u == "player" then n = n + 1 end end
    return n
end
GetNumSubgroupMembers = function()
    local n = 0
    for u in pairs(world.members) do if u:match("^party%d+$") then n = n + 1 end end
    return n
end
UnitExists = function(u)
    if u == "target" then return world.target.exists end
    return world.members[u] ~= nil
end
UnitCanAttack = function() return world.target.attack end
UnitIsDead = function() return world.target.dead end
UnitName = function(u) return world.members[u].name end
UnitClass = function(u) return world.members[u].name, world.members[u].class end
UnitIsUnit = function(a, b) return world.members[a] ~= nil and world.members[a].self == true and b == "player" end
UnitDetailedThreatSituation = function(u, t)
    local m = world.members[u]
    if m.secret then return M.Secret(m.tank or false), M.Secret(3), M.Secret(m.raw), M.Secret(m.raw), M.Secret(m.value) end
    if m.nothing then return nil end
    return m.tank or false, m.tank and 3 or 1, math.min(m.raw, 100), m.raw, m.value
end
SOUNDKIT = { RAID_WARNING = 8959 }
PlaySound = function(id, ch) world.sounds[#world.sounds + 1] = { id, ch } end
local function party(spec) world.members = spec; Threat.Reset() end
local function names(list) local t = {}; for _, r in ipairs(list.rows) do t[#t + 1] = r.name end; return table.concat(t, ",") end
Settings.ResetProfile()

party({
    player = { name = "Me", class = "MAGE", raw = 40, value = 1000, self = true },
    party1 = { name = "Tank", class = "WARRIOR", tank = true, raw = 100, value = 5000 },
    party2 = { name = "Abe", class = "ROGUE", raw = 40, value = 900 },
    pet = { name = "Kitty", class = "HUNTER", raw = 10, value = 100 },
})
local list = Threat.List()
check("not unavailable", list.unavailable, false)
check("sorted: tank, pct desc, name", names(list), "Tank,Abe,Me,Kitty")
check("tank shows 100", list.rows[1].pct, 100)
check("tank flag", list.rows[1].tanking, true)
check("class file name", list.rows[1].class, "WARRIOR")
check("own row flagged", list.rows[3].isPlayer, true)
check("others not flagged", list.rows[2].isPlayer, false)
check("unit token kept", list.rows[1].unit, "party1")
Settings.Set("showPets", false)
check("pets off", names(Threat.List()), "Tank,Abe,Me")
Settings.Set("showPets", true)

world.raid = true
party({
    raid1 = { name = "Zed", class = "PRIEST", raw = 20, value = 10 },
    raid2 = { name = "Tank", class = "WARRIOR", tank = true, raw = 100, value = 99 },
    raidpet2 = { name = "Imp", class = "WARLOCK", raw = 5, value = 1 },
})
check("raid units, pets included", names(Threat.List()), "Tank,Zed,Imp")
world.raid = false

party({ player = { name = "Me", raw = 10, value = 0, self = true }, party1 = { name = "Silent", nothing = true } })
check("units without threat are skipped", names(Threat.List()), "Me")

world.target.dead = true
check("dead target: no rows", #Threat.List().rows, 0)
world.target.dead, world.target.attack = false, false
check("friendly target: no rows", #Threat.List().rows, 0)
world.target.attack = true
world.target.exists = false
check("no target: no rows", #Threat.List().rows, 0)
check("no target: not unavailable", Threat.List().unavailable, false)
world.target.exists = true

-- Equal keys fall back to the unit token; secret names are never compared.
party({
    party2 = { name = M.Secret("Bea"), raw = 50, value = 1 },
    party1 = { name = M.Secret("Cid"), raw = 50, value = 1 },
    player = { name = M.Secret("Me"), raw = 50, value = 1, self = true },
    party3 = { name = M.Secret("Tank"), tank = true, raw = 10, value = 1 },
})
local okSort, sorted = pcall(Threat.List)
check("secret names: sorting raises nothing", okSort, true)
local units = {}
for _, r in ipairs(okSort and sorted.rows or {}) do units[#units + 1] = r.unit end
check("holder first, ties by unit token", table.concat(units, ","), "party3,party1,party2,player")

section("Threat per second")
party({ player = { name = "Me", raw = 40, value = 1000, self = true } })
world.time = 100
check("first sample is zero", Threat.List().rows[1].perSecond, 0)
world.members.player.value = 1500
world.time = 102
check("delta over time", Threat.List().rows[1].perSecond, 250)
world.time = 102.05
check("a too quick call keeps the rate", Threat.List().rows[1].perSecond, 250)
world.members.player.value = 1400
world.time = 104
check("a falling value is zero", Threat.List().rows[1].perSecond, 0)
world.members.player.value = 3000
world.time = 105
M.Fire("PLAYER_TARGET_CHANGED")
check("target change resets", Threat.List().rows[1].perSecond, 0)
world.members.player.value = 4000
world.time = 106
M.Fire("GROUP_ROSTER_UPDATE")
check("roster change resets", Threat.List().rows[1].perSecond, 0)

section("Threat warning")
party({
    player = { name = "Me", class = "MAGE", raw = 95, value = 1, self = true },
    party1 = { name = "Tank", class = "WARRIOR", tank = true, raw = 100, value = 9 },
})
world.sounds = {}
check("warning active at 95 %", Threat.CheckWarning(), true)
check("sound played", #world.sounds, 1)
check("sound id and channel", world.sounds[1][1] .. world.sounds[1][2], "8959Master")
check("still active", Threat.CheckWarning(), true)
check("sound only once per target", #world.sounds, 1)
M.Fire("GROUP_ROSTER_UPDATE")
Threat.CheckWarning()
check("roster change does not re-arm", #world.sounds, 1)
M.Fire("PLAYER_TARGET_CHANGED")
check("target change re-arms", Threat.CheckWarning() and #world.sounds, 2)
Threat.CheckWarning()
check("same fight: no second sound", #world.sounds, 2)
M.Fire("PLAYER_REGEN_DISABLED")
check("new fight on the same target re-arms", Threat.CheckWarning() and #world.sounds, 3)
world.members.player.raw = 89
check("below the threshold", Threat.CheckWarning(), false)
world.members.player.raw = 90
check("at the threshold", Threat.CheckWarning(), true)
world.members.player.tank, world.members.player.raw = true, 100
M.Fire("PLAYER_TARGET_CHANGED")
world.sounds = {}
check("tanking: no warning", Threat.CheckWarning(), false)
check("tanking: no sound", #world.sounds, 0)
world.members.player.tank, world.members.player.raw = nil, 95
Settings.Set("threatSound", false)
M.Fire("PLAYER_TARGET_CHANGED")
check("sound off: still active", Threat.CheckWarning(), true)
check("sound off: silent", #world.sounds, 0)
Settings.Set("threatSound", nil)
Settings.Set("threatWarn", false)
check("warning off", Threat.CheckWarning(), false)
Settings.Set("threatWarn", nil)
Settings.Set("threatWarnPct", 98)
check("custom threshold", Threat.CheckWarning(), false)
Settings.Set("threatWarnPct", nil)
world.members.pet = { name = "Kitty", raw = 99, value = 1 }
world.members.player.raw = 10
check("a pet's threat does not warn", Threat.CheckWarning(), false)

section("Threat secret values")
party({
    player = { name = "Me", raw = 95, value = 1, self = true },
    party1 = { name = "Tank", secret = true, tank = true, raw = 100, value = 9 },
})
local ok, sl = pcall(Threat.List)
check("secret does not raise", ok, true)
check("secret: unavailable", sl.unavailable, true)
check("secret: no rows", #sl.rows, 0)
world.sounds = {}
check("secret: no warning", Threat.CheckWarning(), false)
check("secret: no sound", #world.sounds, 0)
check("secret warning does not raise", (pcall(Threat.CheckWarning)), true)

section("Windows")
local Windows = ns.Windows
Settings.ResetProfile()
M.state.combat = false
world.target.exists, world.target.attack, world.target.dead = true, true, false
M.dm.byType[CUR] = { [T.DamageDone] = { totalAmount = 1000, maxAmount = 500, combatSources = {
    source("Bob", "Player-2", 300, 30, { classFilename = "MAGE", specIconID = 135932 }),
    source("Me", "Player-1-0001", 500, 25, { isLocalPlayer = true }),
    source("Wolf", nil, 200, 4, { sourceCreatureID = 69, classFilename = "" }),
} } }
M.dm.byType[CUR][T.Interrupts] = { totalAmount = 3, combatSources = {
    source("Me", "Player-1-0001", 3, 0.3, { isLocalPlayer = true }) } }
M.dm.byType[OVR] = { [T.DamageDone] = { totalAmount = 50, combatSources = { source("Old", "Player-3", 50, 1) } } }
M.dm.byID[4] = { [T.DamageDone] = { totalAmount = 70, combatSources = { source("Past", "Player-4", 70, 7) } } }
M.dm.duration[CUR] = 50
M.dm.sessions = { { sessionID = 4, name = "Hogger", durationSeconds = 42 },
                  { sessionID = 5, name = "Boss", durationSeconds = 95, secretName = true } }
Settings.Set("animate", false)
local w1 = Windows.Frame(1)
local function bar(i, k) return Windows.Frame(i).bars[k] end
local function txt(fs) return M.Reveal(fs:GetText()) end
local function shownBars(i)
    local n = 0
    for _, b in ipairs(Windows.Frame(i).bars) do if b:IsShown() then n = n + 1 end end
    return n
end
check("window 1 exists after login", w1 ~= nil, true)
check("window 1 shown", w1 and w1:IsShown(), true)
check("only one window", Windows.Frame(2), nil)
check("no secure template", w1._template, nil)
check("position not saved by the client", w1._dontSave, true)
check("default mode", Windows.Mode(1), "damage")
check("default view", Windows.View(1), "current")
check("default width", w1:GetWidth(), 220)
check("default rows", Windows.Config(1).rows, 8)
check("default anchor", w1._lastPoint[1] .. "," .. w1._lastPoint[4], "CENTER,300")
check("nothing stored for defaults", ns.DB().windows, nil)
Windows.Refresh(1)
check("title", txt(w1.header.title), "Damage · Current")
check("three bars", shownBars(1), 3)
check("order", txt(bar(1, 1).name) .. "," .. txt(bar(1, 2).name) .. "," .. txt(bar(1, 3).name), "1. Me,2. Bob,3. Wolf")
check("values: total (per second, percent)", txt(bar(1, 1).value), "500 (25.0, 50.0%)")
check("bar max", bar(1, 1)._max, 500)
check("bar value", bar(1, 2)._value, 300)
check("class colour", bar(1, 2)._barColor[1], 0.25)
check("no class: bar colour", bar(1, 3)._barColor[3], 0.75)
check("spec icon", bar(1, 2).icon._texture, 135932)
check("class atlas without a spec", bar(1, 1).icon._atlas, "classicon-warrior")
check("spec icon cropped", bar(1, 2).icon._texCoord[1], 0.08)
check("no icon for a creature", bar(1, 3).icon:IsShown(), false)
check("IconFor: spec", select(2, Windows.IconFor(135932, "MAGE")), 135932)
check("IconFor: spec 0 -> class atlas", select(2, Windows.IconFor(0, "MAGE")), "classicon-mage")
check("IconFor: secret spec -> class atlas", select(2, Windows.IconFor(M.Secret(5), "ROGUE")), "classicon-rogue")
check("IconFor: nothing", Windows.IconFor(nil, ""), nil)
check("IconFor: secret class", Windows.IconFor(nil, M.Secret("MAGE")), nil)
local sMax, sVal = M.Secret(9), M.Secret(4)
local fm, fv = Windows.FillArgs(sMax, sVal)
check("FillArgs passes secrets untouched", rawequal(fm, sMax) and rawequal(fv, sVal), true)
check("FillArgs nil", table.concat({ Windows.FillArgs(nil, nil) }, ","), "1,0")
check("FillArgs non-positive scale", table.concat({ Windows.FillArgs(0, 2) }, ","), "1,2")
check("FillArgs negative scale", (Windows.FillArgs(-3, 2)), 1)
check("FillArgs plain", table.concat({ Windows.FillArgs(50, 20) }, ","), "50,20")
check("value column width", bar(1, 1).value:GetWidth(), math.floor((220 - 8) * 0.45))
check("bar texture", bar(1, 1)._barTexture, "Interface\\TargetingFrame\\UI-StatusBar")
check("bar data for the tooltip", bar(1, 2).row.name, "Bob")
check("empty text hidden", w1.empty:IsShown(), false)
Windows.SetConfig(1, { classColor = false })
Windows.Refresh(1)
check("bar colour setting", bar(1, 2)._barColor[1], 0.45)
Windows.SetConfig(1, { classColor = true })
Settings.Set("showPercent", false)
Windows.Refresh(1)
check("columns: no percent", txt(bar(1, 1).value), "500 (25.0)")
Settings.Set("showPerSecond", false)
Windows.Refresh(1)
check("columns: total only", txt(bar(1, 1).value), "500")
Settings.Set("showTotal", false)
Settings.Set("showPercent", nil)
Windows.Refresh(1)
check("columns: percent only", txt(bar(1, 1).value), "50.0%")
Settings.Set("showTotal", nil)
Settings.Set("showPerSecond", nil)
Settings.Set("showRank", false)
Windows.Refresh(1)
check("no rank", txt(bar(1, 1).name), "Me")
Settings.Set("showRank", nil)
Settings.Set("showIcon", false)
Windows.Refresh(1)
check("icon off", bar(1, 1).icon:IsShown(), false)
Settings.Set("showIcon", nil)
Windows.Refresh(1)
check("icon on", bar(1, 1).icon:IsShown(), true)

section("Windows: rows, scrolling, height")
local h8 = w1:GetHeight()
Windows.SetConfig(1, { rows = 2 })
Windows.Refresh(1)
check("rows setting: two bars", shownBars(1), 2)
check("height follows rows", h8 - w1:GetHeight(), 6 * (18 + 1))
Windows.Scroll(1, -1)
check("scrolled one row", txt(bar(1, 1).name), "2. Bob")
Windows.Scroll(1, -5)
check("scroll clamped", txt(bar(1, 1).name), "2. Bob")
w1.body:GetScript("OnMouseWheel")(w1.body, 1)
check("wheel over the bars scrolls", txt(bar(1, 1).name), "1. Me")
Windows.SetConfig(1, { rows = 8 })
check("rows stored only when not default", ns.DB().windows, nil)

section("Windows: mode and session")
Windows.SetMode(1, "healing")
check("mode set", Windows.Mode(1), "healing")
check("mode stored", ns.DB().windows[1].mode, "healing")
check("healing: empty text", w1.empty:IsShown() and txt(w1.empty), "No data")
Windows.SetMode(1, "bogus")
check("unknown mode ignored", Windows.Mode(1), "healing")
Windows.SetMode(1, "damage")
check("default mode not stored", ns.DB().windows, nil)
Windows.SetView(1, "overall")
check("view stored", ns.DB().windows[1].view, "overall")
check("overall title", txt(w1.header.title), "Damage · Overall")
check("overall data", txt(bar(1, 1).name), "1. Old")
Windows.SetView(1, 4)
check("past fight view", Windows.View(1), 4)
check("past fight not persisted", ns.DB().windows, nil)
check("past fight title", txt(w1.header.title), "Damage · Hogger (0:42)")
check("past fight data", txt(bar(1, 1).name), "1. Past")
M.Fire("DAMAGE_METER_RESET")
check("reset: back to current", Windows.View(1), "current")
Windows.SetView(1, "overall")
M.Fire("DAMAGE_METER_RESET")
check("reset keeps overall", Windows.View(1), "overall")
Windows.SetView(1, "current")
w1.header:GetScript("OnMouseWheel")(w1.header, -1)
check("wheel on the header: next mode", Windows.Mode(1), "healing")
w1.header:GetScript("OnMouseWheel")(w1.header, 1)
w1.header:GetScript("OnMouseWheel")(w1.header, 1)
check("wheel wraps to threat", Windows.Mode(1), "threat")
Windows.SetMode(1, "damage")
Windows.SetMode(1, "interrupts")
check("interrupts per second keeps a decimal", txt(bar(1, 1).value), "3 (0.3, 100.0%)")
Windows.SetMode(1, "damage")

section("Windows: add and close")
check("add", Windows.Add(), 2)
check("window count", S("windowCount"), 2)
check("window 2 shown", Windows.Frame(2):IsShown(), true)
check("window 2 beside window 1", Windows.Frame(2)._lastPoint[4] ~= w1._lastPoint[4], true)
Windows.SetMode(2, "healing")
check("add 3", Windows.Add(), 3)
Windows.SetMode(3, "interrupts")
check("add 4", Windows.Add(), 4)
check("no fifth", Windows.Add(), nil)
check("window 1 cannot close", Windows.Close(1), false)
check("close 2", Windows.Close(2), true)
check("count after close", S("windowCount"), 3)
check("later windows move up", Windows.Mode(2), "interrupts")
check("frame 4 hidden", Windows.Frame(4):IsShown(), false)
Windows.Close(3)
Windows.Close(2)
check("back to one", S("windowCount"), 1)
check("nothing stored for one default window", ns.DB().windows, nil)
Settings.Set("windowCount", 3)
check("count setting shows windows", Windows.Frame(3):IsShown(), true)
Settings.Set("windowCount", nil)
check("count setting hides windows", Windows.Frame(2):IsShown(), false)

section("Windows: threat")
party({
    player = { name = "Me", class = "MAGE", raw = 95, value = 1, self = true },
    party1 = { name = "Tank", class = "WARRIOR", tank = true, raw = 100, value = 9 },
    party2 = { name = "Puller", class = "ROGUE", raw = 120, value = 5 },
})
world.sounds = {}
Windows.SetMode(1, "threat")
check("threat title", txt(w1.header.title), "Threat")
check("threat rows", shownBars(1), 3)
check("threat order", txt(bar(1, 2).name), "2. Puller")
check("tank marker", txt(bar(1, 1).name):find("tank", 1, true) ~= nil, true)
check("threat max", bar(1, 1)._max, 100)
check("threat fill clamped", bar(1, 2)._value, 100)
check("threat text keeps the real percent", txt(bar(1, 2).value):find("120.0%", 1, true) ~= nil, true)
check("warning glow on the own row", bar(1, 3).glow:IsShown(), true)
check("no glow on others", bar(1, 2).glow:IsShown(), false)
check("warning sound", #world.sounds, 1)
GameTooltip._lines = {}
bar(1, 1):GetScript("OnEnter")(bar(1, 1))
check("threat bar: no tooltip", #GameTooltip._lines, 0)
local openedBefore = ns.Detail.IsOpen()
bar(1, 1):GetScript("OnMouseUp")(bar(1, 1), "LeftButton")
check("threat bar: no breakdown", ns.Detail.IsOpen(), openedBefore)
check("threat bar: leave raises nothing", (pcall(bar(1, 1):GetScript("OnLeave"), bar(1, 1))), true)
world.members.player.raw = 10
Windows.Refresh(1)
check("glow off below the threshold", bar(1, 3).glow:IsShown(), false)
party({ player = { name = "Me", raw = 95, value = 1, self = true },
        party1 = { name = "Tank", secret = true, tank = true, raw = 100, value = 9 } })
local okT = pcall(Windows.Refresh, 1)
check("secret threat renders", okT, true)
check("threat unavailable text", txt(w1.empty), "Threat not available")
check("no threat bars", shownBars(1), 0)
world.target.exists = false
Windows.Refresh(1)
check("no target text", txt(w1.empty), "No target")
world.target.exists = true
Windows.SetMode(1, "damage")

section("Windows: secret values")
M.state.combat = true
local okC, errC = pcall(Windows.Refresh, 1)
check("rendering in combat raises nothing", okC, true)
if not okC then print(errC) end
check("API order in combat", txt(bar(1, 1).name), "1. Bob")
check("no percent column in combat", txt(bar(1, 1).value), "300 (30)")
check("secret max", M.Reveal(bar(1, 1)._max), 500)
check("secret value set directly", M.Reveal(bar(1, 1)._value), 300)
Settings.Set("animate", true)
check("animate with secrets raises nothing", (pcall(Windows.Refresh, 1)) and (pcall(Windows.Tick, 0.02)), true)
Settings.Set("animate", false)
Windows.SetMode(1, "interrupts")
check("secret per second keeps a decimal", txt(bar(1, 1).value), "3 (0.3)")
Windows.SetMode(1, "damage")
M.state.combat = false
Settings.Set("animate", true)
Windows.Refresh(1)
check("after combat: no re-grow from zero", bar(1, 1)._value, 500)
Settings.Set("animate", false)
M.state.combat = true
local okV = pcall(Windows.SetView, 1, 5)
check("secret session name renders", okV, true)
check("secret session title: Fight n", txt(w1.header.title), "Damage · Fight 2 (1:35)")
check("title and session tooltip agree", Windows.SessionLabel(1), "Fight 2 (1:35)")
local okM = pcall(Windows.OpenSessionMenu, 1, w1.header)
check("session menu with a secret name", okM, true)
check("secret name not in the menu", M.MenuFind(M.LastMenu(), "Boss"), nil)
Windows.SetView(1, "current")
check("nothing secret kept as a key", M.FindSecretKey(ns), nil)
M.state.combat = false

section("Windows: render loop")
local fetches, realFetch = 0, Meter.Fetch
Meter.Fetch = function(...) fetches = fetches + 1; return realFetch(...) end
Windows.Tick(5) -- past any redraw burst from an earlier PLAYER_REGEN_ENABLED
fetches = 0
Windows.Tick(0.1)
check("nothing dirty: no redraw", fetches, 0)
M.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
Windows.Tick(0.05)
check("throttled", fetches, 0)
Windows.Tick(0.05)
check("redraw after the interval", fetches, 1)
Windows.Tick(0.2)
check("clean again", fetches, 1)
Settings.Set("barHeight", 20)
Windows.Tick(0.2)
check("settings change redraws", fetches, 2)
Settings.Set("barHeight", nil)
Windows.Tick(0.2)
fetches = 0
M.Fire("PLAYER_REGEN_ENABLED")
Windows.Tick(0.2); Windows.Tick(0.2); Windows.Tick(0.2)
check("after combat: every tick", fetches, 3)
Windows.Tick(3)
fetches = 0
Windows.Tick(0.2)
check("after 3 s: idle again", fetches, 0)
M.Fire("ADDON_RESTRICTION_STATE_CHANGED")
Windows.Tick(0.2)
check("restriction change redraws", fetches, 1)
Meter.Fetch = realFetch
local lists, realList = 0, Threat.List
Threat.List = function(...) lists = lists + 1; return realList(...) end
Windows.SetMode(1, "threat")
lists = 0
Windows.Tick(0.2); Windows.Tick(0.2)
check("threat redraws every tick", lists, 2)
Windows.Add()
Windows.SetMode(2, "threat")
lists = 0
Windows.Tick(0.2)
check("one threat sample per tick for all windows", lists, 1)
Windows.Close(2)
Threat.List = realList
Windows.SetMode(1, "damage")
Settings.Set("refresh", 1)
fetches = 0
Meter.Fetch = function(...) fetches = fetches + 1; return realFetch(...) end
M.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
Windows.Tick(0.5)
check("refresh setting is the interval", fetches, 0)
Windows.Tick(0.5)
check("refresh setting: redraw", fetches, 1)
Meter.Fetch = realFetch
Settings.Set("refresh", nil)

section("Windows: animation")
Settings.Set("animate", true)
Windows.SetConfig(1, { rows = 8 })
M.dm.byType[CUR][T.DamageDone].combatSources[1].totalAmount = 400
Windows.Refresh(1)
local before = bar(1, 2)._value
check("animates toward the new value", before < 400, true)
Windows.Tick(0.02)
check("moving", bar(1, 2)._value > before and bar(1, 2)._value < 400, true)
Windows.Tick(1)
check("arrives", bar(1, 2)._value, 400)
M.dm.byType[CUR][T.DamageDone].combatSources[1].totalAmount = 300
Settings.Set("animate", false)

section("Windows: lock, move, resize")
Windows.Refresh(1)
check("unlocked by default", Windows.Config(1).locked, false)
check("four grips shown unlocked", w1.grips.TOPLEFT:IsShown() and w1.grips.TOPRIGHT:IsShown() and w1.grips.BOTTOMLEFT:IsShown() and w1.grips.BOTTOMRIGHT:IsShown(), true)
w1._rect = { 800, 500, 220, w1:GetHeight() }
w1.header:GetScript("OnMouseDown")(w1.header, "LeftButton")
check("drag starts", w1._moving, true)
w1._rect = { 840, 400, 220, w1:GetHeight() }
w1.header:GetScript("OnMouseUp")(w1.header, "LeftButton")
check("drag stops", w1._moving, false)
check("not user placed", w1._userPlaced, false)
local c1 = Windows.Config(1)
check("position saved", c1.point .. "," .. c1.x .. "," .. c1.y, "TOP," .. (840 + 110 - 960) .. "," .. (400 + w1:GetHeight() - 1080))
Windows.ToggleLock(1)
check("locked", Windows.Config(1).locked, true)
check("global follows: all locked", S("locked"), true)
check("grips hidden locked", w1.grips.BOTTOMRIGHT:IsShown() or w1.grips.TOPLEFT:IsShown(), false)
w1.header:GetScript("OnMouseDown")(w1.header, "LeftButton")
check("lock blocks the drag", w1._moving, false)
Settings.SetLocked(false)
check("unlock all", Windows.Config(1).locked, false)
Settings.SetLocked(true)
check("lock all", Windows.Config(1).locked, true)
Settings.SetLocked(false)
Settings.ResetProfile()
local function press(grip) grip:GetScript("OnMouseDown")(grip, "LeftButton") end
local function drag(grip, x, y) M.state.cursorX, M.state.cursorY = x, y; grip:GetScript("OnUpdate")(grip, 0.02) end
local function release(grip) grip:GetScript("OnMouseUp")(grip, "LeftButton") end
-- The window's rectangle in UIParent units from its stored TOP anchor.
local function storedRect(i)
    local c, f = Windows.Config(i), Windows.Frame(i)
    local s = f:GetScale()
    local h = f:GetHeight()
    local w = c.width * s
    local cx = 960 + c.x * s
    local top = 1080 + c.y * s
    return cx - w / 2, cx + w / 2, top - h * s, top
end
local function near(name, got, want) check(name, math.abs(got - want) <= 1, true) end

for _, style in ipairs({ "FOREVER", "COMPACT" }) do
    for _, scale in ipairs({ 1, 1.5 }) do
        Settings.ResetProfile()
        Windows.ApplyStylePreset(style)
        Windows.SetConfig(1, { scale = scale * 100 })
        local W, rows = Windows.Config(1).width, Windows.Config(1).rows
        local H = w1:GetHeight()
        local left, bottom = 500, 300
        w1._rect = { left, bottom, W, H }
        local L0, R0, T0, B0 = left * scale, (left + W) * scale, (bottom + H) * scale, bottom * scale
        for corner, g in pairs(w1.grips) do
            local tag = style .. " x" .. scale .. " " .. corner
            M.state.mouseDown = true
            M.state.cursorX, M.state.cursorY = 100, 100
            press(g)
            local dx = corner:find("RIGHT") and 60 or -60
            drag(g, 100 + dx * scale, 100 + (corner:find("TOP") and 80 or -80) * scale)
            local step = S("barHeight") + S("barSpacing")
            local wantRows = rows + math.floor(80 / step)
            check(tag .. ": live rows", w1.cfg.rows, wantRows)
            check(tag .. ": live width", w1:GetWidth(), W + 60)
            check(tag .. ": nothing stored while dragging", Windows.Config(1).width, W)
            release(g)
            check(tag .. ": width saved", Windows.Config(1).width, W + 60)
            check(tag .. ": rows saved", Windows.Config(1).rows, wantRows)
            check(tag .. ": TOP anchor", Windows.Config(1).point, "TOP")
            local l, r, b, t = storedRect(1)
            if corner:find("RIGHT") then near(tag .. ": left fixed", l, L0) else near(tag .. ": right fixed", r, R0) end
            if corner:find("TOP") then near(tag .. ": bottom fixed", b, B0) else near(tag .. ": top fixed", t, T0) end
            Settings.ResetProfile()
            Windows.ApplyStylePreset(style)
            Windows.SetConfig(1, { scale = scale * 100 })
            w1._rect = { left, bottom, W, H }
        end
    end
end
Windows.SetConfig(1, { scale = 100 })
Settings.ResetProfile()
w1._rect = { 800, 400, 220, w1:GetHeight() }
local rows0 = Windows.Config(1).rows
local gbr = w1.grips.BOTTOMRIGHT
M.state.cursorX, M.state.cursorY = 1000, 400
press(gbr); release(gbr)
check("plain click: nothing written", ns.DB().windows, nil)
press(gbr); drag(gbr, 1000, 400 + 5000)
check("shrinks to 1 row (clamped)", w1.cfg.rows, 1)
drag(gbr, 9000, -90000)
check("width clamped", w1.cfg.width, 600)
check("rows clamped", w1.cfg.rows, 40)
release(gbr)
check("clamped values saved", Windows.Config(1).width .. "," .. Windows.Config(1).rows, "600,40")
local rowsAt = Windows.Config(1).rows
w1._rect = { 800, 400, 600, w1:GetHeight() }
M.state.cursorX, M.state.cursorY = 0, 0
press(gbr)
drag(gbr, 0, 0)
M.state.mouseDown = false
drag(gbr, 50, 0)
check("button released elsewhere ends the drag", gbr:GetScript("OnUpdate"), nil)
M.state.mouseDown = true
Settings.ResetProfile()
w1._rect = { 800, 400, 220, w1:GetHeight() }
M.state.cursorX, M.state.cursorY = 0, 0
gbr:GetScript("OnMouseDown")(gbr, "RightButton")
check("right click starts nothing", gbr:GetScript("OnUpdate"), nil)
gbr:GetScript("OnMouseUp")(gbr, "RightButton")
check("right click writes nothing", ns.DB().windows, nil)

-- Top grips stay clear of the header buttons (frame-local rects, y down).
for _, style in ipairs({ "FOREVER", "COMPACT" }) do
    Settings.ResetProfile()
    Windows.ApplyStylePreset(style)
    local lk = Windows.Look()
    local W = Windows.Config(1).width
    local order = lk.allButtons and 4 or 3
    local g = w1.grips.TOPRIGHT
    local p = g._lastPoint
    check(style .. ": top-right grip hangs off the corner", p[1] .. "," .. p[3] .. "," .. p[4] .. "," .. p[5], "BOTTOMLEFT,TOPRIGHT,-3,-3")
    local gl = w1.grips.TOPLEFT._lastPoint
    check(style .. ": top-left grip", gl[1] .. "," .. gl[4] .. "," .. gl[5], "BOTTOMRIGHT,3,-3")
    -- rect of the grip: x in [W-3, W+9], y (down) from -9 to +3
    local gx0, gx1, gy0, gy1 = W - 3, W + 9, -9, 3
    local right = W - (lk.glow and 4 or 2)
    local top = (lk.header - lk.button) / 2
    local overlap = false
    for k = 1, order do
        local bx1 = right - (k - 1) * (lk.button + 1)
        local bx0 = bx1 - lk.button
        local by0, by1 = top, top + lk.button
        if bx0 < gx1 and bx1 > gx0 and by0 < gy1 and by1 > gy0 then overlap = true end
    end
    check(style .. ": no overlap with header buttons", overlap, false)
    -- the title side: the left grip and the drag handle icon
    check(style .. ": left grip reaches only 3 px in", w1.grips.TOPLEFT._lastPoint[4], 3)
end
Settings.ResetProfile()
local grip = w1.grips.BOTTOMRIGHT
Windows.ToggleLock(1)
M.state.cursorX, M.state.cursorY = 0, 0
grip:GetScript("OnMouseDown")(grip, "LeftButton")
M.state.cursorX = 300
check("locked: no resize started", grip:GetScript("OnUpdate"), nil)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
check("locked: no resize", Windows.Config(1).width, 220)
Settings.Set("fadeAlpha", 50)
w1._mouseOver = false
Windows.Tick(0.02)
check("fades when locked", w1:GetAlpha(), 0.5)
w1._mouseOver = true
Windows.Tick(0.02)
check("mouse over: opaque", w1:GetAlpha(), 1)
w1._mouseOver = false
Settings.ResetProfile()
Windows.Tick(0.02)
check("reset profile: default size", w1:GetWidth(), 220)
check("reset profile: unlocked", Windows.Config(1).locked, false)

section("Windows: menus and buttons")
M.menus = {}
local hb = w1.header.buttons
hb.menu:GetScript("OnClick")(hb.menu, "LeftButton")
local menu = M.LastMenu()
check("menu opened", menu ~= nil, true)
for _, label in ipairs({ "Report", "New window", "Close window", "Lock window", "Reset data", "Options" }) do
    check("menu has " .. label, M.MenuFind(menu, label) ~= nil, true)
end
check("gear menu: no mode entry", M.MenuFind(menu, "Mode"), nil)
check("gear menu: no session entry", M.MenuFind(menu, "Session"), nil)
check("gear menu: no threat entry", M.MenuFind(menu, "Threat"), nil)
-- Right-click on the title: the mode menu
M.menus = {}
w1.header:GetScript("OnClick")(w1.header, "RightButton")
local modeMenu = M.LastMenu()
check("right-click on the title: mode menu", M.MenuFind(modeMenu, "Healing") ~= nil, true)
check("mode menu: no gear entries", M.MenuFind(modeMenu, "New window"), nil)
check("mode menu: threat listed", M.MenuFind(modeMenu, "Threat") ~= nil, true)
local damageItem = M.MenuFind(modeMenu, "Damage")
check("mode menu: current is checked", damageItem.isSelected(damageItem.data), true)
local healItem = M.MenuFind(modeMenu, "Healing")
check("mode menu: others unchecked", healItem.isSelected(healItem.data), false)
M.MenuClick(healItem)
check("mode menu: picks the mode", Windows.Mode(1), "healing")
check("mode menu: radio follows", healItem.isSelected(healItem.data), true)
M.MenuClick(M.MenuFind(modeMenu, "Threat"))
check("mode menu: threat", Windows.Mode(1), "threat")
Windows.SetMode(1, "damage")
check("no mode button", hb.mode, nil)
-- The session button
M.menus = {}
hb.session:GetScript("OnClick")(hb.session, "LeftButton")
local sessMenu = M.LastMenu()
check("session button: menu", sessMenu ~= nil, true)
local cur, ovr = M.MenuFind(sessMenu, "Current"), M.MenuFind(sessMenu, "Overall")
check("session menu: current and overall", cur ~= nil and ovr ~= nil, true)
check("session menu: current checked", cur.isSelected(cur.data), true)
M.MenuClick(ovr)
check("session menu: overall", Windows.View(1), "overall")
check("session menu: overall checked", ovr.isSelected(ovr.data), true)
local past = M.MenuFind(sessMenu, "Hogger (0:42)")
check("session menu: past fights listed", past ~= nil, true)
M.MenuClick(past)
check("session menu: past fight", Windows.View(1), 4)
check("session menu: past checked", past.isSelected(past.data), true)
hb.session:GetScript("OnClick")(hb.session, "RightButton")
check("session button right-click: same menu", M.MenuFind(M.LastMenu(), "Overall") ~= nil, true)
GameTooltip._lines = nil
hb.session:GetScript("OnEnter")(hb.session)
check("session tooltip names the current session", Windows.SessionLabel(1), "Hogger (0:42)")
Windows.SetView(1, "overall")
check("session label: overall", Windows.SessionLabel(1), "Overall")
Windows.SetView(1, "current")
check("session label: current", Windows.SessionLabel(1), "Current")
check("title tooltip hint exists", ns.L.TIP_HEADER ~= nil, true)
M.MenuClick(M.MenuFind(menu, "Lock window"))
check("menu: lock", Windows.Config(1).locked, true)
Windows.ToggleLock(1)
M.MenuClick(M.MenuFind(menu, "New window"))
check("menu: new window", S("windowCount"), 2)
Windows.OpenMenu(2, Windows.Frame(2).header)
M.MenuClick(M.MenuFind(M.LastMenu(), "Close window"))
check("menu: close window", S("windowCount"), 1)
M.MenuClick(M.MenuFind(menu, "Options"))
check("menu: options", ns.Window.IsShown(), true)
ns.Window.Toggle()
Windows.SetView(1, "current")
M.popups = {}
local resets = M.dm.resets
hb.reset:GetScript("OnClick")(hb.reset, "LeftButton")
check("reset asks first", M.popups[1] and M.popups[1].which, "FOREVERCOMBATMETER_RESET")
check("not yet reset", M.dm.resets, resets)
StaticPopupDialogs.FOREVERCOMBATMETER_RESET.OnAccept()
check("reset after confirm", M.dm.resets, resets + 1)
M.popups = {}
M.state.combat = true
M.chat = {}
hb.reset:GetScript("OnClick")(hb.reset, "LeftButton")
check("no reset in combat", M.dm.resets, resets + 1)
check("in combat: no popup", #M.popups, 0)
check("in combat: message", M.chat[1] ~= nil, true)
M.state.combat = false
check("lock button", hb.lock:GetScript("OnClick") ~= nil, true)
hb.lock:GetScript("OnClick")(hb.lock, "LeftButton")
check("lock button locks", Windows.Config(1).locked, true)
hb.lock:GetScript("OnClick")(hb.lock, "LeftButton")

section("Windows: compact style")
check("forever header", w1.header:GetHeight(), 24)
check("forever glow", w1.header.shine:IsShown(), true)
check("forever buttons", hb.session:IsShown() and hb.reset:IsShown() and hb.lock:IsShown() and hb.menu:IsShown(), true)
check("forever button size", hb.menu:GetWidth(), 16)
Windows.ApplyStylePreset("COMPACT")
check("style set", S("style"), "COMPACT")
check("preset bar height", S("barHeight"), 14)
check("preset spacing", S("barSpacing"), 0)
Windows.Refresh(1)
check("compact header", w1.header:GetHeight(), 18)
check("compact: no glow", w1.header.shine:IsShown(), false)
check("compact: no reset button", hb.reset:IsShown(), false)
check("compact: menu, lock and session shown", hb.menu:IsShown() and hb.lock:IsShown() and hb.session:IsShown(), true)
-- At the narrowest width the three buttons leave room for a title.
Windows.SetConfig(1, { width = Windows.RANGES.width[1] })
check("compact minimum width: buttons fit with a title", Windows.RANGES.width[1] - 3 * hb.menu:GetWidth() - 8 >= 60, true)
Windows.SetConfig(1, { width = 220 })
check("compact button size", hb.menu:GetWidth(), 12)
check("compact title size", select(2, w1.header.title:GetFont()), 11)
check("compact: no padding", bar(1, 1)._lastPoint[4], 0)
check("compact: square", w1.clip.radius, 0)
Settings.Set("cornerRadius", 6)
Windows.Refresh(1)
check("compact: radius when set", w1.clip.radius, 6)
Settings.Set("barHeight", 16)
check("preset values stay editable", S("barHeight"), 16)
Windows.ApplyStylePreset("FOREVER")
Windows.Refresh(1)
check("forever again", w1.header:GetHeight(), 24)
check("forever: default bar height", S("barHeight"), 18)
check("forever: rounded", w1.clip.radius, 6)
Settings.ResetProfile()

section("Windows: resize from the default anchor")
Settings.ResetProfile()
w1._rect = { 800, 400, 220, w1:GetHeight() }
M.state.cursorX, M.state.cursorY = 1020, 400
grip = w1.grips.BOTTOMRIGHT
grip:GetScript("OnMouseDown")(grip, "LeftButton")
check("CENTER default stays until the drag is released", Windows.Config(1).point, "CENTER")
M.state.cursorX = 1040
grip:GetScript("OnUpdate")(grip, 0.02)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
check("then TOP, grown to the right", Windows.Config(1).point .. "," .. Windows.Config(1).width .. "," .. Windows.Config(1).x, "TOP,240," .. (800 + 120 - 960))
Settings.ResetProfile()

section("Windows: add keeps the global lock true only while all are locked")
Windows.ToggleLock(1)
check("one window locked: all locked", S("locked"), true)
Windows.Add()
check("a new unlocked window: not all locked", S("locked"), false)
Settings.ResetProfile()

section("Windows: threat warning flash")
party({
    player = { name = "Me", class = "MAGE", raw = 95, value = 1, self = true },
    party1 = { name = "Tank", class = "WARRIOR", tank = true, raw = 100, value = 9 },
})
local samples, listReal = 0, Threat.List
Threat.List = function(...) samples = samples + 1; return listReal(...) end
M.state.combat = true
Windows.Tick(5)
check("warning checked without a threat window", samples, 1)
local fl = Windows.FlashFrame()
check("flash shown", fl ~= nil and fl:IsShown(), true)
check("flash text", fl and txt(fl.text), "Threat: 95%")
check("flash centred on the screen", fl and fl._lastPoint[2] == UIParent, true)
Windows.Tick(1)
check("flash fading", fl:GetAlpha() > 0 and fl:GetAlpha() < 1, true)
Windows.Tick(2)
check("flash gone after ~2.5 s", fl:IsShown(), false)
Windows.Tick(0.2)
check("no second flash while still above", fl:IsShown(), false)
Windows.SetMode(1, "threat")
samples = 0
Windows.Tick(0.2)
check("one sample shared with a threat window", samples, 1)
Windows.SetMode(1, "damage")
world.members.player.raw = 10
Windows.Tick(0.2)
world.members.player.raw = 95
Windows.Tick(0.2)
check("flashes again after dropping below", fl:IsShown(), true)
Windows.Tick(5)
M.Fire("PLAYER_TARGET_CHANGED")
Windows.Tick(0.2)
check("new target flashes again", fl:IsShown(), true)
Windows.Tick(5)
check("same fight: flash gone", fl:IsShown(), false)
M.Fire("PLAYER_REGEN_DISABLED")
Windows.Tick(0.2)
check("new fight on the same target flashes again", fl:IsShown(), true)
Settings.Set("threatWarn", false)
samples = 0
Windows.Tick(0.2)
check("warning off: no sampling", samples, 0)
Settings.Set("threatWarn", nil)
world.target.attack = false
samples = 0
Windows.Tick(0.2)
check("friendly target: no sampling", samples, 0)
world.target.attack = true
M.state.combat = false
samples = 0
Windows.Tick(0.2)
check("out of combat: no sampling", samples, 0)
Threat.List = listReal
Windows.Tick(5)

section("Windows: font re-layout")
M.timers = {}
Settings.Set("nameFont", "Arial Narrow")
check("re-layout queued after a font change", #M.timers > 0, true)
M.RunTimers()
Settings.Set("nameFont", nil)
M.RunTimers()

section("Windows: export and import")
Settings.ResetProfile()
Windows.Add()
Windows.SetMode(1, "healing")
Windows.SetMode(2, "threat")
Windows.SetView(2, "overall")
Windows.SetConfig(2, { width = 300, rows = 5, point = "TOP", x = 10, y = -20 })
Windows.ToggleLock(2)
local exported = ns.Share.Export()
Settings.ResetProfile()
check("reset: one window", S("windowCount"), 1)
check("reset: window 2 hidden", Windows.Frame(2):IsShown(), false)
check("import windows", ns.Share.Import(exported), true)
check("count back", S("windowCount"), 2)
check("window 2 shown again", Windows.Frame(2):IsShown(), true)
local c2 = Windows.Config(2)
check("mode back", Windows.Mode(1) .. "," .. c2.mode, "healing,threat")
check("view back", c2.view, "overall")
check("size back", c2.width .. "x" .. c2.rows, "300x5")
check("position back", c2.point .. "," .. c2.x .. "," .. c2.y, "TOP,10,-20")
check("lock back", c2.locked, true)
check("frame width applied", Windows.Frame(2):GetWidth(), 300)
Settings.ResetProfile()
check("bad window values cleaned", ns.Share.Import(
    "FCM1:ts7:windowstn1;ts4:modes5:boguss4:rowsn999;s6:lockeds3:yess4:views5:dummys5:points4:EVIL}n9;ts4:modes7:healing}}}"), true)
check("bad mode dropped", ns.DB().windows[1].mode, nil)
check("rows clamped", ns.DB().windows[1].rows, 40)
check("bad lock dropped", ns.DB().windows[1].locked, nil)
check("bad view dropped", ns.DB().windows[1].view, nil)
check("bad point dropped", ns.DB().windows[1].point, nil)
check("window 9 dropped", ns.DB().windows[9], nil)
check("windows not a table: skipped", ns.Share.Import("FCM1:ts7:windowsn5;}"), true)
check("skipped value", ns.DB().windows, nil)
Settings.ResetProfile()

-- The language switch.
ns.Locale.Set("deDE")
check("German", ns.L.PAGE_GENERAL, "Allgemein")
check("stored account wide", ForeverCombatMeterProfiles.language, "deDE")
ns.Locale.Set("AUTO")
check("auto follows the game", ns.L.PAGE_GENERAL, "General")
check("auto stores nothing", ForeverCombatMeterProfiles.language, nil)

section("Detail: tooltip, breakdown, recap")
do
    local Detail, Report = ns.Detail, ns.Report
    check("Detail exists", Detail ~= nil, true)
    check("Report exists", Report ~= nil, true)
    check("bar scripts hooked", Windows.BarScripts.enter ~= nil and Windows.BarScripts.leave ~= nil and Windows.BarScripts.click ~= nil, true)
    check("detail defaults", D.detailPoint .. "," .. D.detailX .. "," .. D.detailY, "CENTER,0,150")
    Settings.ResetProfile()
    M.state.combat = false
    M.state.playerGUID = "Player-1-0001"
    local function sp(id, total, ps, creature) return { spellID = id, totalAmount = total, amountPerSecond = ps, creatureName = creature or "" } end
    local many = {}
    for k = 1, 7 do many[k] = sp(1000 + k, 10 * k, k, "") end
    M.dm.byType[CUR] = {
        [T.DamageDone] = { totalAmount = 1000, combatSources = {
            source("Bob", "Player-2", 300, 30, { classFilename = "MAGE", specIconID = 135932,
                spells = { sp(133, 100, 10), sp(116, 200, 20) } }),
            source("Me", "Player-1-0001", 500, 25, { isLocalPlayer = true, spells = many }),
            source("Wolf", nil, 200, 4, { sourceCreatureID = 69, classFilename = "", spells = { sp(17253, 200, 4) } }) } },
        [T.DamageTaken] = { totalAmount = 400, combatSources = {
            source("Me", "Player-1-0001", 400, 8, { isLocalPlayer = true,
                spells = { sp(88163, 300, 6, "Ogre"), sp(116, 100, 2, "") } }) } },
        [T.Deaths] = { totalAmount = 1, combatSources = {
            source("Bob", "Player-2", 1, 0, { deathRecapID = 7, deathTimeSeconds = 65 }),
            source("Me", "Player-1-0001", 1, 0, { isLocalPlayer = true }) } },
    }
    M.dm.duration[CUR] = 50
    M.spells[88163] = { "Cleave", 132338 }
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)
    local function wbar(k) return Windows.Frame(1).bars[k] end
    local function text(v) return M.Reveal(v) end
    local function find(lines, left)
        for _, l in ipairs(lines) do if text(l.left) == left then return l end end
    end

    -- Tooltip lines
    local bob = wbar(2).row
    local lines = Detail.Lines("damage", "current", bob)
    check("tooltip: title is the name", text(lines[1].left), "Bob")
    check("tooltip: total", text(find(lines, ns.L.DETAIL_TOTAL).right), "300")
    check("tooltip: per second", text(find(lines, ns.L.DETAIL_PER_SECOND).right), "30.0")
    check("tooltip: share", text(find(lines, ns.L.DETAIL_SHARE).right), "30.0%")
    check("tooltip: top spell first", find(lines, "Frostbolt") ~= nil, true)
    check("tooltip: spell value with percent", find(lines, "Frostbolt") and text(find(lines, "Frostbolt").right), "200 (66.7%)")
    check("tooltip: second spell", find(lines, "Fireball") ~= nil, true)
    check("tooltip: no after-combat line", find(lines, ns.L.DETAIL_AFTER_COMBAT), nil)
    local me = wbar(1).row
    local mine = Detail.Lines("damage", "current", me)
    local spellLines = 0
    for _, l in ipairs(mine) do if text(l.left):match("^#") then spellLines = spellLines + 1 end end
    check("tooltip: five spells at most", spellLines, 5)
    check("tooltip: biggest first", find(mine, "#1007") ~= nil, true)
    check("tooltip: sixth absent", find(mine, "#1002"), nil)
    local taken = Detail.Lines("taken", "current", me)
    check("tooltip: creature suffix", find(taken, "Cleave \194\183 Ogre") ~= nil, true)
    check("tooltip: no suffix without creature", find(taken, "Frostbolt") ~= nil, true)

    -- Hover on a real bar
    GameTooltip:Hide()
    wbar(2):GetScript("OnEnter")(wbar(2))
    check("hover: tooltip owner", GameTooltip._owner, wbar(2))
    check("hover: tooltip lines", GameTooltip._lines and #GameTooltip._lines > 3, true)
    check("hover: title", GameTooltip._lines[1] and text(GameTooltip._lines[1][1]), "Bob")
    wbar(2):GetScript("OnLeave")(wbar(2))
    check("leave: tooltip hidden", GameTooltip._shown, false)

    -- Deaths
    Windows.SetMode(1, "deaths")
    Windows.Refresh(1)
    local dead = wbar(1).row
    check("deaths row has a recap", dead.recapID, 7)
    local dl = Detail.Lines("deaths", "current", dead)
    check("deaths tooltip: time of death", find(dl, ns.L.DETAIL_DIED_AT:format("1:05")) ~= nil, true)
    local recapLines, firstRecap, lastRecap = 0, nil, nil
    for _, l in ipairs(dl) do
        if l.recap then recapLines = recapLines + 1; firstRecap = firstRecap or l; lastRecap = l end
    end
    check("deaths tooltip: six hits", recapLines, 6)
    check("deaths tooltip: oldest first", firstRecap and text(firstRecap.right), "100")
    check("deaths tooltip: killing blow last", lastRecap and text(lastRecap.right), "900")
    local nodead = Detail.Lines("deaths", "current", wbar(2).row)
    check("deaths tooltip: no recap", find(nodead, ns.L.DETAIL_NO_RECAP) ~= nil, true)

    -- Breakdown panel
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)
    check("panel hidden at start", Detail.Frame() == nil or not Detail.Frame():IsShown(), true)
    wbar(2):GetScript("OnMouseUp")(wbar(2), "LeftButton")
    local p = Detail.Frame()
    check("click opens the panel", p ~= nil and p:IsShown(), true)
    check("panel title", text(p.header.title:GetText()), "Bob \226\128\148 Damage")
    check("panel spell rows", Detail.Count(), 2)
    check("panel row 1 name", text(p.rows[1].name:GetText()), "Frostbolt")
    check("panel row 1 value", text(p.rows[1].value:GetText()), "200 (20.0, 66.7%)")
    check("panel row 2 name", text(p.rows[2].name:GetText()), "Fireball")
    check("panel row 1 fill", p.rows[1]._value, 200)
    check("panel row 1 icon", p.rows[1].icon._texture, 135846)
    check("panel row 3 absent or hidden", p.rows[3] == nil or not p.rows[3]:IsShown(), true)
    check("panel is movable", p:IsMovable(), true)
    check("panel on the profile position", p._lastPoint[1] .. "," .. p._lastPoint[4] .. "," .. p._lastPoint[5], "CENTER,0,150")
    Windows.BarScripts.click(wbar(3), 1, "RightButton")
    check("right click on a bar keeps the panel", text(p.header.title:GetText()), "Bob \226\128\148 Damage")
    -- drag by the header
    p._rect = { 800, 500, 260, 200 }
    p.header:GetScript("OnMouseDown")(p.header, "LeftButton")
    check("header drag starts moving", p._moving, true)
    p.header:GetScript("OnMouseUp")(p.header, "LeftButton")
    check("header drag stops", p._moving, false)
    check("position saved: point", ns.DB().detailPoint, "TOP")
    check("position saved: x", ns.DB().detailX, 800 + 130 - 960)
    check("position saved: y", ns.DB().detailY, 700 - 1080)
    -- close
    p.close:GetScript("OnClick")(p.close)
    check("close button hides", p:IsShown(), false)
    Windows.BarScripts.click(wbar(1), 1, "LeftButton")
    check("reopens at the saved place", p._lastPoint[1], "TOP")
    check("own title", text(p.header.title:GetText()), "Me \226\128\148 Damage")
    check("seven spells shown (own)", Detail.Count(), 7)
    Detail.Close()

    -- Creature suffix in the panel
    Windows.SetMode(1, "taken")
    Windows.Refresh(1)
    Windows.BarScripts.click(wbar(1), 1, "LeftButton")
    check("panel: creature suffix", text(p.rows[1].name:GetText()), "Cleave \194\183 Ogre")
    check("panel: no suffix", text(p.rows[2].name:GetText()), "Frostbolt")
    Detail.Close()

    -- Death recap panel
    Windows.SetMode(1, "deaths")
    Windows.Refresh(1)
    Windows.BarScripts.click(wbar(1), 1, "LeftButton")
    check("recap panel shown", p:IsShown(), true)
    check("recap panel rows", Detail.Count(), 6)
    check("recap panel: killing blow last", text(p.rows[6].value:GetText()):find("900", 1, true) ~= nil, true)
    check("recap panel: oldest first", text(p.rows[1].value:GetText()):find("100", 1, true) ~= nil, true)
    Detail.Close()
    Windows.BarScripts.click(wbar(2), 1, "LeftButton")
    check("no recap: message row", text(p.rows[1].name:GetText()), ns.L.DETAIL_NO_RECAP)
    Detail.Close()

    -- In combat
    Windows.SetMode(1, "damage")
    M.state.combat = true
    Windows.Refresh(1)
    local okE = pcall(function() Windows.BarScripts.enter(wbar(1), 1) end)
    check("combat: tooltip raises nothing", okE, true)
    local other, own
    for k = 1, 3 do
        local r = wbar(k).row
        if r.isPlayer then own = r elseif not other and r.guid == nil and r.creatureID == nil then other = r end
    end
    local cl = Detail.Lines("damage", "current", other)
    check("combat: others unreadable", find(cl, ns.L.DETAIL_AFTER_COMBAT) ~= nil, true)
    local ol = Detail.Lines("damage", "current", own)
    check("combat: own spells readable", find(ol, ns.L.DETAIL_AFTER_COMBAT), nil)
    check("combat: own total", text(find(ol, ns.L.DETAIL_TOTAL).right), "500")
    local okC = pcall(function() Detail.Open(1, other) end)
    check("combat: panel opens without raising", okC, true)
    check("combat: panel says after combat", text(p.rows[1].name:GetText()), ns.L.DETAIL_AFTER_COMBAT)
    check("combat: panel title with a secret name", text(p.header.title:GetText()), "Bob \226\128\148 Damage")
    check("combat: refresh raises nothing", (pcall(Detail.Refresh)), true)
    Detail.Close()
    M.spells[1001] = { "Pyroblast", 135808 }   -- secret rows keep the API order
    Detail.Open(1, own)
    check("combat: own breakdown in the panel", Detail.Count(), 7)
    local icon1 = p.rows[1].icon:GetTexture()
    check("combat: secret spell icon reaches SetTexture unchanged", M.IsSecret(icon1) and M.Reveal(icon1), 135808)
    check("combat: unknown spell keeps the question mark", p.rows[2].icon:GetTexture(), 134400)
    M.spells[1001] = nil
    check("combat: own value is a secret display string", M.IsSecret(p.rows[1].value:GetText()), true)
    check("combat: own refresh raises nothing", (pcall(Detail.Refresh)), true)
    Detail.Close()
    Windows.SetMode(1, "deaths")
    check("combat: death lines raise nothing", (pcall(Detail.Lines, "deaths", "current", wbar(1).row)), true)
    M.state.combat = false
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)

    -- Opened in combat on another player: never resolved by rank afterwards.
    local src = M.dm.byType[CUR][T.DamageDone].combatSources
    src[1].totalAmount = 600
    M.state.combat = true
    Windows.Refresh(1)
    Detail.Open(1, wbar(1).row)
    check("stale: after combat line first", text(p.rows[1].name:GetText()), ns.L.DETAIL_AFTER_COMBAT)
    check("stale: title is secret in combat", M.IsSecret(p.header.title:GetText()), true)
    -- another player of the same class takes Bob's rank
    src[1], src[3] = src[3], src[1]
    src[1].classFilename = src[3].classFilename
    M.state.combat = false
    Windows.Refresh(1)
    Detail.Refresh()
    check("stale: generic plain title", p.header.title:GetText(), "Damage")
    check("stale: reopen hint", text(p.rows[1].name:GetText()), ns.L.DETAIL_REOPEN)
    check("stale: one row", Detail.Count(), 1)
    -- reopening from the bar after combat works
    for k = 1, 3 do if wbar(k).row.guid == "Player-2" then Detail.Open(1, wbar(k).row) end end
    check("reopen: Bob's title", p.header.title:GetText(), "Bob \226\128\148 Damage")
    check("reopen: Bob's spells", text(p.rows[1].name:GetText()), "Frostbolt")
    Detail.Close()
    -- own row keeps working across the boundary
    M.state.combat = true
    Windows.Refresh(1)
    local mine
    for k = 1, 3 do if wbar(k).row.isPlayer then mine = wbar(k).row end end
    Detail.Open(1, mine)
    M.state.combat = false
    Windows.Refresh(1)
    Detail.Refresh()
    check("own row: spells after combat", Detail.Count(), 7)
    Detail.Close()

    -- The panel: icons, scrolling, resizing while unlocked
    Settings.ResetProfile()
    check("detail width default", D.detailWidth, 300)
    check("detail rows default", D.detailRows, 20)
    local lots = {}
    for k = 1, 30 do lots[k] = sp(2000 + k, 1000 - k, 1) end
    lots[30] = sp(9999, 1, 1)   -- unknown to the spell database: no icon
    for k = 1, 29 do M.spells[2000 + k] = { "Spell" .. k, 100000 + k } end
    M.dm.byType[CUR][T.DamageDone] = { totalAmount = 1000, combatSources = {
        source("Me", "Player-1-0001", 500, 25, { isLocalPlayer = true, spells = lots }) } }
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)
    Windows.BarScripts.click(wbar(1), 1, "LeftButton")
    local p = Detail.Frame()
    check("many spells: default rows", Detail.Count(), 20)
    for k = 1, 20 do
        local row = p.rows[k]
        local ip, ir, irp = row.icon:GetPoint()
        check("row " .. k .. " icon has a texture", row.icon._texture ~= nil, true)
        check("row " .. k .. " icon sits left of its bar", ip .. "," .. irp, "RIGHT,LEFT")
        check("row " .. k .. " icon is on its bar", ir, row)
        local _, _, _, bx = row:GetPoint()
        check("row " .. k .. " bar starts after the icon", bx >= S("padding") + row.icon:GetWidth(), true)
        check("row " .. k .. " icon is square, row high", row.icon:GetWidth() == row:GetHeight() and row.icon:GetHeight() == row:GetHeight(), true)
        check("row " .. k .. " icon cropped", row.icon._texCoord ~= nil and row.icon._texCoord[1], 0.08)
    end
    Settings.Set("detailRows", 30)
    check("rows setting: all thirty", Detail.Count(), 30)
    check("last spell without icon: question mark", p.rows[30].icon._texture, 134400)
    Settings.Set("detailRows", 8)
    check("rows setting: eight", Detail.Count(), 8)
    check("scroll offset starts at 0", Detail.Offset(), 0)
    local wheel = p.body:GetScript("OnMouseWheel")
    wheel(p.body, -1)
    check("wheel down scrolls one", Detail.Offset(), 1)
    check("wheel: first row moved", text(p.rows[1].name:GetText()), "Spell2")
    wheel(p.body, 1)
    check("wheel up scrolls back", Detail.Offset(), 0)
    wheel(p.body, 1)
    check("wheel up stops at the top", Detail.Offset(), 0)
    wheel(p.body, -100)
    check("wheel down stops at the end", Detail.Offset(), 22)
    check("wheel: last row is the last spell", text(p.rows[8].name:GetText()) ~= nil, true)
    wheel(p.body, 100)

    -- grips only while unlocked
    Settings.SetLocked(false)
    local n = 0
    for _, g in pairs(p.grips) do if g:IsShown() then n = n + 1 end end
    check("unlocked: four grips", n, 4)
    p.lock:GetScript("OnClick")(p.lock)
    check("panel lock button locks all", S("locked"), true)
    n = 0
    for _, g in pairs(p.grips) do if g:IsShown() then n = n + 1 end end
    check("locked: no grips", n, 0)
    p.lock:GetScript("OnClick")(p.lock)
    check("panel lock button unlocks", S("locked"), false)

    -- resize towards each corner, the opposite corner fixed
    local H0 = p:GetHeight()
    for _, corner in ipairs({ "TOPRIGHT", "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT" }) do
        Settings.SetMany({ detailWidth = 300, detailRows = 8 })
        H0 = p:GetHeight()
        local left, bottom = 500, 300
        p._rect = { left, bottom, 300, H0 }
        local g = p.grips[corner]
        M.state.mouseDown = true
        M.state.cursorX, M.state.cursorY = 100, 100
        press(g)
        drag(g, 100 + (corner:find("RIGHT") and 60 or -60), 100 + (corner:find("TOP") and 80 or -80))
        local step = S("barHeight") + S("barSpacing")
        local wantRows = 8 + math.floor(80 / step)
        check(corner .. ": live width", p:GetWidth(), 360)
        check(corner .. ": live rows", p.laidRows, wantRows)
        check(corner .. ": nothing stored while dragging", ns.DB().detailWidth, nil)
        release(g)
        check(corner .. ": width saved", S("detailWidth"), 360)
        check(corner .. ": rows saved", S("detailRows"), wantRows)
        check(corner .. ": TOP anchor", S("detailPoint"), "TOP")
        local w, h = 360, p:GetHeight()
        local cx, top = 960 + S("detailX"), 1080 + S("detailY")
        local l, r, b, t = cx - w / 2, cx + w / 2, top - h, top
        if corner:find("RIGHT") then near(corner .. ": left fixed", l, left) else near(corner .. ": right fixed", r, left + 300) end
        if corner:find("TOP") then near(corner .. ": bottom fixed", b, bottom) else near(corner .. ": top fixed", t, bottom + H0) end
    end
    Settings.SetMany({ detailWidth = 300, detailRows = 8 })
    p._rect = { 500, 300, 300, p:GetHeight() }
    press(p.grips.TOPRIGHT)
    drag(p.grips.TOPRIGHT, 100 + 5000, 100 + 5000)
    release(p.grips.TOPRIGHT)
    check("width clamped", S("detailWidth"), 600)
    check("rows clamped", S("detailRows"), 40)
    Settings.SetLocked(true)
    M.state.cursorX, M.state.cursorY = 100, 100
    press(p.grips.TOPRIGHT)
    check("locked: no resize starts", p.resizing, nil)
    Settings.SetLocked(false)
    Detail.Close()
    Settings.ResetProfile()
    Windows.Refresh(1)
end

section("Report")
do
    local Report, Detail = ns.Report, ns.Detail
    Settings.ResetProfile()
    M.state.combat = false
    M.state.group = false
    M.state.instance = nil
    world.raid = false
    -- Lines leave one per timer tick: let the queue run dry first.
    local function drain()
        for _ = 1, 50 do
            if Report.Pending() == 0 and #M.timers == 0 then return end
            M.RunTimers()
        end
    end
    local function sent()
        drain()
        local t = {}
        for _, s in ipairs(M.sent) do t[#t + 1] = s.channel .. ":" .. s.msg end
        return t
    end
    local function reset() M.sent = {}; M.chat = {} end
    local function chat()
        local t = {}
        for _, m in ipairs(M.chat) do t[#t + 1] = M.Reveal(m) end
        return table.concat(t, "\n")
    end
    check("channel: none", Report.Channel(), nil)
    M.state.instance = { kind = "party", name = "Dungeon" }
    check("channel: say inside an instance", Report.Channel(), "SAY")
    M.state.group = true
    check("channel: party", Report.Channel(), "PARTY")
    world.raid = true
    check("channel: raid", Report.Channel(), "RAID")
    M.state.group, M.state.instanceGroup = false, true
    check("channel: finder group", Report.Channel(), "INSTANCE_CHAT")
    world.raid = true
    check("channel: finder raid", Report.Channel(), "INSTANCE_CHAT")
    M.state.group = true
    check("channel: home party wins over the finder", Report.Channel(), "RAID")
    M.state.instanceGroup = false
    world.raid = false
    M.state.group = false
    M.state.instance = nil

    local function sp(id, total, ps) return { spellID = id, totalAmount = total, amountPerSecond = ps, creatureName = "" } end
    M.dm.byType[CUR] = {
        [T.DamageDone] = { totalAmount = 2000, combatSources = {
            source("Bob", "Player-2", 300, 30, { classFilename = "MAGE", spells = { sp(133, 100, 10), sp(116, 200, 20) } }),
            source("Me", "Player-1-0001", 1500, 25, { isLocalPlayer = true, spells = { sp(78, 1500, 25) } }),
            source("Wolf", nil, 200, 4, { sourceCreatureID = 69, classFilename = "" }) } } }
    M.dm.duration[CUR] = 50
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)

    reset()
    M.state.group = true
    world.raid = true
    check("window report: ok", Report.Window(1, 2), true)
    local s = sent()
    check("window report: header + 2 lines", #s, 3)
    check("window report: header", s[1], "RAID:Forever Combat Meter: Damage \194\183 Current")
    check("window report: first line", s[2], "RAID:1. Me  1.5k (75.0%)")
    check("window report: second line", s[3], "RAID:2. Bob  300 (15.0%)")
    check("window report: via the global sender", M.sent[1].via, "global")
    -- One line now, the next one per 0.2 s timer.
    reset()
    M.timers = {}
    Report.Window(1, 2)
    check("throttle: first line at once", #M.sent, 1)
    check("throttle: rest queued", Report.Pending(), 2)
    local function tick() local l = M.timers; M.timers = {}; for _, fn in ipairs(l) do fn() end end
    tick()
    check("throttle: one more per tick", #M.sent, 2)
    Report.Window(1, 1)
    check("throttle: a second report waits behind the first", #M.sent, 2)
    tick(); tick(); tick()
    check("throttle: all sent in order", #M.sent == 5 and M.sent[3].msg:find("2. Bob", 1, true) ~= nil, true)
    tick()
    check("throttle: queue empty", Report.Pending(), 0)
    tick()
    check("throttle: idle again", #M.timers, 0)
    reset()
    Settings.Set("reportLines", 3)
    Report.Window(1)
    check("window report: default line count from the setting", #sent(), 4)
    reset()
    Report.Window(1, 99)
    check("window report: capped at the rows", #sent(), 4)
    Settings.Set("reportLines", nil)

    reset()
    world.raid = false
    Report.Window(1, 1)
    check("party channel", sent()[2], "PARTY:1. Me  1.5k (75.0%)")
    reset()
    M.state.group = false
    M.state.instance = { kind = "party", name = "Dungeon" }
    Report.Window(1, 1)
    check("say inside an instance", sent()[2], "SAY:1. Me  1.5k (75.0%)")
    reset()
    M.state.instance = nil
    check("local report: ok", Report.Window(1, 1), true)
    check("local report: nothing sent", #sent(), 0)
    check("local report: printed", chat():find("1. Me  1.5k (75.0%)", 1, true) ~= nil, true)

    -- C_ChatInfo wins when present
    C_ChatInfo = { SendChatMessage = function(msg, channel) M.sent[#M.sent + 1] = { msg = msg, channel = channel, via = "C_ChatInfo" } end }
    reset()
    M.state.group = true
    Report.Window(1, 1)
    drain()
    check("uses C_ChatInfo.SendChatMessage", M.sent[1] and M.sent[1].via, "C_ChatInfo")
    C_ChatInfo = nil

    -- Refusal with secret values
    reset()
    M.state.combat = true
    Windows.Refresh(1)
    local okR, res = pcall(Report.Window, 1, 3)
    check("secret: raises nothing", okR, true)
    check("secret: refused", res, false)
    check("secret: nothing sent", #sent(), 0)
    check("secret: localized message", chat():find(ns.L.REPORT_SECRET, 1, true) ~= nil, true)
    reset()
    local own
    for k = 1, 3 do if Windows.Frame(1).bars[k].row.isPlayer then own = Windows.Frame(1).bars[k].row end end
    Detail.Open(1, own)
    local okS, resS = pcall(Report.Spells, Detail.Source(), 3)
    check("secret spells: raises nothing", okS, true)
    check("secret spells: refused", resS, false)
    check("secret spells: nothing sent", #sent(), 0)
    Detail.Close()
    M.state.combat = false

    -- Spells report
    check("creature label is shared", ns.Format.SpellLabel({ name = "Cleave", creature = "Ogre" }), "Cleave \194\183 Ogre")
    check("value text is shared", ns.Format.ValueText(1500, 75), "1.5k (75.0%)")
    check("Present: secret", ns.Format.Present(M.Secret(1)), true)
    check("Present: nil", ns.Format.Present(nil), false)
    reset()
    M.state.group = true
    Windows.Refresh(1)
    local bobRow
    for k = 1, 3 do if Windows.Frame(1).bars[k].row.guid == "Player-2" then bobRow = Windows.Frame(1).bars[k].row end end
    Detail.Open(1, bobRow)
    check("spells report: ok", Report.Spells(Detail.Source(), 5), true)
    s = sent()
    check("spells report: header + 2 lines", #s, 3)
    check("spells report: header", s[1], "PARTY:Bob \226\128\148 Damage")
    check("spells report: first", s[2], "PARTY:1. Frostbolt  200 (66.7%)")
    check("spells report: second", s[3], "PARTY:2. Fireball  100 (33.3%)")
    -- Right click on the title reports out of combat
    reset()
    local header = Detail.Frame().header
    header:GetScript("OnClick")(header, "RightButton")
    check("title right click reports", #sent(), 3)
    Detail.Close()
    reset()
    check("empty window report", (function() M.dm.byType[CUR] = {}; Windows.Refresh(1); return Report.Window(1, 3) end)(), false)
    check("empty window report: message", chat():find(ns.L.REPORT_EMPTY, 1, true) ~= nil, true)
    M.state.group = false
end

section("Options pages")
Settings.ResetProfile()
local INTERNAL = { minimapAngle = true, detailPoint = true, detailX = true, detailY = true }
local covered = {}
for _, page in ipairs(ns.Window.PAGES) do
    if page.rows then
        for _, r in ipairs(page.rows()) do
            if r.key then covered[r.key] = true end
        end
    end
end
for key in pairs(Settings.DEFAULTS) do
    if not INTERNAL[key] then check("row for setting " .. key, covered[key], true) end
end
check("windowCount row", covered.windowCount, true)
-- The slider goes through Add / Close: leftovers and the global lock stay right.
do
    local countRow
    for _, page in ipairs(ns.Window.PAGES) do
        for _, r in ipairs(page.rows and page.rows() or {}) do if r.key == "windowCount" then countRow = r end end
    end
    Settings.ResetProfile()
    countRow.set(3)
    Windows.SetConfig(3, { mode = "healing" })
    countRow.set(2)
    Settings.SetLocked(true)
    check("slider: all locked", S("locked"), true)
    countRow.set(3)
    check("slider: count", S("windowCount"), 3)
    check("slider: a new window starts from its defaults", Windows.Mode(3), "damage")
    check("slider: a new unlocked window clears the global lock", S("locked"), false)
    countRow.set(1)
    check("slider: down to one", S("windowCount"), 1)
    check("slider: no leftovers", ns.DB().windows and ns.DB().windows[2], nil)
    Settings.ResetProfile()
end

local RAW = "^[A-Z][A-Z0-9]*_[A-Z0-9_]+$"
for code, strings in pairs(ns.Locales) do
    ns.Locale.Set(code)
    ns.Window.Open("general")
    for _, page in ipairs(ns.Window.PAGES) do
        check(code .. ": page label " .. page.id, strings[page.label] ~= nil, true)
        ns.Window.ShowPage(page.id)
        local raw
        for _, fs in ipairs(M.fontStrings) do
            if fs._text and type(fs._text) == "string" and fs._text:match(RAW) and fs:IsVisible() then raw = fs._text end
        end
        check(code .. ": no raw key shown on " .. page.id, raw, nil)
        if page.rows then
            for _, r in ipairs(page.rows()) do
                if type(r.label) == "string" then check(code .. ": label " .. r.label, strings[r.label] ~= nil, true) end
                for _, b in ipairs(r.buttons or {}) do check(code .. ": button " .. b.label, strings[b.label] ~= nil, true) end
                if r.choices then
                    for _, c in ipairs(r.choices()) do
                        check(code .. ": choice " .. tostring(c.label), type(c.label) == "string" and not c.label:match(RAW), true)
                    end
                end
            end
        end
    end
    ns.Window.Toggle()
end
ns.Locale.Set("AUTO")

local function specRows(id)
    for _, page in ipairs(ns.Window.PAGES) do if page.id == id then return page.rows() end end
end
local function rowByKey(id, key)
    for _, r in ipairs(specRows(id)) do if r.key == key then return r end end
end
local rowStyle = rowByKey("general", "style")
rowStyle.set("COMPACT")
check("style select: style", S("style"), "COMPACT")
check("style select: preset bar height", S("barHeight"), 14)
check("style select: preset spacing", S("barSpacing"), 0)
rowStyle.set("FOREVER")
check("style back: bar height", S("barHeight"), 18)
Settings.ResetProfile()

local function visibleWindows()
    local seen, n = {}, 0
    for _, r in ipairs(specRows("windows")) do
        if r.window and (not r.visible or r.visible()) and not seen[r.window] then seen[r.window] = true; n = n + 1 end
    end
    return n
end
check("windows page: one window block", visibleWindows(), 1)
Settings.Set("windowCount", 3)
check("windows page: three blocks", visibleWindows(), 3)
local function winRow(i, field)
    for _, r in ipairs(specRows("windows")) do
        if r.window == i and r.field == field then return r end
    end
end
winRow(2, "mode").set("threat")
check("windows page: mode", Windows.Mode(2), "threat")
check("windows page: mode get", winRow(2, "mode").get(), "threat")
winRow(2, "view").set("overall")
check("windows page: session", Windows.View(2), "overall")
local modeChoices = {}
for _, c in ipairs(winRow(1, "mode").choices()) do modeChoices[c.value] = true end
check("mode choices include threat and damage", modeChoices.threat and modeChoices.damage, true)
local function windowButtons()
    local out = {}
    for _, r in ipairs(specRows("windows")) do
        for _, b in ipairs(r.buttons or {}) do out[#out + 1] = { row = r, b = b } end
    end
    return out
end
local newBtn, closeBtn
check("windows page no longer has width", winRow(2, "width"), nil)
for _, e in ipairs(windowButtons()) do
    if e.b.label == "MENU_NEW_WINDOW" then newBtn = e.b end
    if e.row.window == 3 and e.b.label == "MENU_CLOSE_WINDOW" then closeBtn = e.b end
end
check("new window button", newBtn ~= nil, true)
check("close window button on window 3", closeBtn ~= nil, true)
newBtn.onClick()
check("new window button works", S("windowCount"), 4)
closeBtn.onClick()
check("close window button works", S("windowCount"), 3)
Settings.ResetProfile()
Windows.Tick(0.02)

section("Layout page")
Settings.ResetProfile()
Settings.Set("windowCount", 3)
local function layoutRow(field)
    for _, r in ipairs(specRows("layout")) do if r.field == field then return r end end
end
for _, field in ipairs({ "window", "locked", "x", "y", "width", "rows", "scale" }) do
    check("layout row " .. field, layoutRow(field) ~= nil, true)
end
check("layout: window select is hidden with one window", (function()
    Settings.Set("windowCount", 1)
    local hidden = layoutRow("window").visible() == false
    Settings.Set("windowCount", 3)
    return hidden
end)(), true)
layoutRow("window").set(2)
check("layout: picked window", layoutRow("window").get(), 2)
layoutRow("width").set(300)
check("layout: width of the picked window", Windows.Config(2).width, 300)
check("layout: other window untouched", Windows.Config(1).width, 220)
layoutRow("rows").set(5)
check("layout: rows", Windows.Config(2).rows, 5)
check("layout: width get", layoutRow("width").get(), 300)
for i = 1, 3 do
    layoutRow("window").set(i)
    layoutRow("locked").set(true)
    check("layout: lock " .. i, Windows.Config(i).locked, true)
    check("layout: global flag after lock " .. i, S("locked"), i == 3)
end
layoutRow("locked").set(false)
check("layout: unlocking one clears the global flag", S("locked"), false)
layoutRow("window").set(2)
Windows.SetConfig(2, { scale = 200 })
local w2 = Windows.Frame(2)
check("scale applied to the frame", w2:GetScale(), 2)
w2._rect = { 300, 500, 220, 200 }
check("layout: X is the real position", layoutRow("x").get(), -140)
check("layout: Y is the real position", layoutRow("y").get(), 320)
layoutRow("x").set(-100)
check("layout: X stored in the window's units", Windows.Config(2).x, -50)
check("layout: X stored as TOP", Windows.Config(2).point, "TOP")
layoutRow("y").set(-200)
check("layout: Y stored in the window's units", Windows.Config(2).y, -100)
check("layout: frame placed with the unscaled offset", select(5, w2:GetPoint()), -100 / 2)
Windows.SetConfig(2, { x = 100, y = -40 })
w2._rect = { 470, 400, 220, 100 }
layoutRow("scale").set(150)
check("layout: scale set", Windows.Config(2).scale, 150)
check("layout: scale on the frame", w2:GetScale(), 1.5)
near("layout: scaling keeps the place (X)", Windows.Config(2).x * 1.5, 200)
near("layout: scaling keeps the place (Y)", Windows.Config(2).y * 1.5, -80)
layoutRow("scale").set(500)
check("layout: scale clamped", Windows.Config(2).scale, 200)
Windows.SetConfig(2, { scale = 200 })
-- Below the minimap
local function buttonNamed(label)
    for _, r in ipairs(specRows("layout")) do
        for _, b in ipairs(r.buttons or {}) do if b.label == label then return b end end
    end
end
buttonNamed("OPT_SNAP_MINIMAP").onClick()
near("snap: right edge in line with the minimap", (Windows.Config(2).x * 2 + 960) + Windows.Config(2).width, 1912)
near("snap: top below the minimap", 1080 + Windows.Config(2).y * 2, 767 - 16)
check("snap: TOP anchor", Windows.Config(2).point, "TOP")
buttonNamed("OPT_RESET_POSITION").onClick()
check("reset position: x", Windows.Config(2).x, Windows.Defaults(2).x)
check("reset position: y", Windows.Config(2).y, Windows.Defaults(2).y)
check("reset position: point", Windows.Config(2).point, Windows.Defaults(2).point)
check("reset position keeps the scale", Windows.Config(2).scale, 200)
local pad = specRows("layout")
local function keyRow(key) for _, r in ipairs(pad) do if r.key == key then return r end end end
keyRow("padding").set(2)
check("layout: padding", S("padding"), 2)
keyRow("barSpacing").set(3)
check("layout: bar spacing", S("barSpacing"), 3)
keyRow("fadeAlpha").set(40)
check("layout: fade", S("fadeAlpha"), 40)
keyRow("detailWidth").set(400)
check("layout: panel width", S("detailWidth"), 400)
keyRow("detailRows").set(12)
check("layout: panel rows", S("detailRows"), 12)
Settings.SetMany({ detailPoint = "TOP", detailX = 5, detailY = 5 })
local resets = {}
for _, r in ipairs(pad) do
    for _, b in ipairs(r.buttons or {}) do if b.label == "OPT_RESET_POSITION" then resets[#resets + 1] = b end end
end
check("layout: two reset position buttons", #resets, 2)
resets[2].onClick()
check("layout: panel position reset", S("detailPoint") .. "," .. S("detailX") .. "," .. S("detailY"), "CENTER,0,150")
Windows.ApplyStylePreset("COMPACT")
check("compact preset: padding 0", S("padding"), 0)
Windows.ApplyStylePreset("FOREVER")
check("forever preset: padding back", S("padding"), 4)
Settings.ResetProfile()
check("window scale shared through export", (function()
    Windows.SetConfig(1, { scale = 120 })
    local str = ns.Share.Export()
    Settings.ResetProfile()
    ns.Share.Import(str)
    return Windows.Config(1).scale
end)(), 120)
Settings.ResetProfile()

section("Colours per window and for the panel")
Settings.ResetProfile()
Settings.Set("windowCount", 2)
check("window colour defaults stored as nothing", ns.DB().windows, nil)
Windows.SetConfig(2, { classColor = false, barColor = { 0.9, 0.1, 0.1 } })
check("window 2 own colour", Windows.Config(2).barColor[1], 0.9)
check("window 2 class colour off", Windows.Config(2).classColor, false)
check("window 1 class colour untouched", Windows.Config(1).classColor, true)
check("window 1 colour untouched", Windows.Config(1).barColor[1], 0.45)
check("only differences stored", ns.DB().windows[1], nil)
Windows.SetConfig(2, { classColor = true })
check("class colour back to default: not stored", ns.DB().windows[2].classColor, nil)
Windows.SetConfig(2, { barColor = { 0.45, 0.55, 0.75 } })
check("default colour: nothing stored", ns.DB().windows, nil)
Windows.SetConfig(2, { barColor = { 5, "x", 0 } })
check("bad colour refused", ns.DB().windows, nil)
Windows.SetConfig(2, { classColor = false, barColor = { 0.9, 0.1, 0.1 } })
local str = ns.Share.Export()
Settings.ResetProfile()
check("import with window colours", ns.Share.Import(str), true)
check("round trip: colour", Windows.Config(2).barColor[1], 0.9)
check("round trip: class colour false", Windows.Config(2).classColor, false)
check("round trip: other window", Windows.Config(1).classColor, true)
local c1, c2 = { Windows.ClassColor("MAGE", true, { 1, 0, 0 }) }, { Windows.ClassColor("MAGE", false, { 1, 0, 0 }) }
check("ClassColor: class", c1[1] ~= 1 or c1[2] ~= 0, true)
check("ClassColor: own colour", c2[1] .. c2[2] .. c2[3], "100")
-- Painted per window
M.state.combat = false
M.dm.byType[CUR] = { [T.DamageDone] = { totalAmount = 500, combatSources = {
    source("Bob", "Player-2", 500, 25, { classFilename = "MAGE" }) } } }
Settings.ResetProfile()
Settings.Set("windowCount", 2)
Windows.SetConfig(2, { classColor = false, barColor = { 0.9, 0.1, 0.1 } })
Windows.SetMode(1, "damage"); Windows.SetMode(2, "damage")
Windows.Refresh(1); Windows.Refresh(2)
local b1, b2 = Windows.Frame(1).bars[1], Windows.Frame(2).bars[1]
check("window 1 bar uses class colours", b1._barColor ~= nil and b1._barColor[1] ~= 0.9, true)
check("window 2 bar uses its own colour", b2._barColor ~= nil and b2._barColor[1], 0.9)
Windows.SetMode(2, "threat")
Windows.Refresh(2)
-- Migration of the old global keys
Settings.ResetProfile()
local db = ns.DB()
db.windowCount = 2
db.barClassColor, db.barColor = false, { 0.2, 0.3, 0.4 }
db.windows = { [2] = { classColor = true } }
Settings.Changed(nil)
check("migration: old keys dropped", db.barClassColor == nil and db.barColor == nil, true)
check("migration: window 1 gets class colour off", Windows.Config(1).classColor, false)
check("migration: window 1 gets the colour", Windows.Config(1).barColor[3], 0.4)
check("migration: window 2 keeps its own class colour", Windows.Config(2).classColor, true)
check("migration: window 2 gets the colour", Windows.Config(2).barColor[3], 0.4)
check("migration: no window 3", ns.DB().windows[3], nil)
-- Old export string
Settings.ResetProfile()
ns.DB().barClassColor, ns.DB().barColor, ns.DB().windowCount = false, { 0.2, 0.3, 0.4 }, 2
local oldString = ns.Share.Export()
Settings.ResetProfile()
check("old string imports", ns.Share.Import(oldString), true)
check("old string: keys moved", ns.DB().barColor == nil and ns.DB().barClassColor == nil, true)
check("old string: window 1", tostring(Windows.Config(1).classColor), "false")
check("old string: window 2 colour", Windows.Config(2).barColor[2], 0.3)
Settings.ResetProfile()
-- Options rows
local function barsRow(field) for _, r in ipairs(specRows("bars")) do if r.field == field then return r end end end
Settings.Set("windowCount", 2)
local pickBars = barsRow("window")
pickBars.set(2)
barsRow("classColor").set(false)
check("options: class colour of the picked window", Windows.Config(2).classColor, false)
check("options: other window untouched", Windows.Config(1).classColor, true)
check("options: colour row visible when class colours are off", barsRow("barColor").visible(), true)
barsRow("barColor").set({ 0.3, 0.4, 0.5, 1 })
check("options: colour of the picked window", Windows.Config(2).barColor[3], 0.5)
check("options: colour get", barsRow("barColor").get()[1], 0.3)
pickBars.set(1)
check("options: colour row hidden while class colours are on", barsRow("barColor").visible(), false)
local function bkey(key) for _, r in ipairs(specRows("bars")) do if r.key == key then return r end end end
bkey("detailClassColor").set(false)
check("options: panel class colour", S("detailClassColor"), false)
check("options: panel colour row visible", bkey("detailBarColor").visible(), true)
bkey("detailBarColor").set({ 0.6, 0.6, 0.1, 1 })
check("options: panel colour", S("detailBarColor")[1], 0.6)
check("panel independent of windows", Windows.Config(1).classColor, true)
Windows.Refresh(1)
Windows.BarScripts.click(Windows.Frame(1).bars[1], 1, "LeftButton")
check("panel bars use the panel colour", ns.Detail.Frame().rows[1]._barColor[1], 0.6)
check("window bars still use the class colour", Windows.Frame(1).bars[1]._barColor[1] ~= 0.6, true)
Settings.Set("detailClassColor", true)
check("panel bars use the class colour", ns.Detail.Frame().rows[1]._barColor[1] ~= 0.6, true)
ns.Detail.Close()
Settings.ResetProfile()
layoutRow("window").set(1)

section("Bar icons")
Settings.ResetProfile()
M.state.combat = false
M.dm.byType[CUR] = { [T.DamageDone] = { totalAmount = 900, combatSources = {
    source("Bob", "Player-2", 500, 25, { classFilename = "MAGE", specIconID = 135932 }),
    source("Sue", "Player-3", 300, 15, { classFilename = "ROGUE" }),
    source("Wolf", nil, 100, 5, { sourceCreatureID = 69, classFilename = "" }) } } }
Windows.SetMode(1, "damage")
Windows.Refresh(1)
local ib = Windows.Frame(1).bars
check("icon above the fill (OVERLAY)", ib[1].icon._layer, "OVERLAY")
check("icon not on the fill's layer", ib[1].icon._layer ~= "ARTWORK", true)
check("spec icon: file", ib[1].icon._texture, 135932)
check("spec icon: cropped", ib[1].icon._texCoord[1], 0.08)
check("class without spec: atlas", ib[2].icon._atlas, "classicon-rogue")
check("atlas: texcoord reset to full", ib[2].icon._texCoord[1] .. ib[2].icon._texCoord[2], "01")
-- A reused bar: spec icon first, then a class atlas
Windows.SetMode(1, "damage")
M.dm.byType[CUR][T.DamageDone].combatSources[1] = source("Bob", "Player-2", 500, 25, { classFilename = "MAGE" })
Windows.Refresh(1)
check("reused bar: atlas", ib[1].icon._atlas, "classicon-mage")
check("reused bar: crop reset", ib[1].icon._texCoord[1] .. ib[1].icon._texCoord[2] .. ib[1].icon._texCoord[3] .. ib[1].icon._texCoord[4], "0101")
-- No such atlas on this client: the class sheet
C_Texture = { GetAtlasInfo = function() return nil end }
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 } }
Windows.SetMode(1, "damage")
Windows.Refresh(1)
check("no atlas: class sheet", ib[1].icon._texture, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
check("no atlas: class coords", ib[1].icon._texCoord[1] .. "," .. ib[1].icon._texCoord[2], "0.25,0.5")
check("no atlas: shown", ib[1].icon:IsShown(), true)
check("spec icon still a file", Windows.ChooseIcon(135932, "MAGE"), "file")
CLASS_ICON_TCOORDS = {}
check("neither atlas nor sheet: nothing", Windows.ChooseIcon(nil, "MAGE"), nil)
Windows.Refresh(1)
check("neither: hidden", ib[1].icon:IsShown(), false)
C_Texture, CLASS_ICON_TCOORDS = nil, nil
Windows.Refresh(1)
M.chat = {}
SlashCmdList["FOREVERCOMBATMETER"]("debug icon")
check("/fcm debug icon prints", M.chat[1] ~= nil and M.chat[1]:find("specIcon", 1, true) ~= nil and M.chat[1]:find("class=MAGE", 1, true) ~= nil, true)
Settings.ResetProfile()

section("Blizzard meter switch")
local cvars, cvarWrites = { damageMeterEnabled = "1" }, 0
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, v) cvarWrites = cvarWrites + 1; cvars[name] = v; return true end,
}
Settings.Set("hideBlizzard", true)
check("on: CVar 0", cvars.damageMeterEnabled, "0")
check("on: previous value remembered", ns.AccountDB().blizzardMeterBackup, "1")
Settings.Set("hideBlizzard", false)
check("off: CVar restored", cvars.damageMeterEnabled, "1")
check("off: backup cleared", ns.AccountDB().blizzardMeterBackup, nil)
cvars.damageMeterEnabled = "0"
Settings.Set("hideBlizzard", true)
Settings.Set("hideBlizzard", false)
check("user had it off: stays off", cvars.damageMeterEnabled, "0")
cvars.damageMeterEnabled = "1"
Settings.Set("hideBlizzard", true)
Settings.Set("refresh", 0.5)
cvars.damageMeterEnabled = "1"
M.Fire("PLAYER_LOGIN")
check("login re-applies", cvars.damageMeterEnabled, "0")
check("login keeps the first backup", ns.AccountDB().blizzardMeterBackup, "1")
Settings.ResetProfile()
check("profile reset restores", cvars.damageMeterEnabled, "1")
ns.SwitchProfile("Default")
cvarWrites = 0
cvars.damageMeterEnabled = nil
Settings.Set("hideBlizzard", true)
check("no such CVar: no write", cvarWrites, 0)
check("no such CVar: no backup", ns.AccountDB().blizzardMeterBackup, nil)
Settings.Set("hideBlizzard", false)
check("no such CVar: off writes nothing", cvarWrites, 0)
local savedCVar = C_CVar
C_CVar = nil
check("no C_CVar: no error", pcall(Settings.Set, "hideBlizzard", true), true)
C_CVar = savedCVar
Settings.ResetProfile()
-- The user switches Blizzard's meter by hand while ours is on.
cvars.damageMeterEnabled = "1"
Settings.Set("hideBlizzard", true)
cvars.damageMeterEnabled = "1"; M.Fire("CVAR_UPDATE", "damageMeterEnabled", "1")
cvars.damageMeterEnabled = "0"; M.Fire("CVAR_UPDATE", "damageMeterEnabled", "0")
Settings.Set("hideBlizzard", false)
check("manual off while ours is on is respected", cvars.damageMeterEnabled, "0")
check("manual off: backup cleared", ns.AccountDB().blizzardMeterBackup, nil)
Settings.ResetProfile()
-- Our own write does not overwrite the backup.
cvars.damageMeterEnabled = "1"
Settings.Set("hideBlizzard", true)
M.Fire("CVAR_UPDATE", "damageMeterEnabled", "0")
check("own write keeps the backup", ns.AccountDB().blizzardMeterBackup, "1")
-- A refused write keeps the backup and says so once.
C_CVar.SetCVar = function() error("blocked") end
M.chat = {}
check("refused restore: no error", pcall(Settings.Set, "hideBlizzard", false), true)
check("refused restore: backup kept", ns.AccountDB().blizzardMeterBackup, "1")
Settings.Set("hideBlizzard", true); Settings.Set("hideBlizzard", false)
check("refused write: noted once", #M.chat, 1)
C_CVar.SetCVar = function(name, v) cvars[name] = v; return true end
Settings.Set("hideBlizzard", false)
check("later restore works", cvars.damageMeterEnabled, "1")
Settings.ResetProfile()
check("Blizzard frame never created by us", rawget(_G, "DamageMeter"), nil)
-- Never written in combat: the toggle waits for the end of combat.
cvars.damageMeterEnabled = "1"
ns.SwitchProfile("Plain")   -- a copy without the option
ns.SwitchProfile("Default")
M.state.combat = true
Settings.Set("hideBlizzard", true)
check("combat: CVar untouched", cvars.damageMeterEnabled, "1")
M.Fire("PLAYER_LOGIN")
check("combat login: CVar untouched", cvars.damageMeterEnabled, "1")
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("after combat: written", cvars.damageMeterEnabled, "0")
check("after combat: backup", ns.AccountDB().blizzardMeterBackup, "1")
M.state.combat = true
ns.SwitchProfile("Plain")
check("combat profile switch: CVar untouched", cvars.damageMeterEnabled, "0")
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("profile switch after combat: restored", cvars.damageMeterEnabled, "1")
ns.SwitchProfile("Default")
ns.DeleteProfile("Plain")
Settings.ResetProfile()

section("Gear menu report, slash commands")
local calls = {}
local realReport = ns.Report.Window
ns.Report.Window = function(i, n, ch, t) calls[#calls + 1] = { i, n, ch, t } end
Windows.OpenMenu(1, Windows.Frame(1).header)
M.MenuClick(M.MenuFind(M.MenuFind(M.LastMenu(), "Report"), "Automatic"))
check("menu: report", calls[1] and (calls[1][1] .. "," .. calls[1][2] .. "," .. calls[1][3]) or "none", "1,5,AUTO")
local function slash(msg) M.chat = {}; SlashCmdList["FOREVERCOMBATMETER"](msg) end
slash("report")
check("/fcm report", calls[2] and (calls[2][1] .. "," .. tostring(calls[2][2])) or "none", "1,nil")
slash("report 3")
check("/fcm report 3", calls[3] and (calls[3][1] .. "," .. calls[3][2]) or "none", "1,3")
ns.Report.Window = realReport
slash("mode threat")
check("/fcm mode threat", Windows.Mode(1), "threat")
slash("mode Healing")
check("/fcm mode is case blind", Windows.Mode(1), "healing")
slash("windows 3")
check("/fcm windows 3", S("windowCount"), 3)
slash("mode 2 deaths")
check("/fcm mode 2 deaths", Windows.Mode(2), "deaths")
slash("mode 1.5 damage")
check("/fcm mode 1.5: refused", Windows.Mode(1), "healing")
slash("mode nonsense")
check("/fcm mode nonsense: unchanged", Windows.Mode(1), "healing")
check("/fcm mode nonsense: usage", M.chat[1] ~= nil and M.chat[1]:find("/fcm", 1, true) ~= nil, true)
slash("windows 2")
check("/fcm windows 2", S("windowCount"), 2)
slash("windows 9")
check("/fcm windows 9 refused", S("windowCount"), 2)
slash("windows 0")
check("/fcm windows 0 refused", S("windowCount"), 2)
slash("windows")
check("/fcm windows without number refused", S("windowCount"), 2)
slash("toggle")
check("/fcm toggle prints", M.chat[1] ~= nil and M.chat[1]:find(ns.L.MSG_WINDOWS_HIDDEN, 1, true) ~= nil, true)
check("/fcm toggle hides", Windows.Frame(1):IsShown() or Windows.Frame(2):IsShown(), false)
Windows.Tick(0.3)
check("/fcm toggle: stays hidden through a tick", Windows.Frame(1):IsShown(), false)
slash("toggle")
check("/fcm toggle prints shown", M.chat[1] ~= nil and M.chat[1]:find(ns.L.MSG_WINDOWS_SHOWN, 1, true) ~= nil, true)
check("/fcm toggle shows", Windows.Frame(1):IsShown() and Windows.Frame(2):IsShown(), true)
M.popups = {}
slash("reset")
check("/fcm reset asks", M.popups[#M.popups] and M.popups[#M.popups].which, "FOREVERCOMBATMETER_RESET")
Settings.ResetProfile()

section("Report channels")
do
    local Report, Detail = ns.Report, ns.Detail
    Settings.ResetProfile()
    M.state.combat, M.state.group, M.state.instanceGroup, M.state.instance = false, false, false, nil
    world.raid = false
    local guild = false
    IsInGuild = function() return guild end
    local tgt = nil   -- { name, realm, player, friend }
    local realUnitExists, realUnitName = UnitExists, UnitName
    UnitExists = function(u) if u == "target" then return tgt ~= nil end return realUnitExists(u) end
    UnitName = function(u) if u == "target" then return tgt.name, tgt.realm end return realUnitName(u) end
    UnitIsPlayer = function(u) return u == "target" and tgt ~= nil and tgt.player end
    UnitIsFriend = function(_, u) return u == "target" and tgt ~= nil and tgt.friend end
    local out = {}
    C_ChatInfo = { SendChatMessage = function(msg, chatType, lang, target)
        out[#out + 1] = { msg = msg, chatType = chatType, lang = lang, target = target } end }
    local function drain() for _ = 1, 50 do if Report.Pending() == 0 and #M.timers == 0 then return end M.RunTimers() end end
    local function reset() drain(); out = {}; M.sent = {}; M.chat = {}; M.popups = {} end

    local function sp(id, total) return { spellID = id, totalAmount = total, amountPerSecond = 1, creatureName = "" } end
    M.dm.byType[CUR] = { [T.DamageDone] = { totalAmount = 2000, combatSources = {
        source("Bob", "Player-2", 300, 30, { classFilename = "MAGE", spells = { sp(133, 100), sp(116, 200) } }),
        source("Me", "Player-1-0001", 1500, 25, { isLocalPlayer = true, spells = { sp(78, 1500) } }) } } }
    Windows.SetMode(1, "damage")
    Windows.Refresh(1)

    check("default channel", S("reportChannel"), "AUTO")
    check("stored channel falls back to AUTO", (function() ns.DB().reportChannel = "BOGUS"; local c = Report.StoredChannel(); ns.DB().reportChannel = nil; return c end)(), "AUTO")

    local function reportMenu()
        Windows.OpenMenu(1, Windows.Frame(1).header)
        return M.MenuFind(M.LastMenu(), "Report")
    end
    local function entry(text) return M.MenuFind(reportMenu(), text) end
    local function enabled(text) local e = entry(text); return e ~= nil and e.enabled ~= false end
    local function hint(text)
        local e, got = entry(text), nil
        if e and e.tooltip then e.tooltip({ AddLine = function(_, t) got = t end }) end
        return got
    end

    -- Entries and their states
    check("menu entries", M.MenuTexts(reportMenu()), "Automatic,Say,Party,Raid,Instance,Guild,Whisper\226\128\166")
    check("solo: automatic enabled", enabled("Automatic"), true)
    check("solo: say disabled outside an instance", enabled("Say"), false)
    check("solo: say hint", hint("Say"), ns.L.REPORT_HINT_SAY)
    check("solo: party disabled", enabled("Party"), false)
    check("solo: party hint", hint("Party"), ns.L.REPORT_HINT_GROUP)
    check("solo: raid disabled", enabled("Raid"), false)
    check("solo: instance disabled", enabled("Instance"), false)
    check("solo: guild disabled", enabled("Guild"), false)
    check("solo: guild hint", hint("Guild"), ns.L.REPORT_HINT_GUILD)
    check("solo: whisper enabled", enabled("Whisper\226\128\166"), true)
    M.state.instance = { kind = "party", name = "Dungeon" }
    check("instance: say enabled", enabled("Say"), true)
    M.state.instance = nil
    M.state.group = true
    check("party: party enabled", enabled("Party"), true)
    check("party: raid still disabled", enabled("Raid"), false)
    world.raid = true
    check("raid: raid enabled", enabled("Raid"), true)
    world.raid, M.state.group = false, false
    M.state.instanceGroup = true
    check("finder group: instance enabled", enabled("Instance"), true)
    check("finder group: party disabled", enabled("Party"), false)
    M.state.instanceGroup = false
    guild = true
    check("guild: enabled", enabled("Guild"), true)

    -- Picking a channel stores it and sends there
    reset()
    M.MenuClick(entry("Guild"))
    drain()
    check("guild: stored", S("reportChannel"), "GUILD")
    check("guild: sent (header + both rows)", #out, 3)
    check("guild: chat type", out[1] and out[1].chatType, "GUILD")
    check("guild: header", out[1] and out[1].msg, "Forever Combat Meter: Damage \194\183 Current")
    check("menu: stored entry checked", entry("Guild").isSelected("GUILD"), true)
    check("menu: other entries not checked", entry("Automatic").isSelected("AUTO"), false)
    -- The stored channel is used by /fcm report and the panel's right click
    reset()
    SlashCmdList["FOREVERCOMBATMETER"]("report 2")
    drain()
    check("/fcm report: stored channel", out[1] and out[1].chatType, "GUILD")
    check("/fcm report 2: lines", #out, 3)
    reset()
    local bob
    for k = 1, 2 do if Windows.Frame(1).bars[k].row.guid == "Player-2" then bob = Windows.Frame(1).bars[k].row end end
    Detail.Open(1, bob)
    local header = Detail.Frame().header
    header:GetScript("OnClick")(header, "RightButton")
    drain()
    check("panel right click: stored channel", out[1] and out[1].chatType, "GUILD")
    Detail.Close()
    -- A stored channel that does not work now is refused with a reason
    guild = false
    reset()
    check("unusable stored channel: refused", Report.Window(1, 2), false)
    check("unusable stored channel: nothing sent", #out, 0)
    check("unusable stored channel: says why", (M.Reveal(M.chat[1] or "")):find("Guild", 1, true) ~= nil, true)

    -- Whisper: a friendly player target is whispered directly
    reset()
    tgt = { name = "Ann", realm = nil, player = true, friend = true }
    check("whisper entry names the target", entry("Whisper Ann") ~= nil, true)
    M.MenuClick(entry("Whisper Ann"))
    drain()
    check("whisper target: stored channel", S("reportChannel"), "WHISPER")
    check("whisper target: stored name", S("reportTarget"), "Ann")
    check("whisper target: chat type", out[1] and out[1].chatType, "WHISPER")
    check("whisper target: to the target", out[1] and out[1].target, "Ann")
    check("whisper target: no popup", #M.popups, 0)
    tgt = { name = "Ann", realm = "Other", player = true, friend = true }
    check("whisper entry with realm", entry("Whisper Ann-Other") ~= nil, true)
    tgt = { name = "Ogre", player = false, friend = false }
    check("hostile npc: popup entry", entry("Whisper\226\128\166") ~= nil, true)
    tgt = { name = M.Secret("Ann"), player = true, friend = true }
    check("secret target name: popup entry, no error", (pcall(reportMenu)) and entry("Whisper\226\128\166") ~= nil, true)
    tgt = nil
    -- Otherwise a popup asks for the name
    reset()
    M.MenuClick(entry("Whisper\226\128\166"))
    check("whisper: popup", M.popups[1] and M.popups[1].which, "FOREVERCOMBATMETER_WHISPER")
    check("whisper: nothing sent yet", #out, 0)
    local dialog = StaticPopupDialogs.FOREVERCOMBATMETER_WHISPER
    check("whisper popup: edit box", dialog.hasEditBox, true)
    check("whisper popup: maxLetters", dialog.maxLetters, 48)
    local box = { text = "", max = 255 }
    function box:SetMaxLetters(n) self.max = n end
    function box:SetText(t) self.text = t end
    function box:GetText() return self.text end
    function box:HighlightText() end
    function box:SetFocus() end
    local popup = { editBox = box }
    dialog.OnShow(popup)
    check("whisper popup: limit set explicitly on show", box.max, 48)
    check("whisper popup: prefilled with the last name", box.text, "Ann")
    box.text = "  Cid-Realm  "
    dialog.OnAccept(popup)
    drain()
    check("whisper popup: sent to the typed name", out[1] and out[1].target, "Cid-Realm")
    check("whisper popup: name stored", S("reportTarget"), "Cid-Realm")
    dialog.OnHide(popup)
    check("whisper popup: shared box limit given back", box.max, 0)
    -- The stored name is used without asking
    reset()
    SlashCmdList["FOREVERCOMBATMETER"]("report 1")
    drain()
    check("stored whisper: no popup", #M.popups, 0)
    check("stored whisper: to the stored name", out[1] and out[1].target, "Cid-Realm")
    -- Whisper without any stored name: the popup
    reset()
    Settings.Set("reportTarget", "")
    SlashCmdList["FOREVERCOMBATMETER"]("report 1")
    check("whisper without a name: popup", M.popups[1] and M.popups[1].which, "FOREVERCOMBATMETER_WHISPER")
    dialog.OnHide(popup)
    -- /fcm report [n] [channel] [name]
    reset()
    SlashCmdList["FOREVERCOMBATMETER"]("report 1 whisper Dee")
    drain()
    check("/fcm report 1 whisper Dee", out[1] and (out[1].chatType .. ":" .. tostring(out[1].target)), "WHISPER:Dee")
    check("/fcm report: channel stored", S("reportTarget"), "Dee")
    reset()
    SlashCmdList["FOREVERCOMBATMETER"]("report auto")
    drain()
    check("/fcm report auto: stored", S("reportChannel"), "AUTO")
    check("/fcm report auto: printed locally when solo", #out, 0)
    reset()
    SlashCmdList["FOREVERCOMBATMETER"]("report 2 nowhere")
    check("/fcm report bad channel: usage", M.chat[1] ~= nil and M.chat[1]:find("/fcm", 1, true) ~= nil, true)
    check("/fcm report bad channel: nothing stored", S("reportChannel"), "AUTO")
    -- Same secret refusal on every channel
    Settings.Set("reportChannel", "WHISPER")
    Settings.Set("reportTarget", "Dee")
    M.state.combat = true
    Windows.Refresh(1)
    reset()
    local okW, resW = pcall(Report.Window, 1, 2)
    check("secret whisper: raises nothing", okW, true)
    check("secret whisper: refused", resW, false)
    check("secret whisper: nothing sent", #out, 0)
    check("secret whisper: no popup", #M.popups, 0)
    M.state.combat = false
    Windows.Refresh(1)
    -- Options: channel select and whisper name on the General page
    local rows = {}
    for _, page in ipairs(ns.Window.PAGES) do
        for _, r in ipairs(page.rows and page.rows() or {}) do if r.key then rows[r.key] = r end end
    end
    check("options: channel select", rows.reportChannel and rows.reportChannel.type, "select")
    check("options: channel choices", rows.reportChannel and #rows.reportChannel.choices(), 7)
    rows.reportChannel.set("PARTY")
    check("options: channel set", S("reportChannel"), "PARTY")
    check("options: whisper name hidden unless whisper", rows.reportTarget.visible(), false)
    rows.reportChannel.set("WHISPER")
    check("options: whisper name shown for whisper", rows.reportTarget.visible(), true)
    rows.reportTarget.set("  Eve ")
    check("options: whisper name trimmed", S("reportTarget"), "Eve")
    -- Import keeps only known channels
    Settings.ResetProfile()
    check("import: bad channel skipped", ns.Share.Import("FCM1:ts13:reportChannels5:SHOUT}"), true)
    check("import: bad channel not stored", ns.DB().reportChannel, nil)
    ns.Share.Import("FCM1:ts13:reportChannels5:GUILDs12:reportTargets3:Eve}")
    check("import: good channel kept", S("reportChannel"), "GUILD")
    check("import: whisper name kept", S("reportTarget"), "Eve")
    Settings.ResetProfile()
    UnitExists, UnitName, UnitIsPlayer, UnitIsFriend, IsInGuild, C_ChatInfo = realUnitExists, realUnitName, nil, nil, nil, nil
    reset()
end

section("Secret lint")
-- A cheap static check, because the mock cannot catch it: on the client even
-- `secret == nil`, `secret ~= nil`, `not secret`, `secret and/or x` and
-- `if secret then` raise, while Lua 5.1 has no __eq across types and lets
-- them pass here. Every line that tests one of the field names below in one
-- of those ways must, on the same line, either check issecret( / present( /
-- Present( first, or say why the value is plain with a "-- plain: ..."
-- comment. Keep the list in step with what C_DamageMeter, C_DeathRecap,
-- C_Spell and UnitName can hand out in secret (Meter.lua, Threat.lua).
local SECRET_FIELDS = {
    "name", "total", "totalAmount", "perSecond", "amountPerSecond", "percent", "percentOfSource", "max",
    "maxAmount", "icon", "spellID", "spell", "guid", "sourceGUID", "creature", "creatureID", "duration",
    "deathTime", "timestamp", "value", "amount", "hp", "pct", "title", "source", "id", "sessionID",
}
local LINT_FILES = { "Format.lua", "Meter.lua", "Threat.lua", "Windows.lua", "Detail.lua", "Report.lua",
    "Resize.lua", "Commands.lua", "Blizzard.lua", "Options/Window.lua", "Options/Widgets.lua",
    "Options/Style.lua", "Options/Panel.lua", "Options/MinimapButton.lua" }
local function lintLine(line)
    if line:find("%-%- plain:") then return nil end
    local code = line:gsub("%-%-.*$", "")
    if code:find("issecret(", 1, true) or code:find("present(", 1, true) or code:find("Present(", 1, true) then return nil end
    for _, field in ipairs(SECRET_FIELDS) do
        local w = "%f[%w_]" .. field .. "%f[^%w_]"
        for _, pat in ipairs({ w .. "%s*[=~]=%s*nil", "nil%s*[=~]=%s*[%w_%.]*" .. w, w .. "%s+or%f[^%w_]",
            w .. "%s+and%f[^%w_]", "not%s+[%w_%.]*" .. w, "if%s+[%w_%.]*" .. w .. "%s+then" }) do
            if code:find(pat) then return field end
        end
    end
end
check("lint: icon == nil caught", lintLine("        if icon == nil then icon = QUESTION_MARK end"), "icon")
check("lint: ~= nil caught", lintLine("    if row.percent ~= nil then x() end"), "percent")
check("lint: or caught", lintLine("    local n = sp.name or \"?\""), "name")
check("lint: truthiness caught", lintLine("    if sp.creature then return 1 end"), "creature")
check("lint: not caught", lintLine("    if not r.total then return end"), "total")
check("lint: guarded line passes", lintLine("    if not issecret(icon) and icon == nil then icon = 1 end"), nil)
check("lint: plain note passes", lintLine("    if line.title then   -- plain: a flag"), nil)
check("lint: other names pass", lintLine("    if names == nil or titles then end"), nil)
for _, f in ipairs(LINT_FILES) do
    local n = 0
    for line in io.lines(ROOT .. "/" .. f) do
        n = n + 1
        local hit = lintLine(line)
        if hit then check(("secret lint %s:%d (%s)"):format(f, n, hit), line, "explicit issecret or -- plain:") end
    end
end

section("No accidental globals")
local allowed = { SLASH_FOREVERCOMBATMETER1 = true, SLASH_FOREVERCOMBATMETER2 = true, ForeverCombatMeterProfiles = true,
    ForeverCombatMeterChar = true, ForeverCombatMeter_OnAddonCompartmentClick = true,
    ForeverCombatMeter_OnAddonCompartmentEnter = true, ForeverCombatMeter_OnAddonCompartmentLeave = true }
for _, f in ipairs(tocFiles()) do
    local listing = io.popen("luac5.1 -l -p '" .. ROOT .. "/" .. f .. "' 2>/dev/null"):read("*a")
    for name in listing:gmatch("SETGLOBAL%s+%d+%s+[%-%d]*%s*; ([%w_]+)") do
        check(f .. " sets global " .. name, allowed[name] or false, true)
    end
end

section("Nothing private, no CVars, no forbidden calls")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    -- Settings never live in CVars; only Blizzard.lua flips the damage meter's own switch.
    if f ~= "Blizzard.lua" then check("no CVar write in " .. f, src:find("SetCVar", 1, true), nil) end
    check("no combat log event in " .. f, src:find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), nil)
    check("no hooksecurefunc call in " .. f, src:gsub("%-%-[^\n]*", ""):find("hooksecurefunc%("), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
