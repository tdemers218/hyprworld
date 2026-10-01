import QtQuick
import qs.Commons
import "MinimapLayout.js" as MinimapLayout

// Minimap style that draws each window as a glowing star. Links form a
// spanning tree of the layout, and focus changes send the glow along it.
Canvas {
    id: sky
    // address -> {x, y}: live star positions in this item's coordinates.
    property var stars: ({})
    // address -> {x, y}: settled positions. Links use these so the tree does
    // not flicker while the minimap animates.
    property var layoutStars: ({})
    property string active: ""
    // Focus travel along the links, then the arrival glow fading in; both
    // follow the animation settings.
    property int travelMs: 450
    property int easingType: Easing.InOutCubic
    property var bezierCurve: []
    property int fadeMs: 140
    property int fadeEasingType: Easing.Linear
    property var fadeBezierCurve: []
    property color glow: Color.accent
    property color dim: Color.foreground

    readonly property var links: MinimapLayout.constellation(layoutStars)
    property var path: []
    property real travel: 1
    // 0: the previous star still glows, 1: the active star glows.
    property real fade: 1
    property string previous: ""
    property string lastActive: ""

    SequentialAnimation {
        id: focusAnimation
        NumberAnimation {
            target: sky; property: "travel"; from: 0; to: 1
            duration: sky.path.length > 1 ? sky.travelMs : 0
            easing.type: sky.easingType; easing.bezierCurve: sky.bezierCurve
        }
        NumberAnimation {
            target: sky; property: "fade"; from: 0; to: 1
            duration: sky.fadeMs; easing.type: sky.fadeEasingType; easing.bezierCurve: sky.fadeBezierCurve
        }
        onFinished: { sky.path = []; sky.previous = "" }
    }
    onActiveChanged: {
        previous = lastActive
        lastActive = active
        var route = previous && active && previous !== active && travelMs > 0 && stars[previous]
            ? MinimapLayout.constellationPath(links, previous, active) : []
        path = route.length > 1 ? route : []
        focusAnimation.stop()
        travel = path.length > 1 ? 0 : 1
        fade = previous && previous !== active && fadeMs > 0 ? 0 : 1
        if (path.length > 1 || fade < 1) focusAnimation.start()
        requestPaint()
    }
    onFadeChanged: requestPaint()
    onStarsChanged: requestPaint()
    onTravelChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    function rgba(c, a) { return "rgba(" + Math.round(c.r*255) + "," + Math.round(c.g*255) + "," + Math.round(c.b*255) + "," + a + ")" }
    // Point at `fraction` of the polyline through `ids`, plus the vertices passed.
    function along(ids, fraction) {
        var points = ids.map(function(id) { return stars[id] }).filter(function(p) { return !!p })
        if (points.length < 2) return null
        var lengths = [], total = 0
        for (var i = 1; i < points.length; i++) {
            var d = Math.hypot(points[i].x-points[i-1].x, points[i].y-points[i-1].y)
            lengths.push(d); total += d
        }
        var remaining = Math.max(0, Math.min(1, fraction)) * total, trail = [points[0]]
        for (var j = 0; j < lengths.length; j++) {
            if (remaining <= lengths[j] || j === lengths.length-1) {
                var t = lengths[j] > 0 ? Math.min(1, remaining/lengths[j]) : 1
                var p = {x: points[j].x + (points[j+1].x-points[j].x)*t, y: points[j].y + (points[j+1].y-points[j].y)*t}
                trail.push(p)
                return {point: p, trail: trail}
            }
            remaining -= lengths[j]
            trail.push(points[j+1])
        }
        return null
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.lineWidth = 1
        ctx.strokeStyle = rgba(glow, .32)
        ctx.shadowColor = rgba(glow, .6)
        ctx.shadowBlur = 4
        links.forEach(function(link) {
            var a = stars[link[0]], b = stars[link[1]]
            if (!a || !b) return
            ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke()
        })
        var orb = path.length > 1 && travel < 1 ? along(path, travel) : null
        if (orb) {
            // The links already travelled light up behind the glow.
            ctx.lineWidth = 2
            ctx.strokeStyle = rgba(glow, .85)
            ctx.shadowColor = glow
            ctx.shadowBlur = 10
            ctx.beginPath()
            ctx.moveTo(orb.trail[0].x, orb.trail[0].y)
            for (var i = 1; i < orb.trail.length; i++) ctx.lineTo(orb.trail[i].x, orb.trail[i].y)
            ctx.stroke()
        }
        Object.keys(stars).forEach(function(id) {
            var star = stars[id]
            // The departing star dims as the glow leaves it; the active star
            // lights up once the glow arrives.
            var level = id === active ? (orb ? 0 : fade)
                : id === previous ? (path.length > 1 ? Math.max(0, 1 - travel*4) : 1 - fade) : 0
            ctx.beginPath()
            ctx.fillStyle = rgba(dim, .7)
            ctx.shadowColor = rgba(dim, .8)
            ctx.shadowBlur = 5
            ctx.arc(star.x, star.y, 2.4 + 1.6*level, 0, 2*Math.PI)
            ctx.fill()
            if (level > 0) {
                ctx.beginPath()
                ctx.fillStyle = rgba(glow, level)
                ctx.shadowColor = rgba(glow, level)
                ctx.shadowBlur = 5 + 9*level
                ctx.arc(star.x, star.y, 2.4 + 1.6*level, 0, 2*Math.PI)
                ctx.fill()
            }
        })
        if (orb) {
            ctx.beginPath()
            ctx.fillStyle = rgba(glow, .25)
            ctx.shadowBlur = 0
            ctx.arc(orb.point.x, orb.point.y, 8, 0, 2*Math.PI)
            ctx.fill()
            ctx.beginPath()
            ctx.fillStyle = rgba(glow, 1)
            ctx.shadowColor = glow
            ctx.shadowBlur = 18
            ctx.arc(orb.point.x, orb.point.y, 4, 0, 2*Math.PI)
            ctx.fill()
        }
    }
}
