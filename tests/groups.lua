local core = dofile("layout/core.lua")
local config = dofile("layout/config.lua")
local area = {x=770,y=-104,w=2560,h=1414}
local function fresh()
    local state = core.new_state()
    core.sync(state, {"A","B","C","D","E","F"}, "A", config)
    return state
end
local function join(state, id)
    core.observe_focus(state, id)
    assert(core.move_to(state, 0, 0))
end
local function valid(state)
    local boxes = core.placements(state, area, config)
    for _, id in ipairs(state.ids) do
        local members = core.members(state, id)
        assert(#members >= 1 and #members <= 4)
        local a = boxes[id]
        assert(a and a.w > 0 and a.h > 0)
        for _, other in ipairs(state.ids) do
            if id ~= other then
                local b = boxes[other]
                assert(a.x+a.w <= b.x+.0001 or b.x+b.w <= a.x+.0001
                    or a.y+a.h <= b.y+.0001 or b.y+b.h <= a.y+.0001, "overlapping windows")
            end
        end
    end
end
local s = fresh()
local function connected(state)
    local ids=state.ids
    if #ids==0 then return end
    local reached={[ids[1]]=true}
    local changed=true
    while changed do
        changed=false
        for _, a in ipairs(ids) do
            for _, b in ipairs(ids) do
                local p,q=state.positions[a],state.positions[b]
                if reached[a] and not reached[b] and math.abs(p.col-q.col)+math.abs(p.row-q.row)<=1 then
                    reached[b]=true; changed=true
                end
            end
        end
    end
    for _, id in ipairs(ids) do assert(reached[id],"disconnected tile after compacting") end
end
do
    local compact=fresh()
    compact.keep_connected=true
    core.observe_focus(compact,"C")
    core.move_to(compact,20,20)
    connected(compact); valid(compact)
    assert(compact.positions.C.col~=20 or compact.positions.C.row~=20,"focused window was excluded from compaction")
    assert(compact.positions.D.col==3 and compact.positions.E.col==4,"focused window attracted stationary tiles")
    core.observe_focus(compact,"B")
    core.move_to(compact,compact.positions.A.col,compact.positions.A.row)
    local slot=compact.positions.B.slot
    core.observe_focus(compact,"F")
    core.move_to(compact,-15,-15)
    connected(compact); valid(compact)
    assert(#core.members(compact,"A")==2 and compact.positions.B.slot==slot,"compaction changed group")
    for n=1,120 do
        core.observe_focus(compact,compact.ids[n % #compact.ids+1])
        core.move_to(compact,n%11-5,n%7-3)
        connected(compact); valid(compact)
    end
    local free=fresh()
    free.keep_connected=false
    core.move_to(free,50,50)
    assert(free.positions.A.col==50 and free.positions.A.row==50,"disabled compaction changed drop")
end
join(s,"B")
assert(core.part(s,"A").w == .5 and core.part(s,"B").w == .5)
core.observe_focus(s,"A")
assert(core.focus(s,"right") == "B", "focus skipped group member")
join(s,"C")
assert(core.part(s,"A").h == 1 and core.part(s,"B").h == .5 and core.part(s,"C").h == .5)
core.observe_focus(s,"A")
assert(core.focus(s,"right") == "B", "neighbor displaced group focus")
valid(s)
join(s,"D")
for _, id in ipairs({"A","B","C","D"}) do
    local p = core.part(s,id)
    assert(p.w*p.h == .25)
end
valid(s)
-- A fifth swaps with the complete group.
join(s,"E")
assert(#core.members(s,"E")==1 and s.positions.E.col==0)
for _, id in ipairs({"A","B","C","D"}) do assert(s.positions[id].col==4) end
valid(s)
-- A member can leave a group; survivors expand and slot order survives sync.
core.observe_focus(s,"C")
assert(core.move(s,"down"))
assert(#core.members(s,"C")==1 and #core.members(s,"A")==3)
core.sync(s,{"F","E","D","C","B","A"},"C",config)
assert(core.members(s,"A")[1]=="A")
valid(s)
core.sync(s,{"F","E","D","C","B"},"C",config)
assert(#core.members(s,"B")==2 and core.part(s,"B").w==.5)
valid(s)
-- Both groups remain whole when the destination is full.
s=fresh()
for _, id in ipairs({"B","C","D"}) do join(s,id) end
core.observe_focus(s,"F"); assert(core.move_to(s,4,0))
core.observe_focus(s,"E"); assert(core.move_to(s,0,0))
assert(#core.members(s,"E")==2 and #core.members(s,"A")==4)
assert(s.positions.E.col==0 and s.positions.A.col==4)
valid(s)
-- Long mixed move/focus/resize sequences cannot overfill or overlap tiles.
math.randomseed(20260910)
for i=1,600 do
    core.observe_focus(s,s.ids[math.random(#s.ids)])
    if i%5==0 then core.resize_direction(s,config,({"left","right","up","down"})[math.random(4)])
    else core.move(s,({"left","right","up","down"})[math.random(4)]) end
    valid(s)
end
print("ok - 2/3/4-window partitions, fifth-window swaps, detach, close, focus and 600 mixed operations")
