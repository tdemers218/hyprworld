local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."

local registered = nil
local dispatched = {}
local active_window = nil
local active_handler

_G.__hyprworld_focus_subscription = nil
_G.hl = {
    layout = {
        register = function(name, provider)
            registered = { name = name, provider = provider }
        end,
    },
    on = function(name, callback)
        if name=="window.active" then active_handler=callback end
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

local placement_count=0
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
            placement_count=placement_count+1
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

-- Crossing monitors changes keyboard focus before release. The move must still
-- dispatch against the original source, even from an empty destination context.
local source_monitor={name="LEFT",active_workspace={id=9}}
local other_monitor={name="RIGHT",x=1000,y=-200,active_workspace={id=12}}
local cursor_monitor=source_monitor
local cursor={x=0,y=0}
local follow_mouse=1
local tick
local preview_events={}
hl.dsp.event=function(message) preview_events[#preview_events+1]=message; return {kind="event"} end
hl.get_cursor_pos=function() return cursor end
hl.get_monitor_at_cursor=function() return cursor_monitor end
hl.get_config=function(name) return name=="input.follow_mouse" and follow_mouse or 0 end
hl.config=function(value) if value.input and value.input.follow_mouse~=nil then follow_mouse=value.input.follow_mouse end end
hl.timer=function(callback) tick=callback;return {set_enabled=function() end} end
hl.dsp.window={move=function(options) return {kind="move",options=options} end}
__hyprworld_apply_mouse=function() end
a.window.monitor=source_monitor
b.window.monitor=source_monitor
b.window.workspace.id=9
a.window.active=true; b.window.active=false; active_window=a.window
registered.provider.recalculate(ctx)
cursor={x=a.placed.x+a.placed.w/2,y=a.placed.y+a.placed.h/2}
registered.provider.layout_msg(ctx,"gesture-move")
cursor_monitor=other_monitor
cursor={x=1400,y=300}
active_window={workspace={id=12},layout={name="other"}}
active_handler(active_window,"mouse")
tick()
local preview=__hyprworld_preview()
assert(preview:find('"monitorX":1000',1,true) and preview:find('"monitorY":-200',1,true),"destination origin missing")
assert(preview:find('Release to move to RIGHT',1,true),"transfer hint missing")
assert(preview:find('"ghost":',1,true) and preview:find('"workspaceId":9',1,true),"drag lost its source snapshot after focus changed")
assert(preview_events[#preview_events]:find('"ghost":',1,true),"pushed snapshot omitted drag outline")
-- Returning to the source must remove the transfer hint, then crossing again restores it.
cursor_monitor=source_monitor
cursor={x=a.placed.x+a.placed.w/2+20,y=a.placed.y+a.placed.h/2}
tick()
assert(not __hyprworld_preview():find('Release to move',1,true),"transfer hint stuck after returning")
cursor_monitor=other_monitor; cursor={x=1400,y=300}; tick()
assert(__hyprworld_finish_gesture(),"monitor focus cancelled the drag")
assert(not preview_events[#preview_events]:find('"gesture":',1,true),"release left an outline visible")
assert(dispatched[#dispatched-1].kind=="move")
assert(dispatched[#dispatched-1].options.window=="address:0xA")
assert(dispatched[#dispatched-1].options.workspace=="12")
assert(dispatched[#dispatched].window=="address:0xA")
assert(follow_mouse==1,"drag did not restore pointer settings")
assert(not __hyprworld_finish_gesture(),"release committed twice")
print("ok - mocked Hyprland adapter and cross-monitor drag after focus changes")

-- Large titles reproduce the socket's 1024-byte truncation. Every fragment
-- must fit and preserve UTF-8; drag frames must arrive on either monitor.
a.window.title=string.rep("雪😀, title ",220)
active_window=a.window;cursor_monitor=source_monitor
preview_events={}
registered.provider.recalculate(ctx)
cursor={x=a.placed.x+a.placed.w/2,y=a.placed.y+a.placed.h/2}
registered.provider.layout_msg(ctx,"gesture-move")
local startup_events=preview_events
preview_events={}
local placements_before_drag=placement_count
for frame=1,20 do
    cursor_monitor=frame<=10 and source_monitor or other_monitor
    cursor={x=frame<=10 and a.placed.x+a.placed.w/2+frame*10 or 1400+frame*10,y=300}
    tick()
end
assert(#preview_events==20,"each drag tick should emit exactly one geometry event")
assert(placement_count==placements_before_drag,"moving the outline re-placed actual windows")
for _,event in ipairs(startup_events) do
    assert(#event<=1024 and utf8.len(event),"initial snapshot exceeded event limits")
    if os.getenv('HYPRWORLD_TEST_PREVIEW_EVENTS') then print(event) end
end
for _,event in ipairs(preview_events) do
    assert(event:find('hyprworld-drag,',1,true)==1,"pointer motion resent the workspace model")
    assert(not event:find('"tiles":',1,true),"drag event contains window metadata")
    assert(#event<=1024,"preview event exceeds compositor limit")
    assert(utf8.len(event),"fragment split a UTF-8 codepoint")
    if os.getenv('HYPRWORLD_TEST_PREVIEW_EVENTS') then print(event) end
end
__hyprworld_finish_gesture()
