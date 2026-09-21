const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const api = {};
vm.createContext(api);
vm.runInContext(fs.readFileSync(__dirname + "/../Settings.js", "utf8").replace(/^\.pragma library\s*/, ""), api);
const defaults = api.defaults();
assert.equal(api.normalize({}).workflow.keepConnected, true);
assert.equal(api.normalize({workflow:{keepConnected:false}}).workflow.keepConnected, false);
assert.equal(api.normalize({}).workflow.compactDelayMs,5000);
assert.equal(api.normalize({workflow:{compactDelayMs:0}}).workflow.compactDelayMs,5000);
assert.equal(api.normalize({workflow:{compactDelayMs:9000}}).workflow.compactDelayMs,9000);
assert.equal(api.normalize({workflow:{compactDelayMs:50000}}).workflow.compactDelayMs,30000);
assert.equal(api.normalize({minimap:{x:0}, overview:{animationMs:0}}).minimap.x, 0);
assert.equal(api.normalize({overview:{animationMs:0}}).overview.animationMs, 0);
assert.equal(api.normalize({minimap:{width:99999, enabled:false}}).minimap.width, 800);
assert.equal(api.normalize({minimap:{enabled:false}}).minimap.enabled, false);
assert.equal(api.normalize({workflow:{mouseCooldownMs:-1}}).workflow.mouseCooldownMs, 0);
assert.equal(api.normalize({minimap:null}).minimap.opacity, 0.72);
assert.equal(api.normalize({shortcuts:{zoomIn:"SUPER + CTRL + H"}}).shortcuts.zoomIn, "SUPER + CTRL + H");
assert.equal(Object.keys(defaults.shortcuts).length, 19);
assert.equal(api.normalize({workflow:{focusMode:"click"}}).workflow.focusMode, "click");
assert.equal(api.normalize({plugin:{enabled:false}}).plugin.enabled, false);
for (const corner of ["top-left","top-right","bottom-left","bottom-right"]) {
    assert.equal(api.normalize({minimap:{corner}}).minimap.corner, corner);
}
console.log("ok - settings migration, bounds, corners, mouse mode and 19 remappable actions");

const expanded=api.normalize({placement:{enabled:true,preset:'custom',nodes:[{col:1,row:2,capacity:9},{col:1,row:2,capacity:2}]},groups:{layouts:{'3':{mode:'master-top',ratio:2}}},startup:{templates:[{workspace:2,apps:[{class:'kitty',command:'kitty',col:0,row:0}]}]}});
assert.equal(expanded.placement.nodes.length,1);
assert.equal(expanded.placement.nodes[0].capacity,4);
assert.equal(expanded.groups.layouts['3'].ratio,.8);
assert.equal(expanded.startup.templates[0].apps[0].class,'kitty');
for(const count of [2,3,4]) for(const mode of ['columns','rows','master-left','master-top']) {
 const rects=api.groupRects(count,{mode,ratio:.6});
 assert.equal(rects.length,count);
 assert.ok(Math.abs(rects.reduce((a,r)=>a+r.w*r.h,0)-1)<1e-9);
}
console.log('ok - expanded settings, path bounds, startup templates and group partitions');

assert.equal(api.normalize({}).placement.scope, 'all');
const scoped=api.normalize({placement:{scope:'specific',workspaces:[2,4,2,-1,0,'5',10001]}});
assert.equal(JSON.stringify(scoped.placement.workspaces),'[2,4]');
assert.equal(scoped.placement.scope,'specific');
const right=api.groupRects(3,{mode:'master-right',ratio:.6});
assert.equal(right[0].x,.4);assert.equal(right[0].w,.6);
assert.equal(right[1].x,0);assert.equal(right[1].w,.4);
assert.equal(api.normalize({groups:{layouts:{'3':{mode:'master-right'}}}}).groups.layouts['3'].mode,'master-right');
