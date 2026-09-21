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
