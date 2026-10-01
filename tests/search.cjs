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
const apps = [
 {id:'zen',name:'Zen Browser',startupClass:'zen',keywords:['web']},
 {id:'org.gnome.Nautilus',name:'Files',genericName:'File manager'},
 {id:'kitty',name:'kitty',startupClass:'kitty'},
 {id:'app.zen_browser.zen',name:'Zen Twilight'},
];
assert.deepEqual([...search.launchable('zen',apps,[]).map(a=>a.id)],['zen','app.zen_browser.zen']);
assert.deepEqual([...search.launchable('zen',apps,[{class:'zen'}]).map(a=>a.id)],[],'open app offered for launch');
assert.deepEqual([...search.launchable('kitty',apps,windows).map(a=>a.id)],[],'window class match');
assert.deepEqual([...search.launchable('file manager',apps,[]).map(a=>a.id)],['org.gnome.Nautilus']);
assert.deepEqual([...search.launchable('zbr',apps,[]).map(a=>a.id)],[],'subsequence matches must not launch');
assert.equal(search.launchable('',apps,[]).length,0);
assert.equal(search.launchable('z',apps,[]).length,0,'single character offered launches');
assert.deepEqual([...search.details({floating:true,xwayland:true,grouped:['a','b'],inhibitingIdle:true,contentType:'video'})],
 ['Floating','Tabbed ×2','Video','Keeping awake','XWayland']);
assert.equal(search.details({floating:false,fullscreen:0,grouped:[]}).length,0);
console.log('ok - launchable apps exclude open windows and fuzzy noise; window details');
