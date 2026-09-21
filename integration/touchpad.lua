-- Match keyboard actions once per deliberate swipe; cancellation is a no-op.
local M = {}
function M.install(hl, actions)
    local directory=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
    local preferences=dofile(directory.."/../layout/preferences.lua")
    local function flow() return preferences.section('workflow') end
    local function swipe(fingers, direction, action)
        local distance = 0
        hl.gesture({fingers=fingers, direction=direction, action={
            start=function(e) distance=math.abs((e.delta or {}).x or 0)+math.abs((e.delta or {}).y or 0) end,
            update=function(e) distance=distance+math.abs((e.delta or {}).x or 0)+math.abs((e.delta or {}).y or 0) end,
            finish=function(e) if not e.cancelled and flow().touchpadEnabled~=false and distance>=(tonumber(flow().swipeThreshold) or 40) then action() end; distance=0 end,
        }})
    end
    for _,direction in ipairs({'left','right','up','down'}) do
        swipe(3,direction,function() actions.focus(direction) end)
    end
    swipe(4,'left',function() actions.workspace(-1) end)
    swipe(4,'right',function() actions.workspace(1) end)
    swipe(4,'up',actions.overview)
    swipe(4,'down',actions.overview)
    local previous = 1
    hl.gesture({fingers=2,direction='pinch',action={
        start=function() previous=1 end,
        update=function(e)
            local scale=tonumber(e.scale)
            if not scale or scale<=0 then return end
            local delta=math.log(scale/previous)
            if math.abs(delta)>=0.025 then if flow().touchpadEnabled~=false then actions.zoom(delta*(tonumber(flow().pinchSensitivity) or 1)) end; previous=scale end
        end,
        finish=function() previous=1 end,
    }})
end
return M
