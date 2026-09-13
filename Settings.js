.pragma library
function defaults() {
    var shortcuts = {}
    shortcutRows().forEach(function(row) { shortcuts[row.id] = row.key })
    return {plugin:{enabled:true}, minimap:{enabled:true,corner:"top-left",x:12,y:52,opacity:0.72,width:220,height:140,lineWidth:1},
        overview:{animationMs:360,wallpaper:true,cardOpacity:0.82}, workflow:{mouseCooldownMs:550,focusMode:"auto",keepConnected:true,compactDelayMs:5000},
        shortcuts:shortcuts}
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
function normalize(raw) {
    var result = defaults()
    var ranges = {x:[0,240],y:[0,240],opacity:[0.1,1],width:[100,440],height:[60,280],lineWidth:[1,3],animationMs:[0,900],cardOpacity:[0.3,1],mouseCooldownMs:[0,1500],compactDelayMs:[100,30000]}
    Object.keys(result).forEach(function(section) {
        Object.keys(result[section]).forEach(function(key) {
            var v = raw && raw[section] ? raw[section][key] : undefined
            if (v === undefined) return
            if (key === "compactDelayMs" && typeof v === "number" && v <= 0) v = 5000
            if (section === "shortcuts") { if (typeof v === "string") result[section][key] = v }
            else if (key === "corner") { if (["top-left","top-right","bottom-left","bottom-right"].indexOf(v) >= 0) result[section][key] = v }
            else if (key === "focusMode") { if (v === "auto" || v === "click") result[section][key] = v }
            else if (typeof result[section][key] === "boolean") { if (typeof v === "boolean") result[section][key] = v }
            else if (typeof v === "number" && isFinite(v)) result[section][key] = Math.max(ranges[key][0],Math.min(ranges[key][1],v))
        })
    })
    return result
}
