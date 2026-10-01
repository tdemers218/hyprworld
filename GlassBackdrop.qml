import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Backdrop for the Glass minimap style: a real blur of what is behind each
// window card. Hyprland's layer blur uses one global size, so the backdrop is
// rebuilt here from the wallpaper plus live captures of only the windows under
// the minimap, blurred at the configured radius and masked to the cards.
Item {
    id: root
    property string wallpaper: ""
    // This item's rectangle in monitor-local pixels, and the monitor size.
    property var screenRect: ({x: 0, y: 0, w: width, h: height})
    property size screenSize: Qt.size(width, height)
    // Windows behind the minimap: [{address, x, y, w, h}] in monitor-local pixels.
    property var windows: []
    // Card shapes in this item's coordinates: [{x, y, w, h}].
    property var cards: []
    property real cardRadius: 3
    property real radius: 10

    function toplevel(address) {
        var key = String(address || "").toLowerCase().replace(/^0x/, "")
        var match = Hyprland.toplevels.values.find(function(t) {
            return String(t.address || "").toLowerCase().replace(/^0x/, "") === key
        })
        return match ? match.wayland : null
    }

    Item {
        id: scene
        anchors.fill: parent
        visible: false
        clip: true
        layer.enabled: root.visible
        Image {
            x: -root.screenRect.x; y: -root.screenRect.y
            width: root.screenSize.width; height: root.screenSize.height
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            sourceSize: Qt.size(1024, 1024)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Repeater {
            model: root.visible ? root.windows : []
            delegate: ScreencopyView {
                required property var modelData
                x: modelData.x - root.screenRect.x; y: modelData.y - root.screenRect.y
                width: modelData.w; height: modelData.h
                captureSource: root.toplevel(modelData.address)
                live: true
            }
        }
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.visible
        Repeater {
            model: root.cards
            delegate: Rectangle {
                required property var modelData
                x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                radius: root.cardRadius; color: "white"
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: scene
        autoPaddingEnabled: false
        blurEnabled: root.radius > 0
        blurMax: 64
        blur: Math.min(1, root.radius / 64)
        maskEnabled: true
        maskSource: mask
    }
}
