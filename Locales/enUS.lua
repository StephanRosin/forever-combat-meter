local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Combat Meter"
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."
L.MSG_IMPORTED = "Profile imported."
L.MINIMAP_LEFT_CLICK = "Left-click: options"
L.OPEN_OPTIONS = "Open the options"
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.PAGE_GENERAL = "General"
L.PAGE_PROFILES = "Profiles"
L.OPT_MINIMAP = "Minimap"
L.OPT_MINIMAP_SHOW = "Minimap button"
L.OPT_POSITION = "Position and size"
L.OPT_LOCK = "Locked"
L.OPT_SCALE = "Scale"
L.OPT_FADE = "Fading"
L.OPT_FADE_ALPHA = "Opacity without the mouse over it"
L.OPT_BACKGROUND = "Background"
L.OPT_BG_MODE = "Kind"
L.BG_SOLID = "Solid"
L.BG_GRADIENT = "Gradient"
L.BG_TEXTURE = "Texture"
L.OPT_BG_COLOR = "Colour"
L.OPT_BG_TEXTURE = "Texture"
L.OPT_BG_ALPHA = "Opacity"
L.OPT_HEADER_LINE = "Line under the header"
L.OPT_BORDER = "Border"
L.OPT_BORDER_STYLE = "Style"
L.BORDER_GOLD = "Gold"
L.BORDER_FLAT = "Flat"
L.BORDER_NONE = "None"
L.OPT_BORDER_SIZE = "Thickness"
L.OPT_BORDER_COLOR = "Colour (flat)"
L.OPT_CORNER_RADIUS = "Corner radius"
L.OPT_SHADOW = "Shadow"
L.OPT_SHADOW_SHOW = "Drop shadow"
L.OPT_SHADOW_SIZE = "Size"
L.OPT_SHADOW_ALPHA = "Strength"
L.STYLE_HEADER = "Header"
L.OPT_FONT = "Font"
L.OPT_FONT_SIZE = "Size"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_SHADOW = "Shadow"
L.OUTLINE_NORMAL = "Outline"
L.OUTLINE_THICK = "Thick outline"
L.OPT_COLOR = "Colour"
L.OPT_BAR_HEIGHT = "Height"
L.OPT_BAR_TEXTURE = "Texture"
L.OPT_BAR_COLOR = "Colour"
L.OPT_BAR_BG_ALPHA = "Empty part"
L.OPT_PROFILES = "Profiles"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Delete the profile \"%s\"?"
L.OPT_SHARE = "Share"
L.OPT_SHARE_HINT = "Export copies the active profile as a string; paste a string and click Import to take it over."
L.OPT_EXPORT = "Export"
L.OPT_IMPORT = "Import"
L.OPT_RESET = "Reset"
L.OPT_RESET_HINT = "Back to the defaults for the active profile."
L.OPT_RESET_BUTTON = "Reset the profile"
L.OPT_POS_X = "Horizontal (from the centre)"
L.OPT_POS_Y = "Vertical (from the top)"
L.MSG_LOCKED = "Windows locked."
L.MSG_UNLOCKED = "Windows unlocked: drag the header to move a window, the corner to resize it."
L.MSG_USAGE = "/fcm (options), /fcm lock, /fcm unlock"
L.MSG_IMPORT_FAILED = "That is not a Forever Combat Meter profile string."
L.MINIMAP_RIGHT_CLICK = "Right-click: lock or unlock the windows"
L.OPT_UNLOCK_FRAME = "Unlock the windows"
L.OPT_LOCK_FRAME = "Lock the windows"
L.OPT_GENERAL = "General"
L.OPT_REFRESH = "Update interval"
L.OPT_STYLE = "Style"
L.STYLE_FOREVER = "Forever (quest log look)"
L.STYLE_COMPACT = "Compact"
L.MINIMAP_DRAG = "Drag: move this button"
L.INHERITED = "(inherited)"
L.RESET_OVERRIDE = "Reset"

-- Meter windows
L.MODE_DAMAGE = "Damage"
L.MODE_HEALING = "Healing"
L.MODE_ABSORBS = "Absorbs"
L.MODE_TAKEN = "Damage taken"
L.MODE_ENEMYTAKEN = "Enemy damage taken"
L.MODE_AVOIDABLE = "Avoidable damage"
L.MODE_INTERRUPTS = "Interrupts"
L.MODE_DISPELS = "Dispels"
L.MODE_DEATHS = "Deaths"
L.MODE_THREAT = "Threat"
L.SESSION_CURRENT = "Current"
L.SESSION_OVERALL = "Overall"
L.SESSION_FIGHT = "Fight %s"
L.SESSION_NONE = "No past fights"
L.MENU_MODE = "Mode"
L.MENU_SESSION = "Session"
L.MENU_NEW_WINDOW = "New window"
L.MENU_CLOSE_WINDOW = "Close window"
L.MENU_LOCK = "Lock window"
L.MENU_UNLOCK = "Unlock window"
L.MENU_RESET = "Reset data"
L.MENU_OPTIONS = "Options"
L.TIP_MENU = "Menu (or right-click the header)"
L.TIP_RESET = "Reset all meter data"
L.TIP_LOCK_WINDOW = "Lock this window"
L.TIP_UNLOCK_WINDOW = "Unlock this window"
L.TIP_SESSION = "Left-click: current / overall. Right-click: past fights."
L.TIP_MODE = "Mode (or the mouse wheel over the header)"
L.TIP_RESIZE = "Drag: width and rows"
L.POPUP_RESET = "Reset all meter data?"
L.MSG_RESET_COMBAT = "Data can only be reset out of combat."
L.EMPTY_NO_DATA = "No data"
L.THREAT_UNAVAILABLE = "Threat not available"
L.THREAT_NO_TARGET = "No target"
L.THREAT_TANK = "tank"
L.METER_UNAVAILABLE = "Meter not available"
