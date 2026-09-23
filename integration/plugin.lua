if rawget(_G, "__hyprworld_plugin_loaded") then return true end

local source = debug and debug.getinfo(1, "S").source
if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    error("hyprworld: unable to resolve plugin directory")
end

local integration_dir = source:sub(2):match("^(.*)/[^/]*$")
local root_dir = integration_dir and integration_dir:match("^(.*)/integration$")
if not root_dir then error("hyprworld: invalid plugin directory") end

-- Keep the established preference filename so an existing user's settings
-- survive the package-ID change; resolve bundled defaults from this checkout.
local preferences = (os.getenv("HOME") or "") .. "/.config/omarchy/hyprworld.json"
local existing = io.open(preferences, "r")
if existing then existing:close()
else
    local legacy = io.open(root_dir .. "/customizer.json", "r")
    local raw = legacy and legacy:read("*a") or "{}"
    if legacy then legacy:close() end
    local output = io.open(preferences, "w")
    if output then output:write(raw); output:close() end
end

-- Reject incompatible hosts before replacing any desktop bindings or layout.
local native_touched = false
local function unavailable(message)
    _G.__hyprworld_enabled = false
    if native_touched then
        local helper = hl.plugin.hyprworld_shared
        if helper and type(helper.set_enabled) == "function" then
            local ok, err = pcall(helper.set_enabled, false)
            if not ok then print("Hyprworld helper cleanup failed: " .. tostring(err)) end
        end
    end
    print("Hyprworld unavailable: " .. tostring(message))
    return false
end
for _,spec in ipairs({{hl,"config"},{hl,"bind"},{hl,"unbind"},{hl,"dispatch"},
    {hl,"get_active_window"},{hl,"get_active_monitor"},{hl,"get_monitors"},
    {hl,"get_monitor_at_cursor"},{hl,"get_cursor_pos"},{hl,"get_config"},
    {hl,"timer"},{hl,"on"},{hl,"curve"},{hl,"animation"},
    {hl and hl.layout,"register"},{hl and hl.plugin,"load"},{o,"bind"}}) do
    if type(spec[1])~="table" or type(spec[1][spec[2]])~="function" then
        return unavailable("missing Lua API " .. spec[2])
    end
end
for _,name in ipairs({"layout/init.lua","integration/omarchy.lua","integration/workspaces.lua","integration/touchpad.lua"}) do
    local chunk,err=loadfile(root_dir .. "/" .. name)
    if not chunk then return unavailable(err) end
end
local ok_preferences,preferences_module = pcall(dofile, root_dir .. "/layout/preferences.lua")
if not ok_preferences then return unavailable(preferences_module) end
_G.__hyprworld_enabled = preferences_module.enabled()
if _G.__hyprworld_enabled then
    native_touched = true
    -- Declare on every config generation, including when already loaded.
    -- Omitting a loaded config plugin makes Hyprland unload it and reload the
    -- config, which would then declare it again: an endless load/unload loop.
    local ok,result = pcall(hl.plugin.load, _G.__hyprworld_native_path or root_dir .. "/native/build/shared-workspaces.so")
    if not ok or result==false then return unavailable(result) end
    if not hl.plugin.hyprworld_shared or type(hl.plugin.hyprworld_shared.set_enabled) ~= "function" then
        return unavailable("native helper is not ready; the shell bootstrap must load it before the layout")
    end
    if hl.plugin.hyprworld_shared and hl.plugin.hyprworld_shared.set_enabled then
        local ok, err = pcall(hl.plugin.hyprworld_shared.set_enabled, true)
        if not ok then return unavailable(err) end
    end
    local layout_ok,layout_error=pcall(dofile, root_dir .. "/layout/init.lua")
    if not layout_ok then return unavailable(layout_error) end
elseif hl.plugin.hyprworld_shared and hl.plugin.hyprworld_shared.set_enabled then
    local ok, err = pcall(hl.plugin.hyprworld_shared.set_enabled, false)
    if not ok then return unavailable(err) end
end
local previous_layout=hl.get_config("general.layout")
local integrated,integration_error=pcall(dofile,root_dir .. "/integration/omarchy.lua")
if not integrated then
    pcall(hl.config,{general={layout=previous_layout}})
    return unavailable(integration_error)
end

_G.__hyprworld_plugin_loaded = true
return true
