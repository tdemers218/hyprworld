import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.tdemers218.hyprworld"
    property var monitorOrder: []
    readonly property string monitorName: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    readonly property int bank: monitorOrder.indexOf(monitorName)
    readonly property var monitor: Hyprland.monitors.values.find(function(m) { return m.name === root.monitorName }) || null
    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/hyprworld-monitors"
        watchChanges: true
        onLoaded: root.monitorOrder = text().trim().split(/\r?\n/)
        onFileChanged: reload()
    }
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight
    GridLayout {
        id: grid
        columns: root.vertical ? 1 : 5
        columnSpacing: root.vertical ? 0 : Style.space(1)
        rowSpacing: root.vertical ? Style.space(2) : 0
        Repeater {
            model: root.bank >= 0 ? 5 : 0
            WidgetButton {
                required property int index
                readonly property int workspaceId: root.bank*5+index+1
                readonly property var workspace: Hyprland.workspaces.values.find(function(w) { return w.id === workspaceId }) || null
                readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
                active: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === workspaceId
                useActiveColor: false
                bar: root.bar
                text: String(index+1)
                opacity: occupied || active ? 1 : 0.5
                horizontalMargin: 6
                verticalPadding: 6
                fixedWidth: root.vertical ? root.barSize : Style.space(20)
                fixedHeight: root.barSize
                Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 12; height: 2; radius: 1; color: Color.accent; visible: parent.active }
                onPressed: Hyprland.dispatch("hl.dsp.focus({workspace=" + JSON.stringify(String(workspaceId)) + "})")
            }
        }
    }
}
