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
