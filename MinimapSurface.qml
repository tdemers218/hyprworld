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
    readonly property bool styledShadow: effects.shadows && (preferences.shadow || style === "elevated" || style === "glass")
    readonly property bool styledBlur: effects.blur && (preferences.wallpaperBlur || style === "glass")
    readonly property color baseColor: preferences.backgroundColor || Color.background
    readonly property real surfaceOpacity: Math.max(preferences.backgroundOpacity,
        style === "high-contrast" ? 1 : style === "elevated" ? .98 : style === "glass" ? .28 : 0)
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
            color: Util.alpha(root.style === "high-contrast" ? Qt.rgba(.03,.047,.078,1) : root.style === "elevated" ? Qt.lighter(root.baseColor,1.65) : root.baseColor, root.surfaceOpacity)
            border.width: root.style === "classic" ? 0 : root.style === "high-contrast" ? 2 : 1
            border.color: root.style === "high-contrast" ? "#ffffff" : Util.alpha(Color.foreground, .35)
        }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            visible: root.style === "glass"
            gradient: Gradient {
                GradientStop { position:0; color:Util.alpha(Color.accent,.45) }
                GradientStop { position:1; color:Util.alpha(Color.foreground,.06) }
            }
            border.width:1; border.color:Util.alpha(Color.foreground,.65)
        }
        Rectangle {
            visible: root.style === "high-contrast"
            x:3; y:6; width:2; height:Math.max(0,parent.height-12); radius:1
            color:Color.accent
        }
    }
    Rectangle {
        id: roundedMask
        width: surface.width; height: surface.height; radius: surface.radius
        color: "white"; visible: false; layer.enabled: surface.layer.enabled
    }
}
