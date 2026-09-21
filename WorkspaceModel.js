.pragma library

// Always show 1–5, occupied workspaces, and this monitor's current workspace.
function ids(workspaces, currentId) {
    var result = [1, 2, 3, 4, 5];
    for (var i = 0; i < workspaces.length; i++) {
        var ws = workspaces[i];
        if (ws.id > 5 && ws.toplevels.values.length > 0 && result.indexOf(ws.id) === -1)
            result.push(ws.id);
    }
    if (currentId > 5 && result.indexOf(currentId) === -1) result.push(currentId);
    result.sort(function(a, b) { return a - b; });
    return result;
}
