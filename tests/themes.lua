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
    check("revision raised for the plain comic outline", Themes.REVISION, 4)
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
    check("every theme listed", #Settings.THEMES, 9)
    -- Title in the theme's font; rows in a font that reads at row size.
    local BODY = { WOOD = "Cinzel", TECH = "Space Grotesk", RUNESTONE = "Marcellus", PIXEL = "VT323",
        PARCHMENT = "Friz Quadrata", FROST = "Friz Quadrata", GLASS = "Friz Quadrata", COMIC = "Friz Quadrata" }
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

    -- Comic colours: paper and title accent, apart from the theme sets.
    local registry = _G.ForeverThemes.ForeverCombatMeter
    local function title() return table.concat({ f.header.title:GetTextColor() }, "/", 1, 3) end
    local greyTitle, stored = title(), ns.Share.Export()
    check("comic colour: grey by default", registry.ComicColor(), "GREY")
    check("comic colour: the nine", table.concat(registry.ComicColors, " "),
        "GREY DARKGREY BLACK WHITE YELLOW BLUE RED GREEN PURPLE")
    check("comic colour: blue", registry.SetComicColor("BLUE"), true)
    check("comic colour: blue paper", box.back._vertex[3] .. "/" .. box.back._vertex[4], "0.86/1")
    check("comic colour: yellow title", title(), "1/0.9/0.1")
    check("comic colour: yellow", registry.SetComicColor("YELLOW"), true)
    check("comic colour: yellow paper", box.back._vertex[1], 0.86)
    check("comic colour: blue title", title(), "0.15/0.45/0.95")
    check("comic colour: the look not stored", ns.Share.Export(), stored)
    check("comic colour: dark grey", registry.SetComicColor("DARKGREY"), true)
    check("comic colour: dark grey paper", box.back._vertex[1], 0.38)
    check("comic colour: dark grey, yellow title", title(), "1/0.9/0.1")
    check("comic colour: dark paper, light icons", gear.icon._vertex[1], 0.85)
    gear:GetScript("OnEnter")(gear)
    check("comic colour: dark paper, hover white", gear.icon._vertex[1], 1)
    gear:GetScript("OnLeave")(gear)
    check("comic colour: dark paper, light grip", f.header.grip._vertex[1], 0.85)
    check("comic colour: white", registry.SetComicColor("WHITE"), true)
    check("comic colour: white paper", box.back._vertex[1] .. "/" .. box.back._vertex[3], "1/1")
    check("comic colour: white, blue title", title(), "0.15/0.45/0.95")
    check("comic colour: white, ink icons", gear.icon._vertex[1], 0.1)
    registry.SetComicColor("YELLOW")
    check("comic colour: unknown", select(2, registry.SetComicColor("PINK")), "UNKNOWN")
    check("comic colour: unknown leaves it", registry.ComicColor(), "YELLOW")
    Themes.Switch("WOOD")
    check("comic colour: kept away from comic", registry.ComicColor(), "YELLOW")
    check("comic colour: wood paper as it is", box.back._vertex[1], 1)
    check("comic colour: picked under wood", registry.SetComicColor("GREEN"), true)
    Themes.Switch("COMIC")
    check("comic colour: back to comic", box.back._vertex[2], 0.76)
    check("comic colour: grey again", registry.SetComicColor("GREY"), true)
    check("comic colour: grey paper restored", box.back._vertex[1] .. "/" .. box.back._vertex[4], "0.7/1")
    check("comic colour: grey title restored", title(), greyTitle)
    ns.DB().themeSets.comicColor = "PINK"
    check("comic colour: unknown stored is grey", registry.ComicColor(), "GREY")
    ns.DB().themeSets.comicColor = nil
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
            check(id .. ": ring as thick as its inset", ns.Border.Pieces(f)[1]._h, extent)
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
    check("comic colour only under Comic", first[4].visible(), false)
    first[3].set("COMIC")
    check("comic colour under Comic", first[4].visible() and first[4].get(), "GREY")
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
