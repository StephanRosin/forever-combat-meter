-- Tests for Forever Combat Meter. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
-- Events the client knows: registering any other name throws, as in the game.
M.validEvents = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true, GLOBAL_MOUSE_DOWN = true }
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
    "Position", "Corners", "Border", "Window", "MinimapButton", "Style", "Widgets", "Format", "Meter" }) do
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
Settings.SetLocked(false)
check("unlock", S("locked"), false)
Settings.SetLocked(true)
check("lock", S("locked"), true)
check("lock stores nothing (default)", ns.DB().locked, nil)
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
check("right-click unlocks", S("locked"), false)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click locks", S("locked"), true)
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
for _, f in ipairs({ "Format.lua", "Meter.lua" }) do
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
