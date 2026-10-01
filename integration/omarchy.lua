local function safe_field(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    if ok then return result end
end

local function is_hyprworld_active()
    if _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then return true end
    local ok, window = pcall(hl.get_active_window)
    if not ok or not window then
        return _G.__hyprworld_workspace_is_managed and _G.__hyprworld_workspace_is_managed() or false
    end
    local workspace = safe_field(window, "workspace")
    local workspace_id = safe_field(workspace, "id")
    local workspace_name = safe_field(workspace, "name") or ""
    if (workspace_id and workspace_id < 0) or workspace_name:match("^special:") then
        return _G.__hyprworld_workspace_is_managed and _G.__hyprworld_workspace_is_managed() or false
    end
    local layout = safe_field(window, "layout")
    return safe_field(layout, "name") == "lua:hyprworld"
end

local function customizer_shortcut(name, fallback)
    local directory = debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$")
    local file = io.open((os.getenv("HOME") or "") .. "/.config/omarchy/hyprworld.json", "r")
        or io.open(directory .. "/../customizer.json", "r")
    if not file then return fallback end
    local raw = file:read("*a")
    file:close()
    local value = raw:match('"' .. name .. '"%s*:%s*"([^"]+)"')
    -- The settings UI validates keysyms, duplicate actions and active bindings.
    return value and value:match("^[%w_+:%s]+$") and value or fallback
end

local function launcher_handled(delta)
    if _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then return false end
    local target = os.getenv("HYPRWORLD_LAUNCHER_IPC")
    if not target or not target:match("^[%w_.-]+$") then return false end
    local command = "timeout --kill-after=0.1s 0.2s omarchy-shell shell call " .. target .. " moveSelected " .. delta
    local handle = io.popen(command)
    if not handle then return false end

    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*handled%s*$") ~= nil
end

local function route(message, fallback, launcherDelta)
    return function()
        if launcherDelta and launcher_handled(launcherDelta) then
            return
        elseif is_hyprworld_active() then
            hl.dispatch(hl.dsp.layout(message))
        elseif fallback then
            hl.dispatch(fallback())
        end
    end
end

local function replace(keys, description, message, fallback, launcherDelta)
    hl.unbind(keys)
    o.bind(keys, "Hyprworld: " .. description, route(message, fallback, launcherDelta))
end

local function layout_only(message, launcherDelta)
    return function()
        if launcherDelta and launcher_handled(launcherDelta) then return end
        if is_hyprworld_active() then
            hl.dispatch(hl.dsp.layout(message))
        end
    end
end

local function replace_layout_only(keys, description, message, launcherDelta)
    hl.unbind(keys)
    o.bind(keys, "Hyprworld: " .. description, layout_only(message, launcherDelta))
end

-- The controller remains reachable when the layout itself is disabled.
local settings_key = customizer_shortcut("settings", "SUPER + SHIFT + L")
hl.unbind(settings_key)
o.bind(settings_key, "Hyprworld: Open settings", "omarchy-shell hyprworld toggleCustomizer")
if _G.__hyprworld_enabled == false then return true end
-- Hyprland otherwise discards wheel bindings within scroll_event_delay.
hl.config({binds={scroll_event_delay=0}})
local workspace_nav
if hl.get_monitors then
    local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
    workspace_nav=dofile(directory.."/workspaces.lua").install(hl,o)
end

-- Legacy plugin controls no longer represent layout actions.
for _, key in ipairs({"SUPER + L", "SUPER + code:20", "SUPER + code:21",
    "SUPER + SHIFT + code:20", "SUPER + SHIFT + code:21",
    "SUPER + CTRL + ALT + LEFT", "SUPER + CTRL + ALT + RIGHT",
    "SUPER + J", "SUPER + P", "SUPER + HOME", "SUPER + ALT + HOME",
    "SUPER + ALT + MINUS", "SUPER + CTRL + MINUS",
    "SUPER + SHIFT + ALT + EQUAL", "SUPER + SHIFT + CTRL + EQUAL",
    "SUPER + ALT + EQUAL", "SUPER + CTRL + EQUAL",
    "SUPER + SHIFT + ALT + MINUS", "SUPER + SHIFT + CTRL + MINUS"}) do hl.unbind(key) end

for _, dir in ipairs({"left", "right", "up", "down"}) do
    local suffix = dir:sub(1,1):upper() .. dir:sub(2)
    local delta = dir == "up" and "-1" or dir == "down" and "1" or nil
    replace_layout_only(customizer_shortcut("focus" .. suffix, "SUPER + " .. dir:upper()),
        "Focus " .. dir, "focus " .. dir, delta)
    replace(customizer_shortcut("move" .. suffix, "SUPER + SHIFT + " .. dir:upper()),
        "Move window " .. dir, "move " .. dir, function()
            return hl.dsp.window.swap({direction = dir:sub(1,1)})
        end)
    replace(customizer_shortcut("resize" .. suffix, "SUPER + ALT + " .. dir:upper()),
        "Resize " .. dir, "resize " .. dir)
end
-- Keep the saved shortcut IDs compatible while repurposing camera keys.
-- Same curves as Settings.js (layout/motion.lua); elastic and bounce use the
-- overshoot curve in Hyprland.
local effect_preferences, motion
do
    local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
    effect_preferences=dofile(directory.."/../layout/preferences.lua")
    motion=dofile(directory.."/../layout/motion.lua")
end
local effect_curves=motion.CURVES
if hl.curve then
    for name,p in pairs(effect_curves) do hl.curve("hyprworld-"..name,{type="bezier",points={{p[1],p[2]},{p[3],p[4]}}}) end
end
-- Hyprland curve name for a saved curve: a named one, or a custom
-- "bezier:x1,y1,x2,y2" registered under this animation's own name.
local function effect_curve(value,id,fallback)
    if effect_curves[value] then return "hyprworld-"..value end
    if value=="elastic" or value=="bounce" then return "hyprworld-overshoot" end
    if tostring(value or ""):match("^bezier:") and hl.curve then
        local p=motion.points(value)
        hl.curve("hyprworld-custom-"..id,{type="bezier",points={{p[1],p[2]},{p[3],p[4]}}})
        return "hyprworld-custom-"..id
    end
    return "hyprworld-"..fallback
end
local effective=motion.effective
_G.__hyprworld_apply_effects=function(enabled)
    local effects=effect_preferences.section("effects")
    local workspace_ms,workspace_curve=effective(effects,"workspace",350)
    hl.animation({leaf="workspaces",enabled=enabled~=false and workspace_ms>0,speed=math.max(.1,workspace_ms/100),
        bezier=effect_curve(workspace_curve,"workspace","out-quint"),style="slide"})
    -- Camera movement is Hyprland moving the tiled windows.
    local camera_ms,camera_curve=effective(effects,"camera",380)
    hl.animation({leaf="windowsMove",enabled=enabled~=false and camera_ms>0,speed=math.max(.1,camera_ms/100),
        bezier=effect_curve(camera_curve,"camera","out-quint")})
end
_G.__hyprworld_apply_effects(effect_preferences.section("effects").animations~=false)
for _, spec in ipairs({{id="panLeft",key="LEFT",delta="r-1",label="Previous workspace"},
    {id="panRight",key="RIGHT",delta="r+1",label="Next workspace"}}) do
    local key=customizer_shortcut(spec.id,"SUPER + CTRL + "..spec.key)
    hl.unbind(key)
    o.bind(key,"Hyprworld: "..spec.label,function()
        if not workspace_nav and _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then
            hl.dispatch(hl.dsp.layout("overview-dismiss"))
        end
        if workspace_nav then workspace_nav.step(spec.key=="RIGHT" and 1 or -1)
        else hl.dispatch(hl.dsp.focus({workspace=spec.delta})) end
    end)
end
replace(customizer_shortcut("zoomIn", "SUPER + CTRL + UP"), "Zoom in", "zoom in")
replace(customizer_shortcut("zoomOut", "SUPER + CTRL + DOWN"), "Zoom out", "zoom out")
local overview_key=customizer_shortcut("overview", "SUPER + O")
hl.unbind(overview_key)
local function toggle_overview()
    if not is_hyprworld_active() then return end
    local active = hl.get_active_window and hl.get_active_window()
    local workspace = safe_field(active, "workspace")
    local special = (safe_field(workspace, "name") or ""):match("^special:(.+)$")
    if special and hl.dsp.workspace and hl.dsp.workspace.toggle_special then
        hl.dispatch(hl.dsp.workspace.toggle_special(special))
    end
    if _G.__hyprworld_toggle_overview then _G.__hyprworld_toggle_overview()
    else hl.dispatch(hl.dsp.layout("overview-open")) end
end
o.bind(overview_key,"Hyprworld: Toggle overview",toggle_overview)
replace(customizer_shortcut("toggleMax", "SUPER + ALT + F"), "Toggle maximum tile", "toggle-max", function()
    return hl.dsp.layout("colresize +conf")
end)
_G.__hyprworld_omarchy_integrated = true
-- Override stock workspace scrolling only inside this layout.
replace("SUPER + mouse_up", "Mouse zoom in", "zoom-wheel in", function() return hl.dsp.focus({workspace="m-1"}) end)
replace("SUPER + mouse_down", "Mouse zoom out", "zoom-wheel out", function() return hl.dsp.focus({workspace="m+1"}) end)

-- Replace Omarchy's one-way action with a true per-window scratchpad toggle.
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Hyprworld: Toggle window in scratchpad", function()
    local window = hl.get_active_window and hl.get_active_window()
    if not window then return end
    local workspace = safe_field(window, "workspace")
    local name = safe_field(workspace, "name") or ""
    if name == "special:scratchpad" then
        local monitor = hl.get_active_monitor and hl.get_active_monitor()
        local normal = safe_field(monitor, "active_workspace")
        local id = safe_field(normal, "id")
        if id and id > 0 then
            hl.dispatch(hl.dsp.window.move({window="address:" .. tostring(safe_field(window, "address")), workspace=tostring(id), follow=true}))
        end
    else
        hl.dispatch(hl.dsp.window.move({window="address:" .. tostring(safe_field(window, "address")), workspace="special:scratchpad", follow=false}))
    end
end)
_G.__hyprworld_mouse_bindings = {}
local native_drag = false
for _, spec in ipairs({{button="272",mode="move"},{button="274",mode="pan"}}) do
    local key = "SUPER + mouse:" .. spec.button
    hl.unbind(key)
    local binding = hl.bind(key, function()
        if spec.mode == "move" and native_drag then
            native_drag = false
            hl.dispatch(hl.dsp.window.drag())
        elseif is_hyprworld_active() then
            hl.dispatch(hl.dsp.layout("gesture-" .. spec.mode))
        elseif spec.mode == "move" then
            native_drag = true
            hl.dispatch(hl.dsp.window.drag())
        end
    end, {description="Hyprworld: Mouse " .. spec.mode})
    if binding then table.insert(_G.__hyprworld_mouse_bindings, binding) end
    -- Observe release even if Super was released first; ordinary clicks pass through.
    o.bind("mouse:" .. spec.button, "Hyprworld: End mouse " .. spec.mode, function()
        if _G.__hyprworld_finish_gesture and _G.__hyprworld_finish_gesture() then return end
        if spec.mode == "move" and native_drag then
            native_drag = false
            hl.dispatch(hl.dsp.window.drag())
        elseif is_hyprworld_active() then
            hl.dispatch(hl.dsp.layout("gesture-end"))
        elseif _G.__hyprworld_end_gesture then _G.__hyprworld_end_gesture() end
    end, {release=true, ignore_mods=true, non_consuming=true})
end
local overview_swipe_closing=false
-- Ten opacity steps for the workspace swipe's fade out and fade in. Removing
-- a tag restores the window's own opacity rules exactly.
if hl.window_rule then
    for level=1,10 do
        pcall(hl.window_rule,{match={tag="hyprworld-fade-"..level},opacity=string.format("%.1f",1-level*0.1)})
    end
end
if hl.gesture then
    local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
    dofile(directory.."/touchpad.lua").install(hl, {
        focus=function(direction) route("focus "..direction,nil,direction=="up" and "-1" or direction=="down" and "1" or nil)() end,
        -- Live camera swipes; an open launcher still takes up/down on release.
        swipeBegin=function(direction)
            if not is_hyprworld_active() then return false end
            hl.dispatch(hl.dsp.layout("swipe-begin "..direction))
            return true
        end,
        swipeUpdate=function(progress) hl.dispatch(hl.dsp.layout(string.format("swipe-update %.4f", progress))) end,
        -- The overview transition follows the fingers; the overlay reads the
        -- progress from a small custom event. Either direction toggles it.
        overviewSwipeBegin=function()
            if not is_hyprworld_active() then return false end
            overview_swipe_closing=_G.__hyprworld_overview_active and _G.__hyprworld_overview_active() or false
            return true
        end,
        overviewSwipeUpdate=function(progress)
            local value=overview_swipe_closing and 1-progress or progress
            hl.dispatch(hl.dsp.event(string.format("hyprworld-overview-swipe,%.4f",math.max(0,math.min(1,value)))))
        end,
        overviewSwipeEnd=function(_, commit)
            if commit then toggle_overview() end
            hl.dispatch(hl.dsp.event("hyprworld-overview-swipe,-1"))
        end,
        -- Live workspace swipe: fades the non-focused windows, then Hyprland's
        -- full workspace slide. Empty workspaces and an open overview use the
        -- one-shot step, which also carries the overview along.
        workspaceSwipeBegin=function(direction)
            if not is_hyprworld_active() or not hl.get_active_window() then return false end
            if _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then return false end
            hl.dispatch(hl.dsp.layout("workspace-swipe-begin "..(direction=="left" and "-1" or "1")))
            return true
        end,
        workspaceSwipeUpdate=function(progress) hl.dispatch(hl.dsp.layout(string.format("workspace-swipe-update %.4f", progress))) end,
        workspaceSwipeEnd=function(_, commit) hl.dispatch(hl.dsp.layout("workspace-swipe-end "..(commit and "commit" or "cancel"))) end,
        swipeEnd=function(direction, commit)
            local delta=direction=="up" and "-1" or direction=="down" and "1" or nil
            if commit and delta and launcher_handled(delta) then commit=false end
            hl.dispatch(hl.dsp.layout("swipe-end "..(commit and "commit" or "cancel")))
        end,
        workspace=function(delta) if workspace_nav then workspace_nav.step(delta) end end,
        overview=toggle_overview,
        zoom=function(delta) if is_hyprworld_active() then hl.dispatch(hl.dsp.layout("zoom-pinch "..tostring(delta))) end end,
    })
end
return true
