import qs.Commons
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Settings.js" as Settings

Item {
    id: root
    property var snapshot: ({})
    property bool pushAvailable: false
    property bool compactAnimating: false
    Timer { id: compactAnimation; interval: 320; onTriggered: root.compactAnimating=false }
    signal changingSnapshot(var next)
    ListModel { id: tileModel; dynamicRoles: true }
    function acceptSnapshot(next) {
        if (next.epoch && next.epoch===snapshot.epoch && next.revision<=snapshot.revision) return
        if (next.workspaceId===snapshot.workspaceId && next.epoch===snapshot.epoch && (next.compactSerial || 0)!==(snapshot.compactSerial || 0)) {
            compactAnimating=true; compactAnimation.restart()
        }
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
    function switchWorkspace(direction) {
        Quickshell.execDetached(["hyprctl","eval","if __hyprworld_workspace_nav then __hyprworld_workspace_nav.step("+direction+") end"])
    }
    readonly property var gesture: snapshot.gesture || ({})
    readonly property bool gesturing: !!gesture.mode
    readonly property var tiles: Array.isArray(snapshot.tiles) ? snapshot.tiles : []
    readonly property bool overview: preferences.plugin.enabled && snapshot.overview === true
    readonly property string commitAddress: snapshot.commitAddress || ""
    readonly property bool hasGroups: tiles.some(function(tile) { return tile.part && tile.part.count > 1 })
    onCommitAddressChanged: if (commitAddress && !overview) commitTimer.restart()
    // Focus only after the layer has released exclusive keyboard ownership.
    // This is the requested selection being committed once, not a focus repair.
    Timer { id: commitTimer; interval: 60; onTriggered: if (root.commitAddress && !root.overview) root.command("overview-commit " + root.commitAddress) }
    readonly property bool minimap: preferences.plugin.enabled && preferences.minimap.enabled && tiles.length > 1 && !overview && snapshot.zoom < snapshot.maxZoom
    property bool pending: false
    property real overviewProgress: overview ? 1 : 0
    Behavior on overviewProgress { NumberAnimation { duration: root.preferences.overview.animationMs; easing.type: Easing.InOutCubic } }
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

    function refresh() {
        if (reader.running) { pending = true; return }
        reader.running = true
    }
    function command(message) {
        if (message === "overview-close" && tiles.length === 0) {
            Quickshell.execDetached(["hyprctl","eval","if __hyprworld_set_overview then __hyprworld_set_overview(false) end"])
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
    Timer { interval: root.gesturing ? 32 : root.pushAvailable ? 2000 : 400; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data.startsWith("hyprworld-preview,")) {
                try {
                    root.acceptSnapshot(JSON.parse(event.data.slice("hyprworld-preview,".length)))
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
        command: ["hyprctl", "repl", "return __hyprworld_preview and __hyprworld_preview() or '{}' "]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.acceptSnapshot(JSON.parse(text.trim())) } catch (e) { /* Keep the last valid frame. */ }
            }
        }
        onRunningChanged: if (!running && root.pending) { root.pending = false; refreshTimer.restart() }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panel
                property var outgoing: []
                property real workspaceSlide: 0
                property int slideDirection: 1
                NumberAnimation { id: slideAnimation; target: panel; property: "workspaceSlide"; from: 1; to: 0; duration: root.preferences.overview.animationMs; easing.type: Easing.OutCubic; onFinished: panel.outgoing=[] }
                Connections {
                    target: root
                    function onChangingSnapshot(next) {
                        if (!root.overview || !next.overview || next.monitor!==panel.modelData.name || root.snapshot.monitor!==next.monitor || next.workspaceId===root.snapshot.workspaceId) return
                        var previous=[]
                        for (var i=0;i<currentTiles.count;i++) {
                            var item=currentTiles.itemAt(i)
                            if (item) previous.push({data:JSON.parse(JSON.stringify(root.tiles.find(function(t) { return t.address===item.modelData.address }) || {})),
                                x:canvas.x+item.x,y:canvas.y+item.y,w:item.width,h:item.height})
                        }
                        slideAnimation.stop()
                        panel.outgoing=previous
                        panel.slideDirection=next.slideDirection || (next.workspaceId>root.snapshot.workspaceId ? 1 : -1)
                        canvas.panX=0; canvas.panY=0
                        slideAnimation.restart()
                    }
                }
                required property var modelData
                screen: modelData
                visible: (root.transitioning || root.minimap || root.gesturing) && root.snapshot.monitor === modelData.name
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "hyprworld-preview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.overview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                mask: Region { item: root.overview ? background : null }
                // Click-through hints: these never take input away from the compositor drag.
                Rectangle {
                    readonly property var box: root.gesture.ghost || ({x:0,y:0,w:0,h:0})
                    visible: !!root.gesture.ghost
                    x: box.x-(root.snapshot.monitorX || 0); y: box.y-(root.snapshot.monitorY || 0)
                    width: box.w; height: box.h; radius: 10
                    color: Util.alpha(Color.accent, 0.08)
                    border.color: Color.accent; border.width: 2
                }
                Rectangle {
                    id: dropHint
                    readonly property var drop: root.gesture.drop || ({})
                    readonly property var box: drop.box || ({x:0,y:0,w:0,h:0})
                    visible: !!drop.box
                    x: box.x-(root.snapshot.monitorX || 0); y: box.y-(root.snapshot.monitorY || 0)
                    width: box.w; height: box.h; radius: 10
                    color: Util.alpha(Color.accent, 0.18)
                    border.color: Color.accent; border.width: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: dropLabel.implicitWidth+28; height: 38; radius: 8
                        color: Color.background; border.color: Color.accent; border.width: 1
                        Text { id: dropLabel; anchors.centerIn: parent; text: dropHint.drop.label || ""; color: Color.foreground; font.pixelSize: 14; font.bold: true }
                    }
                }
                Rectangle {
                    id: background
                    anchors.fill: parent
                    layer.enabled: root.overviewProgress > 0.001 && root.overviewProgress < 0.999
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 12
                        blur: Math.sin(root.overviewProgress * Math.PI) * 0.35
                    }
                    color: root.transitioning && !root.preferences.overview.wallpaper ? Util.alpha(Color.background, root.overviewProgress) : "transparent"
                    Image {
                        anchors.fill: parent
                        source: root.wallpaper && root.preferences.overview.wallpaper ? "file://" + root.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        visible: root.transitioning
                        opacity: root.overviewProgress
                    }
                    MouseArea { anchors.fill: parent; enabled: root.overview; onClicked: root.command("overview-close") }
                    focus: root.overview
                    Keys.onEscapePressed: root.command("overview-close")
                    Keys.onReturnPressed: root.command("overview-close")
                    Keys.onPressed: function(event) {
                        var directions = {}; directions[Qt.Key_Left] = "left"; directions[Qt.Key_Right] = "right"
                        directions[Qt.Key_Up] = "up"; directions[Qt.Key_Down] = "down"
                        if (!directions[event.key]) return
                        var direction = directions[event.key]
                        if ((event.modifiers & Qt.ControlModifier) && (direction === "left" || direction === "right")) root.switchWorkspace(direction === "right" ? 1 : -1)
                        else if (event.modifiers & Qt.ShiftModifier) root.command("move " + direction)
                        else if (event.modifiers & Qt.AltModifier) root.command("resize " + direction)
                        else if (event.modifiers & Qt.ControlModifier) {
                            root.command(direction === "up" ? "zoom in" : direction === "down" ? "zoom out" : "pan " + direction)
                        } else root.command("focus " + direction)
                        event.accepted = true
                    }
                    Text {
                        visible: root.transitioning; opacity: root.overviewProgress
                        x: 36; y: 28
                        text: "Workspace overview"
                        color: Color.foreground; font.pixelSize: 25; font.bold: true
                    }
                    Text {
                        visible: root.transitioning; opacity: root.overviewProgress; x: 36; y: 66
                        text: root.tiles.length + " windows  ·  Arrows: focus  ·  Shift + arrows / drag: move & group  ·  Click / Enter / Esc: return"
                        color: Color.foreground; font.pixelSize: 13
                    }
                    Item {
                        id: canvas
                        transform: Translate { x: root.overview ? panel.slideDirection*panel.width*panel.workspaceSlide : 0 }
                        visible: root.transitioning || root.minimap
                        property real panX: 0
                        property real panY: 0
                        readonly property bool animateMinimap: root.minimap && !root.transitioning
                        // The minimap is sized from the actual grid extent, so
                        // a 2x1 layout stays compact while larger layouts grow
                        // until they reach the small corner footprint.
                        x: root.transitioning ? 36 : root.preferences.minimap.corner.endsWith("right") ? parent.width-root.mapWidth-root.preferences.minimap.x : root.preferences.minimap.x
                        y: root.transitioning ? 112 : root.preferences.minimap.corner.startsWith("bottom") ? parent.height-root.mapHeight-root.preferences.minimap.y : root.preferences.minimap.y
                        width: root.transitioning ? parent.width-x*2 : root.mapWidth
                        height: root.transitioning ? parent.height-y-36 : root.mapHeight
                        readonly property real cellW: root.transitioning
                            ? Math.min(root.hasGroups ? 520 : 290, width / root.extent.cols)
                            : Math.min(24, width / root.extent.cols)
                        readonly property real cellH: root.transitioning
                            ? Math.min(root.hasGroups ? 320 : 150, height / root.extent.rows)
                            : Math.min(22, height / root.extent.rows)
                        readonly property real originX: root.transitioning ? (width - cellW*root.extent.cols)/2+panX : 0
                        readonly property real originY: root.transitioning ? (height - cellH*root.extent.rows)/2+panY : 0
                        function cardRect(data) {
                            var p = data.part || {x:0,y:0,w:1,h:1}
                            return {x: originX + (data.col-root.extent.col+p.x)*cellW + 3,
                                y: originY + (data.row-root.extent.row+p.y)*cellH + 3,
                                w: Math.max(2, cellW*p.w-6), h: Math.max(2, cellH*p.h-6)}
                        }
                        Repeater {
                            id: currentTiles
                            model: tileModel
                            delegate: Rectangle {
                                id: tile
                                required property var tileData
                                readonly property var modelData: tileData
                                property bool ready: false
                                Component.onCompleted: ready=true
                                readonly property bool animateGeometry: ready && root.overview && root.overviewProgress>0.999 && panel.workspaceSlide===0 && !dragArea.panning
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
                                readonly property real miniX: miniRect.x
                                readonly property real miniY: miniRect.y
                                readonly property real miniW: miniRect.w
                                readonly property real miniH: miniRect.h
                                readonly property var area: root.snapshot.area || {x:0,y:0,w:panel.width,h:panel.height}
                                readonly property real progress: root.transitioning ? root.overviewProgress : 1
                                x: root.transitioning ? (box.x-area.x-canvas.x)*(1-progress)+targetX*progress : miniX
                                y: root.transitioning ? (box.y-area.y+panel.height-area.h-canvas.y)*(1-progress)+targetY*progress : miniY
                                width: root.transitioning ? box.w*(1-progress)+targetW*progress : miniW
                                height: root.transitioning ? box.h*(1-progress)+targetH*progress : miniH
                                opacity: root.transitioning ? Math.min(1, root.overviewProgress*4) : root.preferences.minimap.opacity
                                radius: root.transitioning ? 10 : 3
                                color: root.transitioning ? Util.alpha(Color.background, root.preferences.overview.cardOpacity) : "transparent"
                                border.color: modelData.active ? Color.accent : Util.alpha(Color.foreground, 0.38)
                                Behavior on border.color { enabled: canvas.animateMinimap; ColorAnimation { duration: 140 } }
                                border.width: (root.transitioning ? 1 : root.preferences.minimap.lineWidth) + (modelData.active ? 1 : 0)
                                clip: true
                                Image {
                                    id: icon
                                    visible: root.transitioning; opacity: root.overviewProgress
                                    x: 12; y: 8; width: Math.min(28, tile.height*.2); height: width
                                    source: Quickshell.iconPath(tile.application.icon, true) || Quickshell.iconPath("application-x-executable", true)
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    visible: root.transitioning; opacity: root.overviewProgress; x: 12; y: icon.y+icon.height+10; width: parent.width-24
                                    text: tile.application.name; color: Color.foreground; font.pixelSize: tile.height < 100 ? 11 : 15; font.bold: true
                                    elide: Text.ElideRight; textFormat: Text.PlainText
                                }
                                Text {
                                    visible: root.transitioning; opacity: root.overviewProgress; x: 12; y: icon.y+icon.height+(tile.height < 100 ? 26 : 34); width: parent.width-24
                                    text: String(modelData.title || "Untitled window").replace(/[\r\n]+/g, " ")
                                    color: Util.alpha(Color.foreground, 0.72); font.pixelSize: 12; elide: Text.ElideRight; textFormat: Text.PlainText
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
                        transform: Translate { x: -panel.slideDirection*panel.width*(1-panel.workspaceSlide) }
                        Repeater {
                            model: panel.outgoing
                            Rectangle {
                                required property var modelData
                                readonly property var application: root.app(modelData.data)
                                x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; radius: 10
                                color: Util.alpha(Color.background,root.preferences.overview.cardOpacity)
                                border.color: modelData.data.active ? Color.accent : Util.alpha(Color.foreground,0.38)
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
