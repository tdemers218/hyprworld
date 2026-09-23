local M = {}
local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
local json=dofile(directory.."/json.lua")
local cached_raw, cached_data
local function object(v) return type(v)=='table' and v or {} end
local function number(v,default,low,high)
    v=tonumber(v)
    if not v or v~=v or math.abs(v)==math.huge then return default end
    return math.max(low,math.min(high,v))
end
local function integer(v,default,low,high) return math.floor(number(v,default,low,high)+.5) end
local function sanitize(data)
    for _,key in ipairs({'plugin','workflow','placement','groups','startup','effects'}) do data[key]=object(data[key]) end
    local p=data.placement
    local nodes={}
    for i,n in ipairs(object(p.nodes)) do
        if i>64 then break end
        if type(n)=='table' then nodes[#nodes+1]={col=integer(n.col,0,-32,32),row=integer(n.row,0,-32,32),capacity=integer(n.capacity,1,1,4)} end
    end
    p.nodes=nodes
    local ids={}
    for i,id in ipairs(object(p.workspaces)) do
        if i>10000 then break end
        if type(id)=='number' and id>=1 and id<=10000 and id%1==0 then ids[#ids+1]=id end
    end
    p.workspaces=ids
    data.groups.layouts=object(data.groups.layouts)
    for _,count in ipairs({'2','3','4'}) do
        local g=object(data.groups.layouts[count])
        local modes={columns=true,rows=true,grid=true,['master-left']=true,['master-right']=true,['master-top']=true}
        if modes[g.mode] then g.ratio=number(g.ratio,.5,.2,.8);data.groups.layouts[count]=g
        else data.groups.layouts[count]=nil end
    end
    local templates={}
    for i,t in ipairs(object(data.startup.templates)) do
        if i>20 then break end
        if type(t)=='table' then
            t.workspace=integer(t.workspace,i,1,10000);t.zoom=number(t.zoom,1,.65,1.25)
            local apps={}
            for j,a in ipairs(object(t.apps)) do
                if j>32 then break end
                if type(a)=='table' and type(a.class)=='string' then
                    a.col=integer(a.col,0,-32,32);a.row=integer(a.row,0,-32,32);apps[#apps+1]=a
                end
            end
            t.apps=apps;templates[#templates+1]=t
        end
    end
    data.startup.templates=templates
    return data
end
function M.data()
    local raw=M.read()
    if raw~=cached_raw then
        local ok,result=pcall(json.decode,raw)
        cached_raw=raw
        -- An interrupted or malformed edit must not throw away working settings.
        if ok and type(result)=='table' then cached_data=sanitize(result) end
    end
    return cached_data or {}
end
function M.section(name) return object(M.data()[name]) end
function M.read()
    local home = os.getenv("HOME") or ""
    local file = io.open(home .. "/.config/omarchy/hyprworld.json", "r")
        or io.open(directory .. "/../customizer.json", "r")
    if not file then return "" end
    local raw = file:read(1024*1024+1); file:close()
    if not raw or #raw>1024*1024 then return "" end
    return raw
end
function M.enabled() return M.section('plugin').enabled~=false end
function M.mouse()
    local flow=M.section('workflow')
    return flow.focusMode=='click' and 'click' or 'auto', number(flow.mouseCooldownMs,550,0,1500)
end
function M.keep_connected(data)
    local flow=object((data or M.data()).workflow)
    local delay=number(flow.compactDelayMs,5000,0,30000)
    if delay<=0 then delay=5000 end
    return flow.keepConnected~=false, math.max(100,delay)
end
return M
