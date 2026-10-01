import qs.Commons
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Settings.js" as Settings
import "Search.js" as Search
import "MinimapLayout.js" as MinimapLayout
import "OverviewMotion.js" as OverviewMotion
import "PreviewStream.js" as PreviewStream

Item {
    id: root
    property var snapshot: ({})
    OverlayState { id: overlayState }
    property string searchQuery: ""
    property int searchIndex: 0
    property var ipcWindows: []
    // Full `hyprctl clients` objects carry state that toplevel IPC snapshots may lack.
    readonly property var ipcByAddress: {
        var map = {}
        ipcWindows.forEach(function(w) { if (w && w.address) map[w.address] = w })
        return map
    }
    readonly property var searchWindows: {
        var windows = [], seen = {}
        Hyprland.toplevels.values.forEach(function(t) {
            var data = t.lastIpcObject || {}
            if (!data.address) return
            var copy = Object.assign({}, data, root.ipcByAddress[data.address] || {})
            copy.application = root.app(data).name
            windows.push(copy); seen[data.address] = true
        })
        ipcWindows.forEach(function(data) {
            if (!data.address || seen[data.address]) return
            var copy = Object.assign({}, data)
            copy.application = root.app(data).name
            windows.push(copy); seen[data.address] = true
        })
        root.tiles.forEach(function(t) {
            if (!seen[t.address]) windows.push(Object.assign({}, t, {workspace:{id:root.snapshot.workspaceId}, application:root.app(t).name}))
        })
        // Equal search scores keep the most recently focused window first.
        function recency(w) { return typeof w.focusHistoryID === "number" && w.focusHistoryID >= 0 ? w.focusHistoryID : 1e6 }
        return windows.sort(function(a, b) { return recency(a) - recency(b) })
    }
    readonly property var searchResults: Search.rank(searchQuery, searchWindows.filter(function(w) {
        return preferences.overview.searchScope!=="workspace" || (w.workspace && w.workspace.id===snapshot.workspaceId)
    }).map(function(w) {
        return preferences.overview.searchMetadata ? w : {address:w.address,class:w.class,title:w.title,workspace:w.workspace,application:w.application}
    }))
    readonly property var launchEntries: {
        var entries = DesktopEntries.applications.values, result = []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.noDisplay) continue
            result.push({id:String(e.id), name:e.name, genericName:e.genericName, keywords:e.keywords,
                startupClass:e.startupClass, icon:e.icon})
        }
        return result
    }
    readonly property var launchResults: preferences.overview.launchApps
        ? Search.launchable(searchQuery, launchEntries, searchWindows, 4) : []
    // Windows first, then installed apps that have no window yet.
    readonly property var resultItems: searchResults.map(function(w) { return {kind:"window", window:w} })
        .concat(launchResults.map(function(a) { return {kind:"app", app:a} }))
    onSearchQueryChanged: searchIndex = 0
    onResultItemsChanged: searchIndex = Math.max(0, Math.min(searchIndex, resultItems.length-1))
    onOverviewChanged: {
        scheduleCommit()
        if (!overview) searchQuery = ""
        else if (!clientsReader.running) clientsReader.running = true
    }
    function launchApp(app) {
        if (!app || !app.id) return
        // Dismiss rather than close: closing re-focuses the old selection,
        // which would steal focus from the window that is about to open.
        command("overview-dismiss")
        // The layout predicts the new window's box; see launchBox below.
        var serial = snapshot.launchSerial || 0
        if (tiles.length) command("launch-preview")
        // Same launch path as the Omarchy app launcher; the window opens on
        // the active workspace, which is the one this overview shows.
        Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", app.id + ".desktop"])
        var known = {}
        Hyprland.toplevels.values.forEach(function(t) { if (t.address) known[root.addressKey(t.address)] = true })
        launchInfo = {name: app.name || app.id, icon: app.icon, known: known, started: Date.now(), serial: serial}
        launching = true
        launchWatch.restart()
    }
    // Placeholder shown until the launched app maps any new window.
    property bool launching: false
    property var launchInfo: ({})
    // Only a prediction requested by this launch counts; older ones are stale.
    readonly property var launchBox: launching && snapshot.launchBox && (snapshot.launchSerial || 0) > launchInfo.serial ? snapshot.launchBox : null
    function addressKey(address) { return String(address || "").toLowerCase().replace(/^0x/, "") }
    Timer {
        id: launchWatch
        interval: 150; repeat: true
        onTriggered: {
            var info = root.launchInfo
            var mapped = Hyprland.toplevels.values.some(function(t) { return t.address && !info.known[root.addressKey(t.address)] })
            var expired = Date.now() - info.started > 20000
            if (!root.launching || mapped || root.overview || expired) {
                // Nothing opened: return the camera from the empty slot.
                if (expired && !mapped && root.launching && root.tiles.length) root.command("follow launch-expired")
                // Reopening the overview first must also end the layout's guard.
                else if (!mapped && root.launching && root.overview) root.command("launch-cancel")
                root.launching = false; stop()
            }
        }
    }
    function selectSearchResult(index) {
        var item = resultItems[index]
        if (item && item.kind === "app") { launchApp(item.app); return }
        var w = item && item.window
        if (!w || !/^0x[0-9a-f]+$/i.test(w.address)) return
        var ws = Number(w.workspace && w.workspace.id)
        var workspaceName = String((w.workspace && w.workspace.name) || "")
        var special = workspaceName.match(/^special:([A-Za-z0-9_.-]+)$/)
        // A window in this overview uses the layout's own select + commit path.
        if (!special && ws === snapshot.workspaceId && tiles.some(function(t) { return t.address === w.address })) {
            command("overview-select " + w.address); return
        }
        // Elsewhere: release the keyboard, switch workspace, then focus once
        // the layer no longer holds exclusive focus (Hyprland refuses before).
        locallyDismissed = true
        var code = "__hyprworld_set_overview(false); "
        if (special) code += "hl.dispatch(hl.dsp.workspace.toggle_special(" + JSON.stringify(special[1]) + "))"
        else if (ws > 0 && Number.isInteger(ws)) code += "__hyprworld_workspace_nav.select(" + ws + ")"
        Quickshell.execDetached(["timeout", "--kill-after=1s", "5s", "hyprctl", "eval", code])
        focusRetry.address = w.address; focusRetry.attempts = 0; focusRetry.restart()
    }
    function sameAddress(a, b) { return addressKey(a) === addressKey(b) }
    Timer {
        id: focusRetry
        property string address: ""
        property int attempts: 0
        interval: 80; repeat: true
        onTriggered: {
            var active = Hyprland.activeToplevel
            if (!address || root.overview || attempts >= 12 || (active && root.sameAddress(active.address, address))) { stop(); return }
            if (root.transitioning) return
            attempts++
            Hyprland.dispatch('hl.dsp.focus({window="address:' + address + '"})')
        }
    }
    property bool pushAvailable: false
    property var previewStream: ({})
    property var dragStream: ({})
    property var gestureFrame: ({})
    function acceptGesture(next) {
        if (next.epoch && next.epoch === gestureFrame.epoch && next.revision <= gestureFrame.revision) return
        gestureFrame = {epoch:next.epoch, revision:next.revision, gesture:next.gesture,
            monitor:next.monitor, monitorX:next.monitorX, monitorY:next.monitorY}
    }
    property bool compactAnimating: false
    Timer { id: compactAnimation; interval: root.anim("compact").ms + 20; onTriggered: root.compactAnimating=false }
    signal changingSnapshot(var next)
    ListModel { id: tileModel; dynamicRoles: true }
    function acceptSnapshot(next) {
        if (next.epoch && next.epoch===snapshot.epoch && next.revision<=snapshot.revision) return
        acceptGesture(next)
        if (next.workspaceId===snapshot.workspaceId && next.epoch===snapshot.epoch && (next.compactSerial || 0)!==(snapshot.compactSerial || 0)) {
            compactAnimating=true; compactAnimation.restart()
        }
        locallyDismissed = false
        changingSnapshot(next)
        var tiles=Array.isArray(next.tiles) ? next.tiles : []
        var wanted={}
        tiles.forEach(function(t) { wanted[t.address]=true })
        for (var i=tileModel.count-1;i>=0;i--) if (!wanted[tileModel.get(i).tileData.address]) tileModel.remove(i)
        var indices={}
        for (var i=0;i<tileModel.count;i++) indices[tileModel.get(i).tileData.address]=i
        tiles.forEach(function(t) {
            var signature=JSON.stringify(t)
            var index=indices[t.address]
            if (index!==undefined) {
                if (tileModel.get(index).signature!==signature) tileModel.set(index,{tileData:t,signature:signature})
                return
            }
            tileModel.append({tileData:t,signature:signature})
        })
        snapshot=next
    }
    function navigateOverview(event) {
                        var directions = {}; directions[Qt.Key_Left] = "left"; directions[Qt.Key_Right] = "right"
                        directions[Qt.Key_Up] = "up"; directions[Qt.Key_Down] = "down"
                        if (!directions[event.key]) return false
                        var direction = directions[event.key]
                        if ((event.modifiers & Qt.ControlModifier) && (direction === "left" || direction === "right")) root.switchWorkspace(direction === "right" ? 1 : -1)
                        else if (event.modifiers & Qt.ShiftModifier) root.command("move " + direction)
                        else if (event.modifiers & Qt.AltModifier) root.command("resize " + direction)
                        else if (event.modifiers & Qt.ControlModifier) {
                            root.command(direction === "up" ? "zoom in" : direction === "down" ? "zoom out" : "pan " + direction)
                        } else root.command("focus " + direction)
                        event.accepted = true
                        return true
    }
    function switchWorkspace(direction) {
        Quickshell.execDetached(["timeout", "--kill-after=1s", "5s", "hyprctl","eval","if __hyprworld_workspace_nav then __hyprworld_workspace_nav.step("+direction+") end"])
    }
    readonly property var gesture: gestureFrame.gesture || ({})
    readonly property bool gesturing: !!gesture.mode
    readonly property var tiles: Array.isArray(snapshot.tiles) ? snapshot.tiles : []
    property bool locallyDismissed: false
    readonly property bool overview: !locallyDismissed && preferences.plugin.enabled && snapshot.overview === true
    readonly property string commitAddress: snapshot.commitAddress || ""
    readonly property bool hasGroups: tiles.some(function(tile) { return tile.part && tile.part.count > 1 })
    // commitAddress and overview both derive from the snapshot and notify in
    // either order, so check again whenever either one changes.
    function scheduleCommit() {
        if (!commitAddress || overview || commitTimer.running) return
        commitTimer.attempts = 0
        commitTimer.restart()
    }
    onCommitAddressChanged: scheduleCommit()
    // Focus only after the layer has released exclusive keyboard ownership.
    // Hyprland refuses focus while the layer still holds the keyboard, so the
    // adapter keeps the selection pending and this retries until it lands.
    Timer {
        id: commitTimer
        property int attempts: 0
        interval: attempts === 0 ? root.overviewDuration + 20 : 60
        repeat: true
        onTriggered: {
            if (!root.commitAddress || root.overview || attempts >= 8) { stop(); return }
            if (root.transitioning) return
            attempts++
            root.command("overview-commit " + root.commitAddress)
        }
    }
    readonly property bool minimap: preferences.plugin.enabled && preferences.minimap.enabled && (!preferences.minimap.hideFullscreen || !overlayState.fullscreenActive) && tiles.length > (preferences.minimap.hideSingle ? 1 : 0) && !overview && (!preferences.minimap.hideMaxZoom || snapshot.zoom < snapshot.maxZoom)
    property real minimapProgress: minimap ? 1 : 0
    readonly property bool animationsEnabled: preferences.effects.animations
    readonly property bool overviewAnimations: animationsEnabled && !preferences.overview.reducedMotion
    // Durations and curves for every animation live in the effects settings.
    readonly property var fx: preferences.effects
    function easingType(curve) { return curve === "elastic" ? Easing.OutElastic : curve === "bounce" ? Easing.OutBounce : Easing.BezierSpline }
    function easingCurve(curve) { return Settings.bezier(curve) }
    // Duration and curve an animation uses under the current curve mode.
    function anim(id) { return Settings.effective(fx, id) }
    Behavior on minimapProgress { NumberAnimation { duration: root.animationsEnabled ? root.anim("fade").ms : 0; easing.type: root.easingType(root.anim("fade").curve); easing.bezierCurve: root.easingCurve(root.anim("fade").curve) } }
    readonly property int overviewDuration: overviewAnimations ? anim("overview").ms : 0
    onAnimationsEnabledChanged: effectsTimer.restart()
    // Hyprland's workspace slide and camera movement follow the saved durations and curves.
    readonly property string workspaceEffect: [anim("workspace").ms, anim("workspace").curve, anim("camera").ms, anim("camera").curve].join(":")
    onWorkspaceEffectChanged: effectsTimer.restart()
    Timer { id:effectsTimer; interval:100; onTriggered: effectsSync.running=true }
    Process {
        id:effectsSync
        command:["timeout", "--kill-after=1s", "5s", "hyprctl","eval","if __hyprworld_apply_effects then __hyprworld_apply_effects("+(root.animationsEnabled ? "true" : "false")+") end"]
    }
    property bool pending: false
    // The transition runs on linear time; each element applies the overview
    // curve to its own phase, so cascades and staged fades keep the curve.
    // A four-finger swipe drives the timeline directly (swipeValue 0..1); on
    // release it animates on from the finger position to open or closed.
    property real swipeValue: -1
    property bool swipeHeld: false
    property real overviewLinear: swipeValue >= 0 ? swipeValue : (overview ? 1 : 0)
    Behavior on overviewLinear { enabled: !root.swipeHeld; NumberAnimation { duration: root.overviewDuration } }
    function acceptOverviewSwipe(value) {
        if (value >= 0) { swipeHeld = true; swipeValue = value }
        // Re-enable the animation before releasing, so the rest is animated.
        else { swipeHeld = false; swipeValue = -1 }
    }
    function ease(curve, t) { return t <= 0 ? 0 : t >= 1 ? 1 : Settings.curveAt(curve, t) }
    function overviewEase(t) { return ease(anim("overview").curve, t) }
    readonly property real overviewProgress: overviewEase(overviewLinear)
    readonly property bool transitioning: overview || overviewLinear > 0.001
    readonly property real cascade: overviewAnimations ? preferences.overview.cascade : 0
    readonly property var cascadeDelays: OverviewMotion.cascadeDelays(tiles)
    function cascadePhase(delay) { return OverviewMotion.phase(overviewLinear, delay, cascade) }
    // Header and arrows follow shortly after the first cards.
    readonly property real headerIn: overviewEase(OverviewMotion.phase(overviewLinear, 0.35, overviewAnimations ? 0.3 : 0))
    readonly property real headerShift: overviewAnimations ? 1 - headerIn : 0
    property string wallpaper: ""
    property var preferences: Settings.defaults()
    FileView {
        id: preferencesFile
        path: Quickshell.env("HOME") + "/.config/omarchy/hyprworld.json"
        watchChanges: true
        printErrors: false
        onLoaded: { try { root.preferences = Settings.normalize(JSON.parse(text())) } catch (e) {} }
        onFileChanged: reload()
    }
    Process {
        id: wallpaperReader
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
        stdout: StdioCollector { onStreamFinished: root.wallpaper = text.trim() }
    }
    Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!wallpaperReader.running) wallpaperReader.running = true }

    function refresh(recovery) {
        // Drag frames arrive through custom events. Suppress event-triggered
        // queries during gestures while allowing the low-rate recovery timer.
        if (root.gesturing && !recovery) return
        if (reader.running) { pending = true; return }
        reader.running = true
    }
    function command(message) {
        // Always relinquish exclusive keyboard focus even when compositor IPC fails.
        var closing = message === "overview-close" || message === "overview-dismiss"
        if (closing) locallyDismissed = true
        if (closing && tiles.length === 0) {
            Quickshell.execDetached(["timeout", "--kill-after=1s", "5s", "hyprctl","eval","if __hyprworld_set_overview then __hyprworld_set_overview(false) end"])
            refreshTimer.restart(); return
        }
        Hyprland.dispatch("hl.dsp.layout(" + JSON.stringify(message) + ")")
        refreshTimer.restart()
    }
    readonly property var appIndex: {
        var index={}
        var entries = DesktopEntries.applications.values
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            var keys=[String(e.id).toLowerCase(),String(e.startupClass || "").toLowerCase(),String(e.name).toLowerCase()]
            keys.forEach(function(key) { if (index[key]===undefined) index[key]={name:e.name,icon:e.icon} })
        }
        return index
    }
    function app(tile) {
        return appIndex[String(tile.class || "").toLowerCase()] || {name: tile.class || "Application", icon: tile.class || "application-x-executable"}
    }
    function bounds() {
        var minC = 0, maxC = 0, minR = 0, maxR = 0
        if (tiles.length) { minC = maxC = tiles[0].col; minR = maxR = tiles[0].row }
        for (var i = 0; i < tiles.length; i++) {
            minC = Math.min(minC, tiles[i].col); maxC = Math.max(maxC, tiles[i].col)
            minR = Math.min(minR, tiles[i].row); maxR = Math.max(maxR, tiles[i].row)
        }
        return {col: minC, row: minR, cols: maxC-minC+1, rows: maxR-minR+1}
    }
    readonly property var extent: bounds()
    function layoutBounds() {
        var first = null
        for (var i = 0; i < tiles.length; i++) {
            var box = tiles[i].box
            if (!box) continue
            if (!first) first = {x: Number(box.x), y: Number(box.y), right: Number(box.x) + Number(box.w), bottom: Number(box.y) + Number(box.h)}
            else {
                first.x = Math.min(first.x, Number(box.x)); first.y = Math.min(first.y, Number(box.y))
                first.right = Math.max(first.right, Number(box.x) + Number(box.w))
                first.bottom = Math.max(first.bottom, Number(box.y) + Number(box.h))
            }
        }
        if (!first) return {x: 0, y: 0, w: 1, h: 1}
        return {x: first.x, y: first.y, w: Math.max(1, first.right-first.x), h: Math.max(1, first.bottom-first.y)}
    }
    readonly property var mapBounds: layoutBounds()
    readonly property real mapScale: Math.min(preferences.minimap.width / mapBounds.w, preferences.minimap.height / mapBounds.h)
    MinimapMotion {
        id: minimapMotion
        duration: root.animationsEnabled && !root.transitioning && root.minimap ? root.anim("minimap").ms : 0
        easingType: root.easingType(root.anim("minimap").curve); bezierCurve: root.easingCurve(root.anim("minimap").curve)
        workspace: root.snapshot.monitor + ":" + root.snapshot.workspaceId
        targetFrame: {
            var rects={}
            root.tiles.forEach(function(tile) {
                if (tile.box) rects[tile.address]={
                    x:(tile.box.x-root.mapBounds.x)*root.mapScale,
                    y:(tile.box.y-root.mapBounds.y)*root.mapScale,
                    w:Math.max(2,tile.box.w*root.mapScale),h:Math.max(2,tile.box.h*root.mapScale)}
            })
            return {width:root.mapBounds.w*root.mapScale,height:root.mapBounds.h*root.mapScale,tiles:rects}
        }
    }
    readonly property real mapWidth: minimapMotion.frame.width
    readonly property real mapHeight: minimapMotion.frame.height
    Timer { id: refreshTimer; interval: 35; onTriggered: root.refresh() }
    // Once the event bridge is live, this is only a low-rate recovery poll.
    // Keep recovery polling even during a gesture: a lost release event must
    // not leave the preview permanently stuck. Ordinary drag events never poll.
    Timer { interval: root.pushAvailable || root.gesturing ? 2000 : 400; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh(true) }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data.startsWith("hyprworld-overview-swipe,")) {
                var value = Number(event.data.slice("hyprworld-overview-swipe,".length))
                if (isFinite(value)) root.acceptOverviewSwipe(value)
                return
            }
            if (event.name === "custom" && (event.data.startsWith("hyprworld-drag,") || event.data.startsWith("hyprworld-drag-part,"))) {
                try {
                    var frame = PreviewStream.accept(root.dragStream, event.data, "drag")
                    if (frame !== null) { root.acceptGesture(JSON.parse(frame)); root.pushAvailable = true }
                } catch (e) { /* The bounded recovery poll repairs a lost frame. */ }
                return
            }
            if (event.name === "custom" && (event.data.startsWith("hyprworld-preview,") || event.data.startsWith("hyprworld-preview-part,"))) {
                try {
                    var payload = PreviewStream.accept(root.previewStream, event.data)
                    if (payload === null) return
                    root.acceptSnapshot(JSON.parse(payload))
                    root.pushAvailable=true
                    refreshTimer.stop()
                    root.pending=false
                } catch (e) { root.refresh() }
                return
            }
            if (event.name === "custom") return
            if (event.name === "configreloaded") root.pushAvailable=false
            if (!refreshTimer.running) refreshTimer.start()
        }
    }
    Process {
        id: reader
        command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "repl", "return __hyprworld_preview and __hyprworld_preview() or '{}' "]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.acceptSnapshot(JSON.parse(text.trim())) } catch (e) { /* Keep the last valid frame. */ }
            }
        }
        onRunningChanged: if (!running && root.pending) { root.pending = false; refreshTimer.restart() }
    }
    Process {
        id: clientsReader
        command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ipcWindows = JSON.parse(text.trim()) } catch (e) { root.ipcWindows = [] }
            }
        }
    }
    Timer { interval: 750; repeat: true; running: root.overview; onTriggered: if (!clientsReader.running) clientsReader.running = true }
    // The same click-through surface draws local and cross-monitor drag hints.
    // Its geometry stream is independent of the minimap's full workspace model.
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: transferPanel
                required property var modelData
                readonly property var drop: root.gesture.drop || ({})
                readonly property var box: root.gesture.ghost || ({x:0,y:0,w:0,h:0})
                readonly property bool sourceMonitor: root.gestureFrame.monitor === modelData.name
                readonly property real originX: sourceMonitor ? (root.gestureFrame.monitorX || 0) : (drop.monitorX || 0)
                readonly property real originY: sourceMonitor ? (root.gestureFrame.monitorY || 0) : (drop.monitorY || 0)
                screen: modelData
                visible: !overlayState.screensaverActive && root.gesture.mode === "move" && !!root.gesture.ghost && (sourceMonitor || drop.monitor === modelData.name)
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "hyprworld-transfer-preview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {}
                Rectangle {
                    id: transferOutline
                    x: transferPanel.box.x-transferPanel.originX
                    y: transferPanel.box.y-transferPanel.originY
                    width: transferPanel.box.w; height: transferPanel.box.h; radius: 10
                    color: Util.alpha(Color.accent, transferPanel.sourceMonitor ? 0.08 : 0.12)
                    border.color: Color.accent; border.width: transferPanel.sourceMonitor ? 2 : 3
                }
                Rectangle {
                    visible: !transferPanel.sourceMonitor
                    x: Math.max(12, Math.min(transferOutline.x+(transferOutline.width-width)/2, transferPanel.width-width-12))
                    y: Math.max(12, Math.min(transferOutline.y+20, transferPanel.height-height-12))
                    width: Math.min(transferLabel.implicitWidth+28, transferPanel.width-24)
                    height: 38; radius: 8
                    color: Color.background; border.color: Color.accent; border.width: 1
                    Text {
                        id: transferLabel
                        anchors.fill: parent; anchors.margins: 8
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: transferPanel.drop.label || ""
                        elide: Text.ElideRight
                        color: Color.foreground; font.pixelSize: 14; font.bold: true
                    }
                }
                Rectangle {
                    readonly property var box: transferPanel.drop.box || ({x:0,y:0,w:0,h:0})
                    visible: transferPanel.sourceMonitor && !!transferPanel.drop.box
                    x: box.x-transferPanel.originX; y: box.y-transferPanel.originY
                    width: box.w; height: box.h; radius: 10
                    color: Util.alpha(Color.accent, 0.18)
                    border.color: Color.accent; border.width: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: dropLabel.implicitWidth+28; height: 38; radius: 8
                        color: Color.background; border.color: Color.accent; border.width: 1
                        Text { id: dropLabel; anchors.centerIn: parent; text: transferPanel.drop.label || ""; color: Color.foreground; font.pixelSize: 14; font.bold: true }
                    }
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panel
                property var outgoing: []
                property real workspaceSlide: 0
                property real slideDirection: 1
                property real slideDirectionY: 0
                NumberAnimation { id: slideAnimation; target: panel; property: "workspaceSlide"; from: 1; to: 0; duration: root.overviewAnimations ? root.anim("switch").ms : 0; easing.type: root.easingType(root.anim("switch").curve); easing.bezierCurve: root.easingCurve(root.anim("switch").curve); onFinished: panel.outgoing=[] }
                Connections {
                    target:root
                    function onOverviewAnimationsChanged() {
                        if (!root.overviewAnimations) { slideAnimation.stop(); panel.workspaceSlide=0; panel.outgoing=[] }
                    }
                }
                Connections {
                    target: root
                    function onChangingSnapshot(next) {
                        if (!root.overview || !next.overview || next.monitor!==panel.modelData.name || root.snapshot.monitor!==next.monitor || next.workspaceId===root.snapshot.workspaceId) return
                        if (!root.overviewAnimations || root.anim("switch").ms<=0) {
                            slideAnimation.stop(); panel.workspaceSlide=0; panel.outgoing=[]; return
                        }
                        var previous=[]
                        var outgoingData={}
                        root.tiles.forEach(function(data) { outgoingData[data.address]=data })
                        for (var i=0;i<currentTiles.count;i++) {
                            var item=currentTiles.itemAt(i)
                            // Tile data is replaced, not mutated. Retain it and the
                            // resolved app directly instead of O(n²) lookup + JSON copies.
                            if (item) previous.push({data:outgoingData[item.modelData.address] || {},application:item.application,
                                x:canvas.x+item.x,y:canvas.y+item.y,w:item.width,h:item.height})
                        }
                        previous=OverviewMotion.outgoing(previous,panel.outgoing,panel.workspaceSlide,
                            panel.slideDirection*panel.width,panel.slideDirectionY*panel.height)
                        slideAnimation.stop()
                        panel.outgoing=previous
                        panel.slideDirection=next.slideDirection === undefined ? (next.workspaceId>root.snapshot.workspaceId ? 1 : -1) : next.slideDirection
                        panel.slideDirectionY=next.slideDirectionY || 0
                        canvas.panX=0; canvas.panY=0
                        slideAnimation.restart()
                    }
                }
                required property var modelData
                // Layout snapshots are authoritative. IPC focus and geometry arrive
                // separately, so mixing them briefly fits around the outgoing tile.
                property var focusedBox: null
                property string fitWorkspace: ""
                function updateFocusedBox() {
                    var tile = root.tiles.find(function(t) { return t.active && t.box })
                    if (!tile) return // Keep the last valid size during focus transitions.
                    var next = {x:tile.box.x-(root.snapshot.monitorX || 0),
                        y:tile.box.y-(root.snapshot.monitorY || 0),w:tile.box.w,h:tile.box.h}
                    var workspace = root.snapshot.monitor + ":" + root.snapshot.workspaceId
                    var stable = MinimapLayout.stableObstacle(focusedBox, next, workspace === fitWorkspace)
                    fitWorkspace = workspace
                    if (stable !== focusedBox) focusedBox = stable
                }
                Connections { target: root; function onSnapshotChanged() { panel.updateFocusedBox() } }
                Component.onCompleted: updateFocusedBox()
                MinimapFitMotion {
                    id: fitMotion
                    targetFrame: MinimapLayout.fit(root.mapWidth, root.mapHeight, panel.width, panel.height, root.preferences.minimap, panel.focusedBox)
                    duration: root.animationsEnabled && root.minimap && !root.transitioning && root.preferences.minimap.placementMode === "fit" ? root.anim("minimap").ms : 0
                    easingType: root.easingType(root.anim("minimap").curve); bezierCurve: root.easingCurve(root.anim("minimap").curve)
                }
                readonly property var mapFit: fitMotion.frame
                screen: modelData
                visible: !overlayState.screensaverActive && (!root.preferences.minimap.hideFullscreen || !overlayState.fullscreenActive || root.overview) && (root.transitioning || root.minimapProgress>0.001 || root.gesturing || launchPlaceholder.visible) && root.snapshot.monitor === modelData.name
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "hyprworld-preview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.overview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                mask: Region { item: root.overview ? background : root.preferences.minimap.interactive && root.minimap && panel.mapFit.visible ? canvas : null }
                Rectangle {
                    id: background
                    anchors.fill: parent
                    color: root.transitioning && !root.preferences.overview.wallpaper ? Util.alpha(Color.background, root.overviewProgress) : "transparent"
                    Image {
                        anchors.fill: parent
                        source: root.wallpaper && root.preferences.overview.wallpaper ? "file://" + root.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        visible: root.transitioning
                        opacity: Math.min(1, root.overviewProgress)
                        // Depth: the wallpaper settles from a slight zoom and blurs in.
                        scale: root.overviewAnimations && root.preferences.overview.depthZoom ? 1 + 0.06*(1 - root.overviewProgress) : 1
                        layer.enabled: visible && root.preferences.overview.backgroundBlur > 0 && root.preferences.effects.postProcessing
                        layer.effect: MultiEffect {
                            blurEnabled: true; blurMax: 64; autoPaddingEnabled: false
                            blur: Math.min(1, root.preferences.overview.backgroundBlur / 64 * Math.max(0, Math.min(1, root.overviewProgress)))
                        }
                    }
                    Rectangle { anchors.fill: parent; visible: root.transitioning; color: "black"; opacity: root.preferences.overview.dim * Math.min(1, root.overviewProgress) }
                    MouseArea { anchors.fill: parent; enabled: root.overview; onClicked: if (root.preferences.overview.emptyClickCloses) root.command("overview-close") }
                    focus: root.overview
                    Keys.onEscapePressed: root.command("overview-close")
                    Keys.onReturnPressed: root.command("overview-close")
                    Keys.onPressed: function(event) { root.navigateOverview(event) }
                    Text {
                        visible: root.transitioning; opacity: root.headerIn
                        x: 36; y: 28 - 18*root.headerShift
                        text: root.preferences.overview.showWorkspace ? "Workspace " + (root.snapshot.workspaceId || "") + " overview" : "Overview"
                        color: Color.foreground; font.pixelSize: 25; font.bold: true
                    }
                    Text {
                        visible: root.transitioning && root.preferences.overview.showHints; opacity: root.headerIn; x: 36; y: 66 - 18*root.headerShift
                        text: root.tiles.length + (root.tiles.length===1 ? " window" : " windows") + "  ·  Arrows: focus  ·  Shift + arrows / drag: move & group  ·  Click / Enter / Esc: return"
                        color: Color.foreground; font.pixelSize: 13
                    }
                    Rectangle {
                        x: 36; y: 96 - 18*root.headerShift; width: parent.width - 72; height: 44; radius: 8
                        visible: root.transitioning; opacity: root.headerIn
                        color: Util.alpha(Color.background, 0.92)
                        border.color: searchInput.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.35)
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 14; verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text
                            text: root.preferences.overview.launchApps ? "Search windows or launch an app — title, app, workspace, PID, tags…" : "Search all windows — title, app, workspace, PID, tags…"
                            color: Util.alpha(Color.foreground, 0.55); font.pixelSize: 15
                        }
                        TextInput {
                            id: searchInput
                            anchors.fill: parent; anchors.margins: 12
                            color: Color.foreground; font.pixelSize: 15; selectByMouse: true; clip: true
                            text: root.searchQuery
                            onTextEdited: root.searchQuery = text
                            onVisibleChanged: if (visible && root.overview) forceActiveFocus()
                            Connections { target: root; function onOverviewChanged() { if (root.overview) searchInput.forceActiveFocus() } }
                            Keys.priority: Keys.BeforeItem
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    if (text) root.searchQuery = ""; else root.command("overview-close")
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.searchQuery.trim()) root.selectSearchResult(root.searchIndex)
                                    else root.command("overview-close")
                                } else if (root.searchQuery.trim() && root.resultItems.length && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                                        && [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right].indexOf(event.key) >= 0) {
                                    // Results form a grid: left/right step, up/down move a row.
                                    var step = event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Left ? -1
                                        : (event.key === Qt.Key_Down ? 1 : -1) * results.columns
                                    root.searchIndex = Math.max(0, Math.min(root.resultItems.length-1, root.searchIndex + step))
                                } else {
                                    if ((!root.searchQuery.trim() || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) && root.navigateOverview(event)) return
                                    event.accepted = false; return
                                }
                                event.accepted = true
                            }
                        }
                    }
                    GridView {
                        id: results
                        x: 36; y: 164; width: parent.width-72; height: parent.height-y-36
                        visible: root.overview && !!root.searchQuery.trim()
                        clip: true; model: root.resultItems; currentIndex: root.searchIndex
                        readonly property real gap: Math.max(8, root.preferences.overview.gap*2)
                        readonly property int columns: Math.max(1, Math.floor(width / (Math.min(width, root.preferences.overview.cardWidth) + gap)))
                        cellWidth: Math.floor(width / columns)
                        cellHeight: root.preferences.overview.cardHeight + gap
                        highlightFollowsCurrentItem: false
                        // Result cards grow in and glide when the results reflow.
                        readonly property int moveMs: root.animationsEnabled ? root.anim("tiles").ms : 0
                        readonly property string moveCurve: root.anim("tiles").curve
                        populate: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: results.moveMs; easing.type: root.easingType(results.moveCurve); easing.bezierCurve: root.easingCurve(results.moveCurve) }
                            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: results.moveMs; easing.type: root.easingType(results.moveCurve); easing.bezierCurve: root.easingCurve(results.moveCurve) }
                        }
                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: results.moveMs; easing.type: root.easingType(results.moveCurve); easing.bezierCurve: root.easingCurve(results.moveCurve) }
                            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: results.moveMs; easing.type: root.easingType(results.moveCurve); easing.bezierCurve: root.easingCurve(results.moveCurve) }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: results.moveMs; easing.type: root.easingType(results.moveCurve); easing.bezierCurve: root.easingCurve(results.moveCurve) }
                        }
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                        delegate: Item {
                            id: result
                            required property var modelData
                            required property int index
                            readonly property bool isApp: modelData.kind === "app"
                            readonly property var entry: isApp ? modelData.app : modelData.window
                            readonly property bool selected: index === root.searchIndex
                            readonly property var application: isApp ? {name: entry.name, icon: entry.icon} : root.app(entry)
                            readonly property var details: !isApp && root.preferences.overview.showDetails ? Search.details(entry) : []
                            width: results.cellWidth; height: results.cellHeight
                            Rectangle {
                                anchors.fill: parent; anchors.margins: results.gap/2
                                radius: root.preferences.overview.radius; clip: true
                                color: Util.alpha(root.preferences.overview.backgroundColor || Color.background, root.preferences.overview.cardOpacity)
                                border.color: result.selected ? root.preferences.overview.activeColor || Color.accent : Util.alpha(Color.foreground, result.isApp ? 0.22 : 0.38)
                                border.width: result.selected ? 2 : 1
                                Image {
                                    id: resultIcon
                                    visible: root.preferences.overview.showIcons
                                    x: 12; y: 10; width: 28; height: 28
                                    source: Quickshell.iconPath(result.application.icon, true) || Quickshell.iconPath("application-x-executable", true)
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    x: resultIcon.visible ? 48 : 12; y: 10; height: 28; width: parent.width-x-badge.width-20
                                    verticalAlignment: Text.AlignVCenter
                                    text: result.application.name || result.entry.class || "Application"
                                    color: Color.foreground; font.pixelSize: 14; font.bold: true
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Rectangle {
                                    id: badge
                                    anchors.right: parent.right; anchors.rightMargin: 10; y: 14
                                    width: badgeText.implicitWidth+12; height: 20; radius: 10
                                    color: Util.alpha(result.isApp ? Color.accent : Color.foreground, result.isApp ? 0.28 : 0.12)
                                    Text {
                                        id: badgeText; anchors.centerIn: parent
                                        text: result.isApp ? "Launch" : "WS " + ((result.entry.workspace || {}).name || (result.entry.workspace || {}).id || "?")
                                        color: Color.foreground; font.pixelSize: 11; textFormat: Text.PlainText
                                    }
                                }
                                Text {
                                    x: 12; y: 48; width: parent.width-24
                                    height: Math.max(0, parent.height - y - (detailsText.visible ? 30 : 10))
                                    text: result.isApp ? (result.entry.genericName || "Open a new window on this workspace")
                                        : String(result.entry.title || "Untitled window").replace(/[\r\n]+/g, " ")
                                    color: Util.alpha(Color.foreground, 0.72); font.pixelSize: root.preferences.overview.fontSize
                                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Text {
                                    id: detailsText
                                    visible: result.details.length > 0
                                    x: 12; width: parent.width-24; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                    text: result.details.join("  ·  ")
                                    color: Util.alpha(Color.foreground, 0.5); font.pixelSize: 11
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.selectSearchResult(result.index) }
                        }
                        Text { visible: results.count === 0; text: root.preferences.overview.launchApps ? "No matching windows or apps" : "No matching windows"; color: Color.foreground; font.pixelSize: 16 }
                    }
                    Rectangle {
                        id: launchPlaceholder
                        // The layout's prediction of the new window's box; an empty
                        // workspace has no layout yet, so its first window is centred.
                        readonly property var area: root.snapshot.area || {x: root.snapshot.monitorX || 0, y: root.snapshot.monitorY || 0, w: panel.width, h: panel.height}
                        readonly property var box: root.launchBox || {
                            w: area.w * root.preferences.workflow.defaultWidth, h: area.h * root.preferences.workflow.defaultHeight,
                            x: area.x + area.w * (1 - root.preferences.workflow.defaultWidth) / 2,
                            y: area.y + area.h * (1 - root.preferences.workflow.defaultHeight) / 2}
                        width: box.w; height: box.h
                        x: box.x - (root.snapshot.monitorX || 0)
                        y: box.y - (root.snapshot.monitorY || 0)
                        opacity: root.launching && (root.launchBox || !root.tiles.length) ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: root.animationsEnabled ? 220 : 0; easing.type: Easing.OutCubic } }
                        radius: 12
                        color: Util.alpha(Color.background, 0.82)
                        border.width: 2
                        property real pulse: 0
                        border.color: Util.alpha(Color.accent, 0.3 + 0.7*pulse)
                        SequentialAnimation on pulse {
                            running: launchPlaceholder.visible && root.animationsEnabled && root.anim("launch").ms > 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 1; duration: root.anim("launch").ms/2; easing.type: root.easingType(root.anim("launch").curve); easing.bezierCurve: root.easingCurve(root.anim("launch").curve) }
                            NumberAnimation { from: 1; to: 0; duration: root.anim("launch").ms/2; easing.type: root.easingType(root.anim("launch").curve); easing.bezierCurve: root.easingCurve(root.anim("launch").curve) }
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 10; radius: parent.radius - 4
                            color: Util.alpha(Color.accent, 0.04 + 0.08*launchPlaceholder.pulse)
                        }
                        Column {
                            anchors.centerIn: parent; spacing: 14
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 72; height: 72; fillMode: Image.PreserveAspectFit
                                opacity: 0.55 + 0.45*launchPlaceholder.pulse
                                scale: 0.94 + 0.06*launchPlaceholder.pulse
                                source: Quickshell.iconPath(root.launchInfo.icon || "", true) || Quickshell.iconPath("application-x-executable", true)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Opening " + (root.launchInfo.name || "app") + "…"
                                color: Util.alpha(Color.foreground, 0.8); font.pixelSize: 15; textFormat: Text.PlainText
                            }
                        }
                    }
                    Repeater {
                        // Mouse workspace switching; hidden while searching.
                        model: [-1, 1]
                        delegate: Rectangle {
                            required property int modelData
                            visible: root.overview && !root.searchQuery.trim() && panel.workspaceSlide === 0
                            opacity: root.headerIn * (arrowArea.containsMouse ? 1 : 0.7)
                            z: 10
                            width: 44; height: 44; radius: 22
                            x: (modelData < 0 ? 12 : parent.width - width - 12) + modelData*40*root.headerShift
                            y: 164 + (parent.height - 164 - 36 - height) / 2
                            color: Util.alpha(Color.background, arrowArea.containsMouse ? 0.95 : 0.75)
                            border.width: 1; border.color: arrowArea.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.35)
                            Text {
                                anchors.centerIn: parent; anchors.horizontalCenterOffset: modelData < 0 ? -1 : 1
                                text: modelData < 0 ? "‹" : "›"; color: Color.foreground; font.pixelSize: 28
                            }
                            MouseArea {
                                id: arrowArea
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchWorkspace(parent.modelData)
                            }
                            Accessible.name: modelData < 0 ? "Previous workspace" : "Next workspace"
                        }
                    }
                    Item {
                        id: canvas
                        opacity: root.overview ? 1-panel.workspaceSlide : root.transitioning ? 1 : root.minimapProgress
                        transform: Translate { x: root.overview ? panel.slideDirection*panel.width*panel.workspaceSlide : 0; y: root.overview ? panel.slideDirectionY*panel.height*panel.workspaceSlide : 0 }
                        visible: (root.transitioning || (root.minimapProgress>0.001 && panel.mapFit.visible)) && !root.searchQuery.trim()
                        property real panX: 0
                        property real panY: 0
                        readonly property bool animateMinimap: root.animationsEnabled && root.minimap && !root.transitioning
                        // The minimap is sized from the actual grid extent, so
                        // a 2x1 layout stays compact while larger layouts grow
                        // until they reach the small corner footprint.
                        x: root.transitioning ? 36 : panel.mapFit.x
                        y: root.transitioning ? 164 : panel.mapFit.y
                        width: root.transitioning ? parent.width-x*2 : panel.mapFit.w
                        height: root.transitioning ? parent.height-y-36 : panel.mapFit.h
                        readonly property real cellW: root.transitioning
                            ? Math.min(root.hasGroups ? root.preferences.overview.groupWidth : root.preferences.overview.cardWidth, width / root.extent.cols)
                            : Math.min(24, width / root.extent.cols)
                        readonly property real cellH: root.transitioning
                            ? Math.min(root.hasGroups ? root.preferences.overview.groupHeight : root.preferences.overview.cardHeight, height / root.extent.rows)
                            : Math.min(22, height / root.extent.rows)
                        readonly property real originX: root.transitioning ? (width - cellW*root.extent.cols)/2+panX : 0
                        readonly property real originY: root.transitioning ? (height - cellH*root.extent.rows)/2+panY : 0
                        function cardRect(data) {
                            var p = data.part || {x:0,y:0,w:1,h:1}
                            return {x: originX + (data.col-root.extent.col+p.x)*cellW + root.preferences.overview.gap/2,
                                y: originY + (data.row-root.extent.row+p.y)*cellH + root.preferences.overview.gap/2,
                                w: Math.max(2, cellW*p.w-root.preferences.overview.gap), h: Math.max(2, cellH*p.h-root.preferences.overview.gap)}
                        }
                        MinimapSurface { anchors.fill: parent; visible: !root.transitioning; preferences: root.preferences.minimap; effects:root.preferences.effects; wallpaper: root.wallpaper }
                        GlassBackdrop {
                            anchors.fill: parent
                            visible: !root.transitioning && root.minimap && root.preferences.minimap.style === "glass"
                                && root.preferences.effects.postProcessing && GraphicsInfo.api !== GraphicsInfo.Software
                            wallpaper: root.wallpaper
                            screenRect: ({x: canvas.x, y: canvas.y, w: canvas.width, h: canvas.height})
                            screenSize: Qt.size(panel.width, panel.height)
                            radius: root.preferences.minimap.glassBlur
                            cardRadius: root.preferences.minimap.radius
                            // Cards match the tile rectangles drawn below.
                            cards: {
                                var scale = panel.mapFit.scale, result = []
                                root.tiles.forEach(function(t) {
                                    var r = minimapMotion.frame.tiles[t.address]
                                    if (!r) return
                                    var x = Math.min(root.mapWidth, Math.max(0, r.x)) * scale
                                    var y = Math.min(root.mapHeight, Math.max(0, r.y)) * scale
                                    result.push({x: x, y: y, w: Math.max(0, Math.min(r.w*scale, panel.mapFit.w-x)),
                                        h: Math.max(0, Math.min(r.h*scale, panel.mapFit.h-y))})
                                })
                                return result
                            }
                            // Only windows that actually sit behind the minimap are captured.
                            windows: {
                                if (!visible) return []
                                var mx = root.snapshot.monitorX || 0, my = root.snapshot.monitorY || 0, result = []
                                root.tiles.forEach(function(t) {
                                    var b = t.box
                                    if (!b) return
                                    var x = b.x - mx, y = b.y - my
                                    if (x < canvas.x + canvas.width && x + b.w > canvas.x && y < canvas.y + canvas.height && y + b.h > canvas.y)
                                        result.push({address: t.address, x: x, y: y, w: b.w, h: b.h})
                                })
                                return result
                            }
                        }
                        MinimapConstellation {
                            anchors.fill: parent; anchors.margins: -12
                            visible: !root.transitioning && root.preferences.minimap.style === "constellation"
                            function centres(frame, scale) {
                                var result = {}
                                root.tiles.forEach(function(t) {
                                    var r = frame.tiles[t.address]
                                    if (r) result[t.address] = {x: (r.x + r.w/2)*scale + 12, y: (r.y + r.h/2)*scale + 12}
                                })
                                return result
                            }
                            stars: visible ? centres(minimapMotion.frame, panel.mapFit.scale) : ({})
                            layoutStars: visible ? centres(minimapMotion.targetFrame, 1) : ({})
                            active: (root.tiles.find(function(t) { return t.active }) || {}).address || ""
                            travelMs: root.animationsEnabled ? root.anim("constellation").ms : 0
                            easingType: root.easingType(root.anim("constellation").curve); bezierCurve: root.easingCurve(root.anim("constellation").curve)
                            fadeMs: root.animationsEnabled ? root.anim("highlight").ms : 0
                            fadeEasingType: root.easingType(root.anim("highlight").curve); fadeBezierCurve: root.easingCurve(root.anim("highlight").curve)
                            glow: root.preferences.minimap.activeColor || Color.accent
                        }
                        Text { visible: !root.transitioning && root.preferences.minimap.showWorkspace; y:-20; width:parent.width; elide:Text.ElideRight; text:"Workspace "+root.snapshot.workspaceId;color:Color.foreground;font.pixelSize:11 }
                        Repeater {
                            id: currentTiles
                            model: tileModel
                            delegate: Rectangle {
                                id: tile
                                required property var tileData
                                readonly property var modelData: tileData
                                property bool ready: false
                                Component.onCompleted: ready=true
                                readonly property int moveMs: root.compactAnimating ? root.anim("compact").ms : root.anim("tiles").ms
                                readonly property string moveCurve: root.compactAnimating ? root.anim("compact").curve : root.anim("tiles").curve
                                readonly property bool animateGeometry: root.overviewAnimations && ready && root.overview && root.overviewLinear>0.999 && panel.workspaceSlide===0 && !dragArea.panning
                                Behavior on x { enabled: tile.animateGeometry; NumberAnimation { duration: tile.moveMs; easing.type: root.easingType(tile.moveCurve); easing.bezierCurve: root.easingCurve(tile.moveCurve) } }
                                Behavior on y { enabled: tile.animateGeometry; NumberAnimation { duration: tile.moveMs; easing.type: root.easingType(tile.moveCurve); easing.bezierCurve: root.easingCurve(tile.moveCurve) } }
                                Behavior on width { enabled: tile.animateGeometry; NumberAnimation { duration: tile.moveMs; easing.type: root.easingType(tile.moveCurve); easing.bezierCurve: root.easingCurve(tile.moveCurve) } }
                                Behavior on height { enabled: tile.animateGeometry; NumberAnimation { duration: tile.moveMs; easing.type: root.easingType(tile.moveCurve); easing.bezierCurve: root.easingCurve(tile.moveCurve) } }
                                readonly property var application: root.app(modelData)
                                readonly property var target: canvas.cardRect(modelData)
                                readonly property real targetX: target.x
                                readonly property real targetY: target.y
                                readonly property real targetW: target.w
                                readonly property real targetH: target.h
                                readonly property var box: modelData.box || {x:0,y:0,w:targetW,h:targetH}
                                readonly property real aspectRatio: Math.max(0.15, Math.min(8, Number(box.w) / Math.max(1, Number(box.h))))
                                readonly property var miniRect: minimapMotion.frame.tiles[modelData.address] || {x:0,y:0,w:2,h:2}
                                readonly property real miniX: Math.min(root.mapWidth, Math.max(0,miniRect.x)) * panel.mapFit.scale
                                readonly property real miniY: Math.min(root.mapHeight, Math.max(0,miniRect.y)) * panel.mapFit.scale
                                readonly property real miniW: Math.max(0,Math.min(miniRect.w*panel.mapFit.scale,panel.mapFit.w-miniX))
                                readonly property real miniH: Math.max(0,Math.min(miniRect.h*panel.mapFit.scale,panel.mapFit.h-miniY))
                                readonly property var area: root.snapshot.area || {x:0,y:0,w:panel.width,h:panel.height}
                                // Cascade: nearer cards lead on open and trail on close.
                                readonly property real phase: root.transitioning ? root.cascadePhase(root.cascadeDelays[modelData.address] || 0) : 1
                                readonly property real progress: root.transitioning ? root.overviewEase(phase) : 1
                                // Labels fade in as the card lands.
                                readonly property real labelsIn: root.transitioning ? root.overviewEase(Math.max(0, phase*2 - 1)) : 1
                                x: root.transitioning ? (box.x-(root.snapshot.monitorX || 0)-canvas.x)*(1-progress)+targetX*progress : miniX
                                y: root.transitioning ? (box.y-(root.snapshot.monitorY || 0)-canvas.y)*(1-progress)+targetY*progress : miniY
                                width: root.transitioning ? box.w*(1-progress)+targetW*progress : miniW
                                height: root.transitioning ? box.h*(1-progress)+targetH*progress : miniH
                                // Minimap style; the overview always draws plain cards.
                                readonly property string miniStyle: root.transitioning ? "" : root.preferences.minimap.style
                                opacity: root.transitioning ? Math.min(1, Math.max(0, progress)*4)
                                    : miniStyle === "constellation" ? 0 : miniStyle === "base" ? root.preferences.minimap.opacity : 1
                                radius: root.transitioning ? root.preferences.overview.radius : root.preferences.minimap.radius
                                // Glass cards tint the blurred backdrop drawn by GlassBackdrop.
                                color: root.transitioning ? Util.alpha(root.preferences.overview.backgroundColor || Color.background, root.preferences.overview.cardOpacity)
                                    : miniStyle === "glass" ? Util.alpha(root.preferences.minimap.backgroundColor || Color.background, Math.max(0.18, root.preferences.minimap.fillOpacity))
                                    : miniStyle === "icons" ? "transparent"
                                    : Util.alpha(root.preferences.minimap.backgroundColor || Color.background,root.preferences.minimap.fillOpacity)
                                border.color: modelData.active ? (root.transitioning ? root.preferences.overview.activeColor : root.preferences.minimap.activeColor) || Color.accent
                                    : miniStyle === "glass" ? Util.alpha(Color.foreground, 0.28) : root.preferences.minimap.borderColor || Util.alpha(Color.foreground, 0.38)
                                Behavior on border.color { enabled: canvas.animateMinimap; ColorAnimation { duration: root.anim("highlight").ms; easing.type: root.easingType(root.anim("highlight").curve); easing.bezierCurve: root.easingCurve(root.anim("highlight").curve) } }
                                border.width: miniStyle === "icons" ? 0 : (root.transitioning || miniStyle === "glass" ? 1 : root.preferences.minimap.lineWidth) + (modelData.active ? 1 : 0)
                                // The arrival ring draws outside the card while it pulses.
                                clip: !focusRing.visible
                                MouseArea {
                                    anchors.fill: parent; enabled: !root.transitioning && root.preferences.minimap.interactive
                                    onClicked: if (/^0x[0-9a-f]+$/i.test(tile.modelData.address)) Hyprland.dispatch('hl.dsp.focus({window="address:'+tile.modelData.address+'"})')
                                }
                                Image {
                                    id: icon
                                    readonly property bool large: tile.miniStyle === "icons"
                                    visible: root.transitioning ? root.preferences.overview.showIcons : large || root.preferences.minimap.showIcons
                                    opacity: root.transitioning ? tile.labelsIn : large && !tile.modelData.active ? 0.5 : 1
                                    width: large ? Math.max(6, Math.min(tile.width, tile.height)*0.78) : Math.min(28, tile.height*.2); height: width
                                    x: large ? (tile.width-width)/2 : 12; y: large ? (tile.height-height)/2 : 8
                                    source: Quickshell.iconPath(tile.application.icon, true) || Quickshell.iconPath("application-x-executable", true)
                                    fillMode: Image.PreserveAspectFit
                                }
                                Rectangle {
                                    // A ring pulses once around the selected card as it lands.
                                    id: focusRing
                                    property real pulse: 0
                                    readonly property bool arrived: root.overview && tile.modelData.active && tile.phase >= 1
                                    onArrivedChanged: if (arrived && root.overviewAnimations && root.preferences.overview.focusPulse) ringAnimation.restart()
                                    visible: pulse > 0 && pulse < 1 && root.transitioning
                                    anchors.fill: parent; anchors.margins: -2 - 12*pulse
                                    radius: tile.radius + 2 + 12*pulse; color: "transparent"
                                    border.width: 2; border.color: root.preferences.overview.activeColor || Color.accent
                                    opacity: 0.85*(1 - pulse)
                                    NumberAnimation {
                                        id: ringAnimation
                                        target: focusRing; property: "pulse"; from: 0; to: 1
                                        duration: Math.max(240, root.overviewDuration*1.5)
                                        easing.type: root.easingType(root.anim("overview").curve); easing.bezierCurve: root.easingCurve(root.anim("overview").curve)
                                    }
                                }
                                Rectangle {
                                    // Icons style marks the focused window under its icon.
                                    visible: tile.miniStyle === "icons" && tile.modelData.active
                                    width: Math.max(4, icon.width*0.4); height: 2; radius: 1
                                    x: (tile.width-width)/2; y: Math.min(tile.height-height, icon.y+icon.height+1)
                                    color: root.preferences.minimap.activeColor || Color.accent
                                }
                                Text {
                                    visible: root.transitioning && root.preferences.overview.showAppNames; opacity: tile.labelsIn; x: 12; y: icon.y+icon.height+10; width: parent.width-24
                                    text: tile.application.name; color: Color.foreground; font.pixelSize: tile.height < 100 ? 11 : 15; font.bold: true
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Text {
                                    visible: root.transitioning ? root.preferences.overview.showTitles : root.preferences.minimap.showTitles && tile.width>50 && tile.miniStyle !== "icons"; opacity: root.transitioning ? tile.labelsIn : 1; x: 12; y: root.transitioning ? icon.y+icon.height+(tile.height < 100 ? 26 : 34) : tile.height/2-6; width: parent.width-24
                                    text: String(modelData.title || "Untitled window").replace(/[\r\n]+/g, " ")
                                    color: Util.alpha(Color.foreground, 0.72); font.pixelSize: root.preferences.overview.fontSize; elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Text {
                                    readonly property var details: root.transitioning && root.preferences.overview.showDetails ? Search.details(root.ipcByAddress[tile.modelData.address]) : []
                                    visible: details.length > 0 && tile.height >= 110
                                    opacity: tile.labelsIn
                                    x: 12; width: parent.width-24; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                    text: details.join("  ·  ")
                                    color: Util.alpha(Color.foreground, 0.5); font.pixelSize: 11
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                            }
                        }
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent; enabled: root.overview
                            property string address: ""
                            property string label: ""
                            property real startX: 0
                            property real startY: 0
                            property bool moving: false
                            property bool panning: false
                            property real panStartX: 0
                            property real panStartY: 0
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            readonly property int dropCol: root.extent.col + Math.floor((mouseX-canvas.originX)/canvas.cellW)
                            readonly property int dropRow: root.extent.row + Math.floor((mouseY-canvas.originY)/canvas.cellH)
                            readonly property var swapTarget: {
                                var source = root.tiles.find(function(t) { return t.address === address })
                                if (!source) return null
                                return root.tiles.find(function(t) {
                                    var r=canvas.cardRect(t)
                                    return t.address !== address && t.col === source.col && t.row === source.row
                                        && mouseX >= r.x && mouseX <= r.x+r.w && mouseY >= r.y && mouseY <= r.y+r.h
                                }) || null
                            }
                            readonly property string dropLabel: {
                                if (swapTarget) return "Swap positions in group"
                                var members = root.tiles.filter(function(t) { return t.col === dropCol && t.row === dropRow })
                                if (members.some(function(t) { return t.address === address })) return "Keep position"
                                return members.length === 4 ? "Swap full group" : members.length === 1 ? "Create group · 2 windows" : members.length > 1 ? "Add to group · " + (members.length+1) + " windows" : "Move here"
                            }
                            cursorShape: moving ? Qt.ClosedHandCursor : Qt.ArrowCursor
                            onPressed: function(mouse) {
                                address = ""; moving = false; startX = mouse.x; startY = mouse.y
                                panning = mouse.button === Qt.MiddleButton && !!(mouse.modifiers & Qt.MetaModifier)
                                panStartX = canvas.panX; panStartY = canvas.panY
                                if (panning || mouse.button !== Qt.LeftButton) return
                                for (var i = 0; i < root.tiles.length; i++) {
                                    var data = root.tiles[i], rect = canvas.cardRect(data)
                                    if (mouse.x >= rect.x && mouse.x <= rect.x+rect.w && mouse.y >= rect.y && mouse.y <= rect.y+rect.h) {
                                        address = data.address; label = root.app(data).name
                                        root.command("overview-highlight " + address); break
                                    }
                                }
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed && panning) { canvas.panX = panStartX+mouse.x-startX; canvas.panY = panStartY+mouse.y-startY; return }
                                if (pressed && address && Math.hypot(mouse.x-startX, mouse.y-startY) > 8) moving = true
                            }
                            onReleased: function(mouse) {
                                root.command("overview-drag-end")
                                if (address) {
                                    if (moving) {
                                        var col = root.extent.col + Math.floor((mouse.x-canvas.originX)/canvas.cellW)
                                        var row = root.extent.row + Math.floor((mouse.y-canvas.originY)/canvas.cellH)
                                        if (swapTarget) root.command("overview-swap " + address + " " + swapTarget.address)
                                        else root.command("overview-drop " + address + " " + col + "," + row)
                                    } else root.command("overview-select " + address)
                                } else if (!panning && mouse.button===Qt.LeftButton) root.command("overview-close")
                                address = ""; moving = false; panning = false
                            }
                            onCanceled: { root.command("overview-drag-end"); address = ""; moving = false; panning = false }
                        }
                        Rectangle {
                            visible: dragArea.moving
                            readonly property var targetRect: dragArea.swapTarget ? canvas.cardRect(dragArea.swapTarget) : ({
                                x: canvas.originX+(dragArea.dropCol-root.extent.col)*canvas.cellW+2,
                                y: canvas.originY+(dragArea.dropRow-root.extent.row)*canvas.cellH+2,
                                w: canvas.cellW-4, h: canvas.cellH-4})
                            x: targetRect.x; y: targetRect.y
                            width: targetRect.w; height: targetRect.h; radius: 10
                            color: Util.alpha(Color.accent, 0.15); border.color: Color.accent; border.width: 2
                        }
                        Rectangle {
                            visible: dragArea.moving; x: dragArea.mouseX+14; y: dragArea.mouseY+14
                            width: 230; height: 36; radius: 6
                            color: Color.background; border.width: 1; border.color: Color.accent
                            Text { anchors.fill: parent; anchors.margins: 8; text: dragArea.dropLabel; color: Color.foreground; elide: Text.ElideRight; font.pixelSize: 12 }
                        }
                    }
                    Item {
                        anchors.fill: parent
                        visible: root.overview && panel.workspaceSlide>0
                        opacity: panel.workspaceSlide
                        transform: Translate { x: -panel.slideDirection*panel.width*(1-panel.workspaceSlide); y: -panel.slideDirectionY*panel.height*(1-panel.workspaceSlide) }
                        Repeater {
                            model: panel.outgoing
                            Rectangle {
                                required property var modelData
                                readonly property var application: modelData.application
                                opacity: modelData.opacity
                                x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; radius: root.preferences.overview.radius
                                color: Util.alpha(root.preferences.overview.backgroundColor || Color.background,root.preferences.overview.cardOpacity)
                                border.color: modelData.data.active ? root.preferences.overview.activeColor || Color.accent : root.preferences.minimap.borderColor || Util.alpha(Color.foreground,0.38)
                                border.width: modelData.data.active ? 2 : 1
                                clip: true
                                Image { id: oldIcon; x:12; y:8; width:Math.min(28,parent.height*.2); height:width; source:Quickshell.iconPath(parent.application.icon,true); fillMode:Image.PreserveAspectFit }
                                Text { x:12; y:oldIcon.y+oldIcon.height+10; width:parent.width-24; text:parent.application.name; color:Color.foreground; font.pixelSize:parent.height<100 ? 11 : 15; font.bold:true; elide:Text.ElideRight; textFormat:Text.PlainText }
                                Text { x:12; y:oldIcon.y+oldIcon.height+(parent.height<100 ? 26 : 34); width:parent.width-24; text:String(modelData.data.title || "Untitled window").replace(/[\r\n]+/g," "); color:Util.alpha(Color.foreground,.72); font.pixelSize:12; elide:Text.ElideRight; textFormat:Text.PlainText }
                            }
                        }
                    }
                }
            }
        }
    }
}
