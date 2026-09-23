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
    readonly property var searchWindows: {
        var windows = [], seen = {}
        Hyprland.toplevels.values.forEach(function(t) {
            var data = t.lastIpcObject || {}
            if (!data.address) return
            var copy = Object.assign({}, data)
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
        return windows
    }
    readonly property var searchResults: Search.rank(searchQuery, searchWindows.filter(function(w) {
        return preferences.overview.searchScope!=="workspace" || (w.workspace && w.workspace.id===snapshot.workspaceId)
    }).map(function(w) {
        return preferences.overview.searchMetadata ? w : {address:w.address,class:w.class,title:w.title,workspace:w.workspace,application:w.application}
    }))
    onSearchQueryChanged: searchIndex = 0
    onSearchResultsChanged: searchIndex = Math.max(0, Math.min(searchIndex, searchResults.length-1))
    onOverviewChanged: {
        if (!overview) searchQuery = ""
        else if (!clientsReader.running) clientsReader.running = true
    }
    function selectSearchResult(index) {
        var w = searchResults[index]
        if (!w || !/^0x[0-9a-f]+$/i.test(w.address)) return
        var ws = Number(w.workspace && w.workspace.id)
        var workspaceName = String((w.workspace && w.workspace.name) || "")
        var code = "__hyprworld_set_overview(false); "
        var special = workspaceName.match(/^special:([A-Za-z0-9_.-]+)$/)
        if (special) code += "hl.dispatch(hl.dsp.workspace.toggle_special(" + JSON.stringify(special[1]) + ")); "
        else if (ws > 0 && Number.isInteger(ws)) code += "__hyprworld_workspace_nav.select(" + ws + "); "
        code += 'hl.dispatch(hl.dsp.focus({window="address:' + w.address + '"}))'
        Quickshell.execDetached(["timeout", "--kill-after=1s", "5s", "hyprctl", "eval", code])
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
    Timer { id: compactAnimation; interval: 320; onTriggered: root.compactAnimating=false }
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
    onCommitAddressChanged: if (commitAddress && !overview) commitTimer.restart()
    // Focus only after the layer has released exclusive keyboard ownership.
    // This is the requested selection being committed once, not a focus repair.
    Timer { id: commitTimer; interval: root.overviewDuration + 20; onTriggered: if (root.commitAddress && !root.overview) root.command("overview-commit " + root.commitAddress) }
    readonly property bool minimap: preferences.plugin.enabled && preferences.minimap.enabled && (!preferences.minimap.hideFullscreen || !overlayState.fullscreenActive) && tiles.length > (preferences.minimap.hideSingle ? 1 : 0) && !overview && (!preferences.minimap.hideMaxZoom || snapshot.zoom < snapshot.maxZoom)
    property real minimapProgress: minimap ? 1 : 0
    readonly property bool animationsEnabled: preferences.effects.animations
    readonly property bool overviewAnimations: animationsEnabled && !preferences.overview.reducedMotion
    Behavior on minimapProgress { NumberAnimation { duration: root.animationsEnabled ? root.preferences.minimap.fadeMs : 0 } }
    readonly property int overviewDuration: overviewAnimations ? preferences.overview.animationMs : 0
    onAnimationsEnabledChanged: effectsTimer.restart()
    Timer { id:effectsTimer; interval:100; onTriggered: effectsSync.running=true }
    Process {
        id:effectsSync
        command:["timeout", "--kill-after=1s", "5s", "hyprctl","eval","if __hyprworld_apply_effects then __hyprworld_apply_effects("+(root.animationsEnabled ? "true" : "false")+") end"]
    }
    readonly property int overviewEasing: preferences.overview.easing==="linear" ? Easing.Linear : preferences.overview.easing==="in-out-cubic" ? Easing.InOutCubic : Easing.OutCubic
    property bool pending: false
    property real overviewProgress: overview ? 1 : 0
    Behavior on overviewProgress { NumberAnimation { duration: root.overviewDuration; easing.type: root.overviewEasing } }
    readonly property bool transitioning: overview || overviewProgress > 0.001
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
        if (message === "overview-close") locallyDismissed = true
        if (message === "overview-close" && tiles.length === 0) {
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
        duration: root.animationsEnabled && !root.transitioning && root.minimap ? root.preferences.minimap.motionMs : 0
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
                NumberAnimation { id: slideAnimation; target: panel; property: "workspaceSlide"; from: 1; to: 0; duration: root.overviewAnimations ? root.preferences.overview.switchMs : 0; easing.type: root.overviewEasing; onFinished: panel.outgoing=[] }
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
                        if (!root.overviewAnimations || root.preferences.overview.switchMs<=0) {
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
                    duration: root.animationsEnabled && root.minimap && !root.transitioning && root.preferences.minimap.placementMode === "fit" ? root.preferences.minimap.motionMs : 0
                }
                readonly property var mapFit: fitMotion.frame
                screen: modelData
                visible: !overlayState.screensaverActive && (!root.preferences.minimap.hideFullscreen || !overlayState.fullscreenActive || root.overview) && (root.transitioning || root.minimapProgress>0.001 || root.gesturing) && root.snapshot.monitor === modelData.name
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
                        opacity: root.overviewProgress
                    }
                    Rectangle { anchors.fill: parent; visible: root.transitioning; color: "black"; opacity: root.preferences.overview.dim * root.overviewProgress }
                    MouseArea { anchors.fill: parent; enabled: root.overview; onClicked: if (root.preferences.overview.emptyClickCloses) root.command("overview-close") }
                    focus: root.overview
                    Keys.onEscapePressed: root.command("overview-close")
                    Keys.onReturnPressed: root.command("overview-close")
                    Keys.onPressed: function(event) { root.navigateOverview(event) }
                    Text {
                        visible: root.transitioning; opacity: root.overviewProgress
                        x: 36; y: 28
                        text: root.preferences.overview.showWorkspace ? "Workspace " + (root.snapshot.workspaceId || "") + " overview" : "Overview"
                        color: Color.foreground; font.pixelSize: 25; font.bold: true
                    }
                    Text {
                        visible: root.transitioning && root.preferences.overview.showHints; opacity: root.overviewProgress; x: 36; y: 66
                        text: root.tiles.length + (root.tiles.length===1 ? " window" : " windows") + "  ·  Arrows: focus  ·  Shift + arrows / drag: move & group  ·  Click / Enter / Esc: return"
                        color: Color.foreground; font.pixelSize: 13
                    }
                    Rectangle {
                        x: 36; y: 96; width: parent.width - 72; height: 44; radius: 8
                        visible: root.transitioning; opacity: root.overviewProgress
                        color: Util.alpha(Color.background, 0.92)
                        border.color: searchInput.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.35)
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 14; verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text
                            text: "Search all windows — title, app, workspace, PID, tags…"
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
                                } else if (root.searchQuery.trim() && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                                    root.searchIndex = Math.max(0, Math.min(root.searchResults.length-1, root.searchIndex + (event.key === Qt.Key_Down ? 1 : -1)))
                                } else {
                                    if ((!root.searchQuery.trim() || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) && root.navigateOverview(event)) return
                                    event.accepted = false; return
                                }
                                event.accepted = true
                            }
                        }
                    }
                    ListView {
                        id: results
                        x: 36; y: 164; width: parent.width-72; height: parent.height-y-36
                        visible: root.overview && !!root.searchQuery.trim()
                        clip: true; spacing: 8; model: root.searchResults; currentIndex: root.searchIndex
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: results.width; height: 72; radius: 8
                            color: Util.alpha(index === root.searchIndex ? Color.accent : Color.background, 0.85)
                            Text {
                                x: 16; y: 12; width: parent.width-32
                                text: modelData.title || modelData.class || "Untitled window"
                                textFormat: Text.PlainText; elide: Text.ElideRight
                                color: Color.foreground; font.pixelSize: 16
                            }
                            Text {
                                x: 16; y: 40; width: parent.width-32
                                text: (modelData.application || modelData.class || "Application") + " · Workspace " + ((modelData.workspace || {}).name || (modelData.workspace || {}).id || "?")
                                textFormat: Text.PlainText; elide: Text.ElideRight
                                color: Color.foreground; font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.selectSearchResult(index) }
                        }
                        Text { visible: results.count === 0; text: "No matching windows"; color: Color.foreground; font.pixelSize: 16 }
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
                                readonly property bool animateGeometry: root.overviewAnimations && ready && root.overview && root.overviewProgress>0.999 && panel.workspaceSlide===0 && !dragArea.panning
                                Behavior on x { enabled: tile.animateGeometry; NumberAnimation { duration: root.compactAnimating ? 300 : 180; easing.type: Easing.OutCubic } }
                                Behavior on y { enabled: tile.animateGeometry; NumberAnimation { duration: root.compactAnimating ? 300 : 180; easing.type: Easing.OutCubic } }
                                Behavior on width { enabled: tile.animateGeometry; NumberAnimation { duration: root.compactAnimating ? 300 : 180; easing.type: Easing.OutCubic } }
                                Behavior on height { enabled: tile.animateGeometry; NumberAnimation { duration: root.compactAnimating ? 300 : 180; easing.type: Easing.OutCubic } }
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
                                readonly property real progress: root.transitioning ? root.overviewProgress : 1
                                x: root.transitioning ? (box.x-(root.snapshot.monitorX || 0)-canvas.x)*(1-progress)+targetX*progress : miniX
                                y: root.transitioning ? (box.y-(root.snapshot.monitorY || 0)-canvas.y)*(1-progress)+targetY*progress : miniY
                                width: root.transitioning ? box.w*(1-progress)+targetW*progress : miniW
                                height: root.transitioning ? box.h*(1-progress)+targetH*progress : miniH
                                opacity: root.transitioning ? Math.min(1, root.overviewProgress*4) : root.preferences.minimap.opacity
                                radius: root.transitioning ? root.preferences.overview.radius : root.preferences.minimap.radius
                                color: root.transitioning ? Util.alpha(root.preferences.overview.backgroundColor || Color.background, root.preferences.overview.cardOpacity) : Util.alpha(root.preferences.minimap.backgroundColor || Color.background,root.preferences.minimap.fillOpacity)
                                border.color: modelData.active ? (root.transitioning ? root.preferences.overview.activeColor : root.preferences.minimap.activeColor) || Color.accent : root.preferences.minimap.borderColor || Util.alpha(Color.foreground, 0.38)
                                Behavior on border.color { enabled: canvas.animateMinimap; ColorAnimation { duration: 140 } }
                                border.width: (root.transitioning ? 1 : root.preferences.minimap.lineWidth) + (modelData.active ? 1 : 0)
                                clip: true
                                MouseArea {
                                    anchors.fill: parent; enabled: !root.transitioning && root.preferences.minimap.interactive
                                    onClicked: if (/^0x[0-9a-f]+$/i.test(tile.modelData.address)) Hyprland.dispatch('hl.dsp.focus({window="address:'+tile.modelData.address+'"})')
                                }
                                Image {
                                    id: icon
                                    visible: root.transitioning ? root.preferences.overview.showIcons : root.preferences.minimap.showIcons; opacity: root.transitioning ? root.overviewProgress : 1
                                    x: 12; y: 8; width: Math.min(28, tile.height*.2); height: width
                                    source: Quickshell.iconPath(tile.application.icon, true) || Quickshell.iconPath("application-x-executable", true)
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    visible: root.transitioning && root.preferences.overview.showAppNames; opacity: root.overviewProgress; x: 12; y: icon.y+icon.height+10; width: parent.width-24
                                    text: tile.application.name; color: Color.foreground; font.pixelSize: tile.height < 100 ? 11 : 15; font.bold: true
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Text {
                                    visible: root.transitioning ? root.preferences.overview.showTitles : root.preferences.minimap.showTitles && tile.width>50; opacity: root.transitioning ? root.overviewProgress : 1; x: 12; y: root.transitioning ? icon.y+icon.height+(tile.height < 100 ? 26 : 34) : tile.height/2-6; width: parent.width-24
                                    text: String(modelData.title || "Untitled window").replace(/[\r\n]+/g, " ")
                                    color: Util.alpha(Color.foreground, 0.72); font.pixelSize: root.preferences.overview.fontSize; elide: Text.ElideRight; textFormat: Text.PlainText
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
