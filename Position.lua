local ADDON, ns = ...
local Settings = ns.Settings

-- Exact positions for the options' X / Y sliders, the way Forever Progress
-- Bars counts them: X is the frame's centre from the screen's centre, Y its
-- anchored edge from the screen's top (0 at the top, negative further
-- down). Dragging stores the nearest corner instead (so resizing keeps an
-- edge still); the sliders read wherever the frame is and write a centred
-- anchor (TOP, or BOTTOM for a frame growing upwards).
local Position = {}
ns.Position = Position

local function round(v) return math.floor(v + 0.5) end

-- The frame's X / Y in UIParent units, or nil while it has no rectangle.
function Position.Read(frame, vertical)
    if not (frame and frame.GetCenter) then return nil end
    local cx = frame:GetCenter()
    if not cx then return nil end
    local s = frame:GetScale()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local edge = vertical == "BOTTOM" and frame:GetBottom() or frame:GetTop()
    return round(cx * s - sw / 2), round(edge * s - sh)
end

-- keys: { point =, x =, y = } setting names; extra: more values to store.
function Position.Write(keys, vertical, x, y, extra)
    local sh = UIParent:GetHeight()
    local values = {
        [keys.point] = vertical,
        [keys.x] = round(x),
        [keys.y] = round(vertical == "BOTTOM" and (sh + y) or y),
    }
    for k, v in pairs(extra or {}) do values[k] = v end
    Settings.SetMany(values)
end

-- The two slider rows for the options window. read(): x, y (or nil);
-- vertical(): "TOP" or "BOTTOM".
function Position.Rows(keys, frameOf, vertical, extra)
    local function current()
        local x, y = Position.Read(frameOf(), vertical())
        if not x then
            -- Not on screen yet: what the settings say for a centred anchor.
            local point = Settings.Get(keys.point)
            if point == "TOP" then return Settings.Get(keys.x), Settings.Get(keys.y) end
            return 0, 0
        end
        return x, y
    end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw <= 0 then sw = 1920 end
    if sh <= 0 then sh = 1080 end
    return {
        { label = "OPT_POS_X", min = -math.floor(sw / 2), max = math.floor(sw / 2), step = 1, unit = "px",
          get = function() return (current()) end,
          set = function(v)
              local _, y = current()
              Position.Write(keys, vertical(), v, y, extra)
          end },
        { label = "OPT_POS_Y", min = -math.floor(sh), max = 0, step = 1, unit = "px",
          get = function() local _, y = current(); return y end,
          set = function(v)
              local x = current()
              Position.Write(keys, vertical(), x, v, extra)
          end },
    }
end

-- X / Y rows for the meter window index(): the window's real place on the
-- screen in UIParent units (what Read gives), written back as a TOP anchor
-- in the window's own units (its stored x / y are divided by its scale).
function Position.WindowRows(index)
    local function current()
        local i = index()
        local f = ns.Windows.Frame(i)
        local x, y = Position.Read(f, "TOP")
        if x then return x, y end
        local c, s = ns.Windows.Config(i), (ns.Windows.Config(i).scale or 100) / 100
        return round(c.x * s), round(c.y * s)
    end
    local function write(x, y)
        local i = index()
        local s = ns.Windows.Config(i).scale / 100
        ns.Windows.SetConfig(i, { point = "TOP", x = x / s, y = y / s })
    end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw <= 0 then sw = 1920 end
    if sh <= 0 then sh = 1080 end
    return {
        { key = "x", label = "OPT_POS_X", min = -math.floor(sw / 2), max = math.floor(sw / 2), step = 1, unit = "px",
          get = function() return (current()) end,
          set = function(v) local _, y = current(); write(v, y) end },
        { key = "y", label = "OPT_POS_Y", min = -math.floor(sh), max = 0, step = 1, unit = "px",
          get = function() local _, y = current(); return y end,
          set = function(v) local x = current(); write(x, v) end },
    }
end
