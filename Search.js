// Shared by the overview and Node regression tests. Metadata is plain text.
function flatten(value) {
    if (value === null || value === undefined) return "";
    if (typeof value !== "object") return String(value);
    return Object.keys(value).map(function(key) { return key + " " + flatten(value[key]); }).join(" ");
}
function normalize(value) {
    return String(value).normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}
function fields(value) {
    if (value === null || value === undefined) return [];
    if (typeof value !== "object") return [normalize(value)];
    var result = [];
    Object.keys(value).forEach(function(key) { result = result.concat(fields(value[key])); });
    return result;
}
function termScore(term, haystack) {
    var direct = haystack.indexOf(term);
    if (direct >= 0) return direct / 10000;
    var cursor = 0, first = -1, last = 0;
    for (var i = 0; i < term.length; i++) {
        var found = haystack.indexOf(term[i], cursor);
        if (found < 0) return -1;
        if (first < 0) first = found;
        last = found; cursor = found + 1;
    }
    return 1 + (last - first - term.length + 1) / Math.max(1, haystack.length);
}
function score(query, value) {
    var values = fields(value);
    var terms = normalize(query).trim().split(/\s+/).filter(Boolean);
    var total = 0;
    for (var t = 0; t < terms.length; t++) {
        var best = Infinity;
        values.forEach(function(value) {
            var score = termScore(terms[t], value);
            if (score >= 0) best = Math.min(best, score);
        });
        if (best === Infinity) return -1;
        total += best;
    }
    return total;
}
function rank(query, windows) {
    return windows.map(function(window, index) { return {window:window, score:score(query,window), index:index}; })
        .filter(function(result) { return result.score >= 0; })
        .sort(function(a,b) { return a.score-b.score || a.index-b.index; })
        .map(function(result) { return result.window; });
}
// Desktop apps that match the query and have no open window. Only direct
// substring matches of two or more characters count, so a short query does
// not offer unrelated apps.
function launchable(query, apps, windows, limit) {
    if (String(query || "").trim().length < 2) return [];
    var open = {};
    windows.forEach(function(w) {
        [w.class, w.initialClass].forEach(function(c) { if (c) open[normalize(c)] = true; });
    });
    function isOpen(app) {
        var id = String(app.id || "");
        return [app.startupClass, id, id.split(".").pop()].some(function(key) { return key && open[normalize(key)]; });
    }
    return apps.filter(function(app) { return app && app.id && !isOpen(app); })
        .map(function(app, index) {
            return {app:app, index:index, score:score(query, {name:app.name, genericName:app.genericName, keywords:app.keywords, id:app.id})};
        })
        .filter(function(result) { return result.score >= 0 && result.score < 1; })
        .sort(function(a,b) { return a.score-b.score || a.index-b.index; })
        .slice(0, limit || 4)
        .map(function(result) { return result.app; });
}
// Short labels for window states worth noticing; ordinary windows get none.
function details(window) {
    if (!window) return [];
    var result = [];
    if (window.fullscreen) result.push("Fullscreen");
    if (window.floating) result.push("Floating");
    if (window.pinned) result.push("Pinned");
    if (Array.isArray(window.grouped) && window.grouped.length > 1) result.push("Tabbed ×" + window.grouped.length);
    if (window.contentType === "video") result.push("Video");
    else if (window.contentType === "game") result.push("Game");
    if (window.inhibitingIdle) result.push("Keeping awake");
    if (window.hidden) result.push("Hidden");
    if (window.xwayland) result.push("XWayland");
    return result;
}
