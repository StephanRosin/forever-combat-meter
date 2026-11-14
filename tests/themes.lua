-- Themes (Themes.lua, ThemeArt.lua): switching keeps every theme's settings,
-- CLASSIC comes back exactly, a first theme starts from CLASSIC, reset,
-- positions from another theme with undo, the revision upgrade, the art.
-- Called from run.lua with its helpers.
return function(ns, M, check, section)
    local Settings, Themes, Windows = ns.Settings, ns.Themes, ns.Windows
    local S = Settings.Get
    local function x1() return Windows.Config(1).x end

    section("Themes: switch and restore Classic")
    Settings.ResetProfile()
    Settings.Set("barHeight", 25)
    Settings.Set("headerColor", { 0.5, 0.6, 0.7 })
    Windows.SetConfig(1, { point = "TOP", x = 111, y = -50 })
    local classic = ns.Share.Export()
    check("starts on Classic", Themes.Current(), "CLASSIC")
    check("nothing else stored yet", #Themes.Stored(), 0)
    check("switch to wood", Themes.Switch("WOOD"), true)
    check("wood in use", S("theme"), "WOOD")
    check("wood: own bar texture", S("barTexture"), "FCM Wood")
    check("wood: own font", S("headerFont"), "Cinzel")
    check("wood: client outline, never soft", S("nameFlag"), "OUTLINE")
    check("wood: gold rim", S("borderStyle"), "GOLD")
    check("wood: Classic's bar height", S("barHeight"), 25)
    check("wood: Classic's colours", S("headerColor")[3], 0.7)
    check("wood: Classic's position", x1(), 111)
    Settings.Set("barHeight", 30)
    Windows.SetConfig(1, { x = 222 })
    Settings.Set("windowCount", 2)
    check("back to Classic", Themes.Switch("CLASSIC"), true)
    check("Classic exactly as before", ns.Share.Export(), classic)
    check("Classic: no theme stored", ns.DB().theme, nil)
    check("Classic: one window again", S("windowCount"), 1)
    check("wood kept", Themes.Stored()[1], "WOOD")
    Themes.Switch("WOOD")
    check("wood comes back: position", x1(), 222)
    check("wood comes back: bar height", S("barHeight"), 30)
    check("wood comes back: two windows", S("windowCount"), 2)
    check("the live set is not stored twice", ns.DB().themeSets.WOOD, nil)
    check("unknown theme", select(2, Themes.Switch("NOPE")), "UNKNOWN")
    check("same theme: nothing to do", Themes.Switch("WOOD"), true)

    section("Themes: reset")
    check("reset wood", Themes.Reset(), true)
    check("reset: position from Classic", x1(), 111)
    check("reset: bar height from Classic", S("barHeight"), 25)
    check("reset: still wood", S("headerFont"), "Cinzel")
    Themes.Switch("CLASSIC")
    check("Classic cannot be reset", select(2, Themes.Reset()), "CLASSIC")
    check("Classic still as before", ns.Share.Export(), classic)

    section("Themes: positions from another theme, undo")
    Themes.Switch("TECH")
    check("tech starts from Classic", x1(), 111)
    check("tech: same font size", S("nameSize"), Settings.DEFAULTS.nameSize)
    Windows.SetConfig(1, { x = 333, y = -70 })
    Settings.Set("detailX", 40)
    Themes.Switch("WOOD")
    local stored = table.concat(Themes.Stored(), ",")
    check("stored themes, in list order", stored, "CLASSIC,TECH")
    local undo = Themes.CopyPlacement("TECH")
    check("positions taken over", x1(), 333)
    check("panel position taken over", S("detailX"), 40)
    check("look stays wood", S("barTexture"), "FCM Wood")
    Themes.Restore(undo)
    check("undo: position back", x1(), 111)
    check("undo: panel position back", S("detailX"), 0)
    check("a theme never used", select(2, Themes.CopyPlacement("PIXEL")), "GONE")

    section("Themes: revision upgrade")
    Windows.SetConfig(1, { x = 444 })
    ns.DB().themeSets.revision = Themes.REVISION - 1
    Themes.Upgrade()
    check("theme in use made anew from Classic", x1(), 111)
    check("stale theme sets dropped", ns.DB().themeSets.TECH, nil)
    check("Classic kept", ns.DB().themeSets.CLASSIC ~= nil, true)
    check("revision stored", ns.DB().themeSets.revision, Themes.REVISION)
    check("revision raised for Swiss and Pitwall in one black", Themes.REVISION, 7)
    Themes.Switch("CLASSIC")
    check("Classic after the upgrade as before", ns.Share.Export(), classic)

    section("Themes: fonts")
    M.locale = "koKR"
    Themes.Switch("FROST")
    check("non-Latin client keeps its font", S("headerFont"), Settings.DEFAULTS.headerFont)
    check("but the title takes the larger size", S("headerSize"), Settings.DEFAULTS.headerSize + 2)
    check("rows in the standard font keep their size", S("nameSize"), Settings.DEFAULTS.nameSize)
    Themes.Switch("CLASSIC")
    M.locale = "enUS"
    for id, spec in pairs(Themes.SPECS) do
        if spec.font then
            check(id .. ": font shipped", ns.Media.FontPath(spec.font) ~= ns.Media.DEFAULT.font, true)
            check(id .. ": bar texture known", ns.Media.Path("statusbar", spec.bar) ~= ns.Media.DEFAULT.statusbar, true)
            local flag = spec.outline or "OUTLINE"
            check(id .. ": client outline", flag == "OUTLINE" or flag == "THICKOUTLINE", true)
            check(id .. ": named in the list", ns.L["THEME_" .. id] ~= "THEME_" .. id, true)
        end
    end
    check("every theme listed", #Settings.THEMES, 12)
    -- Title in the theme's font; rows in a font that reads at row size.
    local BODY = { WOOD = "Friz Quadrata", TECH = "Space Grotesk", RUNESTONE = "Marcellus", PIXEL = "VT323",
        PARCHMENT = "Friz Quadrata", FROST = "Friz Quadrata", GLASS = "Friz Quadrata", COMIC = "Friz Quadrata",
        SWISS = "Inter Tight", CONSOLE = "IBM Plex Mono", PITWALL = "Titillium Web SemiBold" }
    for id, body in pairs(BODY) do
        Themes.Switch(id)
        Themes.Reset()   -- FROST is stored from the koKR run above
        local spec = Themes.SPECS[id]
        check(id .. ": title font", S("headerFont"), spec.font)
        check(id .. ": name font", S("nameFont"), body)
        check(id .. ": value font", S("valueFont"), body)
        local add = body == spec.font and (spec.fontSizeAdd or 0) or 0
        check(id .. ": name size", S("nameSize"), Settings.DEFAULTS.nameSize + add)
        check(id .. ": title size", S("headerSize"), Settings.DEFAULTS.headerSize + (spec.fontSizeAdd or 0))
        check(id .. ": outlined text", S("valueFlag") ~= "" and S("valueFlag") ~= "SHADOW", true)
        Themes.Switch("CLASSIC")
    end
    check("comic: no fill over the paper", Themes.SPECS.COMIC.look.bgAlpha, 0)
    do
        -- A refused font: the standard font meanwhile, then tried again.
        local fs = UIParent:CreateFontString()
        local refusals = 2
        local set = fs.SetFont
        function fs:SetFont(p, s, f)
            if p:find("Cinzel", 1, true) and refusals > 0 then
                refusals = refusals - 1
                return false
            end
            return set(self, p, s, f)
        end
        M.timers = {}
        ns.Media.ApplyText(fs, { font = "Cinzel", size = 12, flag = "OUTLINE", color = { 1, 1, 1 } })
        check("refused font: standard font meanwhile", fs:GetFont(), ns.Media.DEFAULT.font)
        M.RunTimers()
        check("refused font: taken on a later try", (fs:GetFont():find("Cinzel", 1, true)) ~= nil, true)
    end

    section("Themes: art")
    local f = Windows.Frame(1)
    Themes.Switch("WOOD")
    local box = f.themeBox
    check("wood: backdrop under the window", box ~= nil and box:IsShown(), true)
    check("wood: backdrop file", box.back:GetTexture():find("WoodBack", 1, true) ~= nil, true)
    check("wood: backdrop below the window", box:GetFrameLevel() < f:GetFrameLevel(), true)
    check("wood: backdrop inside the ring", box._points.TOPLEFT[3], 3)
    local ring = ns.Border.Pieces(f)
    check("wood: ring round the backdrop", ring[1]._points.BOTTOMLEFT[1], box)
    check("wood: background colour only behind the bars", f.bg._points.TOPLEFT[3], S("padding"))
    local shown = 0
    for _, o in ipairs(box.ornaments) do if o:IsShown() then shown = shown + 1 end end
    check("wood: four rivets", shown, 4)
    check("wood: rivet in the window's corner", box.ornaments[1]._points.TOPLEFT[1], f)
    check("wood: no gold glow", f.header.shine:IsShown(), false)
    Themes.Switch("PARCHMENT")
    check("parchment: one seal", box.ornaments[3]:IsShown() and not box.ornaments[1]:IsShown(), true)
    Themes.Switch("TECH")
    local brackets = 0
    for _, o in ipairs(box.ornaments) do if o:IsShown() then brackets = brackets + 1 end end
    check("tech: no corner brackets", brackets, 0)
    Themes.Switch("GLASS")
    check("glass: mosaic at full brightness", box.back._vertex[1], 1)
    Themes.Switch("COMIC")
    check("comic: paper grey as in the other addons", box.back._vertex[1] .. "/" .. box.back._vertex[4], "0.7/1")
    check("comic: background clear", S("bgAlpha"), 0)
    local gear = f.header.buttons.menu
    check("comic: header icons in dark ink", gear.icon._vertex[1], 0.1)
    gear:GetScript("OnEnter")(gear)
    check("comic: hover still visible", gear.icon._vertex[1], 0.4)
    gear:GetScript("OnLeave")(gear)
    check("comic: grip in ink", f.header.grip._vertex[1], 0.1)
    check("comic: outline, not thick (pixelated)", S("valueFlag"), "OUTLINE")

    -- Theme colours: backdrop and title accent, apart from the theme sets.
    local registry = _G.ForeverThemes.ForeverCombatMeter
    local function title() return table.concat({ f.header.title:GetTextColor() }, "/", 1, 3) end
    local function back() return box.back:GetTexture():match("[^\\]+$") end
    local function vertex() return table.concat(box.back._vertex, "/") end
    local greyTitle, stored = title(), ns.Share.Export()
    check("comic colour: grey by default", registry.Color(), "GREY")
    check("comic colour: the nine", table.concat(registry.Colors(), " "),
        "GREY DARKGREY BLACK WHITE YELLOW BLUE RED GREEN PURPLE")
    check("colour: by theme", table.concat(registry.Colors("TECH"), " "), "CYAN GREEN AMBER MAGENTA BLUE GREY")
    check("colour: none for classic", #registry.Colors("CLASSIC") .. tostring(registry.Color("CLASSIC")), "0nil")
    check("comic colour: blue", registry.SetColor("BLUE"), true)
    check("comic colour: blue paper", box.back._vertex[3] .. "/" .. box.back._vertex[4], "0.86/1")
    check("comic colour: own paper", back(), "ComicBack")
    check("comic colour: yellow title", title(), "1/0.9/0.1")
    check("comic colour: yellow", registry.SetColor("YELLOW"), true)
    check("comic colour: yellow paper", box.back._vertex[1], 0.86)
    check("comic colour: blue title", title(), "0.15/0.45/0.95")
    check("comic colour: the look not stored", ns.Share.Export(), stored)
    check("comic colour: dark grey", registry.SetColor("DARKGREY"), true)
    check("comic colour: dark grey paper", box.back._vertex[1], 0.38)
    check("comic colour: dark grey, yellow title", title(), "1/0.9/0.1")
    check("comic colour: dark paper, light icons", gear.icon._vertex[1], 0.85)
    gear:GetScript("OnEnter")(gear)
    check("comic colour: dark paper, hover white", gear.icon._vertex[1], 1)
    gear:GetScript("OnLeave")(gear)
    check("comic colour: dark paper, light grip", f.header.grip._vertex[1], 0.85)
    check("comic colour: white", registry.SetColor("WHITE"), true)
    check("comic colour: white paper", box.back._vertex[1] .. "/" .. box.back._vertex[3], "1/1")
    check("comic colour: white, blue title", title(), "0.15/0.45/0.95")
    check("comic colour: white, ink icons", gear.icon._vertex[1], 0.1)
    registry.SetColor("YELLOW")
    check("colour: unknown", select(2, registry.SetColor("PINK")), "UNKNOWN")
    check("colour: another theme's id is unknown", select(2, registry.SetColor("OAK")), "UNKNOWN")
    check("colour: unknown leaves it", registry.Color(), "YELLOW")
    check("colour: picked for another theme", registry.SetColor("AURORA", "FROST"), true)
    Themes.Switch("WOOD")
    check("colour: comic kept away from comic", registry.Color("COMIC"), "YELLOW")
    check("colour: wood as it is", back() .. " " .. vertex(), "WoodBack 1/1/1/1")
    check("colour: wood title as it is", title(), table.concat(S("headerColor"), "/", 1, 3))
    check("colour: cherry", registry.SetColor("CHERRY"), true)
    check("colour: cherry on the grey wood", back(), "WoodBackGrey")
    check("colour: cherry back / mean", vertex(), (0.30 / 0.8) .. "/" .. (0.12 / 0.8) .. "/" .. (0.08 / 0.8) .. "/1")
    check("colour: cherry keeps the title", title(), table.concat(S("headerColor"), "/", 1, 3))
    check("colour: the look not stored", ns.DB().themeSets.WOOD, nil)
    Themes.Switch("FROST")
    check("colour: frost keeps its own", registry.Color(), "AURORA")
    check("colour: aurora on the grey ice, the theme's alpha", back() .. " " .. vertex(),
        "FrostBackGrey " .. (0.10 / 0.796) .. "/" .. (0.27 / 0.796) .. "/" .. (0.24 / 0.796) .. "/0.75")
    check("colour: aurora title", title(), "0.55/1/0.8")
    registry.SetColor("ICE")
    check("colour: ice as frost was", back() .. " " .. vertex() .. " " .. title(),
        "FrostBack 1/1/1/0.75 " .. table.concat(S("headerColor"), "/", 1, 3))
    -- Every theme's first colour draws as before (art.tint, else white).
    for _, id in ipairs(Themes.IDS) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            local picked = registry.Color()
            registry.SetColor(registry.Colors()[1])
            local art = Themes.Spec(id).art
            check(id .. ": first colour as before", back() .. " " .. vertex(),
                art.back .. " " .. table.concat(art.tint or { 1, 1, 1, 1 }, "/"))
            registry.SetColor(picked)
        end
    end
    Themes.Switch("COMIC")
    check("comic colour: back to comic", box.back._vertex[2], 0.76)
    check("comic colour: grey again", registry.SetColor("GREY"), true)
    check("comic colour: grey paper restored", box.back._vertex[1] .. "/" .. box.back._vertex[4], "0.7/1")
    check("comic colour: grey title restored", title(), greyTitle)
    ns.DB().themeSets.themeColors.COMIC = "PINK"
    check("colour: unknown stored is the first", registry.Color(), "GREY")
    ns.DB().themeSets.themeColors = nil
    ns.DB().themeSets.comicColor = "RED"
    check("colour: comicColor moves in", registry.Color() .. " " .. tostring(ns.DB().themeSets.comicColor), "RED nil")
    ns.DB().themeSets.themeColors = nil
    Themes.Switch("CLASSIC")
    check("Classic: no theme art", box:IsShown(), false)
    check("Classic: background over the whole window", f.bg._points.TOPLEFT, nil)

    -- Players stack windows edge to edge: no theme reaches past the window
    -- Classic draws (soft shadow aside), and none changes its size.
    local classicW, classicH = f:GetWidth(), f:GetHeight()
    for _, id in ipairs(Settings.THEMES) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            Themes.Reset()
            local extent = ns.Border.Extent({ style = S("borderStyle"), size = S("borderSize") })
            local p = f.themeBox._points
            check(id .. ": ring's outer edge on the window's edge", p.TOPLEFT[3] .. "," .. p.BOTTOMRIGHT[4],
                extent .. "," .. extent)
            local piece = ns.Border.Pieces(f)[1]
            check(id .. ": ring as thick as its inset", piece:IsShown() and piece._h or 0, extent)
            check(id .. ": same width as Classic", f:GetWidth(), classicW)
            check(id .. ": same height as Classic", f:GetHeight(), classicH)
            for i, o in ipairs(f.themeBox.ornaments) do
                if o:IsShown() then
                    local point, rel, _, dx, dy = o:GetPoint()
                    check(id .. ": ornament " .. i .. " inside the corner",
                        rel == f and dx * ((i == 1 or i == 3) and 1 or -1) >= 0 and dy * (i <= 2 and -1 or 1) >= 0, true)
                end
            end
            check(id .. ": no solid shadow", f.themeBox.shadow, nil)
        end
    end
    Themes.Switch("CLASSIC")
    check("Classic: its own border again (none by default)", ns.Border.Pieces(f)[1]:IsShown(), false)
    check("Classic: gold line", f.header.line._texColor[1], ns.ThemeArt.LINE[1])
    check("Classic: icons in their own colour", f.header.buttons.menu.icon._vertex[1], 0.73)

    section("Themes: rings in the family's colours")
    -- The same ring per theme and colour in every Forever addon (this table
    -- in each of them, Forever Quest Log's Themes.lua the reference); only
    -- Console's colours and Handheld tint the ring. Thickness is our own.
    local RINGS = {
        WOOD = "GOLD", TECH = "0.25/0.88/0.94/0.9", PARCHMENT = "0.29/0.2/0.12/1", RUNESTONE = "0.1/0.1/0.12/1",
        GLASS = "0.07/0.06/0.05/1", COMIC = "0.07/0.07/0.07/1", FROST = "0.86/0.96/1/0.8", PIXEL = "1/0.95/0.91/1",
        SWISS = "0.165/0.165/0.165/1", CONSOLE = "0.306/0.929/0.69/1", PITWALL = "0.043/0.047/0.055/1",
    }
    local RING_OVERRIDES = { CONSOLE = { AMBER = "1/0.69/0/1", PHOSPHOR = "0.224/1/0.078/1",
        VIOLET = "0.627/0.471/1/1" }, PIXEL = { HANDHELD = "0.784/0.941/0.439/1" } }
    local function drawnRing()
        if S("borderStyle") == "GOLD" then return "GOLD" end
        local piece = ns.Border.Pieces(f)[1]
        return piece:IsShown() and table.concat(piece._vertex, "/") or "none"
    end
    for _, id in ipairs(Settings.THEMES) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            local before = registry.Color()
            for _, colour in ipairs(registry.Colors()) do
                registry.SetColor(colour)
                check(id .. " " .. colour .. ": ring", drawnRing(), (RING_OVERRIDES[id] or {})[colour] or RINGS[id])
            end
            registry.SetColor(before)
        end
    end
    Themes.Switch("CLASSIC")

    section("Themes: Swiss, Console, Pitwall, Handheld")
    local function ring() return table.concat(ns.Border.Pieces(f)[1]._vertex, "/", 1, 3) end
    local wedge = box.ornaments[1]
    local function wedgeColor() return table.concat(wedge._vertex, "/", 1, 3) end
    local listed = {}
    for _, c in ipairs(ns.Window.PAGES[1].rows()[3].choices()) do listed[#listed + 1] = c.value end
    check("new: in the options' list, appended", table.concat(listed, " ", 10), "SWISS CONSOLE PITWALL")
    Themes.Switch("SWISS")
    check("swiss: display face for the title only", S("headerFont") .. "/" .. S("nameFont") .. "/" .. S("valueFont"),
        "Inter Tight Bold/Inter Tight/Inter Tight")
    check("swiss: no size growth", S("headerSize") .. "/" .. S("valueSize"),
        Settings.DEFAULTS.headerSize .. "/" .. Settings.DEFAULTS.valueSize)
    check("swiss: flat black", back() .. " " .. vertex(), "SwissBack 1/1/1/1")
    check("swiss: hairline ring", ring(), "0.165/0.165/0.165")
    check("swiss: white rule on top", box.band:IsShown() and box.band._h, 3)
    check("swiss: red title", title(), "1/0.176/0.125")
    check("swiss: colours", table.concat(registry.Colors(), " "), "RED BLUE YELLOW WHITE")
    registry.SetColor("BLUE")
    check("swiss blue: title", title(), "0.176/0.42/1")
    check("swiss blue: backdrop and ring stay", back() .. " " .. vertex() .. " " .. ring(),
        "SwissBack 1/1/1/1 0.165/0.165/0.165")
    registry.SetColor("RED")
    Themes.Switch("CONSOLE")
    check("console: fonts", S("headerFont") .. "/" .. S("valueFont"), "IBM Plex Sans Condensed Bold/IBM Plex Mono")
    check("console: mint ring", ring(), "0.306/0.929/0.69")
    check("console: solid bars", S("barTexture"), "FCM Swiss")
    check("console: no band", box.band:IsShown(), false)
    check("console: colours", table.concat(registry.Colors(), " "), "MINT AMBER PHOSPHOR VIOLET")
    registry.SetColor("AMBER")
    check("console amber: the ring follows the title", ring() .. " " .. title(), "1/0.69/0 1/0.69/0")
    check("console amber: backdrop stays", back() .. " " .. vertex(), "ConsoleBack 1/1/1/1")
    check("console amber: not stored", S("borderColor")[1], 0.306)
    registry.SetColor("MINT")
    check("console mint: ring as stored", ring(), "0.306/0.929/0.69")
    Themes.Switch("PITWALL")
    check("pitwall: fonts", S("headerFont") .. "/" .. S("nameFont"), "Titillium Web Bold Italic/Titillium Web SemiBold")
    check("pitwall: solid bars", S("barTexture"), "FCM Swiss")
    check("pitwall: carbon hairline", ring(), "0.043/0.047/0.055")
    check("pitwall: black title strip", f.header.dark:IsShown() and table.concat(f.header.dark._texColor, "/", 1, 3),
        "0/0/0")
    check("pitwall: red wedge as high as the strip", wedge:IsShown() and wedgeColor() .. " " .. wedge._w,
        "0.882/0.024/0 " .. f.header:GetHeight())
    check("pitwall: title right of the wedge", f.header.title._points.LEFT[3] >= 18, true)
    check("pitwall: colours", table.concat(registry.Colors(), " "), "RED ORANGE TEAL SILVER")
    registry.SetColor("TEAL")
    check("pitwall teal: wedge", wedgeColor(), "0/0.631/0.612")
    check("pitwall teal: title as stored", title(), table.concat(S("headerColor"), "/", 1, 3))
    registry.SetColor("RED")
    -- Swiss and Pitwall share one black with every Forever addon: the flat
    -- backdrop untinted, the background #0a0a0a, opaque.
    for _, id in ipairs({ "SWISS", "PITWALL" }) do
        Themes.Switch(id)
        check(id .. ": the shared black", back() .. " " .. vertex() .. " " .. S("bgMode") .. " "
            .. table.concat(S("bgColor"), "/") .. " " .. S("bgAlpha"), "SwissBack 1/1/1/1 SOLID 0.039/0.039/0.039 100")
    end
    Themes.Switch("PIXEL")
    check("pixel: handheld appended", registry.Colors()[9], "HANDHELD")
    registry.SetColor("HANDHELD")
    check("handheld: grey pixel at back / mean", back() .. " " .. vertex(),
        "PixelBackGrey " .. (0.059 / 0.8) .. "/" .. (0.122 / 0.8) .. "/" .. (0.059 / 0.8) .. "/1")
    check("handheld: green rim and title", ring() .. " " .. title(), "0.784/0.941/0.439 0.784/0.941/0.439")
    registry.SetColor("NAVY")
    check("navy: rim as stored", ring(), "1/0.95/0.91")
    Themes.Switch("CLASSIC")
    check("Classic: no band, plain dark strip", box.band:IsShown() and "band" or table.concat(f.header.dark._texColor, "/"),
        "0/0/0/0.35")
    check("Classic after the new themes", ns.Share.Export(), classic)

    section("Themes: combat, profile, export")
    M.state.combat = true
    check("switch in combat (nothing protected)", Themes.Switch("GLASS"), true)
    M.state.combat = false
    check("export without theme sets", ns.Share.Export():find("themeSets", 1, true), nil)
    local text = ns.Share.Export()
    check("export names the theme", text:find("GLASS", 1, true) ~= nil, true)
    check("import keeps the theme sets", ns.Share.Import(text) and ns.DB().themeSets.CLASSIC ~= nil, true)
    Themes.Switch("CLASSIC")
    check("Classic after import elsewhere", ns.Share.Export(), classic)

    section("Themes: options")
    local first = ns.Window.PAGES[1].rows()
    check("theme section at the top of General", first[1].label, "OPT_THEME")
    check("theme choice", first[3].key, "theme")
    first[3].set("PIXEL")
    check("options switch the theme", Themes.Current(), "PIXEL")
    local copyItems = first[5].choices()
    check("copy list offers Classic", copyItems[1].value, "CLASSIC")
    first[5].set("CLASSIC")
    check("copy list offers undo", first[5].choices()[1].label, ns.L.OPT_THEME_UNDO)
    first[5].set(first[5].choices()[1].value)
    check("undo from the list", first[5].choices()[1].value, "CLASSIC")
    check("reset only for a theme", first[6].visible(), true)
    first[3].set("CLASSIC")
    check("no reset for Classic", first[6].visible(), false)
    check("no colour under Classic", first[4].visible(), false)
    first[3].set("COMIC")
    check("colour under Comic", first[4].visible() and first[4].get(), "GREY")
    first[3].set("PIXEL")
    check("colour: pixel's nine", #first[4].choices() .. " " .. first[4].choices()[9].label, "9 Handheld")
    first[4].set("TEAL")
    check("colour: set from the options", Themes.Color(), "TEAL")
    first[4].set("NAVY")
    first[3].set("CLASSIC")

    section("Themes: picker registry")
    local entry = ForeverThemes and ForeverThemes.ForeverCombatMeter
    check("registry entry", entry ~= nil and entry.title, "Forever Combat Meter")
    check("registry: switch", entry.Switch("FROST"), true)
    check("registry: current", entry.Current(), "FROST")
    check("registry: unknown", select(2, entry.Switch("NOPE")), "UNKNOWN")
    entry.Switch("CLASSIC")
    check("registry: back to Classic as before", ns.Share.Export(), classic)
    ns.DB().windows = { { width = 301 } }
    entry.Refresh()
    check("registry: refresh lays out the stored width", Windows.Frame(1):GetWidth(), 301)
    ns.DB().windows = nil
    entry.Refresh()
    Settings.ResetProfile()
end
