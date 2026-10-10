local ADDON, ns = ...

-- Every user setting, its default and its range. The active profile
-- (Profiles.lua) stores only what differs from the default; Get falls back to
-- DEFAULTS. Set writes the profile and tells the listeners (the windows, the
-- minimap button, the options window).
local Settings = {}
ns.Settings = Settings

-- The text styles; each has <prefix>Font, Size, Flag and Color.
Settings.TEXT_STYLES = { "header", "name", "value" }

-- The windows themselves (position, size, mode, session) are a table per
-- window in the profile, `windows`, owned by Windows.lua.
Settings.DEFAULTS = {
    -- General
    refresh = 0.2,          -- seconds between redraws
    style = "FOREVER",      -- FOREVER (quest log look) or COMPACT
    hideBlizzard = false,
    minimapShow = true,
    minimapAngle = 200,
    locked = false,         -- "lock all": Windows.lua copies it into every window
    windowCount = 1,

    -- Bars
    barHeight = 18,
    barSpacing = 1,
    barTexture = "Blizzard",
    barClassColor = true,
    barColor = { 0.45, 0.55, 0.75 },
    barBgAlpha = 25,        -- percent
    showIcon = true,
    showRank = true,
    showTotal = true,
    showPerSecond = true,
    showPercent = true,
    animate = true,

    -- Frame look (as the quest log's default profile)
    borderStyle = "NONE",   -- NONE, FLAT or GOLD
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    cornerRadius = 10,
    shadowEnabled = true,
    shadowSize = 9,
    shadowAlpha = 65,       -- percent
    bgMode = "SOLID",       -- SOLID, GRADIENT or TEXTURE
    bgColor = { 0.047, 0.047, 0.055 },
    bgAlpha = 70,           -- percent
    bgTexture = "Blizzard Dialog Background Gold",
    headerLine = true,
    fadeAlpha = 100,        -- percent, while the mouse is not over a window

    -- Text styles. Flags: "" none, OUTLINE, THICKOUTLINE, SHADOW.
    headerFont = "Friz Quadrata",
    headerSize = 14,
    headerFlag = "SHADOW",
    headerColor = { 1, 0.82, 0.29 },
    nameFont = "Friz Quadrata",
    nameSize = 11,
    nameFlag = "SHADOW",
    nameColor = { 1, 1, 1 },
    valueFont = "Arial Narrow",
    valueSize = 12,
    valueFlag = "SHADOW",
    valueColor = { 1, 1, 1 },

    -- Threat
    threatWarn = true,
    threatWarnPct = 90,
    threatSound = true,
    showPets = true,

    -- Report
    reportLines = 5,

    -- Breakdown panel (centre anchor and offsets from UIParent)
    detailPoint = "CENTER",
    detailX = 0,
    detailY = 150,
}

-- Slider ranges, used by the options window and to clamp typed values.
Settings.RANGES = {
    refresh = { 0.05, 2 },
    windowCount = { 1, 4 },
    barHeight = { 10, 40 },
    barSpacing = { 0, 10 },
    barBgAlpha = { 0, 100 },
    borderSize = { 1, 8 },
    cornerRadius = { 0, 12 },
    shadowSize = { 1, 20 },
    shadowAlpha = { 0, 100 },
    bgAlpha = { 0, 100 },
    fadeAlpha = { 0, 100 },
    headerSize = { 8, 24 },
    nameSize = { 8, 20 },
    valueSize = { 8, 20 },
    threatWarnPct = { 50, 100 },
    reportLines = { 1, 25 },
}

-- Numbers snap to a step; the default is whole numbers.
Settings.STEPS = { refresh = 0.05 }

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed (profile switch, reset).
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

local function sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then return false end
    end
    return true
end

Settings.SameValue = sameValue

-- A number inside its range, on its step (whole numbers unless STEPS says
-- otherwise); anything else unchanged.
function Settings.Clamp(key, value)
    local range = Settings.RANGES[key]
    if not range or type(value) ~= "number" then return value end
    local step = Settings.STEPS[key] or 1
    value = math.floor(value / step + 0.5) * step
    -- Steps like 0.05 are not exact in binary: round the noise away.
    value = tonumber(("%.4f"):format(value))
    return math.max(range[1], math.min(range[2], value))
end

function Settings.Set(key, value)
    value = Settings.Clamp(key, value)
    if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
    ns.DB()[key] = value
    Settings.Changed(key)
end

-- Several values in one go, one change for all (dragging writes position
-- and size together).
function Settings.SetMany(values)
    local db = ns.DB()
    for key, value in pairs(values) do
        value = Settings.Clamp(key, value)
        if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
        db[key] = value
    end
    Settings.Changed(nil)
end

-- Locks or unlocks the windows (the options footer, the minimap button's
-- right click, /fcm lock / unlock).
function Settings.SetLocked(locked)
    Settings.Set("locked", locked and true or false)
end

-- A text style as one table: font, size, flag, color.
function Settings.TextStyle(name)
    return {
        font = Settings.Get(name .. "Font"),
        size = Settings.Get(name .. "Size"),
        flag = Settings.Get(name .. "Flag"),
        color = Settings.Get(name .. "Color"),
    }
end

-- Back to the defaults (the language is not in the profile).
function Settings.ResetProfile()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end
