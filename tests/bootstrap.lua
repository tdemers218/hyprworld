local real_dofile,real_open=dofile,io.open
local enabled,binary=true,true
local failure=nil
local calls={}
local noop=function()end
_G.hl={plugin={load=function()calls.load=true;if not binary then error('missing binary') end end,
    hyprworld_shared={set_enabled=function(value)calls.enabled=value end}},layout={register=noop}}
for _,name in ipairs({'config','bind','unbind','dispatch','get_active_window','get_active_monitor','get_monitors','get_monitor_at_cursor','get_cursor_pos','get_config','timer','on','curve','animation'}) do hl[name]=noop end
_G.o={bind=noop}
dofile=function(path)
    if path:match('/layout/preferences.lua$') then return {enabled=function()return enabled end} end
    if path:match('/layout/init.lua$') then calls.layout=true;if failure=='layout' then error('layout failed') end;return true end
    if path:match('/integration/omarchy.lua$') then calls.integration=true;if failure=='integration' then error('integration failed') end;return true end
    return real_dofile(path)
end
io.open=function(path,mode)
    if path:match('/hyprworld.json$') then return {close=function()end} end
    return real_open(path,mode)
end
local function boot()
    _G.__hyprworld_plugin_loaded=nil;calls={}
    local ok,result=pcall(real_dofile,'./integration/plugin.lua')
    assert(ok, result)
    return result
end
assert(boot());assert(calls.load and calls.layout and calls.integration and calls.enabled==true)
-- A loaded helper must still be declared in every fresh config generation,
-- otherwise Hyprland removes it and schedules another reload.
assert(boot());assert(calls.load and calls.enabled==true)
hl.get_config=function() return 'previous-layout' end
hl.config=function(config) calls.restored=config.general.layout end
for _,stage in ipairs({'layout','integration'}) do
    failure=stage
    assert(boot()==false)
    assert(calls.enabled==false and not _G.__hyprworld_enabled and not _G.__hyprworld_plugin_loaded)
    if stage=='integration' then assert(calls.restored=='previous-layout') end
end
failure=nil
hl.plugin.hyprworld_shared.set_enabled=function(value)
    calls.enabled=value
    if value then error('enable failed after changing state') end
end
assert(boot()==false);assert(calls.enabled==false and not calls.layout)
hl.plugin.hyprworld_shared.set_enabled=function(value) calls.enabled=value end
enabled=false
assert(boot());assert(not calls.load and not calls.layout and calls.integration and calls.enabled==false)
enabled=true;hl.plugin.hyprworld_shared=nil
assert(boot()==false);assert(calls.load and not calls.layout and not calls.integration)
binary=false
assert(boot()==false);assert(not calls.layout and not calls.integration and not _G.__hyprworld_plugin_loaded)
io.open,dofile=real_open,real_dofile
print('ok - bootstrap enable/disable, partial initialization rollback and missing-helper failure')
