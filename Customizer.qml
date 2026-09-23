import qs.Commons
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Settings.js" as Settings
import "Search.js" as Search

Item {
    id: root
    property bool opened: false
    property string monitorName: ""
    property int section: 0
    property var settings: Settings.defaults()
    property var saved: Settings.defaults()
    property var submitted: ({})
    property bool busy: false
    property bool loaded: false
    property bool reloadNeeded: false
    property bool restartNeeded: false
    property bool checkOnly: false
    property string status: ""
    property bool failed: false
    property string wallpaper: ""
    readonly property bool dirty: JSON.stringify(settings) !== JSON.stringify(saved)
    property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/hyprworld.json"
    readonly property var sections: Settings.sections()
    readonly property string sectionId: sections[section].id
    property string query: ""
    property string capturing: ""
    property string captureHint: ""
    property var keyNames: ({})
    property var bindingConflicts: ({})
    function displayShortcut(chord) {
        return String(chord || "").replace(/code:(\d+)/gi,function(match,code){return root.keyNames[code] || match})
    }
    function readableError(message) {
        var text=message || ""
        Settings.shortcutRows().forEach(function(row){text=text.replace(new RegExp("\\b"+row.id+"\\b","g"),row.label)})
        return text
    }
    function clearConflicts(){bindingConflicts=({})}
    onSectionChanged:capturing=""
    property string shortcutQuery: ""
    property bool advanced: false
    property string shortcutFilter: "all"
    readonly property var visibleFields: Settings.fields().filter(function(f) {
        return (root.query.trim() ? Search.score(root.query,f)>=0 : f.section===root.sectionId) && (!f.advanced || root.advanced || !!root.query.trim())
    })
    readonly property var shortcutRows: Settings.shortcutRows().filter(function(r) {
        var entry={action:r.label,binding:root.displayShortcut(root.settings.shortcuts[r.id]),category:r.id.indexOf("pan")===0?"workspace":r.id,aliases:r.id.indexOf("move")===0?"swap group detach":""}
        return Search.score(root.shortcutQuery,entry)>=0 && (root.shortcutFilter!=="customized" || root.settings.shortcuts[r.id]!==r.key)
    })
    function replaceSection(group,value) {var next=JSON.parse(JSON.stringify(settings));next[group]=value;settings=next;status="";failed=false}
    onOpenedChanged: {capturing=""; if (opened) {
        monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name
        if (!closeOverview.running) closeOverview.running = true
        settingsFile.reload()
        if(!keyNameReader.running)keyNameReader.running=true
        if (!wallpaperReader.running) wallpaperReader.running = true
    }
    }
    function toggle() { opened = !opened }
    function update(group, key, value) {
        var next = JSON.parse(JSON.stringify(settings)); next[group][key] = value
        settings = next; status = ""; failed = false
        if(group==="shortcuts")clearConflicts()
    }
    function revert() { clearConflicts(); settings = JSON.parse(JSON.stringify(saved)); status = ""; failed = false }
    function resetSection() {
        clearConflicts()
        var group = sectionId
        var next = JSON.parse(JSON.stringify(settings)); next[group] = Settings.defaults()[group]; settings = next
        status = "Defaults restored in this section. Apply to save."; failed = false
    }
    function apply() {
        if (!loaded || busy || !dirty) return
        submitted = Settings.normalize(settings)
        var templates=submitted.startup.templates
        for(var i=0;i<templates.length;i++) {
            var counts={}
            for(var j=0;j<templates[i].apps.length;j++) {
                var app=templates[i].apps[j],key=app.col+":"+app.row
                counts[key]=(counts[key]||0)+1
                if(counts[key]>4){status="A startup tile can hold at most four windows.";failed=true;return}
                if(!app.class.trim()){status="Enter an app class for every startup window.";failed=true;return}
            }
        }
        checkOnly = false
        restartNeeded = submitted.plugin.enabled !== saved.plugin.enabled
        reloadNeeded = JSON.stringify(submitted.shortcuts) !== JSON.stringify(saved.shortcuts) || restartNeeded
        busy = true; failed = false; status = "Checking settings…"
        if (reloadNeeded && submitted.plugin.enabled) bindingCheck.running = true
        else if (JSON.stringify(submitted.shortcuts) !== JSON.stringify(saved.shortcuts)) bindingCheck.running = true
        else writeSettings()
    }
    function checkShortcuts() {
        if (busy) return
        submitted = Settings.normalize(settings); checkOnly = true; busy = true; failed = false
        status = "Checking all active shortcuts…"; bindingCheck.running = true
    }
    function writeSettings() { status = "Saving…"; settingsFile.setText(JSON.stringify(submitted, null, 2) + "\n") }
    Process { id: closeOverview; command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "eval", 'if __hyprworld_overview_active and __hyprworld_overview_active() then hl.dispatch(hl.dsp.layout("overview-close")) end'] }
    Process {
        id: wallpaperReader
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
        stdout: StdioCollector { onStreamFinished: root.wallpaper = text.trim() }
    }
    Timer { interval: 1500; repeat: true; running: root.opened; onTriggered: if (!wallpaperReader.running) wallpaperReader.running = true }
    FileView {
        id: settingsFile
        path: root.settingsPath; watchChanges: true; atomicWrites: true; printErrors: false
        onLoaded: {
            if (root.busy) return
            try {
                var value = Settings.normalize(JSON.parse(text()))
                if (!root.dirty) root.settings = value
                root.saved = value; root.loaded = true
            } catch (e) { root.status = "Settings file is invalid. Correct it before saving."; root.failed = true; root.loaded = false }
        }
        onLoadFailed: { root.status = "Settings file is unavailable. Enable the plugin integration first."; root.failed = true; root.loaded = false }
        onFileChanged: if (!root.busy) reload()
        onSaved: {
            if (!root.busy) return
            root.saved = JSON.parse(JSON.stringify(root.submitted)); root.settings = root.saved
            if (root.reloadNeeded) { root.status = "Applying shortcuts…"; reloadBindings.running = true }
            else { root.busy = false; root.status = "Saved · changes are active"; applyMouse.running = true }
        }
        onSaveFailed: { root.busy = false; root.failed = true; root.status = "Could not save. Your changes are still here; try again." }
    }
    Process {
        id:keyNameReader
        command:["python3",decodeURIComponent(Qt.resolvedUrl("validate-shortcuts.py").toString().replace(/^file:\/\//,"")),"--keynames"]
        stdout:StdioCollector {onStreamFinished:{try{var names=JSON.parse(text);if(!names.error)root.keyNames=names}catch(e){}}}
    }
    Process {
        id: bindingCheck
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("validate-shortcuts.py").toString().replace(/^file:\/\//, "")), JSON.stringify(root.submitted.shortcuts)]
        stdout: StdioCollector { id: bindingOutput }
        onExited: function(code) {
            var error = "Could not check shortcuts. Try again."
            if (code === 0) { try {
                var result = JSON.parse(bindingOutput.text); error = root.readableError(result.error);var conflicts=result.conflicts || ({});Object.keys(conflicts).forEach(function(id){conflicts[id]=root.readableError(conflicts[id])});root.bindingConflicts=conflicts
                if (!error) root.submitted.shortcuts = result.shortcuts
            } catch (e) {} }
            if (error) { root.busy = false; root.failed = true; root.status = error }
            else if (root.checkOnly) { root.busy = false; root.status = "No conflicts with active Omarchy or plugin shortcuts." }
            else root.writeSettings()
        }
    }
    Process {
        id: reloadBindings; command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "reload"]
        onExited: function(code) {
            if (code === 0) checkErrors.running = true
            else { root.busy = false; root.failed = true; root.status = "Saved, but shortcut reload failed. Run hyprctl reload to retry." }
        }
    }
    Process {
        id: checkErrors; command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "configerrors"]
        stdout: StdioCollector { id: errorOutput }
        onExited: function(code) {
            root.busy = false; root.failed = code !== 0 || errorOutput.text.trim().length > 0
            root.status = root.failed ? "Saved; Hyprland reports configuration errors. Check hyprctl configerrors." : "Saved · changes are active"
            if (!root.failed && root.restartNeeded) restartShell.running = true
        }
    }
    Process { id: applyMouse; command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "eval", "if __hyprworld_apply_mouse then __hyprworld_apply_mouse() end; hl.dispatch(hl.dsp.layout(\"refresh\"))"] }
    Process { id: restartShell; command: ["timeout", "--kill-after=1s", "5s", "hyprctl", "dispatch", 'hl.dsp.exec_cmd("omarchy restart shell")'] }

    Process {
        id: startupCommand
        property bool capturing: false
        stdout: StdioCollector { id: startupOutput }
        onExited: function(code) {
            root.busy=false
            try {
                var value=JSON.parse(startupOutput.text)
                if(code!==0 || value.error) {root.failed=true;root.status=value.error || "Template action failed";return}
                if(capturing) {var p=JSON.parse(JSON.stringify(root.settings.startup));p.templates.push(value);root.replaceSection("startup",p);root.status="Captured. Add launch commands before enabling startup."}
                else root.status="Template launched · existing windows reused"
            } catch(e) {root.failed=true;root.status="Could not read template result"}
        }
    }
    function templateAction(action,index) {
        if(busy)return
        startupCommand.capturing=action==="capture"
        startupCommand.command=["python3",decodeURIComponent(Qt.resolvedUrl("startup.py").toString().replace(/^file:\/\//,"")),action,"--settings",settingsPath,"--index",String(index||0)]
        busy=true;startupCommand.running=true
    }
    component Label: Text {color:Color.foreground;font.family:Style.font.family;font.pixelSize:13;textFormat:Text.PlainText}
    component Action: Button {
        id:button
        property bool primary:false
        property string glyph:""
        implicitHeight:36;implicitWidth:contentItem.implicitWidth+24
        hoverEnabled:true
        contentItem:Label {text:button.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;color:button.primary?Color.background:Color.foreground}
        background:Rectangle {radius:8;color:button.primary?Color.accent:Util.alpha(Color.foreground,button.hovered?.12:.055);border.color:button.activeFocus?Color.accent:Util.alpha(Color.foreground,.12)}
        opacity:enabled?1:.4
        Accessible.name:text
    }
    Variants {
        model:Quickshell.screens
        delegate:Component {
            PanelWindow {
                id:panel
                required property var modelData
                screen:modelData
                visible:root.opened && root.monitorName===modelData.name
                anchors {top:true;bottom:true;left:true;right:true}
                color:"transparent";exclusionMode:ExclusionMode.Ignore
                WlrLayershell.namespace:"hyprworld-customizer"
                WlrLayershell.layer:WlrLayer.Overlay
                WlrLayershell.keyboardFocus:visible?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
                ShortcutInhibitor {window:panel;enabled:panel.visible && root.capturing!=="";onCancelled:root.capturing=""}
                Rectangle {
                    anchors.fill:parent;color:Util.alpha(Color.background,.65)
                    focus:panel.visible
                    Keys.onEscapePressed:root.opened=false
                    Keys.onPressed:function(event){if(event.modifiers & Qt.ControlModifier && event.key===Qt.Key_S){root.apply();event.accepted=true}}
                    MouseArea {anchors.fill:parent;onClicked:root.opened=false}
                    Rectangle {
                        id:card
                        anchors.centerIn:parent;width:Math.min(1240,parent.width-32);height:Math.min(850,parent.height-32)
                        radius:18;color:Color.background;border.color:Util.alpha(Color.foreground,.18)
                        MouseArea {anchors.fill:parent}
                        readonly property int rail:width<900?164:208
                        readonly property bool wide:width>=1080
                        readonly property bool showPreview:wide && !root.query.trim() && (root.sectionId==="minimap" || root.sectionId==="overview")
                        property real previewWidth:showPreview?300:0
                        Behavior on previewWidth {NumberAnimation {duration:root.settings.effects.animations ? 220 : 0;easing.type:Easing.InOutCubic}}
                        Label {x:24;y:22;text:"Hyprworld";font.pixelSize:23;font.bold:true}
                        Label {x:24;y:53;width:card.rail-28;elide:Text.ElideRight;text:"Make space for your flow";font.pixelSize:11;color:Color.muted}
                        SettingsTextField {
                            x:card.rail+20;y:24;width:parent.width-x-72;height:38
                            placeholderText:"Search settings…";text:root.query;onTextEdited:root.query=text
                            color:Color.foreground;Accessible.name:"Search all settings"
                            background:Rectangle {radius:8;color:Util.alpha(Color.foreground,.05);border.color:parent.activeFocus?Color.accent:Util.alpha(Color.foreground,.15)}
                        }
                        Action {anchors.right:parent.right;anchors.top:parent.top;anchors.margins:24;width:36;text:"×";Accessible.name:"Close settings";onClicked:root.opened=false}
                        Rectangle {x:card.rail;y:88;width:1;height:parent.height-160;color:Util.alpha(Color.foreground,.1)}
                        ScrollView {
                            x:12;y:98;width:card.rail-24;height:card.height-252;clip:true;contentWidth:availableWidth
                            ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                            Column { width:parent.width;spacing:5
                            Repeater {
                                model:root.sections
                                Button {
                                    id:nav
                                    required property var modelData
                                    required property int index
                                    width:parent.width;height:46
                                    onClicked:{root.section=index;root.query=""}
                                    hoverEnabled:true
                                    Accessible.name:modelData.title
                                    background:Rectangle {radius:9;color:root.section===nav.index?Util.alpha(Color.accent,.15):nav.hovered?Util.alpha(Color.foreground,.05):"transparent"}
                                    contentItem:Row {spacing:10
                                        SettingsIcon {width:20;height:20;anchors.verticalCenter:parent.verticalCenter;kind:nav.modelData.id;ink:root.section===nav.index?Color.accent:Color.foreground}
                                        Label {width:nav.width-52;anchors.verticalCenter:parent.verticalCenter;text:nav.modelData.title;wrapMode:Text.Wrap;font.pixelSize:12;color:root.section===nav.index?Color.accent:Color.foreground}
                                    }
                                }
                            }
                        }
                        }
                        Label {x:24;y:parent.height-126;width:card.rail-40;text:root.dirty?"● Unsaved changes":"✓ All changes saved";color:root.dirty?Color.accent:Color.muted;font.pixelSize:11;wrapMode:Text.Wrap}
                        Label {x:24;y:parent.height-105;width:card.rail-30;wrapMode:Text.Wrap;text:"Ctrl+S  Apply  ·  Esc  Close";font.pixelSize:10;color:Color.muted}
                        Item {
                            id:body
                            x:card.rail+24;y:92;width:card.width-x-24-card.previewWidth;height:card.height-y-90
                            Label {text:root.query.trim()?"Search results":root.sections[root.section].title;font.pixelSize:24;font.bold:true}
                            Label {y:36;width:parent.width;text:root.query.trim()?root.visibleFields.length+" matching controls":root.sections[root.section].description;color:Color.muted;font.pixelSize:12;wrapMode:Text.Wrap}
                            ScrollView {
                                id:scroll;x:0;y:68;width:parent.width;height:parent.height-y;clip:true;contentWidth:availableWidth
                                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                                Connections {target:root;function onSectionChanged(){scroll.contentItem.contentY=0}}
                                Column {
                                    width:scroll.availableWidth;spacing:20;enabled:!root.busy
                                    SettingsPreview {visible:!card.wide && (root.sectionId==="minimap" || root.sectionId==="overview");width:parent.width;height:180;preferences:root.settings;overview:root.sectionId==="overview";wallpaper:root.wallpaper}
                                    SettingsSwitch {visible:!root.query.trim() && ["minimap","overview","workflow"].indexOf(root.sectionId)>=0;text:"Advanced controls";checked:root.advanced;onToggled:root.advanced=checked}
                                    Repeater {
                                        model:root.visibleFields
                                        Column {
                                            required property var modelData
                                            required property int index
                                            width:parent.width;spacing:12
                                            Label {visible:index===0 || root.visibleFields[index-1].group!==modelData.group || !!root.query.trim();text:(root.query.trim()?modelData.section+" / ":"")+modelData.group;color:Color.accent;font.pixelSize:11;font.bold:true;font.capitalization:Font.AllUppercase}
                                            SettingRow {width:parent.width;field:modelData;preferences:root.settings[modelData.section];onEdited:function(key,value){root.update(modelData.section,key,value)}}
                                            Rectangle {width:parent.width;height:1;color:Util.alpha(Color.foreground,.07)}
                                        }
                                    }
                                    ArrangementEditor {visible:root.sectionId==="placement" && !root.query.trim();width:parent.width;settings:root.settings.placement;mode:"placement";onEdited:function(value){root.replaceSection("placement",value)}}
                                    ArrangementEditor {visible:root.sectionId==="groups" && !root.query.trim();width:parent.width;settings:root.settings.groups;mode:"groups";onEdited:function(value){root.replaceSection("groups",value)}}
                                    StartupEditor {visible:root.sectionId==="startup" && !root.query.trim();width:parent.width;settings:root.settings.startup;canLaunch:!root.dirty && !root.busy && root.settings.plugin.enabled;onEdited:function(value){root.replaceSection("startup",value)};onCaptureRequested:root.templateAction("capture",0);onLaunchRequested:function(index){root.templateAction("launch",index)}}
                                    Column {
                                        visible:root.sectionId==="shortcuts" && !root.query.trim();width:parent.width;spacing:14
                                        SettingsTextField {width:parent.width;height:40;placeholderText:"Find an action or key combination…";text:root.shortcutQuery;onTextEdited:root.shortcutQuery=text;Accessible.name:"Fuzzy shortcut search"}
                                        Flow {width:parent.width;spacing:6
                                            Action {text:"All actions";primary:root.shortcutFilter==="all";onClicked:root.shortcutFilter="all"}
                                            Action {text:"Customized";primary:root.shortcutFilter==="customized";onClicked:root.shortcutFilter="customized"}

                                        }
                                        Button {
                                            id:checkButton;text:root.busy?"Checking…":"Check conflicts";implicitWidth:190;implicitHeight:42
                                            enabled:!root.busy;hoverEnabled:true;onClicked:root.checkShortcuts()
                                            contentItem:Row {spacing:12
                                                Label {text:"✓";font.pixelSize:18;color:Color.background;anchors.verticalCenter:parent.verticalCenter}
                                                Label {text:checkButton.text;color:Color.background;anchors.verticalCenter:parent.verticalCenter;font.bold:true}
                                            }
                                            background:Rectangle {radius:5;color:checkButton.down?Qt.darker(Color.accent,1.2):checkButton.hovered?Qt.lighter(Color.accent,1.12):Color.accent;border.width:checkButton.activeFocus?2:0;border.color:Color.foreground}
                                            opacity:enabled?1:.5
                                        }
                                        Label {text:root.shortcutRows.length+" actions";color:Color.muted;font.pixelSize:11}
                                        Repeater {
                                            model:root.shortcutRows.length
                                            Column {
                                                required property int index
                                                readonly property var modelData:root.shortcutRows[index] || {id:"",label:"",key:""}
                                                width:parent.width;spacing:6
                                                Label {text:modelData.label;font.bold:true}
                                                Label {visible:!!root.bindingConflicts[modelData.id];width:parent.width;wrapMode:Text.Wrap;text:root.bindingConflicts[modelData.id] || "";color:"#ef4444";font.pixelSize:11}
                                                Row {width:parent.width;spacing:8
                                                    SettingsTextField {width:parent.width-156;height:38;text:root.displayShortcut(root.settings.shortcuts[modelData.id]);
                                                        background:Rectangle {radius:7;color:Util.alpha(Color.foreground,.05);border.width:root.bindingConflicts[modelData.id]?2:1;border.color:root.bindingConflicts[modelData.id]?"#ef4444":parent.activeFocus?Color.accent:Util.alpha(Color.foreground,.16)}
                                                        onTextEdited:root.update("shortcuts",modelData.id,text);Accessible.name:modelData.label+" binding"}
                                                    Action {text:"● Capture";width:100;onClicked:{root.capturing=modelData.id;root.captureHint="";captureBox.forceActiveFocus()}}
                                                    Action {text:"↺";width:40;Accessible.name:"Restore "+modelData.label;onClicked:root.update("shortcuts",modelData.id,modelData.key)}
                                                }
                                            }
                                        }
                                    }
                                    Column {visible:root.sectionId==="plugin" && !root.query.trim();width:parent.width;spacing:12
                                        Label {width:parent.width;wrapMode:Text.Wrap;color:Color.muted;text:"Appearance and Flow changes apply live. Shortcut changes reload Hyprland. In-memory groups reset on a compositor configuration reload."}
                                        Label {text:"Credits";font.pixelSize:18;font.bold:true}
                                        Label {width:parent.width;wrapMode:Text.Wrap;text:"Hyprworld builds on Hyprscroll 2D by kirollosatef. Thank you to the original author and the Omarchy community.";color:Color.muted}
                                        Action {text:"Original plugin ↗";onClicked:Qt.openUrlExternally("https://plugins.omarchy.org/plugin.html?id=io.github.kirollosatef.hyprworld")}
                                        Action {text:"Refresh shell";enabled:!root.dirty && !root.busy;onClicked:restartShell.running=true}
                                    }
                                    Item {width:1;height:12}
                                }
                            }
                        }
                        Item {
                            visible:card.previewWidth>0;x:card.width-card.previewWidth-4;y:102;width:card.previewWidth-20;height:card.height-200;clip:true
                            opacity:card.showPreview?1:0
                            Behavior on opacity {NumberAnimation {duration:root.settings.effects.animations ? 180 : 0}}
                            Column {width:280;spacing:16
                                Label {text:"PREVIEW";font.pixelSize:10;font.letterSpacing:1.5;color:Color.muted}
                                SettingsPreview {width:parent.width;height:240;preferences:root.settings;overview:root.sectionId==="overview";wallpaper:root.wallpaper}
                                Label {width:parent.width;wrapMode:Text.Wrap;text:"Preview uses sample windows. Your desktop changes only after Apply.";color:Color.muted;font.pixelSize:12}
                            }
                        }
                        Rectangle {
                            id:captureBox;z:20;anchors.fill:parent;radius:18;visible:root.capturing!=="";color:Color.background
                            property string pending:""
                            onVisibleChanged: {pending="";if(visible)forceActiveFocus()}
                            MouseArea {anchors.fill:parent}
                            Keys.onPressed:function(event) {
                                event.accepted=true
                                if(event.isAutoRepeat)return
                                if(event.key===Qt.Key_Escape){root.capturing="";return}
                                if([Qt.Key_Control,Qt.Key_Shift,Qt.Key_Alt,Qt.Key_Meta,Qt.Key_AltGr].indexOf(event.key)>=0)return
                                var mods=[]
                                if(event.modifiers&Qt.MetaModifier)mods.push("SUPER")
                                if(event.modifiers&Qt.ControlModifier)mods.push("CTRL")
                                if(event.modifiers&Qt.AltModifier)mods.push("ALT")
                                if(event.modifiers&Qt.ShiftModifier)mods.push("SHIFT")
                                if(!event.nativeScanCode){root.captureHint="Could not read that key. Try another key or enter it manually.";return}
                                pending=mods.concat(["code:"+event.nativeScanCode]).join(" + ")
                                var names=Object.assign({},root.keyNames)
                                if(event.key>=Qt.Key_A && event.key<=Qt.Key_Z)names[String(event.nativeScanCode)]=String.fromCharCode(event.key)
                                else if(event.key>=Qt.Key_0 && event.key<=Qt.Key_9)names[String(event.nativeScanCode)]=String.fromCharCode(event.key)
                                else if(event.key>=Qt.Key_F1 && event.key<=Qt.Key_F35)names[String(event.nativeScanCode)]="F"+(event.key-Qt.Key_F1+1)
                                root.keyNames=names
                                root.captureHint=root.displayShortcut(pending)+" — release the key to finish"
                            }
                            Keys.onReleased:function(event){event.accepted=true;if(pending && [Qt.Key_Control,Qt.Key_Shift,Qt.Key_Alt,Qt.Key_Meta,Qt.Key_AltGr].indexOf(event.key)<0){root.update("shortcuts",root.capturing,pending);root.capturing=""}}
                            Column {anchors.centerIn:parent;width:parent.width-80;spacing:18
                                Label {text:"Press your shortcut";font.pixelSize:24;font.bold:true}
                                Label {width:parent.width;wrapMode:Text.Wrap;text:"Hold the modifiers, press a key, then release. Esc cancels. The physical key is recorded so keyboard layout changes keep the same position.";color:Color.muted}
                                Label {text:root.captureHint || "Waiting for keys…";color:Color.accent}
                                Action {text:"Cancel";onClicked:root.capturing=""}
                            }
                        }
                        Rectangle {x:20;y:parent.height-76;width:parent.width-40;height:1;color:Util.alpha(Color.foreground,.12)}
                        Action {x:20;y:parent.height-57;text:"↺ Section defaults";enabled:!root.busy;onClicked:root.resetSection()}
                        Label {x:210;y:parent.height-61;width:parent.width-420;height:50;wrapMode:Text.Wrap;font.pixelSize:11;color:root.failed?Color.urgent:Color.muted;text:root.status || (root.dirty?"Draft changes · Apply when ready":"All changes saved")}
                        Row {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:20;spacing:8
                            Action {text:"Revert";enabled:root.dirty && !root.busy;onClicked:root.revert()}
                            Action {text:root.busy?"Applying…":"Apply";primary:true;enabled:root.dirty && !root.busy && root.loaded;onClicked:root.apply()}
                        }
                    }
                }
            }
        }
    }
}
