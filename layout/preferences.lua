local M = {}
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
