-- Tests for Forever Combat Meter. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
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
    "Position", "Corners", "Border", "Window", "MinimapButton", "Style", "Widgets" }) do
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
check("minimap row", rowFor("Minimap button", "check") ~= nil or rowFor("Minimap button", "box") ~= nil
    or rowFor("Minimap button", "button") ~= nil or rowFor("Minimap button", "checkbox") ~= nil, true)
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
ns.On("SOME_UNKNOWN_EVENT", function() fired = fired + 1 end)
M.Fire("SOME_UNKNOWN_EVENT")
check("ns.On delivers", fired, 1)
M.state.combat = true
local ran = 0
ns.AfterCombat("k", function() ran = ran + 1 end)
check("deferred in combat", ran, 0)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("runs after combat", ran, 1)

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
    for key in src:gmatch('"((OPT|PAGE|STYLE|TIP|MSG)_[A-Z0-9_]+)"') do check(f .. " uses known " .. key, base[key] ~= nil, true) end
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
