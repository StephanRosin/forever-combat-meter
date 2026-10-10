local ADDON, ns = ...

-- Which language ns.L speaks. The setting is account wide and lives next to
-- the profiles (ForeverCombatMeterProfiles.language), not in a profile:
-- switching or copying a profile keeps your language. "AUTO", or no value,
-- follows the game; a game language without a translation gets English.
local Locale = {}
ns.Locale = Locale

-- The game's locale -> the translation used for it.
Locale.GAME = { deDE = "deDE", esES = "esES", esMX = "esES", frFR = "frFR" }
Locale.DEFAULT = "enUS"

-- The choices in the options, each language in its own name.
Locale.CHOICES = {
    { value = "enUS", label = "English" },
    { value = "deDE", label = "Deutsch" },
    { value = "esES", label = "Español" },
    { value = "frFR", label = "Français" },
}

local current
local listeners = {}

-- The language a setting value stands for.
function Locale.Resolve(setting, gameLocale)
    if setting ~= nil and setting ~= "AUTO" and ns.Locales[setting] then return setting end
    return Locale.GAME[gameLocale] or Locale.DEFAULT
end

function Locale.Current()
    return current
end

-- The stored setting: "AUTO" or a language code.
function Locale.Setting()
    local store = ns.AccountDB and ns.AccountDB()
    return (store and store.language) or "AUTO"
end

-- Called with the new code whenever the language changes (the options page
-- relabels itself).
function Locale.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function use(code)
    if code == current then return false end
    current = code
    ns.SetActiveLocale(code)
    for _, fn in ipairs(listeners) do fn(code) end
    return true
end

-- Stores the setting and applies it at once.
function Locale.Set(setting)
    local store = ns.AccountDB()
    store.language = (setting ~= "AUTO") and setting or nil
    use(Locale.Resolve(setting, GetLocale()))
end

-- Once the saved variables are loaded.
function Locale.Apply()
    use(Locale.Resolve(Locale.Setting(), GetLocale()))
end

use(Locale.Resolve("AUTO", GetLocale and GetLocale()))

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Locale.Apply()
end)
