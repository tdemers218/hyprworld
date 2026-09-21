local real_dofile,real_open=dofile,io.open
local enabled,binary=true,true
local calls={}
_G.hl={plugin={load=function()calls.load=true end,hyprworld_shared={set_enabled=function(value)calls.enabled=value end}}}
dofile=function(path)
    if path:match('/layout/preferences.lua$') then return {enabled=function()return enabled end} end
    if path:match('/layout/init.lua$') then calls.layout=true;return true end
    if path:match('/integration/omarchy.lua$') then calls.integration=true;return true end
    return real_dofile(path)
end
io.open=function(path,mode)
    if path:match('/shared%-workspaces.so$') then return binary and {close=function()end} or nil end
    if path:match('/hyprworld.json$') then return {close=function()end} end
    return real_open(path,mode)
end
local function boot()
    _G.__hyprworld_plugin_loaded=nil;calls={}
    return pcall(real_dofile,'./integration/plugin.lua')
end
assert(boot());assert(not calls.load and calls.layout and calls.integration and calls.enabled==true)
enabled=false
assert(boot());assert(not calls.load and not calls.layout and calls.integration and calls.enabled==false)
enabled=true;binary=false
local ok,error=boot();assert(not ok and error:find('native helper is missing',1,true));assert(not _G.__hyprworld_plugin_loaded)
io.open,dofile=real_open,real_dofile
print('ok - bootstrap enable/disable and actionable missing-helper error')
