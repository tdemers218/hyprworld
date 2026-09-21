import QtQuick
import QtQuick.Controls
import qs.Commons
import "Settings.js" as Settings

Column {
    id: root
    required property var settings
    property string mode: "placement"
    property int groupCount: 2
    property int selected: 0
    readonly property bool customPath: mode === "placement" && settings.preset === "custom"
    readonly property bool master: mode === "groups" && settings.layouts[String(groupCount)].mode.indexOf("master") === 0
    function step(dx,dy) {
        if (!customPath) return
        var p=JSON.parse(JSON.stringify(settings)),n=p.nodes[Math.min(selected,p.nodes.length-1)]
        var col=n.col+dx,row=n.row+dy
        var found=p.nodes.findIndex(function(v){return v.col===col&&v.row===row})
        if(found>=0){selected=found;return}
        if(p.nodes.length>=64 || Math.abs(col)>32 || Math.abs(row)>32)return
        p.nodes.push({col:col,row:row,capacity:1});selected=p.nodes.length-1;edited(p)
    }
    signal edited(var value)
    width: parent.width; spacing: 16
    function change(key,value) { var p=JSON.parse(JSON.stringify(settings));p[key]=value;edited(p) }
    function changeNode(key,value) { var p=JSON.parse(JSON.stringify(settings));p.nodes[selected][key]=value;edited(p) }
    function changeGroup(key,value) { var p=JSON.parse(JSON.stringify(settings));p.layouts[String(groupCount)][key]=value;edited(p) }
    Text { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; font.pixelSize: 12
        text: root.mode === "placement" ? "Choose a straight path or draw your own. New windows fill tiles in numbered order. Select any tile, then click a + to grow a branch from it." : "Choose how groups of 2, 3 or 4 windows look. In a master layout, window 1 gets the larger area; drag its divider to resize it." }
    SettingsSwitch { visible: root.mode === "placement"; text: "Use a default placement path"; checked: root.settings.enabled || false; onToggled: root.change("enabled",checked) }
    Column { visible:root.mode === "placement";width:parent.width;spacing:8
        Text {text:"Use this path on";color:Color.foreground}
        Row {spacing:6
            SettingsButton {text:"All workspaces";checkable:true;checked:root.settings.scope!=="specific";onClicked:root.change("scope","all")}
            SettingsButton {text:"Specific workspaces";checkable:true;checked:root.settings.scope==="specific";onClicked:root.change("scope","specific")}
        }
        SettingsTextField {id:workspaceList;visible:root.settings.scope==="specific";width:parent.width;placeholderText:"Workspace numbers, e.g. 1, 2, 5";Binding {target:workspaceList;property:"text";value:(root.settings.workspaces||[]).join(", ");when:!workspaceList.activeFocus}
            Accessible.name:"Workspaces using this path"
            onTextEdited:root.change("workspaces",text.split(/[,\s]+/).map(Number).filter(function(n){return Number.isInteger(n)&&n>0&&n<=10000}))
        }
        Text {visible:root.settings.scope==="specific";width:parent.width;wrapMode:Text.Wrap;color:Color.muted;font.pixelSize:12;text:"Other workspaces keep their normal window placement. An empty list applies this path nowhere."}
    }
    Flow { width: parent.width; spacing: 6
        Repeater { model: root.mode === "placement" ? ["horizontal","vertical","custom"] : ["2","3","4"]
            SettingsButton { required property string modelData; text: root.mode === "placement" ? modelData : modelData + " windows"
                checkable: true; checked: root.mode === "placement" ? root.settings.preset === modelData : root.groupCount === Number(modelData)
                onClicked: { root.selected=0; if(root.mode === "placement") root.change("preset",modelData); else root.groupCount=Number(modelData) }
            }
        }
    }
    Rectangle {
        id: diagram; objectName:root.mode+"Canvas"; width: parent.width; height: root.mode === "placement" ? 300 : 220;
        activeFocusOnTab: root.customPath
        Keys.onPressed:function(event) {
            var dirs={};dirs[Qt.Key_Left]=[-1,0];dirs[Qt.Key_Right]=[1,0];dirs[Qt.Key_Up]=[0,-1];dirs[Qt.Key_Down]=[0,1]
            if(root.customPath && dirs[event.key]) {root.step(dirs[event.key][0],dirs[event.key][1]);event.accepted=true}
        } radius: 12
        color: Util.alpha(Color.foreground,.035); border.color: activeFocus ? Color.accent : Util.alpha(Color.foreground,.12); clip: true
        readonly property var nodes: root.mode === "placement" ? (root.settings.preset === "custom" ? root.settings.nodes : [0,1,2,3].map(function(i){return {col:root.settings.preset === "horizontal" ? i : 0,row:root.settings.preset === "vertical" ? i : 0,capacity:1}})) : []
        readonly property real minC: Math.min.apply(null,nodes.map(function(n){return n.col}).concat([0]))
        readonly property real minR: Math.min.apply(null,nodes.map(function(n){return n.row}).concat([0]))
        readonly property real maxC: Math.max.apply(null,nodes.map(function(n){return n.col}).concat([0]))
        readonly property real maxR: Math.max.apply(null,nodes.map(function(n){return n.row}).concat([0]))
        readonly property real cell: Math.min(64,(width-32)/(maxC-minC+3),(height-32)/(maxR-minR+3))
        Repeater { model: diagram.nodes
            Rectangle { required property var modelData; required property int index
                x:16+(modelData.col-diagram.minC+1)*diagram.cell; y:16+(modelData.row-diagram.minR+1)*diagram.cell
                width:diagram.cell-8;height:diagram.cell-8;radius:7
                color: Util.alpha(Color.accent,index===root.selected?.24:.07);border.color: index===root.selected ? Color.accent : Color.muted
                Text { anchors.centerIn: parent; text:(index+1)+(modelData.capacity>1 ? "\n▥ ×"+modelData.capacity : "");color:Color.foreground;horizontalAlignment:Text.AlignHCenter;font.pixelSize:12 }
                MouseArea { anchors.fill: parent; onClicked: {root.selected=index;diagram.forceActiveFocus()} }
            }
        }
        Repeater {model:root.customPath?[{dx:-1,dy:0},{dx:1,dy:0},{dx:0,dy:-1},{dx:0,dy:1}]:[]
            SettingsButton {
                required property var modelData
                readonly property var node:root.settings.nodes[Math.min(root.selected,root.settings.nodes.length-1)]
                readonly property int col:node.col+modelData.dx
                readonly property int row:node.row+modelData.dy
                visible:!root.settings.nodes.some(function(n){return n.col===col&&n.row===row})
                x:16+(col-diagram.minC+1)*diagram.cell;y:16+(row-diagram.minR+1)*diagram.cell
                width:diagram.cell-8;height:diagram.cell-8;text:"+"
                Accessible.name:"Extend path "+(modelData.dx<0?"left":modelData.dx>0?"right":modelData.dy<0?"up":"down")
                onClicked:{root.step(modelData.dx,modelData.dy);diagram.forceActiveFocus()}
            }
        }
        Repeater { model: root.mode === "groups" ? Settings.groupRects(root.groupCount,root.settings.layouts[String(root.groupCount)]) : []
            Rectangle { required property var modelData; required property int index
                x:16+modelData.x*(diagram.width-32);y:16+modelData.y*(diagram.height-32)
                width:modelData.w*(diagram.width-32)-6;height:modelData.h*(diagram.height-32)-6;radius:7
                color:Util.alpha(Color.accent,index===0?.22:.07);border.color:index===0?Color.accent:Color.muted
                Text { anchors.centerIn:parent;text:String(index+1);color:Color.foreground;font.pixelSize:24 }
            }
        }
            MouseArea {
            visible:root.mode === "groups" && root.settings.layouts[String(root.groupCount)].mode.indexOf("master")===0
            readonly property bool vertical:root.mode === "groups" && root.settings.layouts[String(root.groupCount)].mode!=="master-top"
            readonly property real ratio:root.mode === "groups"?root.settings.layouts[String(root.groupCount)].ratio:.5
            readonly property real divider:root.mode === "groups" && root.settings.layouts[String(root.groupCount)].mode==="master-right"?1-ratio:ratio
            x:vertical?16+divider*(diagram.width-32)-7:16;y:vertical?16:16+ratio*(diagram.height-32)-7
            width:vertical?14:diagram.width-32;height:vertical?diagram.height-32:14
            cursorShape:vertical?Qt.SplitHCursor:Qt.SplitVCursor
            onPositionChanged:function(mouse){if(pressed){var p=mapToItem(diagram,mouse.x,mouse.y);root.changeGroup("ratio",Math.max(.2,Math.min(.8,vertical?(root.settings.layouts[String(root.groupCount)].mode==="master-right"?1-(p.x-16)/(diagram.width-32):(p.x-16)/(diagram.width-32)):(p.y-16)/(diagram.height-32))))}}
        }
    }

    Column { visible: root.mode === "placement" && root.settings.preset === "custom"; width: parent.width; spacing: 12
        Flow { width: parent.width; spacing: 6
            SettingsButton { text:"Remove selected tile"; Accessible.name:"Remove selected path tile"; enabled:!!root.settings.nodes && root.settings.nodes.length>1
                onClicked:{var p=JSON.parse(JSON.stringify(root.settings));p.nodes.splice(root.selected,1);root.selected=Math.max(0,root.selected-1);root.edited(p)} }
        }
        Row { spacing: 12
            Text { text:"Group size";color:Color.foreground;anchors.verticalCenter:parent.verticalCenter }
            SpinBox { from:1;to:4;value:root.settings.nodes && root.settings.nodes[Math.min(root.selected,root.settings.nodes.length-1)] ? root.settings.nodes[Math.min(root.selected,root.settings.nodes.length-1)].capacity : 1; onValueModified:root.changeNode("capacity",value) }
            SettingsButton { text:"↑ Order";enabled:root.selected>0;onClicked:{var p=JSON.parse(JSON.stringify(root.settings));var n=p.nodes.splice(root.selected,1)[0];p.nodes.splice(root.selected-1,0,n);root.selected--;root.edited(p)} }
        }
    }
    Text {visible:root.customPath;width:parent.width;wrapMode:Text.Wrap;color:Color.muted;font.pixelSize:12;text:"Click the canvas or Tab to focus it, then use arrow keys to extend the path or select a neighboring tile. Group size sets how many windows share the selected tile (1–4)."}
    SettingsSwitch { visible:root.mode === "placement";text:"Fill vacancies before extending";checked:root.settings.fillHoles!==false;onToggled:root.change("fillHoles",checked) }
    Flow { visible:root.mode === "placement";width:parent.width;spacing:6
        SettingsButton {text:"Extend when full";checkable:true;checked:root.settings.overflow==="extend";onClicked:root.change("overflow","extend")}
        SettingsButton {text:"Repeat the pattern";checkable:true;checked:root.settings.overflow==="repeat";onClicked:root.change("overflow","repeat")}
    }
    Flow { visible:root.mode === "groups";width:parent.width;spacing:6
        Repeater {model:["columns","rows","grid","master-left","master-right","master-top"]
            SettingsButton {required property string modelData;text:modelData.replace(/-/g," ");checkable:true;checked:root.mode === "groups" && root.settings.layouts[String(root.groupCount)].mode===modelData;onClicked:root.changeGroup("mode",modelData)}
        }
    }
    SettingsSlider { visible:root.master;enabled:root.mode === "groups" && root.settings.layouts[String(root.groupCount)].mode.indexOf("master")===0
        width:parent.width;from:.2;to:.8;stepSize:.01;value:root.mode === "groups"?root.settings.layouts[String(root.groupCount)].ratio:.5
        Accessible.name:"Master window proportion";onMoved:root.changeGroup("ratio",value)
    }
}
