-- One shared, unbounded positive workspace namespace. The native helper applies
-- swap-on-request to all dispatchers, including external bars and IPC callers.
local M = {}
-- Diagnostic trace for an intermittent jump to workspace 10: every Hyprworld
-- workspace request (with the binding that asked for it) and every actual
-- workspace change, so a report can tell which path moved the monitor.
local trace_path=os.getenv("HYPRWORLD_TRACE_LOG") or (os.getenv("HOME") or "").."/.local/state/hyprworld/workspace-trace.log"
local trace_seq=0
-- Create the log folder once: a shell per write would stall the compositor on
-- every workspace switch.
local trace_ready=false
local function trace(event, detail)
    trace_seq=trace_seq+1
    local ok=pcall(function()
        if not trace_ready then
            local folder=trace_path:match("^(.*)/[^/]+$")
            if folder and folder~="" then os.execute("mkdir -p '"..folder:gsub("'","'\\''").."'") end
            trace_ready=true
        end
        local file=io.open(trace_path,"a")
        if not file then return end
        file:write(string.format("%s #%d %s %s\n",os.date("%Y-%m-%d %H:%M:%S"),trace_seq,event,detail or ""))
        local size=file:seek("end")
        file:close()
        -- Keep the newest half once the log passes 64 KB.
        if size and size>65536 then
            local reader=io.open(trace_path,"r")
            local text=reader and reader:read("*a") or ""
            if reader then reader:close() end
            local writer=io.open(trace_path,"w")
            if writer then writer:write(text:sub(#text-32768):match("\n(.*)$") or ""); writer:close() end
        end
    end)
    return ok
end
M.trace=trace
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
    function nav.select(id, move, follow, source)
        local monitor_now=hl.get_active_monitor()
        local from=monitor_now and monitor_now.active_workspace and monitor_now.active_workspace.id
        trace("select", string.format("id=%s move=%s from=%s source=%s",tostring(id),tostring(move and true or false),tostring(from),source or debug.traceback("",2):gsub("%s+"," "):sub(1,300)))
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
        if ws then nav.select(math.max(1,ws.id+delta),nil,nil,"step "..tostring(delta)) end
    end
    function nav.monitor(delta)
        dismiss()
        hl.dispatch(hl.dsp.focus({monitor=delta>0 and "+1" or "-1"}))
    end
    for slot=1,10 do
        local key="code:"..(slot+9)
        for _,mods in ipairs({"SUPER + ","SUPER + SHIFT + ","SUPER + SHIFT + ALT + "}) do hl.unbind(mods..key) end
        o.bind("SUPER + "..key,"Hyprworld: Workspace "..slot,function() nav.select(slot,nil,nil,"bind SUPER+"..key) end)
        o.bind("SUPER + SHIFT + "..key,"Hyprworld: Move to workspace "..slot,function() nav.select(slot,true,true,"bind SUPER+SHIFT+"..key) end)
        o.bind("SUPER + SHIFT + ALT + "..key,"Hyprworld: Move silently to workspace "..slot,function() nav.select(slot,true,false,"bind SUPER+SHIFT+ALT+"..key) end)
    end
    for _,spec in ipairs({{key="SUPER + TAB",delta=1},{key="SUPER + SHIFT + TAB",delta=-1}}) do
        hl.unbind(spec.key)
        o.bind(spec.key,"Hyprworld: "..(spec.delta==1 and "Next monitor" or "Previous monitor"),function() nav.monitor(spec.delta) end)
    end
    hl.unbind("SUPER + CTRL + TAB")
    o.bind("SUPER + CTRL + TAB","Hyprworld: Former workspace",function()
        dismiss(); hl.dispatch(hl.dsp.focus({workspace="previous_per_monitor"}))
    end)
    -- Record every workspace change, including ones Hyprworld did not request.
    if hl.on and not rawget(_G,"__hyprworld_workspace_trace") then
        local ok,subscription=pcall(hl.on,"workspace.active",function(workspace)
            local id=workspace and (workspace.id or (type(workspace)=="table" and workspace.workspace and workspace.workspace.id))
            local monitor=hl.get_active_monitor()
            trace("active", string.format("id=%s monitor=%s",tostring(id),tostring(monitor and monitor.name)))
        end)
        if ok then _G.__hyprworld_workspace_trace=subscription or true end
    end
    _G.__hyprworld_workspace_nav=nav
    _G.__hyprworld_workspace_is_managed=function()
        local monitor=hl.get_active_monitor()
        return monitor and monitor.active_workspace and monitor.active_workspace.id>0 or false
    end
    return nav
end
return M
