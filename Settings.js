.pragma library

function sections() {
    return [
        {id:"minimap",title:"Minimap",icon:"view-grid-symbolic",description:"Your workspace at a glance."},
        {id:"overview",title:"Overview",icon:"view-fullscreen-symbolic",description:"Space to see, search, and arrange."},
        {id:"effects",title:"Effects",icon:"preferences-system-symbolic",description:"Animation and rendering performance."},
        {id:"workflow",title:"Flow",icon:"input-mouse-symbolic",description:"Make navigation feel natural."},
        {id:"placement",title:"Placement paths",icon:"go-jump-symbolic",description:"Decide where the next window belongs."},
        {id:"groups",title:"Group layouts",icon:"view-split-left-right-symbolic",description:"Give every group a balanced arrangement."},
        {id:"startup",title:"Startup workspaces",icon:"system-run-symbolic",description:"Start with the workspace you need."},
        {id:"shortcuts",title:"Shortcuts",icon:"input-keyboard-symbolic",description:"Find an action. Make it yours."},
        {id:"plugin",title:"Plugin",icon:"preferences-system-symbolic",description:"Manage Hyprworld."}
    ];
}
function fields() {
    var rows=[];
    function add(section,group,key,title,type,value,extra) {
        rows.push(Object.assign({section:section,group:group,key:key,title:title,type:type,value:value},extra||{}));
    }
    function toggle(s,g,k,t,v,extra) { add(s,g,k,t,"toggle",v,extra); }
    function range(s,g,k,t,v,min,max,step,unit,advanced) { add(s,g,k,t,"range",v,{min:min,max:max,step:step||1,unit:unit||"",advanced:!!advanced}); }
    function choice(s,g,k,t,v,options,advanced) { add(s,g,k,t,"choice",v,{options:options,advanced:!!advanced}); }
    toggle('minimap','Visibility','enabled','Show minimap',true);
    toggle('minimap','Visibility','hideSingle','Hide with a single window',true);
    toggle('minimap','Visibility','hideMaxZoom','Hide at maximum zoom',true);
    toggle('minimap','Visibility','hideFullscreen','Hide while fullscreen',true);
    choice('minimap','Placement','placementMode','Sizing mode','fixed',['fixed','fit']);
    rows[rows.length-1].description='Fixed uses your reference size. Fit grows and shrinks up to its maximum width/height, staying inside the monitor and clear of the focused window.';
    choice('minimap','Placement','corner','Anchor','top-left',['top-left','top-right','bottom-left','bottom-right']);
    range('minimap','Placement','x','Horizontal inset',12,0,1000,1,'px');
    range('minimap','Placement','y','Vertical inset',52,0,1000,1,'px');
    range('minimap','Placement','fitMaxWidth','Fit maximum width',300,100,1200,10,'px');
    range('minimap','Placement','fitMaxHeight','Fit maximum height',200,60,800,10,'px');
    range('minimap','Size','width','Reference width',220,100,800,10,'px');
    range('minimap','Size','height','Reference height',140,60,600,10,'px');
    range('minimap','Placement','hideBelow','Hide below scale',35,0,100,1,'%',true);
    rows[rows.length-1].description='In Fit mode, hide below this percentage of the reference size. Zero hides only when no space remains. Fit may grow beyond the reference size.';
    choice('minimap','Appearance','style','Surface style','classic',['classic','elevated','glass','high-contrast']);
    toggle('minimap','Effects','shadow','Soft shadow',false);
    toggle('minimap','Effects','wallpaperBlur','Wallpaper blur',false,{description:'Blur a wallpaper texture inside the backdrop, not the application content behind it.'});
    range('minimap','Effects','blurStrength','Wallpaper blur strength',.65,0,1,.05,'',true);
    range('minimap','Effects','shadowOpacity','Shadow opacity',.35,0,1,.05,'',true);
    range('minimap','Effects','surfaceRadius','Backdrop corner radius',10,0,32,1,'px',true);
    range('minimap','Appearance','opacity','Card opacity',.72,.1,1,.01);
    range('minimap','Appearance','lineWidth','Border width',1,0,6,1,'px');
    range('minimap','Appearance','radius','Corner radius',3,0,24,1,'px');
    range('minimap','Appearance','fillOpacity','Card fill',0,0,1,.01);
    range('minimap','Appearance','backgroundOpacity','Backdrop opacity',0,0,1,.01);
    add('minimap','Appearance','activeColor','Active window color','color','');
    add('minimap','Appearance','borderColor','Other window borders','color','');
    add('minimap','Appearance','backgroundColor','Background color','color','');
    toggle('minimap','Labels','showIcons','App icons',false);
    toggle('minimap','Labels','showTitles','Window titles',false);
    toggle('minimap','Labels','showWorkspace','Workspace number',false);
    toggle('minimap','Interaction','interactive','Click a window to focus',false);
    range('minimap','Animation','motionMs','Movement duration',300,0,1000,10,'ms',true);
    range('minimap','Animation','fadeMs','Fade duration',150,0,1000,10,'ms',true);
    range('overview','Animation','animationMs','Open / close duration',360,0,1500,10,'ms');
    range('overview','Animation','switchMs','Workspace transition',360,0,1500,10,'ms');
    choice('overview','Animation','easing','Easing','out-cubic',['out-cubic','in-out-cubic','linear'],true);
    toggle('overview','Animation','reducedMotion','Reduced motion',false);
    toggle('overview','Background','wallpaper','Use current wallpaper',true);
    range('overview','Background','dim','Wallpaper dimming',0,0,.9,.01);
    range('overview','Cards','cardOpacity','Card opacity',.82,.3,1,.01);
    range('overview','Cards','cardWidth','Maximum card width',290,120,800,10,'px');
    range('overview','Cards','cardHeight','Maximum card height',150,80,500,10,'px');
    range('overview','Cards','groupWidth','Grouped card width',520,200,1000,10,'px',true);
    range('overview','Cards','groupHeight','Grouped card height',320,120,800,10,'px',true);
    range('overview','Cards','gap','Card spacing',6,0,40,1,'px');
    range('overview','Cards','radius','Corner radius',10,0,32,1,'px');
    add('overview','Cards','activeColor','Selected border color','color','');
    add('overview','Cards','backgroundColor','Card background color','color','');
    toggle('overview','Labels','showIcons','App icons',true);
    toggle('overview','Labels','showAppNames','App names',true);
    toggle('overview','Labels','showTitles','Window titles',true);
    toggle('overview','Labels','showWorkspace','Workspace number',true);
    toggle('overview','Labels','showHints','Navigation hints',true);
    range('overview','Labels','fontSize','Title size',12,9,22,1,'px',true);
    choice('overview','Search','searchScope','Search scope','all',['all','workspace']);
    toggle('overview','Search','searchMetadata','Search extended window metadata',true);
    toggle('overview','Interaction','emptyClickCloses','Click empty space to close',true);
    toggle('workflow','Compaction','keepConnected','Keep windows connected',true);
    range('workflow','Compaction','compactDelayMs','Idle delay before compacting',5000,100,30000,100,'ms');
    toggle('workflow','Compaction','compactOnClose','Compact after window removal',true);
    toggle('workflow','Compaction','compactOnMove','Compact after moving windows',true);
    toggle('workflow','Compaction','preserveFocus','Keep focused tile anchored',false);
    choice('workflow','Focus','focusMode','Pointer focus','auto',['auto','click']);
    range('workflow','Focus','mouseCooldownMs','Pause after camera movement',550,0,1500,25,'ms');
    range('workflow','Geometry','peekX','Horizontal edge peek',48,0,200,1,'px',true);
    range('workflow','Geometry','peekY','Vertical edge peek',48,0,200,1,'px',true);
    range('workflow','Geometry','gapX','Horizontal window gap',12,0,100,1,'px',true);
    range('workflow','Geometry','gapY','Vertical window gap',12,0,100,1,'px',true);
    range('workflow','Geometry','defaultWidth','Default width fraction',.85,.2,1,.01,'',true);
    range('workflow','Geometry','defaultHeight','Default height fraction',.85,.2,1,.01,'',true);
    range('workflow','Gestures','swipeThreshold','Swipe threshold',40,10,200,5,'px',true);
    range('workflow','Gestures','pinchSensitivity','Pinch sensitivity',1,.2,3,.1,'×',true);
    toggle('workflow','Gestures','touchpadEnabled','Enable touchpad actions',true);
    toggle('plugin','General','enabled','Enable Hyprworld',true);
    toggle('effects','Performance','animations','Enable animations',true,{description:'Controls minimap, overview and Hyprworld workspace transitions. Does not disable unrelated application or desktop effects.'});
    toggle('effects','Performance','postProcessing','Enable post-processing',true,{description:'Master switch for minimap blur, shadows and effect textures, including those supplied by styles.'});
    toggle('effects','Post-processing','shadows','Allow shadows',true);
    toggle('effects','Post-processing','blur','Allow wallpaper blur',true);
    return rows;
}
function shortcutRows() {
    var rows = [{id:"settings",label:"Open settings",key:"SUPER + SHIFT + L"},
        {id:"overview",label:"Toggle overview",key:"SUPER + O"},
        {id:"zoomIn",label:"Zoom in",key:"SUPER + CTRL + UP"},
        {id:"zoomOut",label:"Zoom out",key:"SUPER + CTRL + DOWN"}]
    var directions = ["Left","Right","Up","Down"]
    ;[{prefix:"focus",label:"Focus",mods:"SUPER"},{prefix:"move",label:"Move / group",mods:"SUPER + SHIFT"},
        {prefix:"resize",label:"Resize",mods:"SUPER + ALT"}].forEach(function(action) {
        directions.forEach(function(d) { rows.push({id:action.prefix+d,label:action.label+" "+d.toLowerCase(),key:action.mods+" + "+d.toUpperCase()}) })
    })
    rows.push({id:"panLeft",label:"Previous workspace",key:"SUPER + CTRL + LEFT"})
    rows.push({id:"panRight",label:"Next workspace",key:"SUPER + CTRL + RIGHT"})
    rows.push({id:"toggleMax",label:"Toggle maximum tile size",key:"SUPER + ALT + F"})
    return rows
}

function defaults() {
    var result={schemaVersion:2,minimap:{},overview:{},effects:{},workflow:{},plugin:{},shortcuts:{},
        placement:{enabled:false,scope:"all",workspaces:[],preset:"horizontal",fillHoles:true,overflow:"extend",nodes:[{col:0,row:0,capacity:1},{col:1,row:0,capacity:1}]},
        groups:{layouts:{"2":{mode:"columns",ratio:.5},"3":{mode:"master-left",ratio:.5},"4":{mode:"grid",ratio:.5}}},
        startup:{enabled:false,templates:[]}};
    fields().forEach(function(f) { result[f.section][f.key]=f.value; });
    shortcutRows().forEach(function(row) { result.shortcuts[row.id]=row.key; });
    return result;
}
function normalize(raw) {
    raw = raw && typeof raw === "object" ? raw : {};
    raw=raw||{};
    var result=defaults();
    if ((raw.minimap||{}).placementMode === undefined && (raw.minimap||{}).shrinkToFit === true)
        result.minimap.placementMode='fit';
    fields().forEach(function(f) {
        var v=(raw[f.section]||{})[f.key];
        if (v===undefined) return;
        if (f.key==='compactDelayMs' && v<=0) v=5000;
        if (f.type==='color' && typeof v==='string' && (v==='' || /^#[0-9a-f]{6}$/i.test(v))) result[f.section][f.key]=v;
        if (f.type==='toggle' && typeof v==='boolean') result[f.section][f.key]=v;
        if (f.type==='range' && typeof v==='number' && isFinite(v)) result[f.section][f.key]=Math.max(f.min,Math.min(f.max,v));
        if (f.type==='choice' && f.options.indexOf(v)>=0) result[f.section][f.key]=v;
    });
    shortcutRows().forEach(function(r) { if (typeof (raw.shortcuts||{})[r.id]==='string') result.shortcuts[r.id]=raw.shortcuts[r.id]; });
    var p=raw.placement||{};
    result.placement.enabled=p.enabled===true;
    result.placement.scope=p.scope==='specific'?'specific':'all';
    result.placement.workspaces=(Array.isArray(p.workspaces)?p.workspaces:[]).filter(function(n,i,a){return Number.isInteger(n)&&n>0&&n<=10000&&a.indexOf(n)===i;});
    if (['horizontal','vertical','custom'].indexOf(p.preset)>=0) result.placement.preset=p.preset;
    result.placement.fillHoles=p.fillHoles!==false;
    if (['extend','repeat'].indexOf(p.overflow)>=0) result.placement.overflow=p.overflow;
    if (Array.isArray(p.nodes) && p.nodes.length) result.placement.nodes=p.nodes.slice(0,64).map(function(n) {
        n = n && typeof n === "object" ? n : {};
        return {col:integer(n.col,-32,32,0),row:integer(n.row,-32,32,0),capacity:integer(n.capacity,1,4,1)};
    }).filter(function(n,i,a) { return a.findIndex(function(v) { return v.col===n.col && v.row===n.row; })===i; });
    [2,3,4].forEach(function(n) {
        var l=((raw.groups||{}).layouts||{})[String(n)]||{};
        if (['columns','rows','grid','master-left','master-right','master-top'].indexOf(l.mode)>=0) result.groups.layouts[String(n)].mode=l.mode;
        if (typeof l.ratio==='number' && isFinite(l.ratio)) result.groups.layouts[String(n)].ratio=Math.max(.2,Math.min(.8,l.ratio));
    });
    var startup=raw.startup||{};
    result.startup.enabled=startup.enabled===true;
    if (Array.isArray(startup.templates)) result.startup.templates=startup.templates.slice(0,20).map(function(t,i) {
        t = t && typeof t === "object" ? t : {};
        return {name:String(t.name||'Workspace '+(i+1)).slice(0,80),workspace:integer(t.workspace,1,10000,i+1),
            enabled:t.enabled!==false,monitor:String(t.monitor||'').slice(0,100),zoom:Math.max(.65,Math.min(1.25,Number(t.zoom)||1)),
            apps:(Array.isArray(t.apps)?t.apps:[]).slice(0,32).map(function(a) { a = a && typeof a === "object" ? a : {}; return {command:String(a.command||'').slice(0,2000),class:String(a.class||'').slice(0,200),
                col:integer(a.col,-32,32,0),row:integer(a.row,-32,32,0)};})};
    });
    return result;
}
function integer(v,min,max,fallback) { return typeof v==='number' && isFinite(v) ? Math.max(min,Math.min(max,Math.round(v))) : fallback; }
function groupRects(count,layout) {
    var mode=layout.mode, ratio=layout.ratio, rects=[];
    if (mode==='grid') { var cols=2, rows=Math.ceil(count/cols); for(var i=0;i<count;i++) rects.push({x:((count===4 && i>=2 ? 5-i : i)%cols)/cols,y:Math.floor(i/cols)/rows,w:1/cols,h:1/rows}); }
    else if (mode==='master-left' || mode==='master-right' || mode==='master-top') {
        rects.push({x:0,y:0,w:ratio,h:1});
        for(var i=1;i<count;i++) rects.push({x:ratio,y:(i-1)/(count-1),w:1-ratio,h:1/(count-1)});
        if(mode==='master-right') rects=rects.map(function(r){return {x:1-r.x-r.w,y:r.y,w:r.w,h:r.h};});
        if(mode==='master-top') rects=rects.map(function(r){return {x:r.y,y:r.x,w:r.h,h:r.w};});
    } else { for(var i=0;i<count;i++) rects.push(mode==='rows'?{x:0,y:i/count,w:1,h:1/count}:{x:i/count,y:0,w:1/count,h:1}); }
    return rects;
}
