.pragma library

// One bounded in-flight snapshot. A newer frame replaces incomplete fragments;
// the recovery poll remains available if the event connection drops a fragment.
function accept(state, message, kind) {
    var prefix = "hyprworld-" + (kind || "preview")
    var full = prefix + ",", fragmented = prefix + "-part,"
    if (message.startsWith(full)) return message.slice(full.length)
    if (!message.startsWith(fragmented)) return null
    var match = message.slice(fragmented.length).match(/^([^,]+),(\d+),(\d+),(\d+),([\s\S]*)$/)
    if (!match) return null
    var key = match[1] + ":" + match[2], index = Number(match[3]), count = Number(match[4])
    if (count < 1 || count > 512 || index < 1 || index > count || match[5].length > 900) return null
    if (state.key !== key || state.count !== count) {
        state.key = key; state.count = count; state.received = 0; state.parts = []
    }
    if (state.parts[index - 1] === undefined) state.received++
    state.parts[index - 1] = match[5]
    if (state.received !== count) return null
    var result = state.parts.join("")
    state.key = null; state.parts = []; state.received = 0
    return result
}
