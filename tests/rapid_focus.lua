local root = arg[1] or '.'
-- Keep this regression independent of the user's current focus preferences.
local real_open = io.open
local preference_text = nil
io.open = function(path, mode)
    if path:match("hyprworld%.json$") or path:match("/customizer%.json$") then
        if not preference_text then return nil end
        return {read=function() return preference_text end, close=function() end}
    end
    return real_open(path, mode)
end
local provider, callback, active
local targets = {}
local focus_count = 0
local options = { follow_mouse = 1, float_switch_override_focus = 2 }
local timers = {}
local area = { x = 770, y = -104, w = 2560, h = 1414 }
local ctx = { area = area, targets = targets }
hl = {
    layout = { register = function(_, value) provider = value end },
    on = function(_, value) callback = value; return true end,
    get_active_window = function() return active end,
    get_config = function(key) return options[key:match("input%.(.+)")] end,
    config = function(value)
        for key, v in pairs(value.input) do options[key] = v end
    end,
    timer = function(fn, settings)
        if settings.timeout==50 and settings.type=='repeat' then return {set_enabled=function() end} end
        assert(settings.timeout == 550 and settings.type == 'oneshot')
        timers[#timers + 1] = fn
        return {}
    end,
    dsp = {
        focus = function(options) return { window = options.window } end,
        layout = function(message) return { message = message } end,
    },
    dispatch = function(action)
        if action.message then
            local result = provider.layout_msg(ctx, action.message)
            provider.recalculate(ctx)
            return result
        end
        for _, target in ipairs(targets) do
            if action.window == 'address:' .. target.window.address then
                local box = assert(target.box)
                local cx, cy = box.x + box.w / 2, box.y + box.h / 2
                -- Model warpTo's monitor selection at dispatch time, before
                -- window.active and the automatic post-message recalculate.
                assert(cx >= area.x and cx < area.x + area.w
                    and cy >= area.y and cy < area.y + area.h,
                    'focus dispatched while destination center was off-monitor')
                if active then active.active = false end
                active = target.window
                active.active = true
                focus_count = focus_count + 1
                callback(active)
                return
            end
        end
        error('unknown destination')
    end,
}
assert(loadfile(root .. '/layout/init.lua'))()
for i = 1, 7 do
    targets[i] = {
        window = { stable_id = i, address = '0x' .. i, active = i == 1,
            workspace = { id = 2 }, layout = { name = 'lua:hyprworld' } },
        place = function(self, box) self.box = box end,
    }
end
active = targets[1].window
provider.recalculate(ctx)
for cycle = 1, 20 do
    for _, direction in ipairs({ 'right', 'left' }) do
        for _ = 1, 9 do
            provider.layout_msg(ctx, 'focus ' .. direction)
            provider.recalculate(ctx)
        end
    end
end
assert(focus_count == 240, 'rapid navigation skipped windows')
-- Mouse/external focus must also follow immediately without a timer.
active.active = false
active = targets[7].window
active.active = true
callback(active)
local box = targets[7].box
assert(box.x >= area.x and box.x + box.w <= area.x + area.w)
assert(#timers == 0, 'keyboard navigation scheduled a delay')
local function hover(index)
    if options.follow_mouse ~= 1 then return end
    active.active = false
    active = targets[index].window
    active.active = true
    callback(active, 1)
end
hover(6)
assert(active == targets[6].window, 'first hover was delayed')
assert(options.follow_mouse == 2 and options.float_switch_override_focus == 0)
hover(5)
assert(active == targets[6].window, 'second hover was not suppressed')
provider.layout_msg(ctx, 'focus left')
assert(active == targets[5].window, 'cooldown blocked keyboard navigation')
assert(#timers == 1, 'keyboard focus extended the cooldown')
local dispatches = focus_count
timers[1]()
assert(focus_count == dispatches, 'cooldown expiry dispatched corrective focus')
assert(options.follow_mouse == 1 and options.float_switch_override_focus == 2)
hover(4)
assert(active == targets[4].window and #timers == 2, 'hover did not resume')
-- Leaving the layout restores settings; an old timer cannot end a new cooldown.
callback({ layout = { name = 'dwindle' } }, 5)
assert(options.follow_mouse == 1)
hover(3)
timers[2]()
assert(options.follow_mouse == 2, 'stale timer cancelled newer cooldown')
timers[3]()
assert(options.follow_mouse == 1)
-- The plugin's automatic mode is applied without starting a cooldown when
-- the selected window is already fully visible.
options.follow_mouse = 0
callback(active, 1)
assert(options.follow_mouse == 1 and #timers == 3)
-- Overview selection remains independent from the compositor's old active
-- window, including while the exclusive layer clears window focus entirely.
provider.layout_msg(ctx, 'overview-open')
local before_overview = focus_count
local original = active
provider.layout_msg(ctx, 'focus right')
provider.recalculate(ctx)
assert(focus_count == before_overview, 'overview navigation focused beneath layer')
assert(__hyprworld_preview():match('"active":true'), 'overview lost selected tile')
active = nil
provider.layout_msg(ctx, 'overview-highlight 0x5')
provider.recalculate(ctx)
provider.layout_msg(ctx, 'move down')
provider.recalculate(ctx)
provider.layout_msg(ctx, 'overview-close')
provider.recalculate(ctx)
assert(focus_count == before_overview, 'focused before layer release')
assert(__hyprworld_preview():match('"commitAddress":"0x5"'), 'selected window was overwritten')
active = original
provider.layout_msg(ctx, 'overview-commit 0x5')
assert(active == targets[5].window and focus_count == before_overview+1, 'exit failed to focus selection once')
provider.layout_msg(ctx, 'overview-commit 0x5')
assert(focus_count == before_overview+1, 'duplicate overview commit')
provider.layout_msg(ctx, 'overview-open')
provider.layout_msg(ctx, 'overview-select 0x2')
provider.recalculate(ctx)
provider.layout_msg(ctx, 'overview-commit 0x2')
assert(active == targets[2].window, 'overview click did not focus selected window')
provider.layout_msg(ctx, 'move right')
provider.recalculate(ctx)
local before_group_timers = #timers
local before_box = targets[2].box.x
hover(3)
assert(active == targets[3].window and #timers == before_group_timers, 'visible group focus started cooldown')
assert(targets[2].box.x == before_box, 'group focus moved camera')
preference_text = '{"workflow":{"focusMode":"click","mouseCooldownMs":550}}'
__hyprworld_apply_mouse()
assert(options.follow_mouse == 2)
hover(2)
assert(active == targets[3].window, 'click mode allowed hover')
preference_text = '{"workflow":{"focusMode":"auto","mouseCooldownMs":550}}'
__hyprworld_apply_mouse()
hover(2)
assert(active == targets[2].window and #timers == before_group_timers)
print('ok - rapid focus, mouse cooldown and overview selection committed after layer release')
