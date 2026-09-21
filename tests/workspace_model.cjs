const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const api = {};
vm.createContext(api);
vm.runInContext(fs.readFileSync(__dirname + '/../WorkspaceModel.js', 'utf8').replace(/^\.pragma library\s*/, ''), api);
const ws = (id, count = 0) => ({id, toplevels: {values: Array(count).fill({})}});
const ids = (values, currentId) => Array.from(api.ids(values, currentId));
assert.deepEqual(ids([]), [1,2,3,4,5]);
assert.deepEqual(ids([ws(6), ws(10)]), [1,2,3,4,5]);
assert.deepEqual(ids([ws(10,1), ws(6,2), ws(6,2), ws(-99,1)]), [1,2,3,4,5,6,10]);
assert.deepEqual(ids([ws(1000000,1)]), [1,2,3,4,5,1000000]);
assert.deepEqual(ids([ws(3,1), ws(2), ws(1)]), [1,2,3,4,5]);
console.log('ok - fixed 1–5, occupied higher IDs, no next slot, sparse IDs and special exclusion');

assert.deepEqual(ids([ws(8)], 8), [1,2,3,4,5,8]);
assert.deepEqual(ids([ws(8)], 9), [1,2,3,4,5,9]);
assert.deepEqual(ids([ws(8,1)], 8), [1,2,3,4,5,8]);
assert.deepEqual(ids([], 3), [1,2,3,4,5]);
