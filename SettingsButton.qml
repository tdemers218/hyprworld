import QtQuick
import QtQuick.Controls
import qs.Commons
Button {
    id:root
    implicitHeight:34;implicitWidth:contentItem.implicitWidth+24;hoverEnabled:true
    contentItem:Text {text:root.text;color:root.checked?Color.background:Color.foreground;font.pixelSize:12;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
    background:Rectangle {radius:7;color:root.checked?Color.accent:Util.alpha(Color.foreground,root.hovered?.12:.055);border.color:root.activeFocus?Color.accent:Util.alpha(Color.foreground,.16)}
    opacity:enabled?1:.4
    Accessible.name:text
}
