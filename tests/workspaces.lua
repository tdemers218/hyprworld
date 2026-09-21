local module=dofile('integration/workspaces.lua')
local path=os.tmpname()
local external={name='HDMI-A-1',position={x=1280,y=0},active_workspace={id=2}}
local laptop={name='eDP-1',position={x=0,y=0},active_workspace={id=8}}
local monitors={laptop,external}
local active=laptop
local actions,bindings,rules,hooks={},{},{},{}
local overview=false
local direction, directionY
local prepared=false
__hyprworld_prepare_overview_transfer=function() prepared=true end
__hyprworld_overview_active=function() return overview end
__hyprworld_set_overview=function(value,delta,commit,y) overview=value; direction=delta; directionY=y end
local h={
    get_monitors=function() local result={} for _,m in ipairs(monitors) do result[#result+1]=m end return result end,
    get_active_monitor=function() return active end,
    config=function(config) rules.default=config.general.layout end,
    unbind=function(key) bindings[key]=nil end,
    on=function(event,callback) hooks[event]=callback end,
    dispatch=function(action)
        actions[#actions+1]=action
        if action.kind=='focus' and action.workspace then active.active_workspace={id=tonumber(action.workspace)} end
        if prepared then assert(overview,'overview must stay open during the workspace dispatch') end
    end,
    dsp={focus=function(opts) opts.kind='focus';return opts end,
        window={move=function(opts) opts.kind='move';return opts end}},
}
local o={bind=function(key,_,action) bindings[key]=action end}
local nav=module.install(h,o)
assert(rules.default=='lua:hyprworld')
bindings['SUPER + code:10']()
assert(actions[#actions].workspace=='1')
bindings['SUPER + SHIFT + code:11']()
assert(actions[#actions-1].workspace=='2' and actions[#actions-1].follow==false)
assert(actions[#actions].kind=='focus' and actions[#actions].workspace=='2')
bindings['SUPER + SHIFT + ALT + code:12']()
assert(actions[#actions].workspace=='3' and actions[#actions].follow==false)
bindings['SUPER + code:19']()
assert(actions[#actions].workspace=='10')
nav.step(1)
assert(actions[#actions].workspace=='11','navigation must create workspaces beyond ten')
nav.select(10000)
assert(actions[#actions].workspace=='10000')
nav.select(1)
local count=#actions
nav.step(-1)
nav.select(-1)
nav.select(1.5)
assert(#actions==count,'invalid IDs and lower boundary must not dispatch')
overview=true
nav.step(1)
assert(overview and direction==1 and actions[#actions].workspace=='2')
assert(prepared,'overview switches must prepare an atomic transfer')
prepared=false
external.position={x=0,y=-800}
external.active_workspace={id=4}
nav.select(4)
assert(direction==0 and directionY==-1,'overview swap must enter from the monitor above')
prepared=false
bindings['SUPER + TAB']()
assert(actions[#actions].monitor=='+1' and not overview)
active=external
nav.select(1)
assert(actions[#actions].workspace=='1','workspace IDs must be identical on every monitor')
os.remove(path)
print('ok - shared IDs, unlimited navigation, movement, overview and monitor focus')
