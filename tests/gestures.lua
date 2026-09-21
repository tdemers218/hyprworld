local core = dofile("layout/core.lua")
local config = dofile("layout/config.lua")
local gestures = dofile("layout/gestures.lua")
local state = core.new_state()
core.sync(state, {"a", "b"}, "a", config)
local area = {x=-596,y=130,w=1366,h=768}
local boxes, grid = core.placements(state, area, config)
local tiles = {}
for _, id in ipairs(state.ids) do
    local p = state.positions[id]
    tiles[#tiles+1] = {address=id,col=p.col,row=p.row,box=boxes[id],part=core.part(state,id)}
end
local b = boxes.b
local drop = gestures.destination(tiles, grid, tiles[1], b.x+b.w/2,b.y+b.h/2)
assert(drop.col == 1 and drop.label:match("Create group"))
tiles[2].part.count = 3
assert(gestures.destination(tiles,grid,tiles[1],b.x+1,b.y+1).label:match("4 windows"))
tiles[2].part.count = 4
assert(gestures.destination(tiles,grid,tiles[1],b.x+1,b.y+1).label == "Swap full group")
assert(not gestures.destination(tiles,grid,tiles[1],boxes.a.x+1,boxes.a.y+1))
local empty = gestures.destination(tiles,grid,tiles[1],b.x+b.w*2,b.y+b.h/2)
assert(empty and empty.col > 1 and empty.label == "Move here")
core.sync(state, {"a"}, "a", config)
boxes,grid = core.placements(state,area,config)
tiles = {{address="a",col=0,row=0,box=boxes.a}}
assert(gestures.destination(tiles,grid,tiles[1],boxes.a.x+boxes.a.w*3,boxes.a.y).col > 0)
local initialX = boxes.a.x
state.camera.x, state.camera.y = 137, -65
boxes = core.placements(state,area,config)
assert(boxes.a.x == initialX+137)
core.follow(state)
assert(core.placements(state,area,config).a.x == initialX)

-- Exercise press/tick/release and monitor cancellation without desktop input.
local provider, timer, active, cursor, monitor, subscriptions
local input = {['input.follow_mouse']=1,['input.float_switch_override_focus']=1}
monitor = {name="test",x=-596,y=130}
subscriptions = {}
hl = {
    layout={register=function(_, p) provider=p end},
    get_active_window=function() return active end,
    get_cursor_pos=function() return cursor end,
    get_monitor_at_cursor=function() return monitor end,
    get_config=function(k) return input[k] end,
    config=function(c) for k,v in pairs(c.input) do input['input.'..k]=v end end,
    on=function(event,callback) subscriptions[event]=callback; return true end,
    timer=function(callback,options)
        local created={callback=callback,enabled=true,set_enabled=function(self,v) self.enabled=v end}
        if not options or options.timeout~=50 then timer=created end
        return created
    end,
    dsp={layout=function(m) return m end,focus=function(opts) return opts end},
}
local ctx = {area=area,targets={}}
hl.dispatch=function(message)
    if type(message)=='string' then provider.layout_msg(ctx,message) end
end
__hyprworld_layout_registered=nil
__hyprworld_focus_subscription=nil
dofile('layout/init.lua')
-- Keep this mock independent of the user's saved focus preference.
__hyprworld_apply_mouse=function() end
for i=1,2 do
    ctx.targets[i]={window={stable_id=i,address='0x'..i,active=i==1,
        workspace={id=9},monitor=monitor,layout={name='lua:hyprworld'}},
        place=function(self,box) self.box=box end}
end
active=ctx.targets[1].window
provider.recalculate(ctx)
local a=ctx.targets[1]
cursor={x=a.box.x+10,y=a.box.y+10}
local x=a.box.x
provider.layout_msg(ctx,'gesture-pan')
assert(input['input.follow_mouse']==2 and timer.enabled)
cursor={x=cursor.x+125,y=cursor.y-40}
timer.callback()
assert(a.box.x==x+125, 'pan must follow pointer in pixels')
provider.layout_msg(ctx,'gesture-end')
assert(input['input.follow_mouse']==1 and not timer.enabled)
cursor={x=a.box.x+10,y=a.box.y+10}
provider.layout_msg(ctx,'gesture-move')
local dest=ctx.targets[2].box
cursor={x=dest.x+dest.w/2,y=dest.y+dest.h/2}
provider.layout_msg(ctx,'gesture-tick')
assert(__hyprworld_preview():match('Create group'))
provider.layout_msg(ctx,'gesture-end')
assert(__hyprworld_preview():match('"count":2'))
assert(not __hyprworld_preview():match('"gesture"'))
cursor={x=a.box.x+10,y=a.box.y+10}
provider.layout_msg(ctx,'gesture-pan')
monitor={name='other'}
timer.callback()
assert(not timer.enabled and input['input.follow_mouse']==1, 'monitor crossing must release gesture')
monitor=active.monitor
input['input.follow_mouse']=2
provider.layout_msg(ctx,'gesture-pan')
provider.layout_msg(ctx,'gesture-end')
assert(input['input.follow_mouse']==2, 'click-focus preference must survive dragging')
provider.layout_msg(ctx,'zoom-wheel in')
assert(timer.enabled)
for _=1,80 do if timer.enabled then timer.callback() end end
assert(not timer.enabled and input['input.follow_mouse']==2, 'zoom timer must settle and restore mouse mode')
print('ok - pointer geometry, group cues, pixel pan, release and monitor cancellation')

local s=core.new_state()
core.sync(s,{'a','b','c','d'},'a',config)
for _,id in ipairs({'b','c','d'}) do core.observe_focus(s,id); core.move_to(s,0,0) end
local before=core.part(s,'a').index
local other=core.part(s,'c').index
assert(core.swap_members(s,'a','c'))
assert(core.part(s,'a').index==other and core.part(s,'c').index==before)
assert(#core.members(s,'a')==4)
core.observe_focus(s,'c') -- now upper left
assert(core.move(s,'right'))
assert(core.part(s,'c').index==2 and #core.members(s,'c')==4)
assert(core.move(s,'right')) -- outer edge detaches
assert(#core.members(s,'c')==1)
local members={
 {address='a',col=0,row=0,box={x=0,y=0,w=50,h=100}},
 {address='b',col=0,row=0,box={x=50,y=0,w=50,h=100}}}
assert(gestures.destination(members,{},members[1],75,50).swapAddress=='b')

local z=core.new_state()
core.sync(z,{'a'},'a',config)
core.wheel_zoom(z,config,1)
assert(core.zoom_value(z,config)==1 and math.abs(z.zoom_target-1.08)<0.0001)
assert(core.advance_zoom(z))
assert(core.zoom_value(z,config)>1 and core.zoom_value(z,config)<1.08)
for _=1,80 do core.advance_zoom(z) end
assert(math.abs(core.zoom_value(z,config)-1.08)<0.0001)
core.zoom(z,config,-1)
assert(core.zoom_value(z,config)==1, 'keyboard zoom chooses adjacent preset')
for _=1,25 do core.wheel_zoom(z,config,-1) end
for _=1,80 do core.advance_zoom(z) end
assert(z.overview and core.zoom_value(z,config)==config.zoom_steps[1])
core.wheel_zoom(z,config,1)
assert(not z.overview)
for _=1,30 do core.wheel_zoom(z,config,1) end
for _=1,80 do core.advance_zoom(z) end
assert(core.zoom_value(z,config)==config.zoom_steps[#config.zoom_steps])
print('ok - group reordering, directional swaps, smooth zoom interpolation and limits')
local emptyMonitor={name='test',x=0,y=0,width=1000,height=800,scale=1}
hl.get_active_monitor=function() return emptyMonitor end
provider.layout_msg(ctx,'overview-open')
hl.get_active_workspace=function() return {id=9} end
active=nil
__hyprworld_toggle_overview()
assert(__hyprworld_preview():match('"commitAddress":"0x'), 'toggle must commit selected window after overview keyboard grab')
hl.get_active_workspace=function() return {id=10} end
active=nil
__hyprworld_toggle_overview()
assert(__hyprworld_overview_active() and __hyprworld_preview():match('"workspaceId":10'))
__hyprworld_toggle_overview()
assert(not __hyprworld_overview_active())
print('ok - overview toggles on empty workspaces without a layout callback')

-- Active-window focus may lag behind the monitor during a workspace transfer.
active=ctx.targets[1].window
hl.get_active_workspace=function() return {id=10} end
__hyprworld_set_overview(true)
assert(__hyprworld_overview_active(), 'stale window focus closed destination overview')
assert(__hyprworld_preview():match('"workspaceId":10'), 'preview followed stale window focus')
__hyprworld_prepare_overview_transfer()
provider.recalculate(ctx)
assert(__hyprworld_preview():match('"workspaceId":10'), 'transfer replaced frozen preview')
__hyprworld_set_overview(true)
assert(__hyprworld_overview_active())
print('ok - overview uses workspace ownership during stale focus and transfers')
