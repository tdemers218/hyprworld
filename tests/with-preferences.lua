-- Tests must not depend on the developer's live placement path or focus mode.
local real_open = io.open
test_preferences = '{"workflow":{"focusMode":"auto","keepConnected":false},"placement":{"enabled":false}}'
io.open = function(path, mode)
    if mode == "r" and (path:match("/hyprworld%.json$") or path:match("/customizer%.json$")) then
        return {read=function() return test_preferences end,
            close=function() end}
    end
    return real_open(path, mode)
end
local script = assert(arg[1], "test script required")
table.remove(arg, 1)
assert(loadfile(script))()
