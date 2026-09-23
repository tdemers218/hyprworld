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
    property bool checkpointPending: false
    Timer {
        id: checkpointTimer; interval: 1500
        onTriggered: {
            if (checkpointWriter.running) root.checkpointPending = true
            else checkpointWriter.running = true
        }
    }
    Process {
        id: checkpointWriter
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("checkpoint.py").toString().replace(/^file:\/\//, ""))]
        onExited: function(code) {
            if (code === 75 || root.checkpointPending) {
                root.checkpointPending = false; checkpointTimer.restart()
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn(text.trim()) }
    }
    function loadLayout() {
        if (loader.running) {
            root.loadPending = true
            return
        }
        loader.command = ["python3", decodeURIComponent(Qt.resolvedUrl("bootstrap.py").toString().replace(/^file:\/\//, ""))]
        loader.running = true
    }

    Component.onCompleted: loadTimer.start()
    Timer { id: startupTimer; interval: 2500; onTriggered: startup.running=true }
    Process { id: startup; command:["python3",decodeURIComponent(Qt.resolvedUrl("startup.py").toString().replace(/^file:\/\//,"")),"autostart"]
        stdout: StdioCollector { onStreamFinished: { if(text.indexOf('"error"')>=0) console.warn("Hyprworld startup:",text) } }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event && event.name === "configreloaded") loadTimer.restart()
            if (event && event.name === "custom" && event.data === "hyprworld-state") checkpointTimer.restart()
        }
    }

    Timer {
        id: loadTimer
        interval: 150
        onTriggered: root.loadLayout()
    }

    Process {
        id: loader
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) { startupTimer.restart(); checkpointTimer.restart() }
            else console.warn("Hyprworld: layout was not loaded; inspect bootstrap errors and retry after fixing build dependencies")
        }

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
