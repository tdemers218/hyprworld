-- Animation curves shared by the layout and the Omarchy integration; the same
-- table and formulas as Settings.js so Lua-driven motion matches the overlay.
local M = {}

M.CURVES = {
    ["linear"] = {0, 0, 1, 1}, ["out-cubic"] = {.33, 1, .68, 1}, ["in-out-cubic"] = {.65, 0, .35, 1},
    ["out-quint"] = {.23, 1, .32, 1}, ["out-expo"] = {.16, 1, .3, 1}, ["in-out-sine"] = {.37, 0, .63, 1},
    ["emphasized"] = {.2, 0, 0, 1}, ["overshoot"] = {.34, 1.56, .64, 1},
}

-- Control points of a named or custom "bezier:x1,y1,x2,y2" curve; nil for
-- elastic and bounce, which have no bezier form.
function M.points(value)
    if M.CURVES[value] then return M.CURVES[value] end
    if value == "elastic" or value == "bounce" then return nil end
    local x1, y1, x2, y2 = tostring(value or ""):match("^bezier:(%-?[%d.]+),(%-?[%d.]+),(%-?[%d.]+),(%-?[%d.]+)$")
    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    if x1 and y1 and x2 and y2 and x1 >= 0 and x1 <= 1 and x2 >= 0 and x2 <= 1 then return {x1, y1, x2, y2} end
    return M.CURVES["out-cubic"]
end

-- Progress at time t in [0, 1].
function M.at(value, t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    if value == "elastic" then return 2^(-10*t) * math.sin((t - .075) * 2*math.pi / .3) + 1 end
    if value == "bounce" then
        local n, d = 7.5625, 2.75
        if t < 1/d then return n*t*t end
        if t < 2/d then t = t - 1.5/d; return n*t*t + .75 end
        if t < 2.5/d then t = t - 2.25/d; return n*t*t + .9375 end
        t = t - 2.625/d; return n*t*t + .984375
    end
    local p = M.points(value)
    local function axis(a, b, s) return 3*a*s*(1-s)*(1-s) + 3*b*s*s*(1-s) + s*s*s end
    local low, high, s = 0, 1, t
    for _ = 1, 30 do
        s = (low + high) / 2
        if axis(p[1], p[3], s) < t then low = s else high = s end
    end
    return axis(p[2], p[4], s)
end

-- Duration and curve an animation uses under the curve mode, as
-- Settings.effective() in QML.
function M.effective(effects, id, default_ms)
    local general = effects.curveMode == "general"
    local scale = general and (tonumber(effects.durationScale) or 1) or 1
    local ms = math.floor((tonumber(effects[id .. "Ms"]) or default_ms) * scale + .5)
    return ms, general and effects.generalCurve or effects[id .. "Curve"]
end

return M
