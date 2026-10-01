-- Live swipes (the default) follow the fingers: three fingers move the camera,
-- four fingers up/down drive the overview transition and left/right fade the
-- non-focused windows before a full workspace slide. Each commits on release past the
-- threshold; shorter or cancelled swipes return. With live swipes off, every
-- gesture acts once on release.
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
    local function liveEnabled() return flow().touchpadEnabled ~= false and flow().liveSwipes ~= false end
    -- `live` names actions <live>Begin(direction) -> bool, <live>Update(progress)
    -- and <live>End(direction, commit), looked up when the gesture runs;
    -- `once` runs on a committed release otherwise.
    local function tracked(fingers, direction, live, once)
        local axis = (direction == 'left' or direction == 'right') and 'x' or 'y'
        local travel, sign, active = 0, nil, false
        -- Distance along the swipe, signed by its first movement so the
        -- preview heads toward the focused neighbour whatever the scroll
        -- direction setting.
        local function track(e)
            local d = tonumber((e.delta or {})[axis]) or 0
            if not sign and d ~= 0 then sign = d > 0 and 1 or -1 end
            travel = travel + d
            return sign and math.max(0, travel*sign) or 0
        end
        local function full() return tonumber(flow().swipeDistance) or 300 end
        hl.gesture({fingers=fingers, direction=direction, action={
            start=function(e)
                travel, sign = 0, nil
                local begin = actions[live.."Begin"]
                active = liveEnabled() and begin ~= nil and begin(direction) or false
                local along = track(e)
                if active then actions[live.."Update"](along/full()) end
            end,
            update=function(e)
                local along = track(e)
                if active then actions[live.."Update"](along/full()) end
            end,
            finish=function(e)
                local commit = not e.cancelled and flow().touchpadEnabled ~= false
                    and track({}) >= (tonumber(flow().swipeThreshold) or 90)
                if active then actions[live.."End"](direction, commit)
                elseif commit then once() end
                travel, sign, active = 0, nil, false
            end,
        }})
    end
    for _,direction in ipairs({'left','right','up','down'}) do
        tracked(3, direction, "swipe", function() actions.focus(direction) end)
    end
    tracked(4, 'left', "workspaceSwipe", function() actions.workspace(-1) end)
    tracked(4, 'right', "workspaceSwipe", function() actions.workspace(1) end)
    for _,direction in ipairs({'up','down'}) do
        tracked(4, direction, "overviewSwipe", function() actions.overview() end)
    end
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
