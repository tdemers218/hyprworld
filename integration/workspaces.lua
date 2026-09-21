-- One shared, unbounded positive workspace namespace. The native helper applies
-- swap-on-request to all dispatchers, including external bars and IPC callers.
local M = {}
function M.install(hl, o)
    hl.config({general={layout="lua:hyprworld"}})
    local function dismiss()
        if _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then
            if _G.__hyprworld_set_overview then _G.__hyprworld_set_overview(false)
            else hl.dispatch(hl.dsp.layout("overview-dismiss")) end
        end
        if _G.__hyprworld_end_gesture then _G.__hyprworld_end_gesture() end
    end
    local nav={}
    function nav.select(id, move, follow)
        id=tonumber(id)
        if not id or id<1 or id%1~=0 then return end
        local monitor=hl.get_active_monitor()
        if not monitor then return end
        local previous=monitor.active_workspace and monitor.active_workspace.id
        if not move and previous==id then return end
        local direction, directionY=previous and id>previous and 1 or -1, 0
        for _,other in ipairs(hl.get_monitors()) do
            if other.name~=monitor.name and other.active_workspace and other.active_workspace.id==id then
                local a,b=monitor.position or monitor,other.position or other
                local dx,dy=(b.x or 0)-(a.x or 0),(b.y or 0)-(a.y or 0)
                local distance=math.max(math.abs(dx),math.abs(dy),1)
                direction,directionY=dx/distance,dy/distance
            end
        end
        local keepOverview=not move and _G.__hyprworld_overview_active and _G.__hyprworld_overview_active()
        if keepOverview and _G.__hyprworld_prepare_overview_transfer then
            _G.__hyprworld_prepare_overview_transfer()
        else dismiss() end
        if move then
            -- Keep the request on this monitor, even when following the moved window.
            hl.dispatch(hl.dsp.window.move({workspace=tostring(id),follow=false}))
            if follow then hl.dispatch(hl.dsp.focus({workspace=tostring(id)})) end
        else
            hl.dispatch(hl.dsp.focus({workspace=tostring(id)}))
            if keepOverview and _G.__hyprworld_set_overview then
                _G.__hyprworld_set_overview(true, direction, false, directionY)
            end
        end
    end
    function nav.step(delta)
        local monitor=hl.get_active_monitor()
        local ws=monitor and monitor.active_workspace
        if ws then nav.select(math.max(1,ws.id+delta)) end
    end
    function nav.monitor(delta)
        dismiss()
        hl.dispatch(hl.dsp.focus({monitor=delta>0 and "+1" or "-1"}))
    end
    for slot=1,10 do
        local key="code:"..(slot+9)
        for _,mods in ipairs({"SUPER + ","SUPER + SHIFT + ","SUPER + SHIFT + ALT + "}) do hl.unbind(mods..key) end
        o.bind("SUPER + "..key,"Hyprworld: Workspace "..slot,function() nav.select(slot) end)
        o.bind("SUPER + SHIFT + "..key,"Hyprworld: Move to workspace "..slot,function() nav.select(slot,true,true) end)
        o.bind("SUPER + SHIFT + ALT + "..key,"Hyprworld: Move silently to workspace "..slot,function() nav.select(slot,true,false) end)
    end
    for _,spec in ipairs({{key="SUPER + TAB",delta=1},{key="SUPER + SHIFT + TAB",delta=-1}}) do
        hl.unbind(spec.key)
        o.bind(spec.key,"Hyprworld: "..(spec.delta==1 and "Next monitor" or "Previous monitor"),function() nav.monitor(spec.delta) end)
    end
    hl.unbind("SUPER + CTRL + TAB")
    o.bind("SUPER + CTRL + TAB","Hyprworld: Former workspace",function()
        dismiss(); hl.dispatch(hl.dsp.focus({workspace="previous_per_monitor"}))
    end)
    _G.__hyprworld_workspace_nav=nav
    _G.__hyprworld_workspace_is_managed=function()
        local monitor=hl.get_active_monitor()
        return monitor and monitor.active_workspace and monitor.active_workspace.id>0 or false
    end
    return nav
end
return M
