.pragma library

// All coordinates are logical, monitor-local pixels. Fit the animated frame,
// not its destination, so resizing cannot overshoot the available space.
function fit(width, height, screenWidth, screenHeight, prefs, obstacle) {
    var right = prefs.corner.endsWith('right'), bottom = prefs.corner.startsWith('bottom');
    var margin = prefs.shadow || prefs.style === 'elevated' || prefs.style === 'glass' ? 28 : 6;
    var top = Math.max(margin, prefs.showWorkspace ? 22 : 0);
    var sx = Math.max(margin, Math.min(prefs.x, screenWidth - margin));
    var sy = Math.max(bottom ? margin : top, Math.min(prefs.y, screenHeight - (bottom ? top : margin)));
    function rect(scale) {
        var w = width * scale, h = height * scale;
        return {x:right ? screenWidth-sx-w : sx, y:bottom ? screenHeight-sy-h : sy, w:w, h:h, scale:scale};
    }
    if (prefs.placementMode !== 'fit') {
        return {x:right ? screenWidth-prefs.x-width : prefs.x,
            y:bottom ? screenHeight-prefs.y-height : prefs.y, w:width,h:height,scale:1,visible:true};
    }
    // Exact solution: each separation from the obstacle gives one upper bound.
    // Avoid 40 binary-search iterations and temporary rectangles on every frame.
    var w = Math.max(.001,width), h = Math.max(.001,height);
    var lo = Math.min((screenWidth-sx-margin)/w,
        (screenHeight-sy-(bottom ? top : margin))/h,
        (prefs.fitMaxWidth || 300)/w, (prefs.fitMaxHeight || 200)/h);
    if (obstacle && obstacle.w>0 && obstacle.h>0) {
        var ax = right ? screenWidth-sx : sx, ay = bottom ? screenHeight-sy : sy;
        var leftOf = right ? (ax+margin<=obstacle.x ? Infinity : -1) : (obstacle.x-ax-margin)/w;
        var rightOf = right ? (ax-margin-obstacle.x-obstacle.w)/w : (ax-margin>=obstacle.x+obstacle.w ? Infinity : -1);
        var above = bottom ? (ay+margin<=obstacle.y ? Infinity : -1) : (obstacle.y-ay-margin)/h;
        var below = bottom ? (ay-top-obstacle.y-obstacle.h)/h : (ay-top>=obstacle.y+obstacle.h ? Infinity : -1);
        lo = Math.min(lo,Math.max(leftOf,rightOf,above,below));
    }
    lo = Math.max(0,lo);
    var result = rect(lo);
    result.visible = lo > 0.0001 && lo+1e-9 >= prefs.hideBelow/100;
    return result;
}

// Focus identity and camera translation do not change the space needed by a
// same-sized tile. Retain the object too, so QML skips downstream fit bindings.
function stableObstacle(previous, next, sameWorkspace) {
    if (!next) return previous;
    if (previous && sameWorkspace && Math.abs(previous.w-next.w)<0.01 && Math.abs(previous.h-next.h)<0.01) return previous;
    return next;
}
