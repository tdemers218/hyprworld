import QtQuick
import QtQuick.Controls
import qs.Commons
TextField {
    implicitHeight:36;color:Color.foreground;placeholderTextColor:Color.muted;font.pixelSize:12
    selectionColor:Color.accent;selectedTextColor:Color.background
    background:Rectangle {radius:7;color:Util.alpha(Color.foreground,.05);border.color:parent.activeFocus?Color.accent:Util.alpha(Color.foreground,.16)}
}
