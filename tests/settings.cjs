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
assert.equal(api.normalize({minimap:{width:99999, enabled:false}}).minimap.width, 440);
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
