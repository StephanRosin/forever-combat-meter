--[[---------------------------------------------------------------------------
Share.lua -- the active profile as a string to pass on, and back.

    FCM1:<value>

A value is n<number>; (a number), b1 / b0 (on, off), s<length>:<text> (a
text, its length in bytes, so any character may follow) or t ... } (a
table: key and value, key and value, then "}").

Decoding is a small reader of exactly this grammar, never loadstring: an
imported string comes from someone else and must not run as code. What it
yields is checked again before anything is applied: only settings the
addon knows, with the type of their default; numbers are clamped to their
range by Settings.Set. Unknown keys are skipped, so a string from a newer
version still imports what this one understands.

Profile values that are not plain settings (the window layout, `windows`,
owned by Windows.lua) register a cleaner with Share.RegisterTable: it gets
the decoded value and returns what may be kept (or nil).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Settings = ns.Settings

local Share = {}
ns.Share = Share

Share.PREFIX = "FCM1:"
-- Guards against a string that nests without end.
local MAX_DEPTH = 4

-- Encoding ------------------------------------------------------------------------
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end

local encode
function encode(v, out)
    local kind = type(v)
    if kind == "number" then
        out[#out + 1] = "n" .. (v == math.floor(v) and ("%d"):format(v) or ("%.4f"):format(v)) .. ";"
    elseif kind == "boolean" then
        out[#out + 1] = v and "b1" or "b0"
    elseif kind == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif kind == "table" then
        out[#out + 1] = "t"
        for _, k in ipairs(sortedKeys(v)) do
            encode(k, out)
            encode(v[k], out)
        end
        out[#out + 1] = "}"
    end
end

-- The active profile: everything it stores (only what differs from the
-- defaults, so the string stays short).
function Share.Export()
    local out = { Share.PREFIX }
    encode(ns.DB(), out)
    return table.concat(out)
end

-- Decoding ------------------------------------------------------------------------
-- Reads one value at position i; returns the value and the next position,
-- or nil on anything that does not fit the grammar.
local decode
function decode(s, i, depth)
    local tag = s:sub(i, i)
    if tag == "n" then
        local j = s:find(";", i + 1, true)
        if not j then return nil end
        local n = tonumber(s:sub(i + 1, j - 1))
        if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
        return n, j + 1
    elseif tag == "b" then
        local flag = s:sub(i + 1, i + 1)
        if flag ~= "0" and flag ~= "1" then return nil end
        return flag == "1", i + 2
    elseif tag == "s" then
        local colon = s:find(":", i + 1, true)
        if not colon then return nil end
        local len = tonumber(s:sub(i + 1, colon - 1))
        if not len or len < 0 or len ~= math.floor(len) or colon + len > #s then return nil end
        return s:sub(colon + 1, colon + len), colon + len + 1
    elseif tag == "t" then
        if depth >= MAX_DEPTH then return nil end
        local t, pos = {}, i + 1
        while s:sub(pos, pos) ~= "}" do
            if pos > #s then return nil end
            local k, v
            k, pos = decode(s, pos, depth + 1)
            if k == nil or type(k) == "table" then return nil end
            v, pos = decode(s, pos, depth + 1)
            if v == nil then return nil end
            t[k] = v
        end
        return t, pos + 1
    end
    return nil
end

-- What may come in: every setting with a default, of the default's type
-- (colours: three or four numbers).
local function sameType(value, default)
    if type(default) == "table" then
        if type(value) ~= "table" then return false end
        for i = 1, #default do
            if type(value[i]) ~= "number" then return false end
        end
        return true
    end
    return type(value) == type(default)
end

-- Settings that take one of a fixed set of values; anything else is skipped.
local ENUMS = {
    style = { FOREVER = true, COMPACT = true },
    borderStyle = { NONE = true, FLAT = true, GOLD = true },
    bgMode = { SOLID = true, GRADIENT = true, TEXTURE = true },
}
for _, name in ipairs(Settings.TEXT_STYLES) do
    ENUMS[name .. "Flag"] = { [""] = true, OUTLINE = true, THICKOUTLINE = true, SHADOW = true }
end

-- key -> function(value) returning the checked value or nil.
local tables = {}
function Share.RegisterTable(key, clean)
    tables[key] = clean
end

-- Settings that no longer exist but still arrive in old strings; Windows.lua
-- moves them into the windows.
local legacy = {}
function Share.RegisterLegacy(key, clean)
    legacy[key] = clean
end

local function allowed(key, value)
    local enum = ENUMS[key]
    return not enum or enum[value] == true
end

-- The decoded profile, checked; nil and a reason when the string is not
-- one of ours.
function Share.Decode(text)
    if type(text) ~= "string" then return nil, "format" end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #Share.PREFIX) ~= Share.PREFIX then return nil, "format" end
    local body = text:sub(#Share.PREFIX + 1)
    local value, pos = decode(body, 1, 0)
    if type(value) ~= "table" or pos ~= #body + 1 then return nil, "format" end
    local clean = {}
    for key, v in pairs(value) do
        local default = Settings.DEFAULTS[key]
        if tables[key] then
            clean[key] = tables[key](v)
        elseif legacy[key] then
            clean[key] = legacy[key](v)
        elseif default ~= nil and sameType(v, default) and allowed(key, v) then
            clean[key] = v
        end
    end
    return clean
end

-- Replaces the active profile with the string's settings. True, or nil and
-- the reason.
function Share.Import(text)
    local clean, why = Share.Decode(text)
    if not clean then return nil, why end
    -- Written in one go, clamped as Settings.Set does, then one change for
    -- everything (as a profile switch), instead of a relayout per key.
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    for key, v in pairs(clean) do
        if tables[key] or legacy[key] then
            db[key] = v
        else
            v = Settings.Clamp(key, v)
            if not Settings.SameValue(v, Settings.DEFAULTS[key]) then db[key] = v end
        end
    end
    Settings.Changed(nil)
    return true
end
