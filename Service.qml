import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    Preview {}
    Customizer { id: customizer }

    IpcHandler {
        target: "hyprworld"
        function toggleCustomizer(): void { customizer.toggle() }
        function openCustomizer(): void { customizer.opened = true }
        function closeCustomizer(): void { customizer.opened = false }
    }

    property bool loadPending: false
    readonly property string bootstrapPath: decodeURIComponent(
        Qt.resolvedUrl("integration/plugin.lua").toString().replace(/^file:\/\//, "")
    )

    function luaQuote(value) {
        return "\"" + value
            .replace(/\\/g, "\\\\")
            .replace(/\"/g, "\\\"")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r") + "\""
    }

    function loadLayout() {
        if (loader.running) {
            root.loadPending = true
            return
        }
        loader.command = ["hyprctl", "eval", "dofile(" + root.luaQuote(root.bootstrapPath) + ")"]
        loader.running = true
    }

    Component.onCompleted: loadTimer.start()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event && event.name === "configreloaded") loadTimer.restart()
        }
    }

    Timer {
        id: loadTimer
        interval: 150
        onTriggered: root.loadLayout()
    }

    Process {
        id: loader

        onRunningChanged: {
            if (!running && root.loadPending) {
                root.loadPending = false
                loadTimer.restart()
            }
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = text.trim()
                if (message) console.warn("Hyprworld:", message)
            }
        }
    }
}
