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
local refuse_focus = false
local options = { follow_mouse = 1, float_switch_override_focus = 2 }
local timers = {}
local deferred = {}
local animations = {}
local tags = {}
local ticker, ticker_on = nil, false
local route_ctx = nil
local area = { x = 770, y = -104, w = 2560, h = 1414 }
local ctx = { area = area, targets = targets }
hl = {
    layout = { register = function(_, value) provider = value end },
    on = function(_, value) callback = value; return true end,
    get_active_window = function() return active end,
    get_config = function(key) return options[key:match("input%.(.+)")] end,
    animation = function(spec) animations[spec.leaf] = spec.enabled end,
    config = function(value)
        for key, v in pairs(value.input) do options[key] = v end
    end,
    timer = function(fn, settings)
        if settings.timeout==50 and settings.type=='repeat' then return {set_enabled=function() end} end
        if settings.timeout==16 and settings.type=='repeat' then
            ticker, ticker_on = fn, true
            return {set_enabled=function(_, on) ticker_on = on end}
        end
        if settings.timeout==1 and settings.type=='oneshot' then deferred[#deferred + 1] = fn; return {} end
        if settings.type=='oneshot' and settings.timeout ~= 550 then deferred[#deferred + 1] = fn; return {} end
        assert(settings.timeout == 550 and settings.type == 'oneshot')
        timers[#timers + 1] = fn
        return {}
    end,
    dsp = {
        focus = function(options) return { window = options.window } end,
        layout = function(message) return { message = message } end,
        window = { tag = function(options) return { tag = options.tag, tagged = options.window } end },
    },
    dispatch = function(action)
        if action.tag then
            local address = action.tagged:match("^address:(.+)$")
            tags[address] = tags[address] or {}
            tags[address][action.tag:sub(2)] = action.tag:sub(1, 1) == "+" or nil
            return
        end
        if action.message then
            local destination = route_ctx or ctx
            local result = provider.layout_msg(destination, action.message)
            provider.recalculate(destination)
            return result
        end
        -- Model Hyprland refusing window focus under an exclusive layer.
        if refuse_focus then return end
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
-- A commit refused under the exclusive layer stays pending for a retry.
provider.layout_msg(ctx, 'overview-open')
provider.layout_msg(ctx, 'focus left')
provider.recalculate(ctx)
provider.layout_msg(ctx, 'overview-close')
provider.recalculate(ctx)
local selected = __hyprworld_preview():match('"commitAddress":"(0x%x+)"')
assert(selected and selected ~= '0x5', 'keyboard selection was not committed')
refuse_focus = true
provider.layout_msg(ctx, 'overview-commit ' .. selected)
provider.recalculate(ctx)
refuse_focus = false
assert(active == targets[5].window, 'refused commit changed focus')
assert(__hyprworld_preview():match('"commitAddress":"' .. selected .. '"'), 'refused commit dropped the selection')
provider.layout_msg(ctx, 'overview-commit ' .. selected)
provider.recalculate(ctx)
assert(active.address == selected, 'retried commit did not focus the selection')
assert(__hyprworld_preview():match('"commitAddress":""'), 'landed commit stayed pending')
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
-- Closing the focused window with no compositor focus hands focus to its
-- nearest neighbour and moves the camera there.
assert(#deferred == 0, 'refocus scheduled without a close')
local closing = active
for i, target in ipairs(targets) do
    if target.window == closing then table.remove(targets, i); break end
end
closing.active = false
active = nil
provider.recalculate(ctx)
assert(#deferred == 1, 'close did not schedule a refocus')
deferred[1]()
assert(active and active ~= closing, 'close left no focused window')
local focused_box
for _, target in ipairs(targets) do if target.window == active then focused_box = target.box end end
assert(focused_box.x >= area.x and focused_box.x + focused_box.w <= area.x + area.w, 'camera did not follow the refocused window')
-- The launch prediction matches where the next window actually lands once
-- it is mapped and focused.
provider.layout_msg(ctx, 'launch-preview')
provider.recalculate(ctx)
local function field_of(text, name) return tonumber(text:match('"' .. name .. '":(-?[%d%.e%-]+)')) end
local predicted = __hyprworld_preview():match('"launchBox":(%b{})')
assert(predicted, 'launch prediction missing from snapshot')
-- The camera already shows the empty slot, so mapping moves nothing else.
local focused_before
for _, target in ipairs(targets) do if target.window == active then focused_before = target.box end end
assert(focused_before and focused_before.x + focused_before.w <= field_of(predicted, 'x') + 1
    or focused_before.x >= field_of(predicted, 'x') + field_of(predicted, 'w') - 1
    or focused_before.y + focused_before.h <= field_of(predicted, 'y') + 1
    or focused_before.y >= field_of(predicted, 'y') + field_of(predicted, 'h') - 1,
    'launch slot overlaps the focused window')
-- The overlay releasing the keyboard re-focuses the old window; the camera
-- must stay on the empty slot.
local slot_camera = __hyprworld_preview():match('"cameraCol":(-?[%d%.]+)')
callback(active)
provider.recalculate(ctx)
assert(__hyprworld_preview():match('"cameraCol":(-?[%d%.]+)') == slot_camera, 'refocus panned away from the launch slot')
local newcomer = { window = { stable_id = 99, address = '0x99', active = false,
    workspace = { id = 2 }, layout = { name = 'lua:hyprworld' } },
    place = function(self, box) self.box = box end }
targets[#targets + 1] = newcomer
provider.recalculate(ctx)
-- Hyprland focuses a newly mapped window itself.
if active then active.active = false end
active = newcomer.window
active.active = true
callback(active)
provider.recalculate(ctx)
local function field(text, name) return tonumber(text:match('"' .. name .. '":(-?[%d%.e%-]+)')) end
for _, name in ipairs({ 'x', 'y', 'w', 'h' }) do
    assert(math.abs(field(predicted, name) - newcomer.box[name]) < 0.5,
        'predicted ' .. name .. ' ' .. field(predicted, name) .. ' but window landed at ' .. newcomer.box[name])
end
-- A splash window unmapping makes Hyprland re-focus an older window; the
-- camera stays on the launched app and focus returns to it.
local camera_on_app = __hyprworld_preview():match('"cameraCol":(-?[%d%.]+),')
local older = targets[1].window
active.active = false
active = older
older.active = true
local before_deferred = #deferred
callback(older)
provider.recalculate(ctx)
assert(#deferred == before_deferred + 1, 'focus was not handed back to the launched app')
deferred[#deferred]()
assert(active == newcomer.window, 'launched app did not get focus back')
for _, name in ipairs({ 'x', 'y' }) do
    assert(math.abs(field(predicted, name) - newcomer.box[name]) < 0.5, 'camera left the launched app')
end
-- Reopening the overview before the app maps cancels the launch: focus
-- changes are no longer handed back to it.
provider.layout_msg(ctx, 'launch-preview'); provider.recalculate(ctx)
provider.layout_msg(ctx, 'launch-cancel')
local layout_msg, handled = provider.layout_msg, false
provider.layout_msg = function(destination, message)
    if message == 'refresh' or message == 'follow' then handled = true end
    return layout_msg(destination, message)
end
active.active = false; older.active = true; active = older
callback(older); provider.recalculate(ctx)
provider.layout_msg = layout_msg
assert(handled, 'a cancelled launch still guarded focus')
older.active = false; newcomer.window.active = true; active = newcomer.window
callback(active); provider.recalculate(ctx)
-- A live trackpad swipe moves the camera with the fingers, commits to the
-- neighbour exactly where the preview ended, and a short swipe returns.
local function box_of(window) for _, t in ipairs(targets) do if t.window == window then return t.box end end end
provider.layout_msg(ctx, 'follow launch-expired')
provider.recalculate(ctx)
local start_box = { x = box_of(active).x, y = box_of(active).y }
options.follow_mouse = 1
provider.layout_msg(ctx, 'swipe-begin left')
assert(animations.windowsMove == false and options.follow_mouse == 2, 'swipe did not pause animation and pointer focus')
provider.layout_msg(ctx, 'swipe-update 0.5'); provider.recalculate(ctx)
local half = box_of(active).x
provider.layout_msg(ctx, 'swipe-update 1'); provider.recalculate(ctx)
local full = box_of(active).x
assert(half ~= start_box.x and math.abs((half - start_box.x) * 2 - (full - start_box.x)) < 0.5, 'camera did not track the swipe')
local previewed = {}
for _, t in ipairs(targets) do previewed[t.window.address] = { x = t.box.x, y = t.box.y } end
local before_swipe = active
provider.layout_msg(ctx, 'swipe-end commit'); provider.recalculate(ctx)
assert(active ~= before_swipe, 'committed swipe did not move focus')
assert(options.follow_mouse == 2, 'focus change during the swipe settle re-enabled hover focus')
for _, t in ipairs(targets) do
    assert(math.abs(t.box.x - previewed[t.window.address].x) < 0.5 and math.abs(t.box.y - previewed[t.window.address].y) < 0.5,
        'commit jumped away from the previewed position')
end
local committed = { x = box_of(active).x, y = box_of(active).y }
provider.layout_msg(ctx, 'swipe-begin left')
provider.layout_msg(ctx, 'swipe-update 0.2'); provider.recalculate(ctx)
provider.layout_msg(ctx, 'swipe-end cancel'); provider.recalculate(ctx)
assert(math.abs(box_of(active).x - committed.x) < 0.5, 'cancelled swipe did not return the camera')
deferred[#deferred]()
assert(options.follow_mouse == 1, 'pointer focus mode was not restored')
-- A four-finger workspace swipe slides the camera with the fingers while the
-- windows fade (the focused one less). A commit fades the whole workspace out
-- before switching and fades the destination in afterwards, so both are
-- never visible together; a cancel slides and fades everything back.
local function faded_level(address)
    for level = 1, 10 do if tags[address] and tags[address]['hyprworld-fade-' .. level] then return level end end
    return 0
end
local function run_ticker()
    for _ = 1, 200 do
        if not ticker_on then return end
        ticker()
    end
    error('workspace swipe never finished')
end
-- A second workspace to switch to.
local incoming_targets = {}
for i = 1, 2 do
    incoming_targets[i] = { window = { stable_id = 300 + i, address = '0x3' .. i, active = i == 1,
        workspace = { id = 3 }, layout = { name = 'lua:hyprworld' } },
        place = function(self, box) self.box = box end }
end
local ctx3 = { area = area, targets = incoming_targets }
provider.recalculate(ctx3)
local stepped, levels_at_switch, workspaces_animated = nil, nil, nil
__hyprworld_workspace_nav = { step = function(delta)
    stepped = delta
    workspaces_animated = animations.workspaces
    levels_at_switch = {}
    for _, t in ipairs(targets) do levels_at_switch[t.window.address] = faded_level(t.window.address) end
    route_ctx = ctx3
end }
-- The integration restores Hyprland's animations from the settings.
__hyprworld_apply_effects = function() animations.workspaces, animations.windowsMove = true, true end
local focused_address = active.address
local start_x = box_of(active).x
provider.layout_msg(ctx, 'workspace-swipe-begin 1'); provider.recalculate(ctx)
provider.layout_msg(ctx, 'workspace-swipe-update 0.3'); provider.recalculate(ctx)
assert(box_of(active).x < start_x - 1, 'camera did not slide with the fingers')
for _, t in ipairs(targets) do
    local level = faded_level(t.window.address)
    if t.window.address == focused_address then assert(level == 1, 'focused window fade ' .. level)
    else assert(level == 5, 'non-focused window fade ' .. level) end
end
provider.layout_msg(ctx, 'workspace-swipe-end cancel')
run_ticker()
for _, t in ipairs(targets) do assert(faded_level(t.window.address) == 0, 'cancel left a window faded') end
assert(math.abs(box_of(active).x - start_x) < 0.5, 'cancel did not slide the camera back')
assert(stepped == nil, 'cancelled swipe changed workspace')

provider.layout_msg(ctx, 'workspace-swipe-begin 1'); provider.recalculate(ctx)
provider.layout_msg(ctx, 'workspace-swipe-update 0.5'); provider.recalculate(ctx)
provider.layout_msg(ctx, 'workspace-swipe-end commit')
-- Watch the incoming fade: the focused window must appear before the others.
local focused_first = false
for _ = 1, 200 do
    if not ticker_on then break end
    ticker()
    if stepped and faded_level('0x31') < faded_level('0x32') then focused_first = true end
end
assert(stepped == 1, 'committed swipe did not step the workspace')
assert(workspaces_animated == false, "Hyprland's workspace slide ran during the switch")
for address, level in pairs(levels_at_switch) do
    assert(level == 10, 'window ' .. address .. ' still visible when the workspace switched')
end
assert(focused_first, 'incoming focused window did not appear first')
for _, t in ipairs(targets) do assert(faded_level(t.window.address) == 0, 'outgoing fade not cleared') end
for _, t in ipairs(incoming_targets) do assert(faded_level(t.window.address) == 0, 'incoming fade not cleared') end
assert(animations.workspaces ~= false, 'workspace animation not restored')
route_ctx = nil
print('ok - rapid focus, mouse cooldown and overview selection committed after layer release')
