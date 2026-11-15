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
    ns.DB().themeSets.revision = 14
    Themes.Upgrade()
    check("theme in use made anew from Classic", x1(), 111)
    check("stale theme sets dropped", ns.DB().themeSets.TECH, nil)
    check("Classic kept", ns.DB().themeSets.CLASSIC ~= nil, true)
    check("revision stored (raised for Console's condensed rows again)", ns.DB().themeSets.revision, 15)
    check("library's seed revision stored", ns.DB().themeSets.seedRevision, LibForeverThemes.SEED_REVISION)
    Themes.Switch("CLASSIC")
    check("Classic after the upgrade as before", ns.Share.Export(), classic)

    section("Themes: fonts")
    M.locale = "koKR"
    Themes.Switch("COMIC")
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
            if id == "FROST" then
                check(id .. ": a drop shadow, no outline", flag, "SHADOW")
            else
                check(id .. ": client outline", flag == "OUTLINE" or flag == "THICKOUTLINE", true)
            end
            check(id .. ": named in the list", ns.L["THEME_" .. id] ~= "THEME_" .. id, true)
        end
    end
    check("every theme listed", #LibForeverThemes.SpecIds(Themes.SPECS), 12)
    -- Title in the theme's font; rows in a font that reads at row size.
    local BODY = { WOOD = "Friz Quadrata", TECH = "Space Grotesk", RUNESTONE = "Marcellus", PIXEL = "VT323",
        PARCHMENT = "Friz Quadrata", FROST = "Julius Sans One", GLASS = "Friz Quadrata", COMIC = "Friz Quadrata",
        SWISS = "Inter Tight", CONSOLE = "IBM Plex Sans Condensed Bold", PITWALL = "Titillium Web SemiBold" }
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
        if id == "FROST" then
            check(id .. ": shadowed text", S("headerFlag") .. " " .. S("nameFlag") .. " " .. S("valueFlag"),
                "SHADOW SHADOW SHADOW")
            local fs = UIParent:CreateFontString()
            ns.Media.ApplyText(fs, Settings.TextStyle("header"))
            check(id .. ": drawn with a 1 px shadow, no outline", select(3, fs:GetFont()) .. " "
                .. table.concat({ fs:GetShadowOffset() }, ","), " 1,-1")
        elseif id == "RUNESTONE" then
            -- White names on a white (priest) bar: outline plus a dark drop shadow, the title outlined only.
            check(id .. ": rows outlined and shadowed", S("headerFlag") .. " " .. S("nameFlag") .. " " .. S("valueFlag"),
                "OUTLINE OUTLINESHADOW OUTLINESHADOW")
            local fs = UIParent:CreateFontString()
            ns.Media.ApplyText(fs, Settings.TextStyle("name"))
            check(id .. ": drawn with outline and a 1 px shadow", select(3, fs:GetFont()) .. " "
                .. table.concat({ fs:GetShadowOffset() }, ","), "OUTLINE 1,-1")
        else
            check(id .. ": outlined text", S("valueFlag") ~= "" and S("valueFlag") ~= "SHADOW", true)
        end
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
    -- A first pick starts in the author's black; the grey paper is the first colour.
    Themes.SetColor("GREY")
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
    check("comic colour: grey is the first", registry.Colors()[1], "GREY")
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
    check("colour: wood as it is", back() .. " " .. vertex(), "WoodBack 0.5/0.5/0.5/1")
    check("colour: wood title as it is", title(), table.concat(S("headerColor"), "/", 1, 3))
    check("colour: cherry", registry.SetColor("CHERRY"), true)
    check("colour: cherry on the grey wood", back(), "WoodBackGrey")
    check("colour: cherry back / mean", vertex(), (0.30 / 0.8) .. "/" .. (0.12 / 0.8) .. "/" .. (0.08 / 0.8) .. "/1")
    check("colour: cherry keeps the title", title(), table.concat(S("headerColor"), "/", 1, 3))
    check("colour: the look not stored", ns.DB().themeSets.WOOD, nil)
    Themes.Switch("FROST")
    check("colour: frost keeps its own", registry.Color(), "AURORA")
    check("colour: aurora on the grey ice, the theme's alpha", back() .. " " .. vertex(),
        "FrostBackGrey " .. (0.10 / 0.796) .. "/" .. (0.27 / 0.796) .. "/" .. (0.24 / 0.796) .. "/0.85")
    check("colour: aurora title", title(), "0.55/1/0.8")
    registry.SetColor("ICE")
    check("colour: ice as frost was", back() .. " " .. vertex() .. " " .. title(),
        "FrostBack 0.55/0.55/0.55/0.85 " .. table.concat(S("headerColor"), "/", 1, 3))
    -- Every theme's first colour draws as before (art.tint, else white).
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
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
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
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
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
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
    local wedge = box.wedge
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
    check("console: fonts", S("headerFont") .. "/" .. S("valueFont"), "IBM Plex Sans Condensed Bold/IBM Plex Sans Condensed Bold")
    check("console: mint ring", ring(), "0.306/0.929/0.69")
    check("console: solid bars", S("barTexture"), "FCM Swiss")
    check("console: no band", box.band:IsShown(), false)
    check("console: colours", table.concat(registry.Colors(), " "), "MINT AMBER PHOSPHOR VIOLET")
    registry.SetColor("AMBER")
    check("console amber: the ring follows the title", ring() .. " " .. title(), "1/0.69/0 1/0.69/0")
    check("console amber: backdrop stays", back() .. " " .. vertex(), "ConsoleBack 1/1/1/1")
    check("console amber: not stored", S("borderColor")[1], 0.306)
    check("console amber: title icons in the accent", table.concat(gear.icon._vertex, "/", 1, 3), "1/0.69/0")
    registry.SetColor("MINT")
    check("console mint: ring as stored", ring(), "0.306/0.929/0.69")
    check("console mint: title icons in the title's colour", table.concat(gear.icon._vertex, "/", 1, 3), "0.306/0.929/0.69")
    -- Every icon accent readable on its backdrop (back, else the black
    -- title strip): at least 3:1, the contrast WCAG asks of icons.
    local function luminance(c)
        local function lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
    end
    for id, colours in pairs(LibForeverThemes.COLORS) do
        for _, c in ipairs(id ~= "COMIC" and colours or {}) do
            local a = c.accent or c.ornament
            if a then
                local ratio = (luminance(a) + 0.05) / (luminance(c.back or { 0, 0, 0 }) + 0.05)
                check(id .. " " .. c.id .. ": icon accent readable", ratio >= 3, true)
            end
        end
    end
    Themes.Switch("PITWALL")
    check("pitwall: fonts", S("headerFont") .. "/" .. S("nameFont"), "Titillium Web Bold Italic/Titillium Web SemiBold")
    check("pitwall: solid bars", S("barTexture"), "FCM Swiss")
    check("pitwall: carbon hairline", ring(), "0.043/0.047/0.055")
    check("pitwall: black title strip", f.header.dark:IsShown() and table.concat(f.header.dark._texColor, "/", 1, 3),
        "0/0/0")
    -- The family's rule: as high and wide as the strip inside the ring, its
    -- slanted part; the title (or grip) 8 past its right edge at the title's middle.
    local inset = ns.Border.Extent({ style = S("borderStyle"), size = S("borderSize") })
    local stripH = f.header:GetHeight() - inset
    check("pitwall: red wedge as high and wide as the strip, flush inside the ring", wedge:IsShown() and wedgeColor()
        .. " " .. wedge._w .. "x" .. wedge._h .. " " .. wedge._texCoord[2] .. " " .. table.concat(wedge._points.TOPLEFT, "/", 3),
        "0.882/0.024/0 " .. stripH .. "x" .. stripH .. " 0.53 0/0")
    local reach = math.floor(0.98 * stripH - 0.36 * (f.header:GetHeight() / 2 - inset) + 0.5)
    local first = f.header.grip:IsShown() and f.header.grip._points.LEFT[3] or f.header.title._points.LEFT[3]
    check("pitwall: 8 between the wedge and the title", first, inset + reach + 8)
    check("pitwall: no corner ornament", box.ornaments[1]:IsShown(), false)
    check("pitwall: colours", table.concat(registry.Colors(), " "), "RED ORANGE TEAL SILVER")
    registry.SetColor("TEAL")
    check("pitwall teal: wedge", wedgeColor(), "0/0.631/0.612")
    check("pitwall teal: title as stored", title(), table.concat(S("headerColor"), "/", 1, 3))
    local function icon3(t) return table.concat(t._vertex, "/", 1, 3) end
    check("pitwall teal: title icons and grip follow the wedge", icon3(gear.icon) .. " " .. icon3(f.header.grip),
        "0/0.631/0.612 0/0.631/0.612")
    gear:GetScript("OnEnter")(gear)
    check("pitwall teal: hover half way to white", icon3(gear.icon), "0.5/0.8155/0.806")
    gear:GetScript("OnLeave")(gear)
    registry.SetColor("RED")
    check("pitwall red: title icons in the wedge's red", icon3(gear.icon), "0.882/0.024/0")
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
    local copyItems = first[10].choices()
    check("copy list offers Classic", copyItems[1].value, "CLASSIC")
    first[10].set("CLASSIC")
    check("copy list offers undo", first[10].choices()[1].label, ns.L.OPT_THEME_UNDO)
    first[10].set(first[10].choices()[1].value)
    check("undo from the list", first[10].choices()[1].value, "CLASSIC")
    check("reset only for a theme", first[11].visible(), true)
    first[3].set("CLASSIC")
    check("no reset for Classic", first[11].visible(), false)
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

    -- "Apply to all Forever addons": only with another addon listed; puts it on
    -- this theme and colour, skips it when it lacks the theme.
    local allRow
    for _, row in ipairs(ns.Window.PAGES[1].rows()) do
        if row.buttons and row.buttons[1].label == "OPT_THEME_ALL" then allRow = row end
    end
    check("apply all: hidden alone", allRow.visible(), false)
    local pick = Themes.Colors("PIXEL")[2]
    local other, known = { theme = "CLASSIC" }, { CLASSIC = {}, PIXEL = { "NAVY", pick } }
    _G.ForeverThemes.FakeOther = {
        title = "Fake", Current = function() return other.theme end,
        Switch = function(id)
            if not known[id] then return nil, "UNKNOWN" end
            other.theme = id
            return true
        end,
        Colors = function(theme) return known[theme] end,
        SetColor = function(id) other.color = id; return true end,
    }
    check("apply all: shown with another", allRow.visible(), true)
    Themes.Switch("PIXEL")
    Themes.SetColor(pick)
    M.chat = {}
    allRow.buttons[1].onClick()
    check("apply all: theme and colour", other.theme .. " " .. tostring(other.color), "PIXEL " .. pick)
    check("apply all: says how many", (M.chat[1] or ""):find("1 other", 1, true) ~= nil, true)
    Themes.Switch("WOOD")
    check("apply all: unknown theme skipped", Themes.ApplyToAll() .. " " .. other.theme, "0 PIXEL")
    Themes.SetColor(Themes.Colors("PIXEL")[1], "PIXEL")
    Themes.Switch("CLASSIC")
    Settings.ResetProfile()

    -- A theme picked the first time looks as the author plays it (values
    -- from his saved settings, positions left out); sets stored before
    -- stay as they were.
    section("Themes: the author's look for first picks")
    Settings.ResetProfile()
    Themes.Switch("PITWALL")
    local function rgb(key) return table.concat(S(key), "/", 1, 3) end
    check("pitwall: title font", S("headerFont"), "Titillium Web Bold Italic")
    check("pitwall: row font", S("nameFont"), "Titillium Web SemiBold")
    check("pitwall: no bar track", S("barBgAlpha"), 0)
    check("pitwall: breakdown in grey", S("detailClassColor"), false)
    check("pitwall: the grey", rgb("detailBarColor"), "0.329/0.322/0.318")
    check("pitwall: black ground", rgb("bgColor"), "0.039/0.039/0.039")
    check("pitwall: red", Themes.Color(), "RED")
    Themes.Switch("COMIC")
    check("comic: black paper", Themes.Color(), "BLACK")
    check("comic: Bangers title", S("headerFont"), "Bangers")
    check("comic: no bar track", S("barBgAlpha"), 0)
    Themes.Switch("CLASSIC")
    check("Classic keeps the default track", S("barBgAlpha"), Settings.DEFAULTS.barBgAlpha)
    check("Classic keeps class colours", S("detailClassColor"), true)
    -- A set stored before (as 1.2.0 made it): unchanged after login.
    Settings.ResetProfile()
    local before = { barTexture = "FCM Comic", barBgAlpha = 40, theme = "COMIC" }
    ns.DB().themeSets = { revision = 15, CLASSIC = {}, COMIC = before }
    Themes.Upgrade()
    check("stored comic: untouched at login", ns.DB().themeSets.COMIC.barBgAlpha, 40)
    check("stored comic: nothing added at login", ns.DB().themeSets.COMIC.detailClassColor, nil)
    Themes.Switch("COMIC")
    check("stored comic: its track", S("barBgAlpha"), 40)
    check("stored comic: class colours", S("detailClassColor"), true)
    check("stored comic: first colour, not the author's", Themes.Color(), "GREY")
    Themes.Switch("CLASSIC")
    Settings.ResetProfile()
    -- Comic worn before the author's BLACK, its colour never stored: pinned
    -- GREY once, so a later reseed (Comic made anew) keeps the grey paper.
    ns.DB().themeSets = { revision = 15, CLASSIC = {} }
    ns.DB().theme = "COMIC"
    check("implicit comic grey: pinned", Themes.Color("COMIC"), "GREY")
    check("implicit comic grey: stored", ns.DB().themeSets.themeColors.COMIC, "GREY")
    Themes.Switch("CLASSIC")
    ns.DB().themeSets.revision = 14
    Themes.Switch("COMIC")
    check("implicit comic grey: survives a reseed", Themes.Color(), "GREY")
    Themes.Switch("CLASSIC")
    Settings.ResetProfile()
    ns.DB().themeSets = { revision = 15, CLASSIC = {}, TECH = {} }
    Themes.Color("COMIC")
    check("never on comic: nothing pinned", ns.DB().themeSets.themeColors.COMIC, nil)
    Settings.ResetProfile()

    -- The hub "Forever Themes": while it is followed the pickers grey out,
    -- a line and a button lead to it and "Apply to all" goes; with an own
    -- theme or without the hub the section is as before.
    section("Themes: Forever Themes hub")
    local L = ns.L
    local function shownText(text)
        for i = #M.fontStrings, 1, -1 do
            local fs = M.fontStrings[i]
            if fs._text == text and fs:IsVisible() then return fs end
        end
    end
    local function themePickerOn()
        local label = shownText(L.OPT_THEME_PICK)
        return label:GetParent().button:IsEnabled()
    end
    local follows, opened = true, 0
    LibForeverThemes.SetHub {
        Follows = function(folder) return folder == "ForeverCombatMeter" and follows end,
        OpenOptions = function() opened = opened + 1 end,
    }
    ns.Window.Open("general")
    check("hub follow: theme picker greyed", themePickerOn(), false)
    check("hub follow: still shows the theme", shownText(L.THEME_CLASSIC) ~= nil, true)
    check("hub follow: the line", shownText(LibForeverThemes.Text("HUB_FOLLOWS")) ~= nil, true)
    ns.Locale.Set("deDE")   -- the addon's own language, not the (English) client's
    check("german addon, english client: the line", shownText("Folgt Forever Themes") ~= nil, true)
    ns.Locale.Set("AUTO")
    check("hub follow: no apply to all", shownText(L.OPT_THEME_ALL), nil)
    shownText(LibForeverThemes.Text("HUB_OPEN")):GetParent():GetScript("OnClick")()
    check("hub follow: button opens the hub", opened, 1)
    Themes.Switch("PIXEL")
    check("hub follow: colour picker greyed", shownText(L.OPT_THEME_COLOR):GetParent().button:IsEnabled(), false)
    follows = false
    ns.Window.Refresh()
    check("hub own theme: picker back", themePickerOn(), true)
    check("hub own theme: colour back", shownText(L.OPT_THEME_COLOR):GetParent().button:IsEnabled(), true)
    check("hub own theme: no line", shownText(LibForeverThemes.Text("HUB_FOLLOWS")), nil)
    check("hub own theme: apply to all", shownText(L.OPT_THEME_ALL) ~= nil, true)
    LibForeverThemes.SetHub(nil)
    follows = true
    ns.Window.Refresh()
    check("no hub: picker on", themePickerOn(), true)
    check("no hub: no line, no button", (shownText(LibForeverThemes.Text("HUB_FOLLOWS")) or shownText(LibForeverThemes.Text("HUB_OPEN"))), nil)
    check("no hub: apply to all", shownText(L.OPT_THEME_ALL) ~= nil, true)
    check("no hub: the hint to get it", shownText(LibForeverThemes.Text("HUB_MISSING")) ~= nil, true)
    M.popups = {}
    shownText(LibForeverThemes.Text("HUB_LINK")):GetParent():GetScript("OnClick")()
    check("hub link: Blizzard's text popup", M.popups[1] and M.popups[1].which, "LIBFOREVERTHEMES_HUB_LINK")
    local box = { SetText = function(self, t) self.text = t end, HighlightText = function() end, SetFocus = function() end }
    StaticPopupDialogs.LIBFOREVERTHEMES_HUB_LINK.OnShow({ GetEditBox = function() return box end })
    check("hub link: the hub's CurseForge page", box.text, "https://www.curseforge.com/wow/addons/forever-themes")
    LibForeverThemes.SetHub { Follows = function() return false end }
    ns.Window.Refresh()
    check("hub own theme: no hint to get it", shownText(LibForeverThemes.Text("HUB_MISSING")), nil)
    -- A profile switch, reset or import brings its own theme: the hub puts
    -- a follower back on the central one.
    local synced = 0
    LibForeverThemes.SetHub { Follows = function() return true end, Sync = function() synced = synced + 1 end }
    ns.SwitchProfile("Hub sync")
    check("hub sync: after a profile switch", synced, 1)
    Settings.ResetProfile()
    check("hub sync: after a reset", synced, 2)
    check("hub sync: after an import", ns.Share.Import(ns.Share.Export()), true)
    check("hub sync: after an import", synced, 3)
    ns.SwitchProfile("Default")
    ns.DeleteProfile("Hub sync")
    LibForeverThemes.SetHub(nil)
    ns.Window.Toggle()
    _G.ForeverThemes.FakeOther = nil
    Themes.Switch("CLASSIC")
    Settings.ResetProfile()
end
