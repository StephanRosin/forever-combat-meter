local ADDON, ns = ...

-- Number, name and time formatting that is safe for secret values.
--
-- In combat C_DamageMeter hands out secret names and amounts. The client lets
-- addon code display them but raises on comparison, arithmetic, ".." and the
-- integer format; string.format with a string or fixed-point conversion and
-- AbbreviateLargeNumbers are allowed and return a (secret) display string.
-- Every function here checks IsSecret first and then only takes the allowed
-- path; plain values get the nicer k/M formatting.

local Format = {}
ns.Format = Format

local issecret = issecretvalue or function() return false end
local format, floor = string.format, math.floor

function Format.IsSecret(v)
    return issecret(v) and true or false
end

-- 950, 1.2k, 12.3k, 1.23M, 2.50B.
local function plainAmount(v)
    local a = v < 0 and -v or v
    if a >= 1e9 then return format("%.2fB", v / 1e9) end
    if a >= 1e6 then return format("%.2fM", v / 1e6) end
    if a >= 1e3 then return format("%.1fk", v / 1e3) end
    return format("%.0f", v)
end

local function secretAmount(v)
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(v) end
    return format("%.0f", v)
end

function Format.Amount(v)
    if issecret(v) then return secretAmount(v) end
    if v == nil then return "0" end
    return plainAmount(v)
end

-- Rates below 100 keep one decimal (interrupts, dispels per second).
-- precise: a secret rate keeps one decimal too (counts per second are small).
function Format.PerSecond(v, precise)
    if issecret(v) then
        if precise then return format("%.1f", v) end
        return secretAmount(v)
    end
    if v == nil then return "0" end
    if v < 100 and v > -100 then return format("%.1f", v) end
    return plainAmount(v)
end

-- p is 0..100; nil (in combat: no percent) gives an empty string.
function Format.Percent(p)
    if issecret(p) then return format("%.1f%%", p) end
    if p == nil then return "" end
    return format("%.1f%%", p)
end

-- "3. Name" or "Name". Never concatenates: the name may be secret.
function Format.Name(rank, name)
    if not issecret(name) and name == nil then name = "?" end
    if rank == nil then return format("%s", name) end
    return format("%s. %s", rank, name)
end

-- 0:09, 1:05, 1:02:05. A secret duration cannot be split: "65s".
function Format.Duration(sec)
    if issecret(sec) then return format("%.0fs", sec) end
    if sec == nil or sec < 0 then return "" end
    local s = floor(sec)
    local h, m = floor(s / 3600), floor(s % 3600 / 60)
    s = s % 60
    if h > 0 then return format("%.0f:%02.0f:%02.0f", h, m, s) end
    return format("%.0f:%02.0f", m, s)
end

-- A value that is there; a secret counts as present without being touched.
function Format.Present(v)
    return issecret(v) or v ~= nil
end

-- "Spell" or "Spell \194\183 Creature" (damage taken: who hit). The name may
-- be secret: string.format only. creature is plain or nil (Meter.Spells).
function Format.SpellLabel(sp)
    if sp.creature then return format("%s \194\183 %s", sp.name, sp.creature) end
    return format("%s", sp.name)
end

-- "total" or "total (percent)"; percent nil (in combat) leaves it out.
function Format.ValueText(total, percent)
    if percent ~= nil then return format("%s (%s)", Format.Amount(total), Format.Percent(percent)) end
    return Format.Amount(total)
end
