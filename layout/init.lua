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
local checkpoint = load_relative("checkpoint.lua")
local checkpoint_scope = checkpoint.scope()
local state_home = os.getenv("XDG_STATE_HOME")
if not state_home or state_home == "" then state_home = (os.getenv("HOME") or "") .. "/.local/state" end
local restored_workspaces = checkpoint.load(state_home .. "/hyprworld/layout.json", checkpoint_scope)
local checkpoint_changed
local gesture, gesture_timer
local snapshots = {}
local publish_snapshot, publish_gesture
local function end_gesture()
    if not gesture then return end
    local old = gesture
    gesture = nil
    if gesture_timer then pcall(function() gesture_timer:set_enabled(false) end) end
    if hl.get_config("input.follow_mouse") == 2 then
        hl.config({input = {follow_mouse = old.follow_mouse}})
    end
    if publish_snapshot and snapshots[old.key] then
        publish_gesture(snapshots[old.key])
        publish_snapshot(snapshots[old.key], true)
    end
end
_G.__hyprworld_end_gesture = end_gesture
local workspaces = {}
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
local last_overview_key = nil


local function safe_field(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    if ok then return result end
end

-- Special workspaces can own keyboard focus without replacing the normal
-- workspace displayed by the monitor. Overview state belongs to the latter.
local function active_normal_workspace()
    local monitor = hl.get_active_monitor and hl.get_active_monitor()
    local normal = safe_field(monitor, "active_workspace")
    local normal_id = safe_field(normal, "id")
    if normal_id and normal_id > 0 then return normal end
    local active = hl.get_active_window and hl.get_active_window()
    local workspace = hl.get_active_workspace and hl.get_active_workspace() or safe_field(active, "workspace")
    local id = safe_field(workspace, "id")
    return id and id > 0 and workspace or nil
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
    local data = preferences.data and preferences.data()
    local function section(name)
        if data then return type(data[name]) == "table" and data[name] or {} end
        return preferences.section(name)
    end
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
    if preferences.section then
        local flow=section('workflow')
        local next_path=section('placement')
        if state.placement~=next_path then state.path_index=nil end
        state.placement=next_path
        if state.placement.scope=='specific' then
            local applies=false
            for _,id in ipairs(state.placement.workspaces or {}) do
                if key=='workspace:'..tostring(id) then applies=true;break end
            end
            if not applies then state.placement=nil end
        end
        state.group_layouts=section('groups').layouts
        state.compact_on_close=flow.compactOnClose~=false
        state.compact_on_move=flow.compactOnMove~=false
        state.preserve_focus=flow.preserveFocus==true
        local function numeric(k,default,low,high) return math.max(low,math.min(high,tonumber(flow[k]) or default)) end
        config.peek_x,config.peek_y=numeric('peekX',48,0,200),numeric('peekY',48,0,200)
        config.gap_x,config.gap_y=numeric('gapX',12,0,100),numeric('gapY',12,0,100)
        local w,h=numeric('defaultWidth',.85,.2,1),numeric('defaultHeight',.85,.2,1)
        config.width_steps={w*.5/.85,w*.67/.85,w,1}
        config.height_steps={h*.5/.85,h*.67/.85,h,1}
    end
    core.sync(state, ids, active_id, config)
    checkpoint.restore(restored_workspaces[key], state, ids, config)
    if preferences.section then
        state.template_placed=state.template_placed or {}
        for _,template in ipairs(section('startup').templates or {}) do
            if template.workspace==tonumber(key:match('workspace:(.+)')) then
                local used={}
                for _,id in ipairs(ids) do
                    local class=safe_field(descriptors[id].window,'class')
                    for index,app in ipairs(template.apps or {}) do
                        if class==app.class and app.class~='' and not used[index] then
                            used[index]=true
                            if not state.template_zoom_applied then state.zoom_value=math.max(.65,math.min(1.25,tonumber(template.zoom) or 1));state.template_zoom_applied=true end
                            if not state.template_placed[id] then
                                local col,row=tonumber(app.col) or 0,tonumber(app.row) or 0
                                local count=0
                                for other,pos in pairs(state.positions) do if other~=id and pos.col==col and pos.row==row then count=count+1 end end
                                if count<4 then state.positions[id]={col=col,row=row,slot=count+1} end
                                state.template_placed[id]=true
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    state.defer_active_camera = true

    state.keep_connected = preferences.keep_connected(data)
    if not state.on_move then
        state.on_move = function()
            if state.compact_timer then state.compact_timer:set_enabled(false) end
            state.compact_due=false
            state.compact_remaining=0
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
            if state.preserve_focus and focused and col and row then
                local dx,dy=col-focused.col,row-focused.row
                for _,pos in pairs(state.positions) do pos.col,pos.row=pos.col+dx,pos.row+dy end
            end
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
    if not overview_transfer and (state.overview or state.pending_focus_id) then last_overview_key = workspace_key(ctx) end
    snapshots[workspace_key(ctx)] = { tiles = tiles, overview = state.overview, compactSerial=state.compact_serial or 0,
        workspaceId = tonumber(workspace_key(ctx):match("workspace:(.+)")), slideDirection=state.slideDirection or 0, slideDirectionY=state.slideDirectionY or 0,
        commitAddress = state.pending_focus_id and descriptors[state.pending_focus_id] and descriptors[state.pending_focus_id].address or "",
        zoom = core.zoom_value(state, config), maxZoom = config.zoom_steps[#config.zoom_steps],
        cameraCol = state.camera.col, cameraRow = state.camera.row, area = ctx.area,
        monitorX = safe_field(monitor, "x") or 0, monitorY = safe_field(monitor, "y") or 0,
        monitor = safe_field(monitor, "name") or "" }
    for id, descriptor in pairs(descriptors) do
        local placement = placements[id]
        if placement then descriptor.target:place(placement) end
    end
    if checkpoint_changed then checkpoint_changed(workspace_key(ctx), state) end
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
    if type(message) ~= "string" then return "hyprworld: layout message must be text" end
    local command, argument, extra = message:match("^(%S+)%s*(%S*)%s*(%S*)$")
    if gesture and (command=="gesture-tick" or command=="gesture-end") then ctx=gesture.ctx end
    local state, descriptors = context(ctx)
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
        gesture = {ctx=ctx,key=workspace_key(ctx), mode=command == "gesture-pan" and "pan" or "move",
            start=cursor, cursor=cursor, source=tile, x=state.camera.x or 0, y=state.camera.y or 0,
            follow_mouse=hl.get_config("input.follow_mouse"), monitor=snapshot.monitor}
        hl.config({input={follow_mouse=2}})
        if not gesture_timer then
            gesture_timer = hl.timer(function()
                if not gesture then return end
                local active = hl.get_active_window()
                local ws = safe_field(active, "workspace")
                local monitor = hl.get_monitor_at_cursor()
                if gesture.mode=="pan" and ("workspace:" .. tostring(safe_field(ws, "id")) ~= gesture.key or safe_field(monitor,"name") ~= gesture.monitor) then end_gesture(); return end
                local pos = hl.get_cursor_pos()
                if pos and (pos.x ~= gesture.cursor.x or pos.y ~= gesture.cursor.y) then
                    layout_msg(gesture.ctx,"gesture-tick")
                end
            end, {timeout=16,type="repeat"})
        else gesture_timer:set_enabled(true) end
        if hl.dsp.event then hl.dispatch(hl.dsp.event("hyprworld-gesture")) end
    elseif command == "gesture-tick" or command == "gesture-end" then
        if not gesture or gesture.key ~= workspace_key(ctx) then end_gesture(); return true end
        local g = gesture
        local source_exists=false
        for _,d in pairs(descriptors) do if g.source and d.address==g.source.address then source_exists=true;break end end
        if g.mode=="move" and not source_exists then end_gesture(); return true end
        local cursor_monitor = hl.get_monitor_at_cursor()
        if not cursor_monitor then end_gesture(); return true end
        g.cursor = hl.get_cursor_pos() or g.cursor
        local dx, dy = g.cursor.x-g.start.x, g.cursor.y-g.start.y
        g.moved = g.moved or dx*dx+dy*dy > 64
        local cursor_monitor_name = safe_field(cursor_monitor, "name")
        if g.mode == "pan" and cursor_monitor_name ~= g.monitor then
            end_gesture(); return true
        elseif g.mode == "pan" then
            state.camera.x, state.camera.y = g.x+dx, g.y+dy
        elseif g.moved then
            local b = g.source.box
            g.ghost = {x=b.x+dx,y=b.y+dy,w=b.w,h=b.h}
            if cursor_monitor_name and cursor_monitor_name ~= g.monitor then
                local workspace = safe_field(cursor_monitor, "active_workspace")
                local workspace_id = safe_field(workspace, "id")
                g.target_workspace = workspace_id and workspace_id > 0 and workspace_id or nil
                g.drop = g.target_workspace and {label="Release to move to " .. cursor_monitor_name, monitor=cursor_monitor_name,
                    monitorX=safe_field(cursor_monitor, "x") or 0, monitorY=safe_field(cursor_monitor, "y") or 0} or nil
            else
                g.target_workspace = nil
                local _, grid = core.placements(state, ctx.area, config)
                g.drop = gestures.destination(snapshots[g.key].tiles, grid, g.source, g.cursor.x, g.cursor.y)
            end
        end
        if command == "gesture-tick" and g.mode == "move" then
            -- Moving the hint does not move/recalculate the actual windows.
            -- Send only drag geometry; full workspace data stays unchanged.
            publish_gesture(snapshots[g.key])
            return true
        end
        if command == "gesture-end" then
            end_gesture()
            if g.mode == "move" then
                for _, d in pairs(descriptors) do
                    if d.address == g.source.address then
                        core.observe_focus(state, d.id)
                        if g.moved and g.target_workspace then
                            hl.dispatch(hl.dsp.window.move({window="address:" .. d.address,
                                workspace=tostring(g.target_workspace), follow=false}))
                            hl.dispatch(hl.dsp.focus({window="address:" .. d.address}))
                            return true -- Do not re-place the transferred target using its old workspace.
                        elseif g.moved and g.drop then
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
    elseif command == "zoom-pinch" then
        local delta = tonumber(argument)
        if not delta or delta ~= delta or math.abs(delta) > 5 then return true end
        stop_zoom()
        local low, high = config.zoom_steps[1], config.zoom_steps[#config.zoom_steps]
        if state.overview and delta > 0 then
            state.overview = false; state.pending_focus_id = state.focused_id
        end
        state.zoom_value = math.max(low, math.min(high, core.zoom_value(state, config) * math.exp(delta)))
        if delta < 0 and state.zoom_value <= low then state.overview = true end
        core.follow(state)
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

_G.__hyprworld_finish_gesture=function()
    if not gesture then return false end
    layout_msg(gesture.ctx,"gesture-end")
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
                -- Monitor focus follows the pointer during a move. The source
                -- context and explicit window address still own this gesture.
                if gesture.mode=="move" then return end
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
local checkpoint_signatures = {}
checkpoint_changed = function(key, state)
    local signature = json(checkpoint.capture(state))
    if checkpoint_signatures[key] == signature then return end
    checkpoint_signatures[key] = signature
    if hl.dsp.event then hl.dispatch(hl.dsp.event("hyprworld-state")) end
end
_G.__hyprworld_checkpoint = function()
    if not checkpoint_scope then return nil end
    if gesture or zoom_key then return json({busy=true}) end
    -- Inactive workspaces may not receive layout callbacks immediately after
    -- a reset. Keep their checkpoint until their live state is available.
    local saved = {}
    for key,record in pairs(restored_workspaces) do saved[key] = record end
    for key,state in pairs(workspaces) do
        if state.overview_drag or (state.compact_remaining and state.compact_remaining>0) then return json({busy=true}) end
        if key:match('^workspace:') then saved[key] = checkpoint.capture(state) end
    end
    return json({version=1,scope=checkpoint_scope,workspaces=saved})
end
local preview_epoch = tostring({})
local function stamp(snapshot)
    revision = revision + 1
    snapshot.revision = revision
    snapshot.epoch = preview_epoch
    snapshot.gesture = gesture and {mode=gesture.mode, ghost=gesture.ghost, drop=gesture.drop} or nil
end
local function publish_payload(kind, snapshot)
    if hl.dsp.event then
        local payload = json(snapshot)
        -- Hyprland truncates event data at 1024 bytes. Keep each fragment,
        -- including its header, below that limit without splitting UTF-8.
        if #payload <= 900 then
            hl.dispatch(hl.dsp.event("hyprworld-" .. kind .. "," .. payload))
        else
            local parts, first = {}, 1
            while first <= #payload do
                local last = math.min(first + 899, #payload)
                while last < #payload and payload:byte(last + 1) >= 128 and payload:byte(last + 1) < 192 do last = last - 1 end
                parts[#parts + 1] = payload:sub(first, last)
                first = last + 1
            end
            for index, part in ipairs(parts) do
                hl.dispatch(hl.dsp.event("hyprworld-" .. kind .. "-part," .. preview_epoch .. "," .. revision .. "," .. index .. "," .. #parts .. "," .. part))
            end
        end
    end
end
publish_gesture = function(snapshot)
    if not snapshot or overview_transfer then return end
    stamp(snapshot)
    publish_payload("drag", {epoch=snapshot.epoch, revision=snapshot.revision,
        monitor=snapshot.monitor, monitorX=snapshot.monitorX, monitorY=snapshot.monitorY,
        gesture=snapshot.gesture or false})
end
publish_snapshot = function(snapshot, force)
    if overview_transfer then return end
    stamp(snapshot)
    local ws = active_normal_workspace()
    local visible_key = gesture and gesture.key or (ws and "workspace:" .. tostring(safe_field(ws,"id")))
    if not force and visible_key and visible_key ~= "workspace:" .. tostring(snapshot.workspaceId) then return end
    publish_payload("preview", snapshot)
end
_G.__hyprworld_prepare_overview_transfer = function()
    overview_transfer = true
    local state = last_overview_key and workspaces[last_overview_key]
    if state then state.overview = false; state.pending_focus_id = nil end
end
_G.__hyprworld_preview = function()
    if overview_transfer then return json(snapshots[last_overview_key] or {}) end
    -- Workspace ownership is authoritative while exclusive layers leave window
    -- focus stale (especially during an atomic two-monitor swap).
    local ws = active_normal_workspace()
    local snapshot = snapshots[gesture and gesture.key or (ws and "workspace:" .. tostring(safe_field(ws, "id")) or last_overview_key)] or {}
    snapshot.gesture = gesture and {mode=gesture.mode, ghost=gesture.ghost, drop=gesture.drop} or nil
    return json(snapshot)
end

_G.__hyprworld_overview_active = function()
    local state = last_overview_key and workspaces[last_overview_key]
    local ws = active_normal_workspace()
    local same = not ws or last_overview_key == "workspace:" .. tostring(safe_field(ws, "id"))
    return same and state and state.overview or false
end

-- Empty workspaces have no layout callback, but overview still needs a state.
_G.__hyprworld_set_overview = function(enabled, direction, commit, directionY)
    local active=hl.get_active_window()
    local monitor=hl.get_active_monitor and hl.get_active_monitor() or safe_field(active,"monitor")
    local ws=active_normal_workspace()
    local id=safe_field(ws,"id")
    if not id then return end
    local key="workspace:"..id
    local state=workspaces[key]
    if not state then state=core.new_state(); state.zoom_step=config.default_zoom_step; workspaces[key]=state end
    if not enabled and commit and #state.ids>0 and state.overview then
        hl.dispatch(hl.dsp.layout("overview-close")); return
    end
    end_gesture(); stop_zoom()
    for other_key, other in pairs(workspaces) do
        if other_key ~= key then
            other.overview = false; other.pending_focus_id = nil
            if snapshots[other_key] then snapshots[other_key].overview=false; snapshots[other_key].commitAddress="" end
        end
    end
    state.overview=enabled; state.pending_focus_id=nil; state.slideDirection=direction or 0; state.slideDirectionY=directionY or 0
    last_overview_key=key
    local snapshot=snapshots[key] or {tiles={},monitor=safe_field(monitor,"name") or "",
        monitorX=safe_field(monitor,"x") or 0,monitorY=safe_field(monitor,"y") or 0,
        area={x=safe_field(monitor,"x") or 0,y=safe_field(monitor,"y") or 0,
            w=(safe_field(monitor,"width") or 1920)/(safe_field(monitor,"scale") or 1),
            h=(safe_field(monitor,"height") or 1080)/(safe_field(monitor,"scale") or 1)},
        zoom=core.zoom_value(state,config),maxZoom=config.zoom_steps[#config.zoom_steps]}
    snapshot.overview=enabled; snapshot.commitAddress=""; snapshot.workspaceId=id; snapshot.slideDirection=direction or 0; snapshot.slideDirectionY=directionY or 0
    snapshots[key]=snapshot
    for _,binding in ipairs(_G.__hyprworld_mouse_bindings or {}) do binding:set_enabled(not enabled) end
    if active and safe_field(safe_field(active,"workspace"),"id")==id and window_layout_name(active)=="lua:hyprworld" then hl.dispatch(hl.dsp.layout("refresh")) end
    overview_transfer = false
    publish_snapshot(snapshots[key])
end
_G.__hyprworld_toggle_overview=function()
    _G.__hyprworld_set_overview(not _G.__hyprworld_overview_active(),nil,true)
end

-- A stale target or a malformed runtime input must not strand input modes or
-- abort the compositor's layout callback. Normal results are passed unchanged.
local last_failure
local function recover_layout(ctx, err)
    pcall(end_gesture); pcall(stop_zoom); pcall(finish_hover_cooldown)
    if last_failure~=tostring(err) then print("Hyprworld layout failed: "..tostring(err));last_failure=tostring(err) end
    local area=safe_field(ctx,"area")
    local targets=safe_field(ctx,"targets") or {}
    if type(targets)~="table" then return end
    if not area or #targets==0 then return end
    for i,target in ipairs(targets) do
        pcall(function() target:place({x=area.x+(i-1)*area.w/#targets,y=area.y,w=math.max(1,area.w/#targets),h=math.max(1,area.h)}) end)
    end
end
local raw_layout_msg=layout_msg
layout_msg=function(ctx,message)
    local ok,result=pcall(raw_layout_msg,ctx,message)
    if ok then return result end
    recover_layout(ctx,result)
    return "hyprworld: layout action failed; see compositor log"
end
hl.layout.register("hyprworld", {
    recalculate = function(ctx)
        local ok,result=pcall(recalculate,ctx)
        if not ok then recover_layout(ctx,result) end
        return result
    end,
    layout_msg = layout_msg,
})

_G.__hyprworld_layout_registered = true
return true
