-- Data-only, session-scoped layout checkpoints. Disk writes happen in Python.
local M={}
local directory=debug.getinfo(1,'S').source:sub(2):match('^(.*)/[^/]+$')
local decoder=dofile(directory..'/json.lua')
local function read(path,limit)
    local f=io.open(path,'r');if not f then return nil end
    local data=f:read(limit+1);f:close()
    return data and #data<=limit and data or nil
end
function M.scope()
    local stat=read('/proc/self/stat',8192)
    local boot=read('/proc/sys/kernel/random/boot_id',128)
    if not stat or not boot then return nil end
    local pid,tail=stat:match('^(%d+) %(.+%) (.*)')
    if not pid then return nil end
    local fields={};for field in tail:gmatch('%S+') do fields[#fields+1]=field end
    return fields[20] and boot:gsub('%s+','')..':'..pid..':'..fields[20] or nil
end
function M.load(path,scope)
    if not scope then return {} end
    for _,suffix in ipairs({'','.1','.2'}) do
        local raw=read(path..suffix,1024*1024)
        if raw then
            local ok,data=pcall(decoder.decode,raw)
            if ok and type(data)=='table' and data.version==1 and data.scope==scope and type(data.workspaces)=='table' then return data.workspaces end
        end
    end
    return {}
end
local function number(value,low,high)
    return type(value)=='number' and value==value and value>=low and value<=high and value or nil
end
local function integer(value,low,high)
    value=number(value,low,high);return value and value%1==0 and value or nil
end
function M.capture(state)
    local windows={}
    for _,id in ipairs(state.ids) do
        local p=state.positions[id]
        if p and not id:match('^target:') then
            windows[#windows+1]={id,p.col,p.row,p.slot or 1,state.width_step_by_id[id] or 3,
                state.height_step_by_id[id] or 3,state.align_x_by_id[id] or 0,state.align_y_by_id[id] or 0}
        end
    end
    table.sort(windows,function(a,b)return a[1]<b[1] end)
    local c=state.camera or {}
    return {windows=windows,camera={c.col or 0,c.row or 0,c.x or 0,c.y or 0},
        zoomStep=state.zoom_step or 3,zoom=state.zoom_value}
end
function M.restore(record,state,ids,config)
    if type(record)~='table' or type(record.windows)~='table' then return end
    state.checkpoint_seen=state.checkpoint_seen or {}
    local by_id={}
    for i,entry in ipairs(record.windows) do
        if i>5000 then break end
        if type(entry)=='table' and type(entry[1])=='string' and #entry[1]<=128
            and integer(entry[2],-10000,10000) and integer(entry[3],-10000,10000)
            and integer(entry[4],1,4) then by_id[entry[1]]=entry end
    end
    local restored=false
    for _,id in ipairs(ids) do
        if not state.checkpoint_seen[id] then
            state.checkpoint_seen[id]=true
            local entry=by_id[id]
            if entry then
                state.positions[id]={col=entry[2],row=entry[3],slot=entry[4]}
                state.width_step_by_id[id]=integer(entry[5],1,#config.width_steps) or config.default_width_step
                state.height_step_by_id[id]=integer(entry[6],1,#config.height_steps) or config.default_height_step
                state.align_x_by_id[id]=integer(entry[7],-1,1) or 0
                state.align_y_by_id[id]=integer(entry[8],-1,1) or 0
                state.template_placed=state.template_placed or {};state.template_placed[id]=true
                restored=true
            end
        end
    end
    if restored and not state.checkpoint_camera_restored then
        local c=type(record.camera)=='table' and record.camera or {}
        state.camera={col=integer(c[1],-10000,10000) or 0,row=integer(c[2],-10000,10000) or 0,
            x=number(c[3],-1000000,1000000) or 0,y=number(c[4],-1000000,1000000) or 0}
        state.zoom_step=integer(record.zoomStep,1,#config.zoom_steps) or config.default_zoom_step
        state.zoom_value=number(record.zoom,config.zoom_steps[1],config.zoom_steps[#config.zoom_steps])
        state.checkpoint_camera_restored=true;state.template_zoom_applied=true
    end
end
return M
