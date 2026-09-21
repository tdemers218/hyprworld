local M = {}
local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
local json=dofile(directory.."/json.lua")
local cached_raw, cached_data
function M.data()
 local raw=M.read()
 if raw~=cached_raw then
  local ok,result=pcall(json.decode,raw)
  cached_raw,cached_data=raw,ok and type(result)=='table' and result or {}
 end
 return cached_data or {}
end
function M.section(name) local value=M.data()[name];return type(value)=='table' and value or {} end

function M.read()
    local home = os.getenv("HOME") or ""
    local file = io.open(home .. "/.config/omarchy/hyprworld.json", "r")
        or io.open(home .. "/.config/omarchy/plugins/io.github.tdemers218.hyprworld/customizer.json", "r")
    if not file then return "" end
    local raw = file:read("*a"); file:close()
    return raw
end
function M.enabled()
    local section = M.read():match('"plugin"%s*:%s*(%b{})') or ""
    return not section:match('"enabled"%s*:%s*false')
end
function M.mouse()
    local section = M.read():match('"workflow"%s*:%s*(%b{})') or ""
    local mode = section:match('"focusMode"%s*:%s*"([^"]+)"')
    local delay = tonumber(section:match('"mouseCooldownMs"%s*:%s*(%-?[%d%.]+)')) or 550
    return mode == "click" and "click" or "auto", math.max(0, math.min(1500, delay))
end
function M.keep_connected()
    local section = M.read():match('"workflow"%s*:%s*(%b{})') or ""
    local delay=tonumber(section:match('"compactDelayMs"%s*:%s*(%-?[%d%.]+)')) or 5000
    if delay<=0 then delay=5000 end -- Migrate the former immediate mode.
    return not section:match('"keepConnected"%s*:%s*false'), math.max(100,math.min(30000,delay))
end
return M
