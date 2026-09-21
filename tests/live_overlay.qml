import Quickshell
import Quickshell.Io
import ".." as Plugin

ShellRoot {
    Plugin.OverlayState { id: state }
    IpcHandler {
        target: "overlayTest"
        function active(): string { return state.screensaverActive ? "true" : "false" }
    }
}
