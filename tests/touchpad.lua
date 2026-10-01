-- Touchpad gestures with live swipes on (the default) and off.
local real_open = io.open
local preference_text = nil
io.open = function(path, mode)
    if path:match("hyprworld%.json$") or path:match("/customizer%.json$") then
        if not preference_text then return nil end
        return {read=function() return preference_text end, close=function() end}
    end
    return real_open(path, mode)
end
local function install(text)
    preference_text = text
    local specs, calls, actions = {}, {}, {}
    for _,name in ipairs({'focus','workspace','overview','zoom'}) do actions[name]=function(value) calls[#calls+1]={name,value} end end
    dofile('integration/touchpad.lua').install({gesture=function(spec) specs[spec.fingers..spec.direction]=spec.action end},actions)
    return specs, calls, actions
end
local axis={left={x=-1},right={x=1},up={y=-1},down={y=1}}
local function along(direction,amount) local d=axis[direction]; return {x=(d.x or 0)*amount,y=(d.y or 0)*amount} end

-- Live swipes off: every gesture acts once on a long enough release.
local specs, calls = install('{"workflow":{"liveSwipes":false}}')
for _,direction in ipairs({'left','right','up','down'}) do
 local s=specs['3'..direction];s.start({});s.update({delta=along(direction,120)});s.finish({})
 assert(calls[#calls][1]=='focus' and calls[#calls][2]==direction)
 local count=#calls;s.start({});s.update({delta=along(direction,120)});s.finish({cancelled=true});assert(#calls==count)
 s.start({});s.update({delta=along(direction,20)});s.finish({});assert(#calls==count)
end
for direction,delta in pairs({left=-1,right=1}) do
 local s=specs['4'..direction];s.start({});s.update({delta=along(direction,120)});s.finish({});assert(calls[#calls][2]==delta)
end
for _,direction in ipairs({'up','down'}) do
 local s=specs['4'..direction];s.start({});s.update({delta=along(direction,120)});s.finish({});assert(calls[#calls][1]=='overview')
end
local s=specs['2pinch'];s.start({});s.update({scale=1.2});assert(calls[#calls][2]>0)
s.update({scale=.8});assert(calls[#calls][2]<0);s.finish({})

-- Live swipes on: progress follows the fingers, then commits or returns.
local actions
specs, calls, actions = install('{}')
for _,live in ipairs({{fingers=3,prefix='swipe',direction='up'},{fingers=4,prefix='overviewSwipe',direction='up'},
  {fingers=4,prefix='workspaceSwipe',direction='left'}}) do
 local log={}
 actions[live.prefix..'Begin']=function(direction) log[#log+1]={'begin',direction}; return true end
 actions[live.prefix..'Update']=function(progress) log[#log+1]={'update',progress} end
 actions[live.prefix..'End']=function(direction,commit) log[#log+1]={'end',direction,commit} end
 local s=specs[live.fingers..live.direction]
 local d=function(n) return along(live.direction,n) end
 s.start({delta=d(30)});s.update({delta=d(120)})
 assert(log[1][1]=='begin' and log[1][2]==live.direction)
 assert(math.abs(log[#log][2]-150/300)<1e-9,'progress follows finger travel')
 -- Moving back reduces progress; it never goes negative.
 s.update({delta=d(-200)});assert(log[#log][2]==0)
 s.update({delta=d(200)});s.finish({})
 assert(log[#log][1]=='end' and log[#log][3]==true,'long swipe commits')
 log={};s.start({delta=d(20)});s.update({delta=d(30)});s.finish({})
 assert(log[#log][3]==false,'short swipe returns')
 log={};s.start({delta=d(200)});s.finish({cancelled=true})
 assert(log[#log][3]==false,'cancelled swipe returns')
end
assert(#calls==0,'live swipes also fired the one-shot action')
-- Without a live handler (e.g. Hyprworld inactive) the one-shot still works.
actions.overviewSwipeBegin=function() return false end
local o=specs['4down'];o.start({});o.update({delta={y=150}});o.finish({})
assert(calls[#calls][1]=='overview')
print('ok - touchpad live and one-shot swipes for focus, overview and workspaces, pinch, jitter and cancellation')
