local module=dofile('integration/workspaces.lua')
local path=os.tmpname()
local external={name='HDMI-A-1',active_workspace={id=2}}
local laptop={name='eDP-1',active_workspace={id=8}}
local monitors={laptop,external}
local active=laptop
local actions,bindings,rules,hooks={},{},{},{}
local overview=false
local direction
local prepared=false
__hyprworld_prepare_overview_transfer=function() prepared=true end
__hyprworld_overview_active=function() return overview end
__hyprworld_set_overview=function(value,delta) overview=value; direction=delta end
local h={
    get_monitors=function() local result={} for _,m in ipairs(monitors) do result[#result+1]=m end return result end,
    get_active_monitor=function() return active end,
    workspace_rule=function(rule) rules[rule.workspace]=rule end,
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
local nav=module.install(h,o,path)
assert(rules['1'].monitor=='HDMI-A-1' and rules['6'].monitor=='eDP-1')
assert(rules['10'].persistent and rules['10'].layout=='lua:hyprworld')
bindings['SUPER + code:10']()
assert(actions[#actions].workspace=='6')
bindings['SUPER + SHIFT + code:11']()
assert(actions[#actions].workspace=='7' and actions[#actions].follow==true)
bindings['SUPER + SHIFT + ALT + code:12']()
assert(actions[#actions].workspace=='8' and actions[#actions].follow==false)
assert(not bindings['SUPER + code:15'])
active=external
nav.step(1)
assert(actions[#actions].workspace=='3')
active.active_workspace={id=5}
local count=#actions
nav.step(1)
assert(#actions==count,'navigation must stop at bank edge')
overview=true
nav.step(-1)
assert(overview and direction==-1 and actions[#actions].workspace=='4')
assert(prepared,'overview switches must prepare an atomic transfer')
prepared=false
bindings['SUPER + TAB']()
assert(actions[#actions].monitor=='+1' and not overview)
-- Reconnecting/order changes must not renumber the laptop bank.
monitors={laptop}
module.install(h,o,path)
assert(rules['6'].monitor=='eDP-1')
monitors={laptop,external,{name='DP-2',active_workspace={id=11}}}
hooks['monitor.added']()
assert(rules['11'].monitor=='DP-2' and rules['1'].monitor=='HDMI-A-1')
os.remove(path)
print('ok - per-monitor workspace banks, local movement, boundaries, overview navigation and stable reconnect IDs')
