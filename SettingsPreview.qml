import QtQuick
import Quickshell
import qs.Commons
import "MinimapLayout.js" as MinimapLayout

Rectangle {
    id: root
    required property var preferences
    property bool overview: false
    property string wallpaper: ""
    color: Color.background; radius: Style.cornerRadius
    border.width: 1; border.color: Util.alpha(Color.foreground, 0.16); clip: true
    readonly property var boxes: [{x:0,y:0,w:310,h:200,name:"Browser",icon:"web-browser",context:"Research & reading"}, {x:326,y:0,w:190,h:200,name:"Terminal",icon:"utilities-terminal",context:"~/Projects"}, {x:0,y:216,w:310,h:140,name:"Files",icon:"system-file-manager",context:"Documents"}]
    Image { anchors.fill: parent; source: root.wallpaper ? "file://" + root.wallpaper : ""; fillMode: Image.PreserveAspectCrop; opacity: root.overview ? (root.preferences.overview.wallpaper ? 0.55 : 0) : 0.18 }
    Rectangle { anchors.fill: parent; color: Util.alpha(Color.background, root.overview ? 0.2 : 0.5) }
    Text { x: 12; y: 10; text: "SAMPLE WORKSPACE"; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: 9; font.letterSpacing: 1 }
    Rectangle {
        visible: !root.overview && root.preferences.minimap.placementMode === "fit"
        x:root.width*.4; y:root.height*.35; width:root.width*.55; height:root.height*.6
        radius:6; color:Util.alpha(Color.foreground,.06)
        border.color:Util.alpha(Color.foreground,.2)
        Text { anchors.centerIn:parent; text:"Focused window"; color:Color.foreground; opacity:.5; font.pixelSize:10 }
    }
    Item {
        id: map
        visible: !root.overview && root.preferences.minimap.enabled && fitted.visible
        readonly property var samplePrefs: Object.assign({}, root.preferences.minimap, {x:12+root.preferences.minimap.x*.2,y:28+root.preferences.minimap.y*.2})
        readonly property real naturalFactor: Math.min(root.preferences.minimap.width / 516, root.preferences.minimap.height / 356) * 0.4
        readonly property var fitted: MinimapLayout.fit(516*naturalFactor,356*naturalFactor,root.width,root.height,samplePrefs,
            {x:root.width*.4,y:root.height*.35,w:root.width*.55,h:root.height*.6})
        width: fitted.w; height: fitted.h; x: fitted.x; y: fitted.y
        readonly property real factor: naturalFactor*fitted.scale
        MinimapSurface { anchors.fill: parent; preferences: root.preferences.minimap; effects:root.preferences.effects; wallpaper: root.wallpaper }
        Repeater {
            model: root.boxes
            Rectangle { required property var modelData; required property int index
                x: modelData.x * map.factor; y: modelData.y * map.factor; width: modelData.w * map.factor; height: modelData.h * map.factor
                color: Util.alpha(Color.background,root.preferences.minimap.fillOpacity); radius: root.preferences.minimap.radius; opacity: root.preferences.minimap.opacity
                border.width: root.preferences.minimap.lineWidth + (index === 0 ? 1 : 0); border.color: index === 0 ? Color.accent : Color.foreground
            }
        }
    }
    Row {
        anchors.centerIn: parent; spacing: 10; visible: root.overview
        Repeater {
            model: root.boxes
            Rectangle { required property var modelData; required property int index
                width: (root.width - 64) / 3; height: Math.min(150,root.preferences.overview.cardHeight*.7); radius: root.preferences.overview.radius; color: Util.alpha(Color.background, root.preferences.overview.cardOpacity)
                border.width: 1; border.color: index === 0 ? Color.accent : Util.alpha(Color.foreground, 0.3)
                Image { visible:root.preferences.overview.showIcons;x: 12; y: 12; width: 24; height: 24; source: Quickshell.iconPath(modelData.icon, true) }
                Text { visible:root.preferences.overview.showAppNames;x: 12; y: 47; width: parent.width - 24; text: modelData.name; color: Color.foreground; font.family: Style.font.family; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                Text { visible:root.preferences.overview.showTitles;x: 12; y: 69; width: parent.width - 24; text: modelData.context; color: Color.muted; font.family: Style.font.family; font.pixelSize: 10; elide: Text.ElideRight }
            }
        }
    }
    Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; text: root.overview ? "App identity, without window content" : "Position & scale preview"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: 9 }
}
