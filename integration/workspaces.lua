-- Stable five-workspace banks. Monitor IDs can change after reconnecting;
-- the saved connector order keeps each monitor's workspace IDs unchanged.
local M = {}
function M.install(hl, o, path)
    path = path or (os.getenv("HOME") .. "/.config/omarchy/hyprworld-monitors")
    local order, index = {}, {}
    local file = io.open(path,"r")
    if file then
        for name in file:lines() do
            if name ~= "" and not index[name] then order[#order+1]=name; index[name]=#order end
        end
        file:close()
    end
    local function refresh()
        local monitors=hl.get_monitors()
        table.sort(monitors,function(a,b) return a.name < b.name end)
        local changed=false
        for _, monitor in ipairs(monitors) do
            if not index[monitor.name] then
                order[#order+1]=monitor.name; index[monitor.name]=#order; changed=true
            end
        end
        if changed then
            local output=assert(io.open(path,"w"),"Cannot save monitor workspace assignments")
            output:write(table.concat(order,"\n").."\n"); output:close()
        end
        for _,monitor in ipairs(monitors) do
            local offset=(index[monitor.name]-1)*5
            for slot=1,5 do
                hl.workspace_rule({workspace=tostring(offset+slot),monitor=monitor.name,
                    persistent=true,default=slot==1,layout="lua:hyprworld"})
            end
        end
    end
    refresh()
    local function dismiss()
        if _G.__hyprworld_overview_active and _G.__hyprworld_overview_active() then
            if _G.__hyprworld_set_overview then _G.__hyprworld_set_overview(false)
            else hl.dispatch(hl.dsp.layout("overview-dismiss")) end
        end
        if _G.__hyprworld_end_gesture then _G.__hyprworld_end_gesture() end
    end
    local function bank()
        local monitor=hl.get_active_monitor()
        if not monitor or not index[monitor.name] then return nil end
        return (index[monitor.name]-1)*5, monitor
    end
    local nav={}
    function nav.select(slot, move, follow)
        local offset,monitor=bank()
        if not offset or slot<1 or slot>5 then return end
        local previous=monitor.active_workspace and monitor.active_workspace.id
        local keepOverview=not move and _G.__hyprworld_overview_active and _G.__hyprworld_overview_active()
        if not move and previous==offset+slot then return end
        if keepOverview and _G.__hyprworld_prepare_overview_transfer then
            _G.__hyprworld_prepare_overview_transfer()
        elseif not keepOverview then dismiss() end
        if move then hl.dispatch(hl.dsp.window.move({workspace=tostring(offset+slot),follow=follow}))
        else
            hl.dispatch(hl.dsp.focus({workspace=tostring(offset+slot)}))
            if keepOverview and _G.__hyprworld_set_overview then
                _G.__hyprworld_set_overview(true, previous and offset+slot>previous and 1 or -1)
            end
        end
    end
    function nav.step(delta)
        local offset,monitor=bank()
        if not offset then return end
        local ws=monitor.active_workspace
        local slot=ws and ws.id-offset or 1
        nav.select(math.max(1,math.min(5,slot+delta)))
    end
    function nav.monitor(delta)
        dismiss()
        hl.dispatch(hl.dsp.focus({monitor=delta>0 and "+1" or "-1"}))
    end
    for slot=1,10 do
        local key="code:"..(slot+9)
        for _,mods in ipairs({"SUPER + ","SUPER + SHIFT + ","SUPER + SHIFT + ALT + "}) do hl.unbind(mods..key) end
        if slot<=5 then
            o.bind("SUPER + "..key,"Hyprworld: Local workspace "..slot,function() nav.select(slot) end)
            o.bind("SUPER + SHIFT + "..key,"Hyprworld: Move to local workspace "..slot,function() nav.select(slot,true,true) end)
            o.bind("SUPER + SHIFT + ALT + "..key,"Hyprworld: Move silently to local workspace "..slot,function() nav.select(slot,true,false) end)
        end
    end
    for _,spec in ipairs({{key="SUPER + TAB",delta=1},{key="SUPER + SHIFT + TAB",delta=-1}}) do
        hl.unbind(spec.key)
        o.bind(spec.key,"Hyprworld: "..(spec.delta==1 and "Next monitor" or "Previous monitor"),function() nav.monitor(spec.delta) end)
    end
    hl.unbind("SUPER + CTRL + TAB")
    o.bind("SUPER + CTRL + TAB","Hyprworld: Former workspace on this monitor",function()
        dismiss(); hl.dispatch(hl.dsp.focus({workspace="previous_per_monitor"}))
    end)
    -- Moving a complete workspace to another monitor would break ownership.
    for _,direction in ipairs({"LEFT","RIGHT","UP","DOWN"}) do hl.unbind("SUPER + SHIFT + ALT + "..direction) end
    hl.on("monitor.added",refresh)
    _G.__hyprworld_workspace_nav=nav
    _G.__hyprworld_workspace_is_managed=function()
        local offset,monitor=bank()
        local ws=monitor and monitor.active_workspace
        return offset and ws and ws.id>offset and ws.id<=offset+5 or false
    end
    return nav
end
return M
