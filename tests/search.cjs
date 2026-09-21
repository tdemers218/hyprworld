const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const search = vm.createContext({});
vm.runInContext(fs.readFileSync('Search.js', 'utf8'), search);
const windows = [
 {address:'0x1',class:'kitty',title:'Résumé budget 2026',pid:4278,workspace:{id:7,name:'Research'},tags:['writing']},
 {address:'0x2',class:'browser',title:'Documentation',initialTitle:'Project plan',workspace:{id:2}},
];
for (const query of ['rsm bdgt','resume','4278','research','writing','2026']) assert.equal(search.rank(query,windows)[0].address,'0x1',query);
assert.equal(search.rank('project plan',windows)[0].address,'0x2');
assert.equal(search.rank('zzzzzz',windows).length,0);
assert.equal(search.rank('',windows).length,2);
assert.ok(search.score('cat','cat') < search.score('cat','creative art'));
console.log('ok - fuzzy title, metadata, multiple terms, accents, ranking and no results');
