-- Loading from hyprland.lua must fail without throwing or changing the layout.
local real=io.open
io.open=function(path,mode)
 if mode=='r' and path:match('hyprworld%.json$') then return {close=function() end} end
 return real(path,mode)
end
hl={};o={}
local ok,result=pcall(dofile,'./integration/plugin.lua')
assert(ok and result==false and __hyprworld_enabled==false)
assert(not __hyprworld_plugin_loaded)
print('ok - unsupported host leaves desktop configuration untouched')
