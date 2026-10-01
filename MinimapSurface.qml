import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
    id: root
    required property var preferences
    property string wallpaper: ""
    property var effects: ({postProcessing:true,shadows:true,blur:true})
    readonly property string style: preferences.style
    readonly property bool effectsAvailable: visible && effects.postProcessing && GraphicsInfo.api !== GraphicsInfo.Software
    // Styles draw per-window effects themselves; the shared backdrop only
    // follows the explicit backdrop, shadow and blur settings.
    readonly property bool styledShadow: effects.shadows && preferences.shadow
    readonly property bool styledBlur: effects.blur && preferences.wallpaperBlur
    readonly property color baseColor: preferences.backgroundColor || Color.background
    readonly property real surfaceOpacity: preferences.backgroundOpacity
    // RectangularShadow has bounded geometry; reserve its full extent when fitting.
    RectangularShadow {
        anchors.fill: surface
        visible: root.styledShadow && root.effectsAvailable
        radius: surface.radius; blur: 18; spread: 0
        offset: Qt.vector2d(0, 3)
        color: Qt.rgba(0, 0, 0, root.preferences.shadowOpacity)
    }
    Rectangle {
        id: surface
        anchors.fill: parent; anchors.margins: -6
        radius: root.preferences.surfaceRadius
        color: "transparent"
        layer.enabled: root.styledBlur && !!root.wallpaper && root.effectsAvailable
        layer.effect: MultiEffect { maskEnabled: true; maskSource: roundedMask }
        Image {
            anchors.fill: parent
            visible: root.styledBlur && !!root.wallpaper && root.effectsAvailable
            source: visible ? "file://" + root.wallpaper : ""
            sourceSize: Qt.size(512, 512)
            fillMode: Image.PreserveAspectCrop
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: root.preferences.blurStrength; autoPaddingEnabled: false }
        }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Util.alpha(root.baseColor, root.surfaceOpacity)
        }
    }
    Rectangle {
        id: roundedMask
        width: surface.width; height: surface.height; radius: surface.radius
        color: "white"; visible: false; layer.enabled: surface.layer.enabled
    }
}
