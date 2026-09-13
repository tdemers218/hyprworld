local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."

local bindings = {}
local dispatched = {}
local active_layout = "lua:hyprworld"
local real_open = io.open
local preferences = nil
io.open = function(path, mode)
    if path:match("hyprworld%.json$") or path:match("/customizer%.json$") then
        if not preferences then return nil end
        return { read = function() return preferences end, close = function() end }
    end
    return real_open(path, mode)
end

_G.o = {
    bind = function(keys, _, action)
        bindings[keys] = action
    end,
}

_G.hl = {
    config = function(options) assert(options.binds.scroll_event_delay == 0) end,
    animation = function(options) assert(options.style == "slide" and options.enabled) end,
    bind = function(keys, action, options)
        bindings[keys] = action
        return {set_enabled=function() end}
    end,
    unbind = function(key) bindings[key] = nil end,
    get_active_window = function()
        return { layout = { name = active_layout } }
    end,
    dispatch = function(value)
        table.insert(dispatched, value)
    end,
    dsp = {
        layout = function(message) return { kind = "layout", message = message } end,
        focus = function(options) return { kind = "focus", direction = options.direction, workspace = options.workspace } end,
        window = {
            drag = function() return {kind="native-drag"} end,
            swap = function(options) return { kind = "swap", direction = options.direction } end,
            resize = function(options) return { kind = "resize", options = options } end,
        },
        group = {
            prev = function() return { kind = "group-prev" } end,
            next = function() return { kind = "group-next" } end,
        },
    },
}

assert(loadfile(root .. "/integration/omarchy.lua"))()

assert(type(bindings["SUPER + LEFT"]) == "function", "left binding was not installed")
bindings["SUPER + LEFT"]()
assert(dispatched[#dispatched].kind == "layout", "2D layout did not receive focus")
assert(dispatched[#dispatched].message == "focus left", "wrong 2D focus message")

active_layout = "scrolling"
local dispatch_count = #dispatched
bindings["SUPER + LEFT"]()
assert(#dispatched == dispatch_count, "non-Hyprworld focus must be ignored")

active_layout = "lua:hyprworld"
assert(bindings["SUPER + SHIFT + code:21"] == nil, "legacy resize binding should be removed")

bindings["SUPER + CTRL + UP"]()
assert(dispatched[#dispatched].message == "zoom in", "wrong zoom-in message")
bindings["SUPER + CTRL + RIGHT"]()
assert(dispatched[#dispatched].workspace == "r+1")
active_layout="dwindle"
bindings["SUPER + CTRL + LEFT"]()
assert(dispatched[#dispatched].workspace == "r-1")
active_layout="lua:hyprworld"

bindings["SUPER + ALT + LEFT"]()
assert(dispatched[#dispatched].message == "resize left", "wrong directional resize message")

assert(bindings["SUPER + CTRL + ALT + LEFT"] == nil, "legacy directional shrink binding should be removed")

bindings["SUPER + ALT + F"]()
assert(dispatched[#dispatched].message == "toggle-max", "wrong maximum toggle message")

active_layout = "scrolling"
local dispatch_count = #dispatched
bindings["SUPER + ALT + LEFT"]()
assert(#dispatched == dispatch_count, "grouping fallback should be removed outside 2D")
bindings["SUPER + ALT + F"]()
assert(dispatched[#dispatched].kind == "layout", "non-2D maximum fallback did not run")
assert(dispatched[#dispatched].message == "colresize +conf", "wrong non-2D maximum fallback")

active_layout = "lua:hyprworld"
for _, modifier in ipairs({ "CTRL + SHIFT", "CTRL + ALT" }) do
    bindings = {}
    preferences = '{"zoomIn":"SUPER + ' .. modifier .. ' + UP","zoomOut":"SUPER + ' .. modifier .. ' + DOWN"}'
    assert(loadfile(root .. "/integration/omarchy.lua"))()
    bindings["SUPER + " .. modifier .. " + UP"]()
    assert(dispatched[#dispatched].message == "zoom in")
    bindings["SUPER + ALT + UP"]()
    assert(dispatched[#dispatched].message == "resize up", "zoom displaced resize")
    bindings["SUPER + SHIFT + UP"]()
    assert(dispatched[#dispatched].message == "move up", "zoom displaced move")
end
preferences = '{"zoomIn":"SUPER + CTRL + H","focusLeft":"SUPER + F8","settings":"SUPER + F9"}'
bindings = {}
assert(loadfile(root .. "/integration/omarchy.lua"))()
bindings["SUPER + CTRL + H"]()
assert(dispatched[#dispatched].message == "zoom in", "custom key was not installed")
assert(bindings["SUPER + F8"] and bindings["SUPER + F9"], "not all actions can be remapped")
bindings["SUPER + mouse_up"]()
assert(dispatched[#dispatched].message == "zoom-wheel in")
bindings["SUPER + mouse:274"]()
assert(dispatched[#dispatched].message == "gesture-pan")
bindings["SUPER + mouse:272"]()
assert(dispatched[#dispatched].message == "gesture-move")
bindings["mouse:272"]()
assert(dispatched[#dispatched].message == "gesture-end")
active_layout="dwindle"
bindings["SUPER + mouse_down"]()
assert(dispatched[#dispatched].workspace == "m+1")
bindings["SUPER + mouse:272"]()
assert(dispatched[#dispatched].kind == "native-drag")
bindings["SUPER + mouse:272"]() -- native dispatcher requests a release callback
assert(dispatched[#dispatched].kind == "native-drag")
_G.__hyprworld_enabled = false
bindings = {["SUPER + LEFT"] = "native"}
assert(loadfile(root .. "/integration/omarchy.lua"))()
assert(bindings["SUPER + LEFT"] == "native" and bindings["SUPER + F9"], "disabled plugin displaced native controls")
_G.__hyprworld_enabled = nil
io.open = real_open
print("ok - Omarchy integration, arbitrary remapping and disabled controller")
