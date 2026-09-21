-- Drive the real adapter with a controlled clock, without desktop input.
local enabled, delay, runs = true, 200, 0
local original_loadfile=loadfile
loadfile=function(path,...)
    if path:match('/preferences.lua$') then
        return function() return {
            keep_connected=function() return enabled,delay end,
            mouse=function() return 'click',0 end,
        } end
    end
    if path:match('/core.lua$') then
        return function()
            local core=original_loadfile(path)()
            local compact=core.compact
            core.compact=function(state) runs=runs+1; compact(state) end
            return core
        end
    end
    return original_loadfile(path,...)
end
local provider, active, timer
local ctx={area={x=0,y=0,w=1920,h=1080},targets={}}
hl={
    layout={register=function(_,p) provider=p end},
    on=function() return true end,
    get_active_window=function() return active end,
    get_active_workspace=function() return {id=9} end,
    get_config=function() return 2 end,
    config=function() end,
    timer=function(callback)
        timer={callback=callback,enabled=true,set_enabled=function(self,value) self.enabled=value end}
        return timer
    end,
    dsp={layout=function(message) return message end,focus=function() return {} end},
    dispatch=function(message) if type(message)=='string' then provider.layout_msg(ctx,message) end end,
}
dofile('layout/init.lua')
loadfile=original_loadfile
for i=1,4 do
    ctx.targets[i]={window={stable_id=i,address='0x'..i,active=i==1,workspace={id=9},
        monitor={name='test'},layout={name='lua:hyprworld'}},place=function() end}
end
active=ctx.targets[1].window
provider.recalculate(ctx)
local function ticks(n)
    for _=1,n do if timer.enabled then timer.callback() end end
end
provider.layout_msg(ctx,'move-to 10 10')
ticks(3); assert(runs==0,'compacted before idle delay')
provider.layout_msg(ctx,'move-to 11 10')
ticks(3); assert(runs==0,'a move did not restart the delay')
ticks(1); assert(runs==1,'idle delay did not compact')
provider.layout_msg(ctx,'overview-open')
provider.layout_msg(ctx,'move-to 12 10')
provider.layout_msg(ctx,'overview-highlight 0x1')
ticks(8); assert(runs==1,'compacted during a held overview drag')
provider.layout_msg(ctx,'overview-drag-end')
ticks(3); assert(runs==1)
ticks(1); assert(runs==2,'release did not resume idle countdown')
provider.layout_msg(ctx,'move-to 13 10')
enabled=false
ticks(8); assert(runs==2,'disabled feature ran pending compaction')
enabled=true; delay=5000
provider.layout_msg(ctx,'move-to 14 10')
ticks(99); assert(runs==2,'five-second delay fired early')
ticks(1); assert(runs==3,'five-second idle delay did not compact')
assert(__hyprworld_preview():match('"compactSerial":3'),'compaction animation event missing')
print('ok - compaction idle delay, restart, held drag, disabling and five-second timing')

-- Deleting a window schedules the same delayed compaction, and another deletion
-- restarts it even when the count is replaced by a newly mapped window.
delay=200
ctx.targets[4]=nil
provider.recalculate(ctx)
ticks(3); assert(runs==3,'deletion compacted too soon')
ctx.targets[3]=nil
provider.recalculate(ctx)
ticks(3); assert(runs==3,'second deletion did not restart delay')
ticks(1); assert(runs==4,'deletion did not compact')
print('ok - deletion schedules and restarts compaction')
