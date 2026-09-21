import QtQuick
import Quickshell.Hyprland

QtObject {
    readonly property bool fullscreenActive: Hyprland.toplevels.values.some(function(t) {
        return !!(t.wayland && t.wayland.fullscreen)
            || !!(t.lastIpcObject && (Number(t.lastIpcObject.fullscreen) > 0 || Number(t.lastIpcObject.fullscreenClient) > 0))
    })
    // The snapshot can outlive focus, so observe all mapped screensaver windows
    // rather than the selected window or the last layout snapshot.
    readonly property bool screensaverActive: Hyprland.toplevels.values.some(function(t) {
        return (t.wayland && t.wayland.appId === "org.omarchy.screensaver")
            || (t.lastIpcObject && t.lastIpcObject.class === "org.omarchy.screensaver")
    })
}
