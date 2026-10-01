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
// Legacy animation keys migrate into effects and mark the preset custom.
const migrated = api.normalize({overview:{animationMs:0,easing:'linear'},minimap:{motionMs:500}});
assert.equal(migrated.effects.overviewMs, 0);
assert.equal(migrated.effects.overviewCurve, 'linear');
assert.equal(migrated.effects.minimapMs, 500);
assert.equal(migrated.effects.preset, 'custom');
assert.equal(api.normalize({overview:{animationMs:360}}).effects.preset, 'smooth');
assert.equal(api.normalize({effects:{overviewMs:200},overview:{animationMs:0}}).effects.overviewMs, 200);
// Presets cover every animation; smooth reproduces the defaults.
const smooth = api.presetValues('smooth'), defaultsEffects = api.defaults().effects;
for (const key of Object.keys(smooth)) assert.equal(smooth[key], defaultsEffects[key], key);
assert.equal(api.presetValues('instant').overviewMs, 0);
assert.ok(api.presetValues('instant').launchMs > 0, 'instant preset removed launch feedback');
assert.equal(api.presetValues('bouncy').tilesCurve, 'overshoot');
assert.equal(api.presetValues('nope'), null);
// Custom bezier curves are kept; out-of-range or malformed ones fall back.
assert.equal(api.normalize({effects:{tilesCurve:'bezier:0.2,1.4,0.5,1'}}).effects.tilesCurve, 'bezier:0.2,1.4,0.5,1');
for (const bad of ['bezier:1.5,0,0.5,1','bezier:0.2,3,0.5,1','bezier:a,b,c,d','nope'])
    assert.equal(api.normalize({effects:{tilesCurve:bad}}).effects.tilesCurve, 'out-cubic', bad);
assert.equal(api.curveValue([0.123,1.456,0.5,1]), 'bezier:0.12,1.46,0.5,1');
assert.equal([...api.bezier('bezier:0.1,0.2,0.3,0.4')].join(','), '0.1,0.2,0.3,0.4,1,1');
for (const name of api.curveNames()) {
    assert.ok(Math.abs(api.curveAt(name, 0)) < 0.01 && Math.abs(api.curveAt(name, 1) - 1) < 0.01, name);
}
assert.ok(Math.abs(api.curveAt('linear', 0.3) - 0.3) < 0.001);
assert.ok(Math.max(...Array.from({length:50},(_, i)=>api.curveAt('overshoot', i/49))) > 1, 'overshoot never exceeds 1');
assert.equal(api.presetValues('smooth').cameraMs, 380);
// General curve mode applies one curve and one speed to every animation.
const general = api.normalize({effects:{curveMode:'general',generalCurve:'overshoot',durationScale:2}}).effects;
assert.equal(api.effective(general,'overview').curve, 'overshoot');
assert.equal(api.effective(general,'overview').ms, 720);
assert.equal(api.effective(general,'camera').ms, 760);
const individual = api.normalize({effects:{tilesCurve:'linear'}}).effects;
assert.equal(api.effective(individual,'tiles').curve, 'linear');
assert.equal(api.effective(individual,'tiles').ms, 180);
assert.equal(api.presetValues('snappy').curveMode, 'individual');
assert.equal(api.normalize({minimap:{glassBlur:99}}).minimap.glassBlur, 40);
assert.equal(api.defaults().minimap.glassBlur, 10);
for (const name of api.presetNames()) {
    const values = api.presetValues(name);
    assert.deepEqual(api.normalize({effects:values}).effects.preset, name);
    for (const a of api.animations()) assert.ok(api.curveNames().includes(values[a.id+'Curve']), name+' '+a.id);
}
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
