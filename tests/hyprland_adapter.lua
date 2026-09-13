local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."

local registered = nil
local dispatched = {}
local active_window = nil

_G.__hyprworld_focus_subscription = nil
_G.hl = {
    layout = {
        register = function(name, provider)
            registered = { name = name, provider = provider }
        end,
    },
    on = function()
        return true
    end,
    get_active_window = function()
        return active_window
    end,
    dispatch = function(dispatcher)
        table.insert(dispatched, dispatcher)
    end,
    dsp = {
        layout = function(message)
            return { kind = "layout", message = message }
        end,
        focus = function(options)
            return { kind = "focus", window = options.window }
        end,
    },
}

assert(loadfile(root .. "/layout/init.lua"))()
assert(registered and registered.name == "hyprworld", "layout did not register")

local function target(id, active)
    return {
        window = {
            stable_id = id,
            address = "0x" .. id,
            active = active,
            workspace = { id = 9 },
            layout = { name = "lua:hyprworld" },
        },
        place = function(self, box)
            self.placed = box
        end,
    }
end

local a = target("A", true)
local b = target("B", false)
active_window = a.window
local ctx = {
    area = { x = 0, y = 0, w = 1000, h = 800 },
    targets = { a, b },
}

registered.provider.recalculate(ctx)
assert(a.placed and b.placed, "recalculate did not place every target")
assert(a.placed.x < b.placed.x, "new targets should initially extend right")

local response = registered.provider.layout_msg(ctx, "focus right")
assert(response == true, "focus command was rejected")
assert(dispatched[#dispatched].kind == "focus", "focus command did not dispatch")
assert(dispatched[#dispatched].window == "address:0xB", "focus targeted the wrong window")

a.window.active = false
b.window.active = true
active_window = b.window
registered.provider.recalculate(ctx)
b.window.workspace.id = 10
a.window.active = true
b.window.active = false
active_window = a.window
local dispatch_count = #dispatched
registered.provider.layout_msg(ctx, "focus left")
registered.provider.layout_msg(ctx, "focus right")
assert(#dispatched == dispatch_count, "cross-workspace focus should be ignored")

response = registered.provider.layout_msg(ctx, "resize height shrink")
assert(response == true, "height resize command was rejected")

response = registered.provider.layout_msg(ctx, "resize height sideways")
assert(type(response) == "string", "invalid resize command should return an error")

response = registered.provider.layout_msg(ctx, "zoom in")
assert(response == true, "zoom command was rejected")
response = registered.provider.layout_msg(ctx, "zoom sideways")
assert(type(response) == "string", "invalid zoom command should return an error")

response = registered.provider.layout_msg(ctx, "resize down")
assert(response == true, "directional resize command was rejected")
response = registered.provider.layout_msg(ctx, "resize sideways")
assert(type(response) == "string", "invalid directional resize command should return an error")

response = registered.provider.layout_msg(ctx, "toggle-max")
assert(response == true, "maximum toggle command was rejected")

print("ok - mocked Hyprland adapter")
