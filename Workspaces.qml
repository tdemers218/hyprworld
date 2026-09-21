import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as WorkspaceModel

BarWidget {
    id: root
    moduleName: "io.github.tdemers218.hyprworld"
    readonly property string monitorName: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    readonly property var monitor: Hyprland.monitors.values.find(function(m) { return m.name === root.monitorName }) || null
    readonly property var workspaceIds: WorkspaceModel.ids(Hyprland.workspaces.values, root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : 0)
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight
    GridLayout {
        id: grid
        columns: root.vertical ? 1 : Math.max(5, root.workspaceIds.length)
        columnSpacing: root.vertical ? 0 : Style.space(1)
        rowSpacing: root.vertical ? Style.space(2) : 0
        Repeater {
            model: root.workspaceIds
            WidgetButton {
                required property int modelData
                readonly property int workspaceId: modelData
                readonly property var workspace: Hyprland.workspaces.values.find(function(w) { return w.id === workspaceId }) || null
                readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
                active: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === workspaceId
                useActiveColor: false
                bar: root.bar
                text: String(workspaceId)
                opacity: occupied || active ? 1 : 0.5
                horizontalMargin: 6
                verticalPadding: 6
                fixedWidth: root.vertical ? root.barSize : Style.space(20)
                fixedHeight: root.barSize
                Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 12; height: 2; radius: 1; color: Color.accent; visible: parent.active }
                onPressed: Quickshell.execDetached(["hyprctl", "eval", "if __hyprworld_workspace_nav then __hyprworld_workspace_nav.select(" + workspaceId + ") end"])
            }
        }
    }
}
