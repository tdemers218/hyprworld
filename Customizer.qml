import qs.Commons
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Settings.js" as Settings

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
    readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/hyprworld.json"
    readonly property var titles: ["Minimap", "Overview", "Mouse", "Shortcuts", "Plugin"]
    readonly property var descriptions: ["A quiet guide to your workspace.", "See every window. Keep your place.", "Choose how the pointer focuses windows.", "Remap every action. Check before applying.", "Manage the layout and refresh the shell."]
    onOpenedChanged: if (opened) {
        monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name
        if (!closeOverview.running) closeOverview.running = true
        settingsFile.reload()
        if (!wallpaperReader.running) wallpaperReader.running = true
    }
    function toggle() { opened = !opened }
    function update(group, key, value) {
        var next = JSON.parse(JSON.stringify(settings)); next[group][key] = value
        settings = next; status = ""; failed = false
    }
    function revert() { settings = JSON.parse(JSON.stringify(saved)); status = ""; failed = false }
    function resetSection() {
        var group = ["minimap", "overview", "workflow", "shortcuts", "plugin"][section]
        var next = JSON.parse(JSON.stringify(settings)); next[group] = Settings.defaults()[group]; settings = next
        status = "Defaults restored in this section. Apply to save."; failed = false
    }
    function apply() {
        if (!loaded || busy || !dirty) return
        submitted = Settings.normalize(settings)
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
    Process { id: closeOverview; command: ["hyprctl", "eval", 'if __hyprworld_overview_active and __hyprworld_overview_active() then hl.dispatch(hl.dsp.layout("overview-close")) end'] }
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
        onLoadFailed: { root.status = "Cannot read settings: " + root.settingsPath; root.failed = true; root.loaded = false }
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
        id: bindingCheck
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("validate-shortcuts.py").toString().replace(/^file:\/\//, "")), JSON.stringify(root.submitted.shortcuts)]
        stdout: StdioCollector { id: bindingOutput }
        onExited: function(code) {
            var error = "Could not check shortcuts. Try again."
            if (code === 0) { try {
                var result = JSON.parse(bindingOutput.text); error = result.error
                if (!error) root.submitted.shortcuts = result.shortcuts
            } catch (e) {} }
            if (error) { root.busy = false; root.failed = true; root.status = error }
            else if (root.checkOnly) { root.busy = false; root.status = "No conflicts with active Omarchy or plugin shortcuts." }
            else root.writeSettings()
        }
    }
    Process {
        id: reloadBindings; command: ["hyprctl", "reload"]
        onExited: function(code) {
            if (code === 0) checkErrors.running = true
            else { root.busy = false; root.failed = true; root.status = "Saved, but shortcut reload failed. Run hyprctl reload to retry." }
        }
    }
    Process {
        id: checkErrors; command: ["hyprctl", "configerrors"]
        stdout: StdioCollector { id: errorOutput }
        onExited: function(code) {
            root.busy = false; root.failed = code !== 0 || errorOutput.text.trim().length > 0
            root.status = root.failed ? "Saved; Hyprland reports configuration errors. Check hyprctl configerrors." : "Saved · changes are active"
            if (!root.failed && root.restartNeeded) restartShell.running = true
        }
    }
    Process { id: applyMouse; command: ["hyprctl", "eval", "if __hyprworld_apply_mouse then __hyprworld_apply_mouse() end"] }
    Process { id: restartShell; command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("omarchy restart shell")'] }

    component Label: Text {
        color: Color.foreground; font.family: Style.font.family; font.pixelSize: 13
        textFormat: Text.PlainText
    }
    component Action: Button {
        id: button
        property bool primary: false
        implicitHeight: 36; implicitWidth: contentItem.implicitWidth + 28
        hoverEnabled: true; opacity: enabled ? 1 : 0.4
        contentItem: Label { text: button.text; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: button.primary ? Color.background : Color.foreground }
        background: Rectangle {
            radius: Style.cornerRadius; color: button.primary ? Color.accent : Util.alpha(Color.foreground, button.hovered ? 0.12 : 0.05)
            border.width: 1; border.color: button.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.15)
        }
    }
    component Range: Column {
        id: range
        property string title
        property string group
        property string field
        property real low: 0
        property real high: 100
        property real step: 1
        property string unit: " px"
        property real multiplier: 1
        property int decimals: 0
        width: parent.width; spacing: 4
        Row {
            width: parent.width
            Label { text: range.title; width: parent.width - 90 }
            Label { width: 90; horizontalAlignment: Text.AlignRight; color: Color.accent; text: (root.settings[range.group][range.field] * range.multiplier).toFixed(range.decimals) + range.unit }
        }
        Slider {
            id: slider; width: parent.width; height: 28
            from: range.low; to: range.high; stepSize: range.step
            value: root.settings[range.group][range.field]
            onMoved: root.update(range.group, range.field, value)
            background: Rectangle { x: slider.leftPadding; y: (slider.height - height) / 2; width: slider.availableWidth; height: 4; radius: 2; color: Util.alpha(Color.foreground, 0.12)
                Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: Color.accent }
            }
            handle: Rectangle { x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width); y: (slider.height - height) / 2; width: 14; height: 14; radius: 7; color: Color.accent; border.width: slider.activeFocus ? 2 : 0; border.color: Color.foreground }
            Accessible.name: range.title
        }
    }
    component Toggle: Switch {
        id: toggle
        width: parent.width; implicitHeight: 40
        contentItem: Label { text: toggle.text; verticalAlignment: Text.AlignVCenter; rightPadding: 60 }
        indicator: Rectangle {
            x: toggle.width - width; y: (toggle.height - height) / 2; width: 38; height: 22; radius: 11
            color: toggle.checked ? Color.accent : Util.alpha(Color.foreground, 0.2)
            border.width: toggle.activeFocus ? 1 : 0; border.color: Color.foreground
            Rectangle { x: toggle.checked ? 19 : 3; y: 3; width: 16; height: 16; radius: 8; color: toggle.checked ? Color.background : Color.foreground; Behavior on x { NumberAnimation { duration: 120 } } }
        }
    }
    component Shortcut: Column {
        id: shortcut
        property string title
        property string field
        width: parent.width; spacing: 8
        Label { text: shortcut.title }
        Row {
            width: parent.width
            spacing: 6
            TextField {
                width: parent.width - 106; height: 38
                text: root.settings.shortcuts[shortcut.field]
                onTextEdited: root.update("shortcuts", shortcut.field, text)
                color: Color.foreground; selectionColor: Color.accent; selectedTextColor: Color.background
                font.family: Style.font.family; font.pixelSize: 12
                placeholderText: "SUPER + CTRL + H"; placeholderTextColor: Color.muted
                background: Rectangle { radius: Style.cornerRadius; color: Util.alpha(Color.foreground, 0.04); border.width: 1; border.color: parent.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.2) }
                Accessible.name: shortcut.title
            }
            Action { text: "Default"; width: 100; onClicked: root.update("shortcuts", shortcut.field, Settings.defaults().shortcuts[shortcut.field]) }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panel
                required property var modelData
                screen: modelData
                visible: root.opened && root.monitorName === modelData.name
                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"; exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "hyprworld-customizer"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                Rectangle {
                    anchors.fill: parent; color: Util.alpha(Color.background, 0.55)
                    focus: panel.visible
                    Keys.onEscapePressed: root.opened = false
                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) { root.apply(); event.accepted = true }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.opened = false }
                    Rectangle {
                        id: card
                        anchors.centerIn: parent; width: Math.min(920, parent.width - 40); height: Math.min(680, parent.height - 64)
                        radius: Style.cornerRadius; color: Color.background; border.width: 1; border.color: Util.alpha(Color.accent, 0.4)
                        MouseArea { anchors.fill: parent }
                        Label { x: 26; y: 24; text: "Hyprworld"; font.pixelSize: 23; font.bold: true }
                        Label { x: 26; y: 57; text: "WORKSPACE SETTINGS"; font.pixelSize: 10; font.letterSpacing: 1.5; color: Color.muted }
                        Action { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 22; text: "Close  ×"; onClicked: root.opened = false }
                        Rectangle { x: 24; y: 91; width: parent.width - 48; height: 1; color: Util.alpha(Color.foreground, 0.12) }
                        Column {
                            x: 18; y: 112; width: 178; spacing: 8
                            Repeater {
                                model: root.titles
                                Action { required property string modelData; required property int index; width: parent.width; text: modelData; primary: root.section === index; onClicked: root.section = index }
                            }
                        }
                        Label { x: 26; y: parent.height - 156; width: 174; text: root.saved.shortcuts.settings + "\nSettings\n\nEsc · Close / Ctrl S · Apply"; color: Color.muted; font.pixelSize: 10; wrapMode: Text.Wrap }
                        Rectangle { x: 214; y: 112; width: 1; height: parent.height - 202; color: Util.alpha(Color.foreground, 0.1) }
                        Label { x: 240; y: 110; text: root.titles[root.section]; font.pixelSize: 21; font.bold: true }
                        Label { x: 240; y: 146; text: root.descriptions[root.section]; color: Color.muted }
                        SettingsPreview {
                            x: 240; y: 179; width: parent.width - 268; height: 164
                            visible: root.section < 2; overview: root.section === 1
                            preferences: root.settings; wallpaper: root.wallpaper
                        }
                        ScrollView {
                            id: scroll
                            x: 240; y: root.section < 2 ? 357 : 185; width: parent.width - 268; height: parent.height - y - 90; clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Util.alpha(Color.foreground, 0.3) }
                            }
                            Connections { target: root; function onSectionChanged() { scroll.contentItem.contentY = 0 } }
                            Column {
                                width: scroll.availableWidth; spacing: 16
                                enabled: !root.busy
                                Column {
                                    width: parent.width; spacing: 12; visible: root.section === 0
                                    Toggle { text: "Show minimap when zoomed out"; checked: root.settings.minimap.enabled; onToggled: root.update("minimap", "enabled", checked) }
                                    Label { width: parent.width; wrapMode: Text.Wrap; text: "Hidden with one window, at full zoom, and in overview. Window positions and proportions match the workspace."; color: Color.muted; font.pixelSize: 11 }
                                    Row { spacing: 6
                                        Repeater {
                                            model: ["top-left", "top-right", "bottom-left", "bottom-right"]
                                            Action {
                                                required property string modelData
                                                text: modelData.replace("-", " "); primary: root.settings.minimap.corner === modelData
                                                onClicked: root.update("minimap", "corner", modelData)
                                            }
                                        }
                                    }
                                    Range { title: "Horizontal inset"; group: "minimap"; field: "x"; high: 240 }
                                    Range { title: "Vertical inset"; group: "minimap"; field: "y"; high: 240 }
                                    Range { title: "Maximum width"; group: "minimap"; field: "width"; low: 100; high: 440 }
                                    Range { title: "Maximum height"; group: "minimap"; field: "height"; low: 60; high: 280 }
                                    Range { title: "Outline opacity"; group: "minimap"; field: "opacity"; low: 0.1; high: 1; step: 0.01; multiplier: 100; unit: "%" }
                                    Range { title: "Outline weight"; group: "minimap"; field: "lineWidth"; low: 1; high: 3 }
                                }
                                Column {
                                    width: parent.width; spacing: 16; visible: root.section === 1
                                    Range { title: "Zoom transition · 0 disables animation"; group: "overview"; field: "animationMs"; high: 900; step: 10; unit: " ms" }
                                    Toggle { text: "Use current Omarchy wallpaper"; checked: root.settings.overview.wallpaper; onToggled: root.update("overview", "wallpaper", checked) }
                                    Range { title: "Card opacity"; group: "overview"; field: "cardOpacity"; low: 0.3; high: 1; step: 0.01; multiplier: 100; unit: "%" }
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "Zoom past the lowest level to enter overview. Use arrows to navigate, click a card to select, or press Esc to return." }
                                }
                                Column {
                                    width: parent.width; spacing: 20; visible: root.section === 2
                                    Toggle { text: "Keep windows connected"; checked: root.settings.workflow.keepConnected; onToggled: root.update("workflow", "keepConnected", checked) }
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "After movement stops, animate all separated tiles back into a connected layout, including focused windows. Groups stay intact." }
                                    Range { enabled: root.settings.workflow.keepConnected; opacity: enabled ? 1 : .4; title: "Compact after movement stops"; group: "workflow"; field: "compactDelayMs"; low: 100; high: 30000; step: 100; multiplier: 0.001; decimals: 1; unit: " s" }
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "Default: 5 seconds. Each move restarts the wait, and held drags pause it. Turn off Keep windows connected to disable compaction." }
                                    Row { spacing: 8
                                        Action { text: "Autofocus on hover"; primary: root.settings.workflow.focusMode === "auto"; onClicked: root.update("workflow", "focusMode", "auto") }
                                        Action { text: "Click to focus"; primary: root.settings.workflow.focusMode === "click"; onClicked: root.update("workflow", "focusMode", "click") }
                                    }
                                    Rectangle { width: parent.width; height: 112; radius: Style.cornerRadius; color: Util.alpha(Color.accent, 0.07)
                                        Column { anchors.fill: parent; anchors.margins: 18; spacing: 10
                                            Label { text: "Pause the camera, not the group."; font.bold: true }
                                            Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "Fully visible windows focus immediately without moving the camera. The hover pause starts only when focus pans the workspace. Clicks and keyboard navigation stay immediate." }
                                        }
                                    }
                                    Range { enabled: root.settings.workflow.focusMode === "auto"; opacity: enabled ? 1 : .4; title: "Pause after camera movement"; group: "workflow"; field: "mouseCooldownMs"; high: 1500; step: 25; unit: " ms" }
                                    Row { spacing: 8
                                        Action { text: "Off"; onClicked: root.update("workflow", "mouseCooldownMs", 0) }
                                        Action { text: "Quick · 300 ms"; onClicked: root.update("workflow", "mouseCooldownMs", 300) }
                                        Action { text: "Relaxed · 550 ms"; onClicked: root.update("workflow", "mouseCooldownMs", 550) }
                                    }
                                    Label { width: parent.width; wrapMode: Text.Wrap; text: "Hold Super: middle-drag pans the camera, scroll zooms, and left-drag moves a window. Drop on a highlighted window to create or extend a group; a full group swaps places."; color: Color.muted }
                                }
                                Column {
                                    width: parent.width; spacing: 24; visible: root.section === 3
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "Type modifiers + key, such as SUPER + CTRL + H. Key names, code:NN and mouse:NNN are supported. Apply checks duplicates and active Omarchy bindings before saving." }
                                    Action { text: "Check all shortcuts"; onClicked: root.checkShortcuts() }
                                    Repeater { model: Settings.shortcutRows(); Shortcut { required property var modelData; title: modelData.label; field: modelData.id } }
                                }
                                Column {
                                    width: parent.width; spacing: 20; visible: root.section === 4
                                    Toggle { text: "Enable Hyprworld"; checked: root.settings.plugin.enabled; onToggled: root.update("plugin", "enabled", checked) }
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: "Apply switches your configured workspaces between Hyprworld and Omarchy’s normal layout, then refreshes the shell. Settings remain available so you can turn it back on." }
                                    Action { text: "Refresh shell"; enabled: !root.dirty && !root.busy; onClicked: restartShell.running = true }
                                    Label { width: parent.width; wrapMode: Text.Wrap; color: Color.muted; text: root.dirty ? "Apply or revert your edits before refreshing the shell." : "Saved preferences survive a shell refresh. Layout groups last until Hyprland configuration is reloaded." }
                                }
                                Action { text: "Restore section defaults"; onClicked: root.resetSection() }
                                Item { width: 1; height: 8 }
                            }
                        }
                        Rectangle { x: 24; y: parent.height - 76; width: parent.width - 48; height: 1; color: Util.alpha(Color.foreground, 0.12) }
                        Label { x: 26; y: parent.height - 61; width: parent.width - 266; height: 48; wrapMode: Text.Wrap; font.pixelSize: 11; color: root.failed ? Color.urgent : Color.muted; text: root.status || (root.dirty ? "Unsaved changes · preview updates as you edit" : "Using your Omarchy theme · all changes saved") }
                        Row { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22; spacing: 8
                            Action { text: "Revert"; enabled: root.dirty && !root.busy; onClicked: root.revert() }
                            Action { text: root.busy ? "Applying…" : "Apply"; primary: true; enabled: root.dirty && !root.busy && root.loaded; onClicked: root.apply() }
                        }
                    }
                }
            }
        }
    }
}
