const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('Preview.qml', 'utf8');
// Run the actual QML JavaScript handlers with process/timer stand-ins.
const refresh = source.slice(source.indexOf('    function refresh('), source.indexOf('    function command('));
const handler = source.slice(source.indexOf('        function onRawEvent(event)'),
    source.indexOf('\n    Process {\n        id: reader')).replace(/\n    }\s*$/, '');
const context = {
    root: {gesturing: true, pushAvailable: true}, reader: {running: false},
    pending: false,
    refreshTimer: {running: false, start() { this.running = true; }}
};
vm.createContext(context);
vm.runInContext(refresh + '\n' + handler, context);
for (let i = 0; i < 100; i++) context.refresh();
assert.equal(context.reader.running, false, 'drag events must not start polling');
context.refresh(true);
assert.equal(context.reader.running, true, 'watchdog recovers a missing drag-end event');
context.refresh(true);
assert.equal(context.pending, true, 'overlapping polls coalesce');
context.reader.running = false;
context.onRawEvent({name: 'configreloaded'});
assert.equal(context.root.pushAvailable, false);
context.refresh(true);
assert.equal(context.reader.running, true, 'reload with stale gesture still permits recovery');
context.reader.running = false;
context.root.gesturing = false;
context.refresh();
assert.equal(context.reader.running, true, 'ordinary refresh resumes after recovery');
assert.match(source, /interval: root.pushAvailable \|\| root.gesturing \? 2000 : 400;[^\n]*onTriggered: root.refresh\(true\)/);
console.log('ok - gesture IPC recovery, reload recovery and coalesced polling');
