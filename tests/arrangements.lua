local core=dofile('layout/core.lua');local config=dofile('layout/config.lua')
local s=core.new_state();s.placement={enabled=true,preset='vertical',fillHoles=true}
core.sync(s,{'a','b','c'},'a',config)
assert(s.positions.b.col==0 and s.positions.b.row==1 and s.positions.c.row==2)
s=core.new_state();s.placement={enabled=true,preset='custom',fillHoles=true,overflow='repeat',nodes={{col=0,row=0,capacity=2},{col=1,row=0,capacity=1},{col=0,row=1,capacity=1}}}
core.sync(s,{'a','b','c','d','e'},'a',config)
assert(#core.members(s,'a')==2)
assert(s.positions.c.col==1 and s.positions.d.row==1 and s.positions.e.col==2)
core.sync(s,{'a','c','d','e','f'},'a',config)
assert(s.positions.f.col==0 and s.positions.f.row==0,'vacancy not reused')
s.group_layouts={['2']={mode='rows',ratio=.5}}
local part=core.part(s,'f');assert(part.h==.5 and part.w==1)
s.group_layouts['2']={mode='master-top',ratio=.7}
part=core.part(s,'a');assert(part.h==.7)
local json=dofile('layout/json.lua')
local decoded=json.decode('{"a":false,"b":[1,2],"text":"line\\n\\u00e9\\uD83D\\uDE00"}')
assert(decoded.a==false and decoded.b[2]==2 and decoded.text=='line\né😀')
assert(not pcall(json.decode,'{"x":1} trailing'))
assert(not pcall(json.decode,'{"x":"\\q"}'))
print('ok - vertical/branch placement, grouping, vacancy reuse, custom partitions and JSON data parsing')

s.group_layouts['2']={mode='master-right',ratio=.7}
local master=core.part(s,'a');local secondary=core.part(s,'f')
assert(math.abs(master.x-.3)<.00001 and master.w==.7)
assert(secondary.x==0 and math.abs(secondary.w-.3)<.00001)

s=core.new_state()
s.placement={enabled=true,preset='custom',overflow='repeat',nodes={{col=-1,row=0,capacity=1},{col=0,row=0,capacity=1}}}
core.sync(s,{'a','b','c','d'},'a',config)
assert(s.positions.a.col==-1 and s.positions.b.col==0 and s.positions.c.col==1 and s.positions.d.col==2,'negative path bounds must repeat without overlap')
s=core.new_state()
s.placement={enabled=true,preset='custom',overflow='extend',nodes={{col=0,row=0,capacity=2},{col=1,row=0,capacity=1}}}
core.sync(s,{'a','b','c','d','e'},'a',config)
assert(s.positions.d.col==2 and s.positions.e.col==3,'extend overflow must create one new tile per window')
s.template_placed={a=true};core.sync(s,{'b','c','d','e'},'b',config)
assert(s.template_placed.a==nil,'closed template windows must release their placement marker')
