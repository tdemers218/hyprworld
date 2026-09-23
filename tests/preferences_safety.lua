local raw='{"workflow":{"focusMode":"click"},"groups":{"layouts":{"3":null}},"placement":{"nodes":[false,{"col":1e300,"row":-1e300,"capacity":100}]},"startup":{"templates":[false,{"apps":[false,{"class":"app","col":1e300}]}]}}'
local real=io.open
io.open=function(path,mode)
 if path:match('hyprworld%.json$') then return {read=function() return raw end,close=function() end} end
 return real(path,mode)
end
local p=dofile('layout/preferences.lua')
local data=p.data()
assert(data.placement.nodes[1].col==32 and data.placement.nodes[1].row==-32)
assert(data.placement.nodes[1].capacity==4)
assert(data.groups.layouts['3']==nil,'invalid group layout must retain built-in arrangement')
assert(data.startup.templates[1].apps[1].col==32)
assert(p.mouse()=='click')
raw='{broken';assert(p.data()==data,'malformed edits must retain last known settings')
raw=string.rep(' ',1024*1024+1);assert(p.data()==data,'oversized settings must retain last known settings')
raw='{"workflow":false,"placement":{"nodes":true},"startup":{"templates":12}}'
assert(type(p.data().startup.templates)=='table')
assert(p.mouse()=='auto')
print('ok - bounded preferences, malformed nesting, last-good settings and group defaults')
