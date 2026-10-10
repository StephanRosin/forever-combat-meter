-- Tests for Forever Combat Meter. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
-- Events the client knows: registering any other name throws, as in the game.
M.validEvents = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true, GLOBAL_MOUSE_DOWN = true,
    PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true, DAMAGE_METER_CURRENT_SESSION_UPDATED = true,
    DAMAGE_METER_COMBAT_SESSION_UPDATED = true, DAMAGE_METER_RESET = true, ADDON_RESTRICTION_STATE_CHANGED = true,
    PLAYER_REGEN_DISABLED = true }
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
    "Windows" }) do
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
check("barColor", D.barColor[3], 0.75)
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
Settings.Set("barColor", { 0.1, 0.2, 0.3 })
Settings.Set("refresh", 0.35)
local text = ns.Share.Export()
check("prefix", text:sub(1, 5), "FCM1:")
Settings.ResetProfile()
check("reset", S("barHeight"), D.barHeight)
check("import", ns.Share.Import(text), true)
check("number back", S("barHeight"), 17)
check("colour back", S("barColor")[3], 0.3)
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
check("two pages", #ns.Window.PAGES, 2)
check("pages", ns.Window.PAGES[1].id .. "," .. ns.Window.PAGES[2].id, "general,profiles")
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
for _, f in ipairs({ "Format.lua", "Meter.lua", "Windows.lua" }) do
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
check("class icon without a spec", bar(1, 1).icon._texture, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
check("class icon coords", bar(1, 1).icon._texCoord[2], 0.25)
check("bar texture", bar(1, 1)._barTexture, "Interface\\TargetingFrame\\UI-StatusBar")
check("bar data for the tooltip", bar(1, 2).row.name, "Bob")
check("empty text hidden", w1.empty:IsShown(), false)
Settings.Set("barClassColor", false)
Windows.Refresh(1)
check("bar colour setting", bar(1, 2)._barColor[1], 0.45)
Settings.Set("barClassColor", nil)
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
check("past fight title", txt(w1.header.title), "Damage · Hogger")
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
check("secret session title", txt(w1.header.title), "Damage · Boss")
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
check("grips shown unlocked", w1.grips.right:IsShown() and w1.grips.left:IsShown(), true)
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
check("grips hidden locked", w1.grips.right:IsShown(), false)
w1.header:GetScript("OnMouseDown")(w1.header, "LeftButton")
check("lock blocks the drag", w1._moving, false)
Settings.SetLocked(false)
check("unlock all", Windows.Config(1).locked, false)
Settings.SetLocked(true)
check("lock all", Windows.Config(1).locked, true)
Settings.SetLocked(false)
local rows0 = Windows.Config(1).rows
w1._rect = { 800, 400, 220, w1:GetHeight() }
M.state.cursorX, M.state.cursorY = 1020, 400
local grip = w1.grips.right
grip:GetScript("OnMouseDown")(grip, "LeftButton")
M.state.cursorX, M.state.cursorY = 1100, 400 - 2 * 19
grip:GetScript("OnUpdate")(grip, 0.02)
check("live width", w1:GetWidth(), 300)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
check("resize: width", Windows.Config(1).width, 300)
check("resize: rows", Windows.Config(1).rows, rows0 + 2)
check("resize: top edge kept", Windows.Config(1).point, "TOP")
w1._rect = { 800, 400, 300, w1:GetHeight() }
M.state.cursorX, M.state.cursorY = 800, 400
local gl = w1.grips.left
gl:GetScript("OnMouseDown")(gl, "LeftButton")
M.state.cursorX = 750
gl:GetScript("OnUpdate")(gl, 0.02)
gl:GetScript("OnMouseUp")(gl, "LeftButton")
check("left grip widens to the left", Windows.Config(1).width, 350)
gl:GetScript("OnMouseDown")(gl, "LeftButton")
M.state.cursorX, M.state.cursorY = -5000, -5000
gl:GetScript("OnUpdate")(gl, 0.02)
gl:GetScript("OnMouseUp")(gl, "LeftButton")
check("width clamped", Windows.Config(1).width, 600)
check("rows clamped", Windows.Config(1).rows, 40)
Windows.ToggleLock(1)
M.state.cursorX, M.state.cursorY = 0, 0
grip:GetScript("OnMouseDown")(grip, "LeftButton")
M.state.cursorX = 300
check("locked: no resize started", grip:GetScript("OnUpdate"), nil)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
check("locked: no resize", Windows.Config(1).width, 600)
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
for _, label in ipairs({ "Mode", "Session", "New window", "Close window", "Lock window", "Reset data", "Options" }) do
    check("menu has " .. label, M.MenuFind(menu, label) ~= nil, true)
end
M.MenuClick(M.MenuFind(M.MenuFind(menu, "Mode"), "Healing"))
check("menu: mode", Windows.Mode(1), "healing")
check("menu: mode radio", M.MenuFind(M.MenuFind(menu, "Mode"), "Healing").isSelected(M.MenuFind(M.MenuFind(menu, "Mode"), "Healing").data), true)
check("menu: threat in the modes", M.MenuFind(M.MenuFind(menu, "Mode"), "Threat") ~= nil, true)
M.MenuClick(M.MenuFind(M.MenuFind(menu, "Session"), "Overall"))
check("menu: session", Windows.View(1), "overall")
M.MenuClick(M.MenuFind(M.MenuFind(menu, "Session"), "Hogger (0:42)"))
check("menu: past fight", Windows.View(1), 4)
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
Windows.SetMode(1, "damage")
hb.mode:GetScript("OnClick")(hb.mode, "LeftButton")
check("mode button menu", M.MenuFind(M.LastMenu(), "Damage") ~= nil, true)
hb.session:GetScript("OnClick")(hb.session, "LeftButton")
check("session button cycles", Windows.View(1), "current")
hb.session:GetScript("OnClick")(hb.session, "LeftButton")
check("session button cycles back", Windows.View(1), "overall")
hb.session:GetScript("OnClick")(hb.session, "RightButton")
check("session right-click: past fights", M.MenuFind(M.LastMenu(), "Hogger (0:42)") ~= nil, true)
Windows.SetView(1, "current")
w1.header:GetScript("OnClick")(w1.header, "RightButton")
check("right-click on the header: menu", M.MenuFind(M.LastMenu(), "New window") ~= nil, true)
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
check("forever buttons", hb.mode:IsShown() and hb.session:IsShown() and hb.reset:IsShown(), true)
check("forever button size", hb.menu:GetWidth(), 16)
Windows.ApplyStylePreset("COMPACT")
check("style set", S("style"), "COMPACT")
check("preset bar height", S("barHeight"), 14)
check("preset spacing", S("barSpacing"), 0)
Windows.Refresh(1)
check("compact header", w1.header:GetHeight(), 18)
check("compact: no glow", w1.header.shine:IsShown(), false)
check("compact: only menu and lock", (hb.mode:IsShown() or hb.session:IsShown() or hb.reset:IsShown()), false)
check("compact: menu and lock shown", hb.menu:IsShown() and hb.lock:IsShown(), true)
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
    check("no CVar storage in " .. f, src:find("SetCVar", 1, true), nil)
    check("no combat log event in " .. f, src:find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), nil)
    check("no hooksecurefunc call in " .. f, src:gsub("%-%-[^\n]*", ""):find("hooksecurefunc%("), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
