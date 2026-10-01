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
    choice('minimap','Appearance','style','Style','base',['base','glass','constellation','icons']);
    rows[rows.length-1].description='Base draws outlined cards. Glass gives each window its own blurred, translucent backdrop. Constellation links glowing stars and sends the focus glow along the links. Icons shows one large app icon per window.';
    toggle('minimap','Effects','shadow','Soft shadow',false);
    toggle('minimap','Effects','wallpaperBlur','Wallpaper blur',false,{description:'Blur a wallpaper texture inside the backdrop, not the application content behind it.'});
    range('minimap','Effects','blurStrength','Wallpaper blur strength',.65,0,1,.05,'',true);
    range('minimap','Effects','glassBlur','Glass blur radius',10,0,40,1,'px',true);
    rows[rows.length-1].description='How strongly the Glass style blurs what is behind each window card.';
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
    toggle('overview','Animation','reducedMotion','Reduced motion',false);
    range('overview','Animation','cascade','Card cascade',.3,0,.6,.05,'');
    rows[rows.length-1].description='Cards ripple out from the selected window when the overview opens, and fold back into it when it closes. 0 moves them together.';
    toggle('overview','Animation','depthZoom','Wallpaper depth zoom',true);
    toggle('overview','Animation','focusPulse','Focus ring on arrival',true);
    toggle('overview','Background','wallpaper','Use current wallpaper',true);
    range('overview','Background','dim','Wallpaper dimming',0,0,.9,.01);
    range('overview','Background','backgroundBlur','Wallpaper blur',16,0,48,1,'px');
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
    toggle('overview','Labels','showDetails','Window state details',true,{description:'Small labels for floating, fullscreen, pinned, tabbed, video, idle-inhibiting and XWayland windows.'});
    toggle('overview','Labels','showHints','Navigation hints',true);
    range('overview','Labels','fontSize','Title size',12,9,22,1,'px',true);
    choice('overview','Search','searchScope','Search scope','all',['all','workspace']);
    toggle('overview','Search','searchMetadata','Search extended window metadata',true);
    toggle('overview','Search','launchApps','Launch apps with no open window',true,{description:'Searching for an installed app that has no window offers to open it on the current workspace.'});
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
    toggle('workflow','Gestures','liveSwipes','Live swipes',true);
    rows[rows.length-1].description='The camera and overview follow your fingers, and workspace swipes fade the surrounding windows before a full slide. Short swipes spring back. Off: each swipe acts once when you lift your fingers.';
    range('workflow','Gestures','swipeThreshold','Swipe commit distance',90,10,400,5,'px',true);
    rows[rows.length-1].description='Three-finger swipes shorter than this return the camera instead of moving focus.';
    range('workflow','Gestures','swipeDistance','Full swipe distance',300,100,1000,10,'px',true);
    rows[rows.length-1].description='Finger travel that moves the camera all the way to the next window.';
    range('workflow','Gestures','pinchSensitivity','Pinch sensitivity',1,.2,3,.1,'×',true);
    toggle('workflow','Gestures','touchpadEnabled','Enable touchpad actions',true);
    toggle('plugin','General','enabled','Enable Hyprworld',true);
    choice('effects','Animation','preset','Animation feel','smooth',presetNames().concat(['custom']));
    rows[rows.length-1].description='Presets set every duration and curve below. Changing any of them switches to custom.';
    choice('effects','Animation curves','curveMode','Curve mode','individual',['general','individual'],true);
    rows[rows.length-1].description='General shapes every animation with one curve and one speed. Individual gives each animation its own curve and duration.';
    add('effects','Animation curves','generalCurve','All animations','curve','out-cubic',{options:curveNames(),advanced:true,when:{key:'curveMode',value:'general'},durationScaleKey:'durationScale'});
    range('effects','Animation curves','durationScale','Speed',1,.25,3,.05,'×',true);
    rows[rows.length-1].hidden=true;
    // Each curve row edits its duration too; the duration rows only normalize.
    animations().forEach(function(a) {
        range('effects','Animation curves',a.id+'Ms',a.title+' duration',a.ms,0,a.max,10,'ms',true);
        rows[rows.length-1].hidden=true;
        add('effects','Animation curves',a.id+'Curve',a.title,'curve',a.curve,{options:curveNames(),durationKey:a.id+'Ms',max:a.max,advanced:true,when:{key:'curveMode',value:'individual'}});
    });
    range('effects','Animation curves','zoomSmoothing','Smooth zoom response',.25,.05,1,.01,'',true);
    rows[rows.length-1].description='Fraction of the remaining zoom covered per frame. 1 is instant.';
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
    // Earlier surface styles fold into the closest current style.
    var legacyStyle={classic:'base',elevated:'base','high-contrast':'base'}[(raw.minimap||{}).style];
    if (legacyStyle) raw=Object.assign({},raw,{minimap:Object.assign({},raw.minimap,{style:legacyStyle})});
    // Animation durations and easing moved from minimap/overview to effects.
    var legacyOverview=raw.overview||{}, legacyMinimap=raw.minimap||{};
    raw=Object.assign({},raw,{effects:Object.assign({},raw.effects||{})});
    [['overviewMs',legacyOverview.animationMs],['switchMs',legacyOverview.switchMs],['minimapMs',legacyMinimap.motionMs],
        ['fadeMs',legacyMinimap.fadeMs],['overviewCurve',legacyOverview.easing],['switchCurve',legacyOverview.easing]].forEach(function(pair) {
        if (pair[1]===undefined || raw.effects[pair[0]]!==undefined) return;
        raw.effects[pair[0]]=pair[1];
        if (raw.effects.preset===undefined && pair[1]!==result.effects[pair[0]]) raw.effects.preset='custom';
    });
    fields().forEach(function(f) {
        var v=(raw[f.section]||{})[f.key];
        if (v===undefined) return;
        if (f.key==='compactDelayMs' && v<=0) v=5000;
        if (f.type==='color' && typeof v==='string' && (v==='' || /^#[0-9a-f]{6}$/i.test(v))) result[f.section][f.key]=v;
        if (f.type==='toggle' && typeof v==='boolean') result[f.section][f.key]=v;
        if (f.type==='range' && typeof v==='number' && isFinite(v)) result[f.section][f.key]=Math.max(f.min,Math.min(f.max,v));
        if (f.type==='choice' && f.options.indexOf(v)>=0) result[f.section][f.key]=v;
        if (f.type==='curve' && validCurve(v)) result[f.section][f.key]=v;
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

// Named animation curves as cubic beziers. Elastic and bounce are Qt easings
// with no bezier form; Hyprland falls back to the overshoot curve for them.
var CURVES = {"linear":[0,0,1,1],"out-cubic":[.33,1,.68,1],"in-out-cubic":[.65,0,.35,1],"out-quint":[.23,1,.32,1],
    "out-expo":[.16,1,.3,1],"in-out-sine":[.37,0,.63,1],"emphasized":[.2,0,0,1],"overshoot":[.34,1.56,.64,1],
    "elastic":null,"bounce":null};
function curveNames() { return Object.keys(CURVES); }
// A curve is a name from CURVES or a custom "bezier:x1,y1,x2,y2". Control
// point x stays in [0,1] so time never runs backwards; y may overshoot.
function customPoints(value) {
    var m = /^bezier:(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+)$/.exec(String(value));
    if (!m) return null;
    var p = m.slice(1).map(Number);
    if (p.some(function(n) { return !isFinite(n); }) || p[0] < 0 || p[0] > 1 || p[2] < 0 || p[2] > 1
        || p[1] < -1 || p[1] > 2 || p[3] < -1 || p[3] > 2) return null;
    return p;
}
function validCurve(value) { return CURVES.hasOwnProperty(value) || !!customPoints(value); }
// Control points of a curve, or null for elastic and bounce.
function curvePoints(value) {
    var custom = customPoints(value);
    if (custom) return custom;
    return CURVES.hasOwnProperty(value) ? CURVES[value] : CURVES["out-cubic"];
}
function curveValue(points) {
    return "bezier:" + points.map(function(n) { return Math.round(n*100)/100; }).join(",");
}
function bezier(name) {
    var p = curvePoints(name) || CURVES["overshoot"];
    return [p[0],p[1],p[2],p[3],1,1];
}
// Progress at time t for drawing; elastic and bounce match Qt's OutElastic
// (amplitude 1, period 0.3) and OutBounce.
function curveAt(value, t) {
    if (value === "elastic") return t <= 0 ? 0 : t >= 1 ? 1 : Math.pow(2, -10*t) * Math.sin((t - .075) * 2*Math.PI / .3) + 1;
    if (value === "bounce") {
        var n = 7.5625, d = 2.75;
        if (t < 1/d) return n*t*t;
        if (t < 2/d) { t -= 1.5/d; return n*t*t + .75; }
        if (t < 2.5/d) { t -= 2.25/d; return n*t*t + .9375; }
        t -= 2.625/d; return n*t*t + .984375;
    }
    var p = curvePoints(value);
    // Solve x(s) = t by bisection, then evaluate y(s).
    function axis(a, b, s) { return 3*a*s*(1-s)*(1-s) + 3*b*s*s*(1-s) + s*s*s; }
    var low = 0, high = 1, s = t;
    for (var i = 0; i < 30; i++) {
        s = (low + high) / 2;
        if (axis(p[0], p[2], s) < t) low = s; else high = s;
    }
    return axis(p[1], p[3], s);
}
function animations() {
    return [
        {id:"overview",title:"Overview open / close",ms:360,curve:"out-cubic",max:1500},
        {id:"switch",title:"Overview workspace switch",ms:360,curve:"out-cubic",max:1500},
        {id:"tiles",title:"Overview tile movement",ms:180,curve:"out-cubic",max:1000},
        {id:"compact",title:"Compaction",ms:300,curve:"out-cubic",max:1000},
        {id:"minimap",title:"Minimap movement",ms:300,curve:"out-cubic",max:1000},
        {id:"fade",title:"Minimap fade",ms:150,curve:"linear",max:1000},
        {id:"highlight",title:"Focus highlight",ms:140,curve:"linear",max:1000},
        {id:"camera",title:"Camera movement",ms:380,curve:"out-quint",max:1500},
        {id:"workspace",title:"Workspace slide",ms:350,curve:"out-quint",max:1500},
        {id:"launch",title:"Launch placeholder pulse",ms:1100,curve:"in-out-sine",max:3000},
        {id:"constellation",title:"Constellation focus travel",ms:450,curve:"in-out-cubic",max:1500}
    ];
}
var PRESETS = {
    smooth:{scale:1,zoom:.25},
    snappy:{scale:.55,zoom:.45,curve:"out-expo",fade:"out-cubic"},
    gentle:{scale:1.5,zoom:.15,curve:"in-out-sine",fade:"in-out-sine"},
    bouncy:{scale:1.2,zoom:.3,curve:"overshoot",fade:"out-cubic",highlight:"elastic"},
    instant:{scale:0,zoom:1}
};
function presetNames() { return Object.keys(PRESETS); }
function presetValues(name) {
    var preset = PRESETS[name];
    if (!preset) return null;
    // Presets always describe individual curves at normal speed.
    var result = {preset:name, zoomSmoothing:preset.zoom, curveMode:'individual', durationScale:1};
    animations().forEach(function(a) {
        // The launch pulse is feedback, not motion; it keeps a usable speed.
        var scale = a.id === "launch" ? Math.max(.6, preset.scale) : preset.scale;
        result[a.id+"Ms"] = Math.round(a.ms*scale/10)*10;
        var fading = a.id === "fade" || a.id === "highlight" || a.id === "launch";
        result[a.id+"Curve"] = a.id === "launch" ? a.curve
            : a.id === "highlight" && preset.highlight ? preset.highlight
            : fading ? preset.fade || a.curve : preset.curve || a.curve;
    });
    return result;
}

// Duration and curve an animation actually uses, honouring the curve mode.
function effective(effects, id) {
    var general = effects.curveMode === 'general';
    var scale = general ? Number(effects.durationScale) || 1 : 1;
    return {ms: Math.round((Number(effects[id+'Ms']) || 0) * scale),
        curve: general ? effects.generalCurve : effects[id+'Curve']};
}
