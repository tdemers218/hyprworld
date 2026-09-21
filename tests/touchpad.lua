local specs, calls = {}, {}
local actions = {}
for _,name in ipairs({'focus','workspace','overview','zoom'}) do actions[name]=function(value) calls[#calls+1]={name,value} end end
dofile('integration/touchpad.lua').install({gesture=function(spec) specs[spec.fingers..spec.direction]=spec.action end},actions)
for _,direction in ipairs({'left','right','up','down'}) do
 local s=specs['3'..direction];s.start({});s.update({delta={x=60}});s.finish({})
 assert(calls[#calls][1]=='focus' and calls[#calls][2]==direction)
 local count=#calls;s.start({});s.update({delta={y=60}});s.finish({cancelled=true});assert(#calls==count)
 s.start({});s.update({delta={x=2}});s.finish({});assert(#calls==count)
end
for direction,delta in pairs({left=-1,right=1}) do
 local s=specs['4'..direction];s.start({});s.update({delta={x=60}});s.finish({});assert(calls[#calls][2]==delta)
end
for _,direction in ipairs({'up','down'}) do
 local s=specs['4'..direction];s.start({});s.update({delta={y=60}});s.finish({});assert(calls[#calls][1]=='overview')
end
local s=specs['2pinch'];s.start({});s.update({scale=1.2});assert(calls[#calls][2]>0)
s.update({scale=.8});assert(calls[#calls][2]<0);s.finish({})
print('ok - touchpad focus, workspace, overview, pinch, jitter and cancellation')
