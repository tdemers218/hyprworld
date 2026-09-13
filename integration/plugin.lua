-- Keep writable preferences outside the shell's watched plugin directory.
local preferences = (os.getenv("HOME") or "") .. "/.config/omarchy/hyprworld.json"
local existing = io.open(preferences, "r")
if existing then existing:close()
else
    local legacy = io.open((os.getenv("HOME") or "") .. "/.config/omarchy/plugins/io.github.tdemers218.hyprworld/customizer.json", "r")
    local raw = legacy and legacy:read("*a") or "{}"
    if legacy then legacy:close() end
    local output = io.open(preferences, "w")
    if output then output:write(raw); output:close() end
end
if rawget(_G, "__hyprworld_plugin_loaded") then return true end

local source = debug and debug.getinfo(1, "S").source
if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    error("hyprworld: unable to resolve plugin directory")
end

local integration_dir = source:sub(2):match("^(.*)/[^/]*$")
local root_dir = integration_dir and integration_dir:match("^(.*)/integration$")
if not root_dir then error("hyprworld: invalid plugin directory") end

local preferences_module = dofile(root_dir .. "/layout/preferences.lua")
_G.__hyprworld_enabled = preferences_module.enabled()
if _G.__hyprworld_enabled then dofile(root_dir .. "/layout/init.lua") end
dofile(root_dir .. "/integration/omarchy.lua")

_G.__hyprworld_plugin_loaded = true
return true
