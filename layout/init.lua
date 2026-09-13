if rawget(_G, "__hyprworld_layout_registered") then return true end

local function current_dir()
    local source = debug and debug.getinfo(1, "S").source
    if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
        error("hyprworld: unable to resolve layout directory")
    end
    return source:sub(2):match("^(.*)/[^/]*$")
end

local function load_relative(filename)
    local chunk, err = loadfile(current_dir() .. "/" .. filename)
    if not chunk then error(err) end
    return chunk()
end

local config = load_relative("config.lua")
local core = load_relative("core.lua")
local preferences = load_relative("preferences.lua")
local gestures = load_relative("gestures.lua")
local gesture, gesture_timer
local function end_gesture()
    if not gesture then return end
    local old = gesture
    gesture = nil
    if gesture_timer then gesture_timer:set_enabled(false) end
    if hl.get_config("input.follow_mouse") == 2 then
        hl.config({input = {follow_mouse = old.follow_mouse}})
    end
end
_G.__hyprworld_end_gesture = end_gesture
local workspaces = {}
local publish_snapshot
local overview_transfer = false
local zoom_timer, zoom_key, zoom_mouse
local function stop_zoom()
    if zoom_timer then zoom_timer:set_enabled(false) end
    if zoom_key and workspaces[zoom_key] then
        workspaces[zoom_key].zoom_target, workspaces[zoom_key].zoom_overview = nil, nil
    end
    zoom_key = nil
    if zoom_mouse and hl.get_config("input.follow_mouse") == 2 then hl.config({input={follow_mouse=zoom_mouse}}) end
    zoom_mouse = nil
end
local snapshots = {}
local last_overview_key = nil


local function safe_field(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    if ok then return result end
end

local function window_id(window, index)
    local stable_id = safe_field(window, "stable_id")
    if stable_id ~= nil then return tostring(stable_id) end
    local address = safe_field(window, "address")
    if address then return "address:" .. tostring(address) end
    return "target:" .. tostring(index)
end

local function target_id(target, index)
    return window_id(safe_field(target, "window"), safe_field(target, "index") or index)
end

local function workspace_key(ctx)
    for _, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local workspace = safe_field(window, "workspace")
        local id = safe_field(workspace, "id")
        if id ~= nil then return "workspace:" .. tostring(id) end
        local name = safe_field(workspace, "name")
        if name then return "workspace-name:" .. tostring(name) end
    end
    return "global"
end

local function describe(ctx)
    local descriptors = {}
    local active_id = nil

    for index, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local id = target_id(target, index)
        descriptors[id] = {
            id = id,
            target = target,
            window = window,
            address = safe_field(window, "address"),
        }
        if safe_field(window, "active") then active_id = id end
    end

    return descriptors, active_id
end

local function context(ctx)
    local key = workspace_key(ctx)
    local state = workspaces[key]
    if not state then
        state = core.new_state()
        workspaces[key] = state
    end

    local descriptors, active_id = describe(ctx)
    local ids = {}
    for _, target in ipairs(ctx.targets or {}) do
        table.insert(ids, target_id(target, #ids + 1))
    end
    core.sync(state, ids, active_id, config)
    state.defer_active_camera = true

    state.keep_connected = preferences.keep_connected()
    if not state.on_move then
        state.on_move = function()
            if state.compact_timer then state.compact_timer:set_enabled(false) end
            state.compact_due=false
            local enabled,delay=preferences.keep_connected()
            if not enabled then return end
            state.compact_remaining=delay
            state.compact_wait=delay
            if not state.compact_timer then
                state.compact_timer=hl.timer(function()
                    if gesture or state.overview_drag then state.compact_remaining=state.compact_wait; return end
                    state.compact_remaining=state.compact_remaining-50
                    if state.compact_remaining>0 then return end
                    state.compact_timer:set_enabled(false)
                    if not preferences.keep_connected() then return end
                    state.compact_due=true
                    local ws=hl.get_active_workspace and hl.get_active_workspace()
                    if ws and "workspace:"..tostring(safe_field(ws,"id"))==key then
                        hl.dispatch(hl.dsp.layout("refresh"))
                    end
                end,{timeout=50,type="repeat"})
            else state.compact_timer:set_enabled(true) end
        end
    end
    if state.compact_due and not gesture and not state.overview_drag then
        state.compact_due=false
        if state.keep_connected then
            local focused=state.positions[state.focused_id]
            local col,row=focused and focused.col,focused and focused.row
            core.compact(state)
            if focused and (focused.col~=col or focused.row~=row) then core.follow(state) end
            state.compact_serial=(state.compact_serial or 0)+1
        end
    end
    return state, descriptors
end

local function same_workspace(first, second)
    local first_workspace = safe_field(first, "workspace")
    local second_workspace = safe_field(second, "workspace")
    local first_id = safe_field(first_workspace, "id")
    local second_id = safe_field(second_workspace, "id")
    if first_id ~= nil and second_id ~= nil then return first_id == second_id end

    local first_name = safe_field(first_workspace, "name")
    local second_name = safe_field(second_workspace, "name")
    return first_name ~= nil and first_name == second_name
end

local function place_state(ctx, state, descriptors)
    local placements, _, parts = core.placements(state, ctx.area, config)
    local tiles = {}
    for _, id in ipairs(state.ids) do
        local d = descriptors[id]
        local pos = state.positions[id]
        if d and pos then
            tiles[#tiles + 1] = { address = d.address, col = pos.col, row = pos.row,
                class = safe_field(d.window, "class") or "Application",
                title = safe_field(d.window, "title") or "",
                active = id == state.focused_id, box = placements[id], part = parts[id] }
        end
    end
    local first = descriptors[state.ids[1]]
    local monitor = first and safe_field(first.window, "monitor")
    if state.overview or state.pending_focus_id then last_overview_key = workspace_key(ctx) end
    snapshots[workspace_key(ctx)] = { tiles = tiles, overview = state.overview, compactSerial=state.compact_serial or 0,
        workspaceId = tonumber(workspace_key(ctx):match("workspace:(.+)")), slideDirection=state.slideDirection or 0,
        commitAddress = state.pending_focus_id and descriptors[state.pending_focus_id] and descriptors[state.pending_focus_id].address or "",
        zoom = core.zoom_value(state, config), maxZoom = config.zoom_steps[#config.zoom_steps],
        cameraCol = state.camera.col, cameraRow = state.camera.row, area = ctx.area,
        monitorX = safe_field(monitor, "x") or 0, monitorY = safe_field(monitor, "y") or 0,
        monitor = safe_field(monitor, "name") or "" }
    for id, descriptor in pairs(descriptors) do
        local placement = placements[id]
        if placement then descriptor.target:place(placement) end
    end
    if publish_snapshot then publish_snapshot(snapshots[workspace_key(ctx)]) end
end

local function focus_descriptor(ctx, state, descriptors, descriptor)
    if not descriptor or not descriptor.address then return end
    local active = hl.get_active_window()
    if active and not same_workspace(active, descriptor.window) then return end

    -- Hyprland's focus dispatcher selects a monitor from the destination's
    -- geometry, even with cursor:no_warps. Set the camera and placement goals
    -- first so an off-screen tile cannot select a neighboring monitor.
    core.observe_focus(state, descriptor.id)
    if not state.overview then core.follow(state) end
    place_state(ctx, state, descriptors)
    if not state.overview then hl.dispatch(hl.dsp.focus({ window = "address:" .. descriptor.address })) end
end

local function recalculate(ctx)
    local state, descriptors = context(ctx)
    place_state(ctx, state, descriptors)
end

local function layout_msg(ctx, message)
    local state, descriptors = context(ctx)
    local command, argument, extra = message:match("^(%S+)%s*(%S*)%s*(%S*)$")
    if command ~= "zoom-wheel" and command ~= "zoom-tick" and command ~= "refresh" then stop_zoom() end

    if command == "gesture-pan" or command == "gesture-move" then
        if state.overview then return true end
        end_gesture()
        if _G.__hyprworld_apply_mouse then _G.__hyprworld_apply_mouse() end
        local cursor = hl.get_cursor_pos()
        if not cursor then return true end
        local snapshot = snapshots[workspace_key(ctx)]
        if not snapshot then return true end
        local tile = gestures.hit(snapshot.tiles, cursor.x, cursor.y)
        if command == "gesture-move" and not tile then return true end
        gesture = {key=workspace_key(ctx), mode=command == "gesture-pan" and "pan" or "move",
            start=cursor, cursor=cursor, source=tile, x=state.camera.x or 0, y=state.camera.y or 0,
            follow_mouse=hl.get_config("input.follow_mouse"), monitor=snapshot.monitor}
        hl.config({input={follow_mouse=2}})
        if not gesture_timer then
            gesture_timer = hl.timer(function()
                if not gesture then return end
                local active = hl.get_active_window()
                local ws = safe_field(active, "workspace")
                local monitor = hl.get_monitor_at_cursor()
                if "workspace:" .. tostring(safe_field(ws, "id")) ~= gesture.key
                    or safe_field(monitor, "name") ~= gesture.monitor then end_gesture(); return end
                local pos = hl.get_cursor_pos()
                if pos and (pos.x ~= gesture.cursor.x or pos.y ~= gesture.cursor.y) then
                    hl.dispatch(hl.dsp.layout("gesture-tick"))
                end
            end, {timeout=16,type="repeat"})
        else gesture_timer:set_enabled(true) end
        if hl.dsp.event then hl.dispatch(hl.dsp.event("hyprworld-gesture")) end
    elseif command == "gesture-tick" or command == "gesture-end" then
        if not gesture or gesture.key ~= workspace_key(ctx) then end_gesture(); return true end
        local g = gesture
        if safe_field(hl.get_monitor_at_cursor(), "name") ~= g.monitor then end_gesture(); return true end
        g.cursor = hl.get_cursor_pos() or g.cursor
        local dx, dy = g.cursor.x-g.start.x, g.cursor.y-g.start.y
        g.moved = g.moved or dx*dx+dy*dy > 64
        if g.mode == "pan" then
            state.camera.x, state.camera.y = g.x+dx, g.y+dy
        elseif g.moved then
            local _, grid = core.placements(state, ctx.area, config)
            g.drop = gestures.destination(snapshots[g.key].tiles, grid, g.source, g.cursor.x, g.cursor.y)
            local b = g.source.box
            g.ghost = {x=b.x+dx,y=b.y+dy,w=b.w,h=b.h}
        end
        if command == "gesture-end" then
            end_gesture()
            if g.mode == "move" then
                for _, d in pairs(descriptors) do
                    if d.address == g.source.address then
                        core.observe_focus(state, d.id)
                        if g.moved and g.drop then
                            if g.drop.swapAddress then
                                for _, target in pairs(descriptors) do
                                    if target.address == g.drop.swapAddress then core.swap_members(state,d.id,target.id); break end
                                end
                            else core.move_to(state, g.drop.col, g.drop.row) end
                        end
                        focus_descriptor(ctx, state, descriptors, d)
                        break
                    end
                end
            end
        end
    elseif command == "overview-open" then
        end_gesture()
        state.pending_focus_id = nil
        state.overview = true
    elseif command == "overview-dismiss" then
        state.overview, state.pending_focus_id = false, nil
    elseif command == "overview-close" then
        if state.overview then state.pending_focus_id = state.focused_id end
        state.overview = false
    elseif command == "overview-commit" then
        local id = state.pending_focus_id
        if not state.overview and id and descriptors[id] and descriptors[id].address == argument then
            focus_descriptor(ctx, state, descriptors, descriptors[id])
            state.pending_focus_id = nil
        end
    elseif command == "overview-select" then
        for _, descriptor in pairs(descriptors) do
            if descriptor.address == argument then
                core.observe_focus(state, descriptor.id)
                core.follow(state)
                state.pending_focus_id = descriptor.id
                state.overview = false
                break
            end
        end
    elseif command == "overview-drag-end" then
        state.overview_drag=false
    elseif command == "overview-highlight" then
        state.overview_drag=true
        if state.overview then
            for _, descriptor in pairs(descriptors) do
                if descriptor.address == argument then core.observe_focus(state, descriptor.id); break end
            end
        end
    elseif command == "overview-swap" then
        if state.overview then
            local first, second
            for _, d in pairs(descriptors) do
                if d.address == argument then first=d.id end
                if d.address == extra then second=d.id end
            end
            if first and second then core.swap_members(state,first,second) end
        end
    elseif command == "overview-drop" then
        local col, row = extra:match("^(-?%d+),(-?%d+)$")
        col, row = tonumber(col), tonumber(row)
        if state.overview and col and row and math.abs(col) <= 10000 and math.abs(row) <= 10000 then
            for _, descriptor in pairs(descriptors) do
                if descriptor.address == argument then
                    core.observe_focus(state, descriptor.id)
                    core.move_to(state, col, row)
                    break
                end
            end
        end
    elseif command == "move-to" then
        local col, row = tonumber(argument), tonumber(extra)
        if not col or not row or math.abs(col) > 10000 or math.abs(row) > 10000 or not core.move_to(state, col, row) then
            return "hyprworld: move-to expects a different integer cell"
        end
    elseif command == "focus" then
        local id = core.focus(state, argument)
        focus_descriptor(ctx, state, descriptors, id and descriptors[id])
        return true
    elseif command == "move" then
        core.move(state, argument)
    elseif command == "pan" then
        if not core.pan(state, argument) then
            return "hyprworld: pan expects left, right, up, or down"
        end
    elseif command == "zoom-wheel" then
        if argument ~= "in" and argument ~= "out" then return true end
        end_gesture()
        local was_overview = state.overview
        core.wheel_zoom(state,config,argument == "in" and 1 or -1)
        if was_overview and not state.overview then state.pending_focus_id=state.focused_id end
        if state.zoom_target then
            zoom_key = workspace_key(ctx)
            if not zoom_mouse then
                if _G.__hyprworld_apply_mouse then _G.__hyprworld_apply_mouse() end
                zoom_mouse=hl.get_config("input.follow_mouse")
                hl.config({input={follow_mouse=2}})
            end
            if not zoom_timer then
                zoom_timer=hl.timer(function()
                    local active=hl.get_active_window()
                    local ws=safe_field(active,"workspace")
                    if not zoom_key or (active and "workspace:"..tostring(safe_field(ws,"id")) ~= zoom_key) then stop_zoom(); return end
                    hl.dispatch(hl.dsp.layout("zoom-tick"))
                end,{timeout=16,type="repeat"})
            else zoom_timer:set_enabled(true) end
        end
    elseif command == "zoom-tick" then
        if zoom_key ~= workspace_key(ctx) then stop_zoom(); return true end
        if not core.advance_zoom(state) then stop_zoom() end
    elseif command == "zoom" then
        if extra ~= "" or (argument ~= "in" and argument ~= "out") then
            return "hyprworld: zoom expects in or out"
        end
        local was_overview = state.overview
        core.zoom(state, config, argument == "in" and 1 or -1)
        if was_overview and not state.overview then state.pending_focus_id = state.focused_id end
    elseif command == "resize" and argument ~= "width" and argument ~= "height" then
        if extra ~= "" or not core.resize_direction(state, config, argument) then
            return "hyprworld: resize expects left, right, up, or down"
        end
    elseif command == "toggle-max" then
        if argument ~= "" or extra ~= "" or not core.toggle_maximize(state, config) then
            return "hyprworld: toggle-max requires an active window"
        end
    elseif command == "follow" or command == "center" then
        core.follow(state)
    elseif command == "refresh" then
        -- Update selection without moving an already visible tile.
    elseif command == "resize" and argument == "width" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprworld: resize width expects grow or shrink"
        end
        core.resize_width(state, config, extra == "grow" and 1 or -1)
    elseif command == "resize" and argument == "height" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprworld: resize height expects grow or shrink"
        end
        core.resize_height(state, config, extra == "grow" and 1 or -1)
    else
        return "hyprworld: expected focus, move, pan, zoom, resize, toggle-max, or center"
    end

    place_state(ctx, state, descriptors)
    for _, binding in ipairs(_G.__hyprworld_mouse_bindings or {}) do
        binding:set_enabled(not state.overview)
    end
    return true
end

local function window_layout_name(window)
    local layout = safe_field(window, "layout")
    return safe_field(layout, "name")
end

-- Temporarily use click-to-focus while the camera moves after a hover.
-- This prevents the next window sliding under the pointer from stealing focus;
-- it never dispatches a corrective focus or delays keyboard navigation.
local hover_cooldown = nil
local function finish_hover_cooldown()
    local saved = hover_cooldown
    if not saved then return end
    hover_cooldown = nil
    local input = {}
    if hl.get_config("input.follow_mouse") == 2 then
        input.follow_mouse = saved.follow_mouse
    end
    if hl.get_config("input.float_switch_override_focus") == 0 then
        input.float_switch_override_focus = saved.float_switch_override_focus
    end
    if next(input) then hl.config({ input = input }) end
end

local function start_hover_cooldown()
    if hover_cooldown or hl.get_config("input.follow_mouse") ~= 1 then return end
    local _, delay = preferences.mouse()
    if delay <= 0 then return end
    local saved = {
        follow_mouse = hl.get_config("input.follow_mouse"),
        float_switch_override_focus = hl.get_config("input.float_switch_override_focus"),
    }
    hover_cooldown = saved
    hl.config({ input = { follow_mouse = 2, float_switch_override_focus = 0 } })
    saved.timer = hl.timer(function()
        if hover_cooldown == saved then finish_hover_cooldown() end
    end, { timeout = delay, type = "oneshot" })
end

local mouse_baseline, mouse_owned = nil, nil
local function apply_mouse_mode(window)
    if window_layout_name(window) == "lua:hyprworld" then
        if not mouse_baseline then
            mouse_baseline = {follow_mouse = hl.get_config("input.follow_mouse"),
                float_switch_override_focus = hl.get_config("input.float_switch_override_focus")}
        end
        if hover_cooldown then return end
        local mode = preferences.mouse()
        mouse_owned = {follow_mouse = mode == "click" and 2 or 1,
            float_switch_override_focus = mode == "click" and 0 or mouse_baseline.float_switch_override_focus}
        hl.config({input = mouse_owned})
    elseif mouse_baseline then
        local restore = {}
        for key, value in pairs(mouse_owned or {}) do
            if hl.get_config("input." .. key) == value then restore[key] = mouse_baseline[key] end
        end
        if next(restore) then hl.config({input = restore}) end
        mouse_baseline, mouse_owned = nil, nil
    end
end
_G.__hyprworld_apply_mouse = function()
    finish_hover_cooldown()
    apply_mouse_mode(hl.get_active_window())
end

local function fully_visible(key, address)
    local snapshot = snapshots[key]
    if not snapshot then return false end
    local area = snapshot.area
    for _, tile in ipairs(snapshot.tiles) do
        local b = tile.box
        if tile.address == address and b then
            return b.x >= area.x - 1 and b.y >= area.y - 1
                and b.x+b.w <= area.x+area.w+1 and b.y+b.h <= area.y+area.h+1
        end
    end
    return false
end

if not rawget(_G, "__hyprworld_focus_subscription") then
    local ok, subscription = pcall(function()
        return hl.on("window.active", function(window, reason)
            if overview_transfer then return end
            if zoom_key then
                local ws=safe_field(window,"workspace")
                if zoom_key == "workspace:"..tostring(safe_field(ws,"id")) then return end
                stop_zoom()
            end
            if gesture then
                local ws = safe_field(window, "workspace")
                if gesture.key == "workspace:" .. tostring(safe_field(ws, "id")) then return end
                end_gesture()
            end
            if window_layout_name(window) ~= "lua:hyprworld" then
                finish_hover_cooldown()
                apply_mouse_mode(window)
                return
            end
            local workspace = safe_field(window, "workspace")
            local workspace_id = safe_field(workspace, "id")
            local key = "workspace:" .. tostring(workspace_id)
            local state = workspace_id ~= nil and workspaces[key] or nil
            if state and (state.overview or state.pending_focus_id) then return end
            apply_mouse_mode(window)
            local visible = fully_visible(key, safe_field(window, "address"))
            -- Only a hover that pans the camera starts a cooldown. Group
            -- members and other fully visible windows remain immediate.
            if reason == 1 and not visible then start_hover_cooldown() end
            if state then core.observe_focus(state, window_id(window)) end
            hl.dispatch(hl.dsp.layout(visible and "refresh" or "follow"))
        end)
    end)
    if ok then _G.__hyprworld_focus_subscription = subscription or true end
end

-- Read-only JSON bridge consumed by the shell overlay. Titles are data only.
local function json(value)
    if type(value) == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
            return string.format('\\u%04x', string.byte(c))
        end) .. '"'
    elseif type(value) == "boolean" or type(value) == "number" then return tostring(value)
    elseif type(value) == "table" then
        local parts = {}
        if #value > 0 then
            for _, v in ipairs(value) do parts[#parts + 1] = json(v) end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        for k, v in pairs(value) do parts[#parts + 1] = json(k) .. ':' .. json(v) end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return 'null'
end
local revision = 0
local preview_epoch = tostring({})
publish_snapshot = function(snapshot)
    if overview_transfer then return end
    revision = revision + 1
    snapshot.revision = revision
    snapshot.epoch = preview_epoch
    local ws = hl.get_active_workspace and hl.get_active_workspace()
    if ws and safe_field(ws,"id") ~= snapshot.workspaceId then return end
    if hl.dsp.event then hl.dispatch(hl.dsp.event("hyprworld-preview," .. json(snapshot))) end
end
_G.__hyprworld_prepare_overview_transfer = function()
    overview_transfer = true
    local state = last_overview_key and workspaces[last_overview_key]
    if state then state.overview = false; state.pending_focus_id = nil end
end
_G.__hyprworld_preview = function()
    if overview_transfer then return json(snapshots[last_overview_key] or {}) end
    local active = hl.get_active_window()
    if not active and hl.get_active_workspace then
        local ws=hl.get_active_workspace()
        return json(snapshots["workspace:"..tostring(safe_field(ws,"id"))] or {})
    end
    if not active and last_overview_key then return json(snapshots[last_overview_key] or {}) end
    if window_layout_name(active) ~= "lua:hyprworld" then return '{}' end
    local ws = safe_field(active, "workspace")
    local snapshot = snapshots["workspace:" .. tostring(safe_field(ws, "id"))] or {}
    snapshot.gesture = gesture and {mode=gesture.mode, ghost=gesture.ghost, drop=gesture.drop} or nil
    return json(snapshot)
end

_G.__hyprworld_overview_active = function()
    local state = last_overview_key and workspaces[last_overview_key]
    local active = hl.get_active_window()
    local ws = safe_field(active, "workspace")
    if not active and hl.get_active_workspace then ws=hl.get_active_workspace() end
    local same = not ws or last_overview_key == "workspace:" .. tostring(safe_field(ws, "id"))
    return same and state and state.overview or false
end

-- Empty workspaces have no layout callback, but overview still needs a state.
_G.__hyprworld_set_overview = function(enabled, direction, commit)
    local active=hl.get_active_window()
    local monitor=hl.get_active_monitor and hl.get_active_monitor() or safe_field(active,"monitor")
    local ws=hl.get_active_workspace and hl.get_active_workspace() or safe_field(active,"workspace")
    local id=safe_field(ws,"id")
    if not id then return end
    local key="workspace:"..id
    local state=workspaces[key]
    if not state then state=core.new_state(); state.zoom_step=config.default_zoom_step; workspaces[key]=state end
    if not enabled and commit and #state.ids>0 and state.overview then
        hl.dispatch(hl.dsp.layout("overview-close")); return
    end
    end_gesture(); stop_zoom()
    state.overview=enabled; state.pending_focus_id=nil; state.slideDirection=direction or 0
    last_overview_key=key
    local snapshot=snapshots[key] or {tiles={},monitor=safe_field(monitor,"name") or "",
        monitorX=safe_field(monitor,"x") or 0,monitorY=safe_field(monitor,"y") or 0,
        area={x=safe_field(monitor,"x") or 0,y=safe_field(monitor,"y") or 0,
            w=(safe_field(monitor,"width") or 1920)/(safe_field(monitor,"scale") or 1),
            h=(safe_field(monitor,"height") or 1080)/(safe_field(monitor,"scale") or 1)},
        zoom=core.zoom_value(state,config),maxZoom=config.zoom_steps[#config.zoom_steps]}
    snapshot.overview=enabled; snapshot.commitAddress=""; snapshot.workspaceId=id; snapshot.slideDirection=direction or 0
    snapshots[key]=snapshot
    for _,binding in ipairs(_G.__hyprworld_mouse_bindings or {}) do binding:set_enabled(not enabled) end
    if active and window_layout_name(active)=="lua:hyprworld" then hl.dispatch(hl.dsp.layout("refresh")) end
    overview_transfer = false
    publish_snapshot(snapshots[key])
end
_G.__hyprworld_toggle_overview=function()
    _G.__hyprworld_set_overview(not _G.__hyprworld_overview_active(),nil,true)
end

hl.layout.register("hyprworld", {
    recalculate = recalculate,
    layout_msg = layout_msg,
})

_G.__hyprworld_layout_registered = true
return true
