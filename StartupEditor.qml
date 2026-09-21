import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id: root
    required property var settings
    property int selected: 0
    property int previousCount:0
    onSettingsChanged:{
        if(settings.templates.length>previousCount)selected=settings.templates.length-1
        selected=Math.max(0,Math.min(selected,settings.templates.length-1))
        previousCount=settings.templates.length
    }
    signal edited(var value)
    signal captureRequested()
    signal launchRequested(int index)
    property bool canLaunch: false
    width: parent.width; spacing: 14
    readonly property var template: settings.templates[selected] || null
    function change(key,value) {var next=JSON.parse(JSON.stringify(settings));next.templates[selected][key]=value;edited(next)}
    function appChange(index,key,value) {var next=JSON.parse(JSON.stringify(settings));next.templates[selected].apps[index][key]=value;edited(next)}
    Text { width:parent.width;wrapMode:Text.Wrap;color:Color.muted;font.pixelSize:12
        text:"Start with a workspace you like: arrange its windows, then capture it below. Add launch commands, choose when it should open, and Apply to save your template." }
    SettingsSwitch { text:"Automatically open selected templates at login";checked:root.settings.enabled;onToggled:{var p=JSON.parse(JSON.stringify(root.settings));p.enabled=checked;root.edited(p)} }
    Flow { width:parent.width;spacing:6
        SettingsButton { text:"＋ Start empty";onClicked:{var p=JSON.parse(JSON.stringify(root.settings));p.templates.push({name:"Workspace "+(p.templates.length+1),workspace:p.templates.length+1,monitor:"",zoom:1,enabled:false,apps:[]});root.selected=p.templates.length-1;root.edited(p)} }
        SettingsButton { text:"▣ Use current workspace";onClicked:root.captureRequested() }
    }
    Text {visible:root.settings.templates.length===0;width:parent.width;wrapMode:Text.Wrap;color:Color.muted;text:"No saved workspaces yet. ‘Use current workspace’ copies window positions and app identifiers for you. Your open windows stay where they are."}
    ComboBox { width:parent.width;model:root.settings.templates.map(function(t){return t.name});currentIndex:root.selected;onActivated:root.selected=currentIndex;visible:count>0 }
    Column { width:parent.width;spacing:12;visible:root.template!==null
        Text {text:"1 · Name and destination";color:Color.accent;font.bold:true}
        SettingsTextField { width:parent.width;placeholderText:"Template name, e.g. Writing or Development";text:root.template?root.template.name:"";onTextEdited:root.change("name",text);Accessible.name:"Template name" }
        Row { spacing:10
            Text { text:"Workspace";color:Color.foreground;anchors.verticalCenter:parent.verticalCenter }
            SpinBox { from:1;to:10000;editable:true;value:root.template?root.template.workspace:1;onValueModified:root.change("workspace",value) }
            SettingsSwitch {text:"Include at login";checked:root.template?root.template.enabled:false;onToggled:root.change("enabled",checked)}
        }
        Text {visible:root.template && root.template.enabled && !root.settings.enabled;width:parent.width;wrapMode:Text.Wrap;color:Color.muted;text:"Enable automatic opening above to launch this template at login."}
        SettingsTextField {width:parent.width;placeholderText:"Preferred monitor (blank = compositor default)";text:root.template?root.template.monitor:"";onTextEdited:root.change("monitor",text);Accessible.name:"Preferred monitor"}
        Text {text:"Initial zoom · "+Math.round((root.template?root.template.zoom:1)*100)+"%";color:Color.foreground}
        SettingsSlider {width:parent.width;from:.65;to:1.25;stepSize:.05;value:root.template?root.template.zoom:1;onMoved:root.change("zoom",value);Accessible.name:"Startup zoom"}
        Text {text:"2 · Windows to open";color:Color.accent;font.bold:true}
        Text {width:parent.width;wrapMode:Text.Wrap;color:Color.muted;font.pixelSize:12;text:"The app identifier matches an existing window; the command opens it if needed. Capture fills identifiers automatically. Leave a command blank to reuse existing windows only."}
        Rectangle {
            width:parent.width;height:160;radius:10;color:Util.alpha(Color.foreground,.035);border.color:Util.alpha(Color.foreground,.12)
            readonly property var apps:root.template?root.template.apps:[]
            readonly property real minC:Math.min.apply(null,apps.map(function(a){return a.col}).concat([0]))
            readonly property real minR:Math.min.apply(null,apps.map(function(a){return a.row}).concat([0]))
            readonly property real spanC:Math.max.apply(null,apps.map(function(a){return a.col}).concat([0]))-minC+1
            readonly property real spanR:Math.max.apply(null,apps.map(function(a){return a.row}).concat([0]))-minR+1
            id:map
            Repeater {model:map.apps
                Rectangle {required property var modelData;required property int index
                    x:10+(modelData.col-map.minC)*(map.width-20)/map.spanC;y:10+(modelData.row-map.minR)*140/map.spanR
                    width:(map.width-20)/map.spanC-6;height:140/map.spanR-6;radius:6;color:Util.alpha(Color.accent,.12);border.color:Color.accent
                    Text {anchors.centerIn:parent;width:parent.width-12;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;color:Color.foreground
                        text:map.apps.filter(function(a){return a.col===modelData.col&&a.row===modelData.row}).map(function(a){return a.class||"New app"}).join(" + ")}
                }
            }
            Text {visible:map.apps.length===0;anchors.centerIn:parent;text:"Add an app to see its position";color:Color.muted}
        }
        Repeater { model:root.template?root.template.apps.length:0
            Column { required property int index; readonly property var modelData: root.template.apps[index] || {class:"",command:"",col:0,row:0};width:parent.width;spacing:6
                Text {text:"Window "+(index+1)+(modelData.class?" · "+modelData.class:"");color:Color.accent;font.bold:true}
                Text {text:"App identifier";color:Color.muted;font.pixelSize:11}
                SettingsTextField { width:parent.width;placeholderText:"Exact app class, e.g. kitty";text:modelData.class;onTextEdited:root.appChange(index,"class",text);Accessible.name:"App class" }
                Text {text:"Command to launch";color:Color.muted;font.pixelSize:11}
                SettingsTextField { width:parent.width;placeholderText:"Launch command, e.g. kitty --title Research";text:modelData.command;onTextEdited:root.appChange(index,"command",text);Accessible.name:"Launch command" }
                Flow {width:parent.width;spacing:8
                    Text {text:"Column →";color:Color.muted;height:32;verticalAlignment:Text.AlignVCenter}
                    SpinBox {from:-32;to:32;value:modelData.col;onValueModified:root.appChange(index,"col",value);Accessible.name:"Column"}
                    Text {text:"Row ↓";color:Color.muted;height:32;verticalAlignment:Text.AlignVCenter}
                    SpinBox {from:-32;to:32;value:modelData.row;onValueModified:root.appChange(index,"row",value);Accessible.name:"Row"}
                    SettingsButton {text:"Remove";Accessible.name:"Remove app";onClicked:{var p=JSON.parse(JSON.stringify(root.settings));p.templates[root.selected].apps.splice(index,1);root.edited(p)}}
                }
            }
        }
        Text {width:parent.width;wrapMode:Text.Wrap;color:Color.muted;font.pixelSize:12;text:"Positions start at column 0, row 0. Increase the column to move right or the row to move down. Give windows the same column and row to group them (up to four)."}
        Text {text:"3 · Save and try";color:Color.accent;font.bold:true}
        Flow {width:parent.width;spacing:6
            SettingsButton {text:"＋ App";onClicked:{var p=JSON.parse(JSON.stringify(root.settings));p.templates[root.selected].apps.push({class:"",command:"",col:p.templates[root.selected].apps.length,row:0});root.edited(p)}}
            SettingsButton {text:"▶ Open workspace now";enabled:root.canLaunch;onClicked:root.launchRequested(root.selected)}
            SettingsButton {text:"Delete template";onClicked:{var p=JSON.parse(JSON.stringify(root.settings));p.templates.splice(root.selected,1);root.selected=Math.max(0,root.selected-1);root.edited(p)}}
        }
        Text {width:parent.width;wrapMode:Text.Wrap;text:root.canLaunch?"Existing matching windows are reused. Unrelated windows stay in place.":"Apply your changes before launching this template.";color:Color.muted;font.pixelSize:11}
    }
}
