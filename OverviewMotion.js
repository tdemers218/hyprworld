.pragma library

// Preserve the currently painted frame when navigation interrupts a slide.
// Metadata objects are immutable snapshots, so no deep copies are needed.
function outgoing(cards, previous, progress, dx, dy) {
    var result=[];
    previous.forEach(function(card) {
        var opacity=card.opacity*progress;
        if (opacity>.02) result.push(Object.assign({},card,{opacity:opacity,
            x:card.x-dx*(1-progress),y:card.y-dy*(1-progress)}));
    });
    cards.forEach(function(card) {
        if (1-progress>.02) result.push(Object.assign({},card,{opacity:1-progress,
            x:card.x+dx*progress,y:card.y+dy*progress}));
    });
    // Rapid repeated navigation must not accumulate an unbounded scene graph.
    return result.slice(-500);
}

// Linear time for one element of the overview transition. Elements start
// `delay` (0..1) of the way through the cascade window and all finish together,
// so the cascade never lengthens the configured duration.
function phase(linear, delay, cascade) {
    var span = 1 - cascade;
    var t = span > 0 ? (linear - delay*cascade) / span : linear;
    return Math.max(0, Math.min(1, t));
}
// Cascade delays from the selected tile outward: {address: 0..1}.
function cascadeDelays(tiles) {
    var origin = tiles.find(function(t) { return t.active; }) || tiles[0], result = {}, reach = 0;
    if (!origin) return result;
    tiles.forEach(function(t) { reach = Math.max(reach, Math.hypot(t.col - origin.col, t.row - origin.row)); });
    tiles.forEach(function(t) { result[t.address] = reach > 0 ? Math.hypot(t.col - origin.col, t.row - origin.row) / reach : 0; });
    return result;
}
