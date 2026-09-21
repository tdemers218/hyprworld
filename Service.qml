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
        Qt.resolvedUrl("bootstrap.py").toString().replace(/^file:\/\//, "")
    )

    function loadLayout() {
        if (loader.running) {
            root.loadPending = true
            return
        }
        loader.command = ["python3", root.bootstrapPath]
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
        }
    }

    Timer {
        id: loadTimer
        interval: 150
        onTriggered: root.loadLayout()
    }

    Process {
        id: loader
        onExited:function(code){if(code===0)startupTimer.restart()}

        onRunningChanged: {
            if (!running && root.loadPending) {
                root.loadPending = false
                loadTimer.restart()
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {var message=text.trim();if(message && message!=="ok")console.warn("Hyprworld:",message)}
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
